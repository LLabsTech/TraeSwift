import Foundation

protocol LLMClient {
    func chat(messages: [Message], tools: [ToolDefinition]?, temperature: Double?, maxTokens: Int?) async throws -> ChatCompletionResponse
    func countTokens(messages: [Message]) async throws -> Int
}

struct ToolDefinition: Codable {
    let type: String
    let function: FunctionDefinition
    
    init(function: FunctionDefinition) {
        self.type = "function"
        self.function = function
    }
    
    struct FunctionDefinition: Codable {
        let name: String
        let description: String
        let parameters: JSONSchema
    }
}

struct JSONSchema: Codable {
    let type: String
    let properties: [String: Property]?
    let required: [String]?
    
    struct Property: Codable {
        let type: String
        let description: String?
        let items: Items?
        let properties: [String: Property]?
        let required: [String]?
        
        struct Items: Codable {
            let type: String
        }
    }
}

enum LLMError: Error {
    case invalidResponse
    case networkError(Error)
    case apiError(String)
    case missingAPIKey
    case unsupportedModel
}