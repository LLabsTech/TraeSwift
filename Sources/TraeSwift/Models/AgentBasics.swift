import Foundation

enum AgentState: String, CaseIterable, Sendable {
    case idle = "idle"
    case thinking = "thinking"
    case callingTool = "calling_tool"
    case reflecting = "reflecting"
    case completed = "completed"
    case error = "error"
}

struct LLMUsage: Sendable {
    let inputTokens: Int
    let outputTokens: Int
    let cacheCreationInputTokens: Int
    let cacheReadInputTokens: Int
    let reasoningTokens: Int
    
    init(inputTokens: Int, outputTokens: Int, cacheCreationInputTokens: Int = 0, cacheReadInputTokens: Int = 0, reasoningTokens: Int = 0) {
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.cacheCreationInputTokens = cacheCreationInputTokens
        self.cacheReadInputTokens = cacheReadInputTokens
        self.reasoningTokens = reasoningTokens
    }
    
    static func + (lhs: LLMUsage, rhs: LLMUsage) -> LLMUsage {
        return LLMUsage(
            inputTokens: lhs.inputTokens + rhs.inputTokens,
            outputTokens: lhs.outputTokens + rhs.outputTokens,
            cacheCreationInputTokens: lhs.cacheCreationInputTokens + rhs.cacheCreationInputTokens,
            cacheReadInputTokens: lhs.cacheReadInputTokens + rhs.cacheReadInputTokens,
            reasoningTokens: lhs.reasoningTokens + rhs.reasoningTokens
        )
    }
}

struct LLMResponse: Sendable {
    let content: String
    let usage: LLMUsage?
    let model: String?
    let finishReason: String?
    let toolCalls: [ToolCall]?
    
    init(content: String, usage: LLMUsage? = nil, model: String? = nil, finishReason: String? = nil, toolCalls: [ToolCall]? = nil) {
        self.content = content
        self.usage = usage
        self.model = model
        self.finishReason = finishReason
        self.toolCalls = toolCalls
    }
}

struct LLMMessage {
    let role: String
    let content: String?
    let toolCall: ToolCall?
    let toolResult: ToolResult?
    
    init(role: String, content: String? = nil, toolCall: ToolCall? = nil, toolResult: ToolResult? = nil) {
        self.role = role
        self.content = content
        self.toolCall = toolCall
        self.toolResult = toolResult
    }
}

struct ToolResult: Sendable {
    let toolCallId: String
    let content: String
    let error: String?
    
    init(toolCallId: String, content: String, error: String? = nil) {
        self.toolCallId = toolCallId
        self.content = content
        self.error = error
    }
}

struct AgentStep: Sendable {
    let stepNumber: Int
    let state: AgentState
    let thought: String?
    let toolCalls: [ToolCall]?
    let toolResults: [ToolResult]?
    let llmResponse: LLMResponse?
    let reflection: String?
    let error: String?
    let extra: [String: String]?
    let llmUsage: LLMUsage?
    
    init(stepNumber: Int, state: AgentState, thought: String? = nil, toolCalls: [ToolCall]? = nil, toolResults: [ToolResult]? = nil, llmResponse: LLMResponse? = nil, reflection: String? = nil, error: String? = nil, extra: [String: String]? = nil, llmUsage: LLMUsage? = nil) {
        self.stepNumber = stepNumber
        self.state = state
        self.thought = thought
        self.toolCalls = toolCalls
        self.toolResults = toolResults
        self.llmResponse = llmResponse
        self.reflection = reflection
        self.error = error
        self.extra = extra
        self.llmUsage = llmUsage
    }
}

struct AgentExecution {
    let task: String
    let steps: [AgentStep]
    let finalResult: String?
    let success: Bool
    let totalTokens: LLMUsage?
    let executionTime: TimeInterval
    let status: String
    let currentStep: Int
    let maxSteps: Int
    let startTime: Date?
    let result: String?
    let tokenUsage: ChatCompletionResponse.Usage?
    
    init(task: String, steps: [AgentStep], finalResult: String? = nil, success: Bool = false, totalTokens: LLMUsage? = nil, executionTime: TimeInterval = 0.0, status: String = "running", currentStep: Int = 0, maxSteps: Int = 20, startTime: Date? = nil, result: String? = nil, tokenUsage: ChatCompletionResponse.Usage? = nil) {
        self.task = task
        self.steps = steps
        self.finalResult = finalResult
        self.success = success
        self.totalTokens = totalTokens
        self.executionTime = executionTime
        self.status = status
        self.currentStep = currentStep
        self.maxSteps = maxSteps
        self.startTime = startTime
        self.result = result
        self.tokenUsage = tokenUsage
    }
}

enum AgentError: Error {
    case executionFailed(String)
    case maxIterationsReached
    case configurationError(String)
    case llmError(String)
    case toolError(String)
    
    var message: String {
        switch self {
        case .executionFailed(let msg):
            return "Execution failed: \(msg)"
        case .maxIterationsReached:
            return "Maximum iterations reached"
        case .configurationError(let msg):
            return "Configuration error: \(msg)"
        case .llmError(let msg):
            return "LLM error: \(msg)"
        case .toolError(let msg):
            return "Tool error: \(msg)"
        }
    }
}