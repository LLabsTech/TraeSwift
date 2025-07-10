import Foundation

enum MessageRole: String, Codable {
    case system
    case user
    case assistant
}

struct Message: Codable {
    let role: MessageRole
    let content: String
    let toolCalls: [ToolCall]?
    let toolCallId: String?
    
    init(role: MessageRole, content: String, toolCalls: [ToolCall]? = nil, toolCallId: String? = nil) {
        self.role = role
        self.content = content
        self.toolCalls = toolCalls
        self.toolCallId = toolCallId
    }
}

struct ToolCall: Codable {
    let id: String
    let type: String
    let function: FunctionCall
}

struct FunctionCall: Codable {
    let name: String
    let arguments: String
}

struct ToolResponse: Codable {
    let toolCallId: String
    let content: String
    
    func toMessage() -> Message {
        return Message(role: .user, content: content, toolCallId: toolCallId)
    }
}

struct ChatCompletionResponse: Codable {
    let id: String
    let choices: [Choice]
    let usage: Usage?
    
    struct Choice: Codable {
        let message: ResponseMessage
        let finishReason: String?
        
        enum CodingKeys: String, CodingKey {
            case message
            case finishReason = "finish_reason"
        }
    }
    
    struct ResponseMessage: Codable {
        let role: String
        let content: String?
        let toolCalls: [ToolCall]?
        
        enum CodingKeys: String, CodingKey {
            case role
            case content
            case toolCalls = "tool_calls"
        }
    }
    
    struct Usage: Codable {
        let promptTokens: Int
        let completionTokens: Int
        let totalTokens: Int
        
        enum CodingKeys: String, CodingKey {
            case promptTokens = "prompt_tokens"
            case completionTokens = "completion_tokens"
            case totalTokens = "total_tokens"
        }
    }
}