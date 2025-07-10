import Foundation

struct LakeViewStep {
    let descTask: String        // Concise task description (≤10 words)
    let descDetails: String     // Detailed description (≤30 words)
    let tagsEmoji: String       // Emoji representation of tags
    
    init(descTask: String, descDetails: String, tagsEmoji: String) {
        self.descTask = descTask
        self.descDetails = descDetails
        self.tagsEmoji = tagsEmoji
    }
}

class LakeView {
    private let config: FullConfig
    private let lakeviewLLMClient: LLMClient
    private var steps: [String] = []
    
    private let knownTags: [String: String] = [
        "WRITE_TEST": "☑️",      // Writing test scripts
        "VERIFY_TEST": "✅",     // Running tests
        "EXAMINE_CODE": "👁️",    // Code exploration
        "WRITE_FIX": "📝",       // Implementing fixes
        "VERIFY_FIX": "🔥",      // Verifying fixes
        "REPORT": "📣",          // Reporting progress
        "THINK": "🧠",           // Analysis/thinking
        "OUTLIER": "⁉️",         // Other actions
    ]
    
    init(config: FullConfig) throws {
        self.config = config
        
        // Create dedicated LLM client for LakeView
        guard let lakeviewConfig = config.lakeviewConfig else {
            throw LLMError.missingAPIKey
        }
        
        self.lakeviewLLMClient = try LLMClientFactory.createClient(
            from: config,
            provider: lakeviewConfig.modelProvider
        )
    }
    
    func getLabel(tags: [String], emoji: Bool = true) -> String {
        if emoji {
            return tags.compactMap { knownTags[$0] }.joined(separator: " ")
        } else {
            return tags.joined(separator: ", ")
        }
    }
    
    func createLakeviewStep(_ agentStep: AgentStep) async throws -> LakeViewStep {
        let stepString = agentStepToString(agentStep)
        steps.append(stepString)
        
        // Extract task and details
        let taskResult = try await extractTaskInStep(stepString)
        
        // Extract tags
        let tags = try await extractTagInStep(stepString)
        let tagsEmoji = getLabel(tags: tags, emoji: true)
        
        return LakeViewStep(
            descTask: taskResult.task,
            descDetails: taskResult.details,
            tagsEmoji: tagsEmoji
        )
    }
    
    private func extractTaskInStep(_ stepString: String) async throws -> (task: String, details: String) {
        let extractorPrompt = """
        You are a software engineering assistant helping summarize agent execution steps.
        
        Given the following agent step, extract:
        1. A concise task description (≤10 words) - what is the agent trying to do?
        2. Detailed context (≤30 words) - specific details about this step
        
        Current step:
        \(stepString)
        
        Context (previous steps):
        \(steps.suffix(5).joined(separator: "\n\n"))
        
        Format your response as:
        <task>your concise task description here</task>
        <details>your detailed context here</details>
        """
        
        let messages = [
            Message(role: .system, content: "You are a helpful assistant that summarizes software engineering tasks."),
            Message(role: .user, content: extractorPrompt)
        ]
        
        let response = try await lakeviewLLMClient.chat(
            messages: messages,
            tools: nil,
            temperature: 0.3,
            maxTokens: 200
        )
        
        guard let content = response.choices.first?.message.content else {
            throw LLMError.invalidResponse
        }
        
        return parseTaskResponse(content)
    }
    
    private func extractTagInStep(_ stepString: String) async throws -> [String] {
        let taggerPrompt = """
        You are a software engineering assistant that categorizes agent actions.
        
        Analyze the following agent step and categorize it with appropriate tags from this list:
        - WRITE_TEST: Writing test scripts or test cases
        - VERIFY_TEST: Running tests or checking test results
        - EXAMINE_CODE: Code exploration, reading files, or analysis
        - WRITE_FIX: Implementing fixes, writing code, or making changes
        - VERIFY_FIX: Testing fixes or verifying solutions work
        - REPORT: Reporting progress, status updates, or results
        - THINK: Analysis, planning, or reasoning tasks
        - OUTLIER: Other actions not covered above
        
        Current step:
        \(stepString)
        
        Full trajectory context:
        \(steps.joined(separator: "\n\n"))
        
        Return only the most relevant tags (1-3 tags maximum) in this format:
        <tags>TAG1,TAG2,TAG3</tags>
        """
        
        let messages = [
            Message(role: .system, content: "You are a helpful assistant that categorizes software engineering tasks."),
            Message(role: .user, content: taggerPrompt)
        ]
        
        let response = try await lakeviewLLMClient.chat(
            messages: messages,
            tools: nil,
            temperature: 0.1,
            maxTokens: 100
        )
        
        guard let content = response.choices.first?.message.content else {
            throw LLMError.invalidResponse
        }
        
        return parseTagsResponse(content)
    }
    
    private func parseTaskResponse(_ content: String) -> (task: String, details: String) {
        let taskRegex = "<task>(.*?)</task>"
        let detailsRegex = "<details>(.*?)</details>"
        
        let task = extractMatch(from: content, pattern: taskRegex) ?? "Processing step"
        let details = extractMatch(from: content, pattern: detailsRegex) ?? "Executing agent action"
        
        return (
            task: String(task.prefix(50)).trimmingCharacters(in: .whitespacesAndNewlines),
            details: String(details.prefix(100)).trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }
    
    private func parseTagsResponse(_ content: String) -> [String] {
        let tagsRegex = "<tags>(.*?)</tags>"
        
        guard let tagsString = extractMatch(from: content, pattern: tagsRegex) else {
            return ["OUTLIER"]
        }
        
        let tags = tagsString
            .components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { knownTags.keys.contains($0) }
        
        return tags.isEmpty ? ["OUTLIER"] : tags
    }
    
    private func extractMatch(from text: String, pattern: String) -> String? {
        do {
            let regex = try NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators])
            let range = NSRange(text.startIndex..., in: text)
            
            if let match = regex.firstMatch(in: text, options: [], range: range),
               let matchRange = Range(match.range(at: 1), in: text) {
                return String(text[matchRange])
            }
        } catch {
            // Regex error, return nil
        }
        
        return nil
    }
    
    private func agentStepToString(_ agentStep: AgentStep) -> String {
        var stepStr = "Step \(agentStep.stepNumber): \(agentStep.state)\n"
        
        if let thought = agentStep.thought {
            stepStr += "Thought: \(thought)\n"
        }
        
        if let llmResponse = agentStep.llmResponse {
            stepStr += "LLM Response: \(llmResponse.content)\n"
        }
        
        if let toolCalls = agentStep.toolCalls, !toolCalls.isEmpty {
            stepStr += "Tool Calls:\n"
            for toolCall in toolCalls {
                stepStr += "  - \(toolCall.function.name): \(toolCall.function.arguments)\n"
            }
        }
        
        if let toolResults = agentStep.toolResults, !toolResults.isEmpty {
            stepStr += "Tool Results:\n"
            for result in toolResults {
                let status = result.error == nil ? "Success" : "Error"
                stepStr += "  - \(result.toolCallId): \(status) - \(result.content)\n"
                if let error = result.error {
                    stepStr += "    Error: \(error)\n"
                }
            }
        }
        
        if let reflection = agentStep.reflection {
            stepStr += "Reflection: \(reflection)\n"
        }
        
        if let error = agentStep.error {
            stepStr += "Error: \(error)\n"
        }
        
        return stepStr
    }
    
    func clearSteps() {
        steps.removeAll()
    }
    
    func getStepsCount() -> Int {
        return steps.count
    }
    
    // Limits context size to prevent token overflow
    private func trimContextIfNeeded() {
        let contextString = steps.joined(separator: "\n\n")
        let maxContextSize = 300_000 // characters
        
        if contextString.count > maxContextSize {
            // Keep only the most recent steps that fit within the limit
            var trimmedSteps: [String] = []
            var currentSize = 0
            
            for step in steps.reversed() {
                if currentSize + step.count > maxContextSize {
                    break
                }
                trimmedSteps.insert(step, at: 0)
                currentSize += step.count
            }
            
            steps = trimmedSteps
        }
    }
}