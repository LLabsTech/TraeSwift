import Foundation

protocol Agent {
    var name: String { get }
    var systemPrompt: String { get }
    var tools: [Tool] { get }
    var llmClient: LLMClient { get }
    var config: FullConfig { get }
    
    func run(task: String) async throws -> String
    func runWithConsole(task: String, console: CLIConsole?, trajectoryRecorder: TrajectoryRecorder?) async throws -> String
}

class BaseAgent: Agent {
    let name: String
    let systemPrompt: String
    let tools: [Tool]
    let llmClient: LLMClient
    let config: FullConfig
    
    private var messages: [Message] = []
    private var state: AgentState = .thinking
    private var currentStepNumber: Int = 0
    private var agentSteps: [AgentStep] = []
    private var startTime: Date?
    private var errorReflectionSystem: ErrorReflectionSystem
    private var errorHistory: [Error] = []
    
    init(name: String, systemPrompt: String, tools: [Tool], llmClient: LLMClient, config: FullConfig) {
        self.name = name
        self.systemPrompt = systemPrompt
        self.tools = tools
        self.llmClient = llmClient
        self.config = config
        self.errorReflectionSystem = ErrorReflectionSystem(llmClient: llmClient)
    }
    
    func run(task: String) async throws -> String {
        return try await runWithConsole(task: task, console: nil, trajectoryRecorder: nil)
    }
    
    func runWithConsole(task: String, console: CLIConsole?, trajectoryRecorder: TrajectoryRecorder?) async throws -> String {
        // Initialize execution
        startTime = Date()
        currentStepNumber = 0
        agentSteps = []
        state = .thinking
        
        // Initialize conversation with system prompt and user task
        messages = [
            Message(role: .system, content: systemPrompt),
            Message(role: .user, content: task)
        ]
        
        let maxSteps = config.maxSteps
        var finalResult = ""
        var totalUsage = ChatCompletionResponse.Usage(promptTokens: 0, completionTokens: 0, totalTokens: 0)
        
        // Display task details if console is available
        if let console = console {
            await console.printTaskDetails(
                task: task,
                workingDirectory: FileManager.default.currentDirectoryPath,
                provider: config.defaultProvider,
                model: config.modelProviders[config.defaultProvider]?.model ?? "unknown",
                maxSteps: maxSteps,
                configPath: nil,
                trajectoryPath: nil
            )
            await console.start()
        }
        
        // Create initial execution state
        var agentExecution = AgentExecution(
            task: task,
            steps: [],
            finalResult: nil,
            success: false,
            totalTokens: nil,
            executionTime: 0,
            status: "running",
            currentStep: 0,
            maxSteps: maxSteps,
            startTime: startTime,
            result: nil,
            tokenUsage: totalUsage
        )
        
        while state != .completed && state != .error && currentStepNumber < maxSteps {
            currentStepNumber += 1
            
            do {
                // Create current step
                var currentStep = AgentStep(
                    stepNumber: currentStepNumber,
                    state: .thinking,
                    thought: nil,
                    toolCalls: nil,
                    toolResults: nil,
                    llmResponse: nil,
                    reflection: nil,
                    error: nil,
                    extra: nil,
                    llmUsage: nil
                )
                
                // Update execution
                agentExecution = AgentExecution(
                    task: task,
                    steps: agentSteps,
                    finalResult: finalResult.isEmpty ? nil : finalResult,
                    success: state == .completed,
                    totalTokens: nil,
                    executionTime: startTime?.timeIntervalSinceNow.magnitude ?? 0,
                    status: state == .completed ? "completed" : state == .error ? "error" : "running",
                    currentStep: currentStepNumber,
                    maxSteps: maxSteps,
                    startTime: startTime,
                    result: finalResult.isEmpty ? nil : finalResult,
                    tokenUsage: totalUsage
                )
                
                // Update console
                if let console = console {
                    await console.updateStatus(agentStep: currentStep, agentExecution: agentExecution)
                }
                
                // THINKING STATE - Get LLM response
                state = .thinking
                currentStep = AgentStep(
                    stepNumber: currentStepNumber,
                    state: .thinking,
                    thought: "Getting LLM response...",
                    toolCalls: nil,
                    toolResults: nil,
                    llmResponse: nil,
                    reflection: nil,
                    error: nil,
                    extra: nil,
                    llmUsage: nil
                )
                
                let defaultProvider = config.modelProviders[config.defaultProvider]
                let response = try await llmClient.chat(
                    messages: messages,
                    tools: tools.map { $0.toToolDefinition() },
                    temperature: defaultProvider?.temperature,
                    maxTokens: defaultProvider?.maxTokens
                )
                
                guard let choice = response.choices.first else {
                    throw LLMError.invalidResponse
                }
                
                // Update usage
                if let usage = response.usage {
                    totalUsage = ChatCompletionResponse.Usage(
                        promptTokens: totalUsage.promptTokens + usage.promptTokens,
                        completionTokens: totalUsage.completionTokens + usage.completionTokens,
                        totalTokens: totalUsage.totalTokens + usage.totalTokens
                    )
                }
                
                let assistantMessage = choice.message
                let llmResponse = LLMResponse(
                    content: assistantMessage.content ?? "",
                    usage: nil,
                    model: nil,
                    finishReason: choice.finishReason,
                    toolCalls: assistantMessage.toolCalls
                )
                
                // Add assistant response to messages
                messages.append(Message(
                    role: .assistant,
                    content: assistantMessage.content ?? "",
                    toolCalls: assistantMessage.toolCalls
                ))
                
                // Update step with LLM response
                currentStep = AgentStep(
                    stepNumber: currentStepNumber,
                    state: .thinking,
                    thought: "Received LLM response",
                    toolCalls: assistantMessage.toolCalls,
                    toolResults: nil,
                    llmResponse: llmResponse,
                    reflection: nil,
                    error: nil,
                    extra: nil,
                    llmUsage: nil
                )
                
                // Check if the assistant wants to use tools
                if let toolCalls = assistantMessage.toolCalls, !toolCalls.isEmpty {
                    // CALLING_TOOL STATE
                    state = .callingTool
                    currentStep = AgentStep(
                        stepNumber: currentStepNumber,
                        state: .callingTool,
                        thought: "Executing \(toolCalls.count) tool call(s)",
                        toolCalls: toolCalls,
                        toolResults: nil,
                        llmResponse: llmResponse,
                        reflection: nil,
                        error: nil,
                        extra: nil,
                        llmUsage: nil
                    )
                    
                    // Update console with tool calling state
                    if let console = console {
                        await console.updateStatus(agentStep: currentStep, agentExecution: agentExecution)
                    }
                    
                    // Execute tool calls
                    var toolResults: [ToolResult] = []
                    let shouldExecuteParallel = defaultProvider?.parallelToolCalls ?? false
                    
                    if shouldExecuteParallel && toolCalls.count > 1 {
                        // Parallel execution
                        toolResults = try await executeToolCallsParallel(toolCalls)
                    } else {
                        // Sequential execution
                        toolResults = try await executeToolCallsSequential(toolCalls)
                    }
                    
                    // Add tool results to messages
                    for result in toolResults {
                        messages.append(Message(
                            role: .user,
                            content: result.content,
                            toolCallId: result.toolCallId
                        ))
                    }
                    
                    // Update step with tool results
                    currentStep = AgentStep(
                        stepNumber: currentStepNumber,
                        state: .callingTool,
                        thought: "Completed tool execution",
                        toolCalls: toolCalls,
                        toolResults: toolResults,
                        llmResponse: llmResponse,
                        reflection: nil,
                        error: nil,
                        extra: nil,
                        llmUsage: nil
                    )
                    
                    // REFLECTING STATE (optional)
                    let reflection = try await generateReflection(toolResults: toolResults)
                    if !reflection.isEmpty {
                        state = .reflecting
                        currentStep = AgentStep(
                            stepNumber: currentStepNumber,
                            state: .reflecting,
                            thought: "Reflecting on tool results",
                            toolCalls: toolCalls,
                            toolResults: toolResults,
                            llmResponse: llmResponse,
                            reflection: reflection,
                            error: nil,
                            extra: nil,
                            llmUsage: nil
                        )
                        
                        // Add reflection to conversation
                        messages.append(Message(role: .assistant, content: reflection))
                    }
                    
                    state = .thinking
                } else {
                    // No tool calls, check if task is complete
                    if isTaskComplete(assistantMessage.content ?? "") {
                        state = .completed
                        finalResult = assistantMessage.content ?? "Task completed"
                        
                        currentStep = AgentStep(
                            stepNumber: currentStepNumber,
                            state: .completed,
                            thought: "Task completed successfully",
                            toolCalls: nil,
                            toolResults: nil,
                            llmResponse: llmResponse,
                            reflection: nil,
                            error: nil,
                            extra: nil,
                            llmUsage: nil
                        )
                    } else {
                        // Continue conversation
                        messages.append(Message(
                            role: .user,
                            content: "Please continue with the task or provide more details about your progress."
                        ))
                    }
                }
                
                // Record step
                agentSteps.append(currentStep)
                trajectoryRecorder?.recordAgentStep(step: currentStep)
                
                // Update console with final step state
                if let console = console {
                    await console.updateStatus(agentStep: currentStep, agentExecution: agentExecution)
                }
                
            } catch {
                // Add error to history for pattern analysis
                errorHistory.append(error)
                
                // Create error context for reflection
                let errorContext = ErrorContext(
                    currentTask: task,
                    currentStep: currentStepNumber,
                    lastToolUsed: agentSteps.last?.toolCalls?.first?.function.name,
                    executionTime: startTime?.timeIntervalSinceNow.magnitude ?? 0,
                    previousErrors: errorHistory
                )
                
                // Perform error reflection
                do {
                    let reflection = try await errorReflectionSystem.reflectOnError(
                        error: error,
                        context: errorContext,
                        attempt: errorHistory.count
                    )
                    
                    // Create enhanced error step with reflection
                    let errorStep = AgentStep(
                        stepNumber: currentStepNumber,
                        state: .error,
                        thought: "Error occurred during execution - analyzing for recovery",
                        toolCalls: nil,
                        toolResults: nil,
                        llmResponse: nil,
                        reflection: reflection.suggestion,
                        error: error.localizedDescription,
                        extra: [
                            "error_type": "\(reflection.errorType)",
                            "should_retry": "\(reflection.shouldRetry)",
                            "retry_delay": reflection.retryDelay?.description ?? "nil",
                            "recovery_actions": reflection.recoveryActions.map { "\($0.type)" }.joined(separator: ", ")
                        ],
                        llmUsage: nil
                    )
                    
                    agentSteps.append(errorStep)
                    trajectoryRecorder?.recordAgentStep(step: errorStep)
                    
                    if let console = console {
                        await console.updateStatus(agentStep: errorStep, agentExecution: agentExecution)
                    }
                    
                    // Attempt recovery if suggested
                    if reflection.shouldRetry && currentStepNumber < maxSteps - 1 {
                        print("🔄 Attempting error recovery: \(reflection.suggestion)")
                        
                        // Execute recovery actions
                        _ = try await errorReflectionSystem.executeRetry(reflection: reflection) {
                            // Continue execution by moving to next iteration
                            return "Recovery attempted"
                        }
                        
                        // Add recovery message to conversation
                        messages.append(Message(
                            role: .assistant,
                            content: "I encountered an error but I'm attempting to recover: \(reflection.suggestion). Let me try a different approach."
                        ))
                        
                        // Reset state to continue execution
                        state = .thinking
                        continue
                    }
                    
                } catch let reflectionError {
                    print("⚠️ Error reflection failed: \(reflectionError)")
                    // Fallback to original error handling
                }
                
                state = .error
                let errorStep = AgentStep(
                    stepNumber: currentStepNumber,
                    state: .error,
                    thought: "Error occurred during execution",
                    toolCalls: nil,
                    toolResults: nil,
                    llmResponse: nil,
                    reflection: nil,
                    error: error.localizedDescription,
                    extra: nil,
                    llmUsage: nil
                )
                
                agentSteps.append(errorStep)
                trajectoryRecorder?.recordAgentStep(step: errorStep)
                
                if let console = console {
                    await console.updateStatus(agentStep: errorStep, agentExecution: agentExecution)
                }
                
                throw error
            }
        }
        
        // Final execution summary
        let finalExecution = AgentExecution(
            task: task,
            steps: agentSteps,
            finalResult: finalResult,
            success: state == .completed,
            totalTokens: nil,
            executionTime: startTime?.timeIntervalSinceNow.magnitude ?? 0,
            status: state == .completed ? "completed" : state == .error ? "error" : "max_steps_reached",
            currentStep: currentStepNumber,
            maxSteps: maxSteps,
            startTime: startTime,
            result: finalResult,
            tokenUsage: totalUsage
        )
        
        if let console = console {
            await console.printExecutionSummary(finalExecution)
            await console.stop()
        }
        
        trajectoryRecorder?.recordAgentExecution(finalExecution)
        
        if currentStepNumber >= maxSteps {
            throw AgentError.maxIterationsReached
        }
        
        return finalResult
    }
    
    // MARK: - Helper Methods
    
    private func executeToolCallsSequential(_ toolCalls: [ToolCall]) async throws -> [ToolResult] {
        var results: [ToolResult] = []
        
        for toolCall in toolCalls {
            let result = try await executeToolCall(toolCall)
            results.append(result)
        }
        
        return results
    }
    
    private func executeToolCallsParallel(_ toolCalls: [ToolCall]) async throws -> [ToolResult] {
        // Use TaskGroup for safe parallel execution
        return try await withThrowingTaskGroup(of: (Int, ToolResult).self) { group in
            var results: [ToolResult] = Array(repeating: ToolResult(toolCallId: "", content: "", error: nil), count: toolCalls.count)
            
            // Add tasks for each tool call with isolated tool instances
            for (index, toolCall) in toolCalls.enumerated() {
                group.addTask { [tools] in
                    let result = try await BaseAgent.executeToolCallIsolated(toolCall, tools: tools)
                    return (index, result)
                }
            }
            
            // Collect results in the correct order
            for try await (index, result) in group {
                results[index] = result
            }
            
            return results
        }
    }
    
    private static func executeToolCallIsolated(_ toolCall: ToolCall, tools: [Tool]) async throws -> ToolResult {
        let toolName = toolCall.function.name
        let toolArguments = toolCall.function.arguments
        
        // Find the matching tool
        guard let tool = tools.first(where: { $0.name == toolName }) else {
            return ToolResult(
                toolCallId: toolCall.id,
                content: "Tool '\(toolName)' not found",
                error: "Tool not found"
            )
        }
        
        do {
            let result = try await tool.execute(arguments: toolArguments)
            return ToolResult(
                toolCallId: toolCall.id,
                content: result,
                error: nil
            )
        } catch {
            return ToolResult(
                toolCallId: toolCall.id,
                content: "Tool execution failed: \(error.localizedDescription)",
                error: error.localizedDescription
            )
        }
    }
    
    private func executeToolCall(_ toolCall: ToolCall) async throws -> ToolResult {
        let toolName = toolCall.function.name
        let toolArguments = toolCall.function.arguments
        
        // Find the matching tool
        guard let tool = tools.first(where: { $0.name == toolName }) else {
            return ToolResult(
                toolCallId: toolCall.id,
                content: "Tool '\(toolName)' not found",
                error: "Tool not found"
            )
        }
        
        do {
            let result = try await tool.execute(arguments: toolArguments)
            return ToolResult(
                toolCallId: toolCall.id,
                content: result,
                error: nil
            )
        } catch {
            return ToolResult(
                toolCallId: toolCall.id,
                content: "Tool execution failed: \(error.localizedDescription)",
                error: error.localizedDescription
            )
        }
    }
    
    private func generateReflection(toolResults: [ToolResult]) async throws -> String {
        // Check if any tools failed or produced concerning results
        let failedTools = toolResults.filter { $0.error != nil }
        let allToolsSucceeded = failedTools.isEmpty
        
        if !allToolsSucceeded {
            // Generate reflection for failed tools
            let failedToolNames = failedTools.map { "Tool \($0.toolCallId): \($0.error ?? "Unknown error")" }
            return "I encountered issues with some tools: \(failedToolNames.joined(separator: ", ")). Let me analyze the results and adjust my approach."
        }
        
        // For now, only reflect on failures. In the future, this could be enhanced
        // to generate more sophisticated reflections using another LLM call
        return ""
    }
    
    private func isTaskComplete(_ content: String) -> Bool {
        let completionIndicators = [
            "task complete",
            "task completed",
            "done",
            "finished",
            "completed successfully",
            "task finished",
            "work complete",
            "work completed"
        ]
        
        let lowercaseContent = content.lowercased()
        return completionIndicators.contains { lowercaseContent.contains($0) }
    }
}

