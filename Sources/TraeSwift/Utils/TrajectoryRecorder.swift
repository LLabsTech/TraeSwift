import Foundation

class TrajectoryRecorder {
    private let trajectoryPath: URL
    private var trajectoryData: [String: Any] = [:]
    private var startTime: Date?
    
    init(trajectoryPath: String? = nil) {
        if let trajectoryPath = trajectoryPath {
            self.trajectoryPath = URL(fileURLWithPath: trajectoryPath)
        } else {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
            let timestampString = dateFormatter.string(from: Date())
            self.trajectoryPath = URL(fileURLWithPath: "trajectory_\(timestampString).json")
        }
        
        self.trajectoryData = [
            "task": "",
            "start_time": "",
            "end_time": "",
            "provider": "",
            "model": "",
            "max_steps": 0,
            "llm_interactions": [],
            "agent_steps": [],
            "success": false,
            "final_result": NSNull(),
            "execution_time": 0.0
        ]
    }
    
    func startRecording(task: String, provider: String, model: String, maxSteps: Int) {
        startTime = Date()
        let dateFormatter = ISO8601DateFormatter()
        
        trajectoryData.merge([
            "task": task,
            "start_time": dateFormatter.string(from: startTime!),
            "provider": provider,
            "model": model,
            "max_steps": maxSteps,
            "llm_interactions": [],
            "agent_steps": []
        ]) { _, new in new }
        
        saveTrajectory()
    }
    
    func recordLLMInteraction(
        messages: [Message],
        response: ChatCompletionResponse,
        provider: String,
        model: String,
        tools: [ToolDefinition]? = nil
    ) {
        let dateFormatter = ISO8601DateFormatter()
        
        var llmInteractions = trajectoryData["llm_interactions"] as? [[String: Any]] ?? []
        
        let interaction: [String: Any] = [
            "timestamp": dateFormatter.string(from: Date()),
            "provider": provider,
            "model": model,
            "input_messages": messages.map(serializeMessage),
            "response": [
                "content": response.choices.first?.message.content ?? "",
                "model": model,
                "finish_reason": response.choices.first?.finishReason ?? NSNull(),
                "usage": [
                    "input_tokens": response.usage?.promptTokens ?? NSNull(),
                    "output_tokens": response.usage?.completionTokens ?? NSNull(),
                    "total_tokens": response.usage?.totalTokens ?? NSNull()
                ] as [String: Any],
                "tool_calls": response.choices.first?.message.toolCalls?.map { toolCall in
                    [
                        "id": toolCall.id,
                        "type": toolCall.type,
                        "function": [
                            "name": toolCall.function.name,
                            "arguments": toolCall.function.arguments
                        ]
                    ]
                } ?? []
            ] as [String: Any],
            "tools": tools?.map { tool in
                [
                    "name": tool.function.name,
                    "description": tool.function.description
                ]
            } ?? []
        ]
        
        llmInteractions.append(interaction)
        trajectoryData["llm_interactions"] = llmInteractions
        
        saveTrajectory()
    }
    
    func recordAgentStep(step: AgentStep) {
        var agentSteps = trajectoryData["agent_steps"] as? [[String: Any]] ?? []
        
        let stepData: [String: Any] = [
            "step_number": step.stepNumber,
            "state": step.state.rawValue,
            "thought": step.thought ?? NSNull(),
            "tool_calls": step.toolCalls?.map { toolCall in
                [
                    "id": toolCall.id,
                    "type": toolCall.type,
                    "function": [
                        "name": toolCall.function.name,
                        "arguments": toolCall.function.arguments
                    ]
                ]
            } ?? [],
            "tool_results": step.toolResults?.map { result in
                [
                    "tool_call_id": result.toolCallId,
                    "content": result.content,
                    "error": result.error as Any
                ]
            } ?? [],
            "reflection": step.reflection ?? NSNull(),
            "error": step.error ?? NSNull(),
            "llm_usage": step.llmUsage.map { usage in
                [
                    "input_tokens": usage.inputTokens,
                    "output_tokens": usage.outputTokens,
                    "cache_creation_input_tokens": usage.cacheCreationInputTokens,
                    "cache_read_input_tokens": usage.cacheReadInputTokens,
                    "reasoning_tokens": usage.reasoningTokens
                ]
            } ?? NSNull()
        ]
        
        agentSteps.append(stepData)
        trajectoryData["agent_steps"] = agentSteps
        
        saveTrajectory()
    }
    
    func recordAgentExecution(_ execution: AgentExecution) {
        let dateFormatter = ISO8601DateFormatter()
        
        trajectoryData.merge([
            "task": execution.task,
            "end_time": dateFormatter.string(from: Date()),
            "success": execution.success,
            "final_result": execution.finalResult ?? NSNull(),
            "execution_time": execution.executionTime,
            "status": execution.status,
            "current_step": execution.currentStep,
            "max_steps": execution.maxSteps,
            "token_usage": execution.tokenUsage.map { usage in
                [
                    "prompt_tokens": usage.promptTokens,
                    "completion_tokens": usage.completionTokens,
                    "total_tokens": usage.totalTokens
                ]
            } ?? NSNull()
        ]) { _, new in new }
        
        saveTrajectory()
    }
    
    func finishRecording(success: Bool, finalResult: String?, executionTime: TimeInterval) {
        let dateFormatter = ISO8601DateFormatter()
        
        trajectoryData.merge([
            "end_time": dateFormatter.string(from: Date()),
            "success": success,
            "final_result": finalResult ?? NSNull(),
            "execution_time": executionTime
        ]) { _, new in new }
        
        saveTrajectory()
    }
    
    private func serializeMessage(_ message: Message) -> [String: Any] {
        var serialized: [String: Any] = [
            "role": message.role.rawValue,
            "content": message.content
        ]
        
        if let toolCalls = message.toolCalls {
            serialized["tool_calls"] = toolCalls.map { toolCall in
                [
                    "id": toolCall.id,
                    "type": toolCall.type,
                    "function": [
                        "name": toolCall.function.name,
                        "arguments": toolCall.function.arguments
                    ]
                ]
            }
        }
        
        if let toolCallId = message.toolCallId {
            serialized["tool_call_id"] = toolCallId
        }
        
        return serialized
    }
    
    private func saveTrajectory() {
        do {
            let data = try JSONSerialization.data(withJSONObject: trajectoryData, options: .prettyPrinted)
            try data.write(to: trajectoryPath)
        } catch {
            print("Failed to save trajectory: \(error)")
        }
    }
    
    func getTrajectoryPath() -> String {
        return trajectoryPath.path
    }
}