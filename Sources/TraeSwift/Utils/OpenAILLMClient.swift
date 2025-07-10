import Foundation
import OpenAI

typealias JSONSchemaObject = Dictionary<String, AnyJSONDocument>

class OpenAILLMClient: LLMClient {
    private let client: OpenAI
    private let model: String
    private let supportsStructuredOutputs: Bool
    private let maxRetries: Int
    
    init(apiKey: String, model: String = "gpt-4o-mini", baseURL: String? = nil, maxRetries: Int = 3) {
        let configuration = OpenAI.Configuration(
            token: apiKey,
            host: baseURL ?? "api.openai.com",
            scheme: "https"
        )
        self.client = OpenAI(configuration: configuration)
        self.model = model
        self.maxRetries = maxRetries
        
        // Enable structured outputs for supported models
        self.supportsStructuredOutputs = model.contains("gpt-4o") || model.contains("gpt-4-turbo") || model.contains("gpt-3.5-turbo")
    }
    
    func chat(messages: [Message], tools: [ToolDefinition]?, temperature: Double?, maxTokens: Int?) async throws -> ChatCompletionResponse {
        // Implement retry logic for robustness
        var lastError: Error?
        
        for attempt in 0..<maxRetries {
            do {
                return try await performChatRequest(messages: messages, tools: tools, temperature: temperature, maxTokens: maxTokens)
            } catch {
                lastError = error
                
                // Check if we should retry
                if shouldRetryError(error) && attempt < maxRetries - 1 {
                    let backoffDelay = pow(2.0, Double(attempt)) * 0.5 // Exponential backoff
                    try await Task.sleep(nanoseconds: UInt64(backoffDelay * 1_000_000_000))
                    continue
                } else {
                    throw error
                }
            }
        }
        
        throw lastError ?? LLMError.networkError(NSError(domain: "UnknownError", code: 0))
    }
    
    private func shouldRetryError(_ error: Error) -> Bool {
        if let llmError = error as? LLMError {
            switch llmError {
            case .networkError(_):
                return true
            case .apiError(let message):
                return message.contains("rate_limit") || message.contains("429") || message.contains("503") || message.contains("502")
            default:
                return false
            }
        }
        return false
    }
    
    private func performChatRequest(messages: [Message], tools: [ToolDefinition]?, temperature: Double?, maxTokens: Int?) async throws -> ChatCompletionResponse {
        // Convert our Message format to OpenAI's ChatQuery.ChatCompletionMessageParam
        let openAIMessages = messages.map { message -> ChatQuery.ChatCompletionMessageParam in
            switch message.role {
            case .system:
                return .system(.init(content: .textContent(message.content)))
            case .user:
                if let toolCallId = message.toolCallId {
                    // This is a tool response
                    return .tool(.init(content: .textContent(message.content), toolCallId: toolCallId))
                } else {
                    return .user(.init(content: .string(message.content)))
                }
            case .assistant:
                if let toolCalls = message.toolCalls {
                    // Convert our ToolCall to OpenAI's format
                    let openAIToolCalls = toolCalls.map { toolCall in
                        ChatQuery.ChatCompletionMessageParam.AssistantMessageParam.ToolCallParam(
                            id: toolCall.id,
                            function: .init(
                                arguments: toolCall.function.arguments,
                                name: toolCall.function.name
                            )
                        )
                    }
                    return .assistant(.init(
                        content: message.content.isEmpty ? nil : .textContent(message.content),
                        toolCalls: openAIToolCalls
                    ))
                } else {
                    return .assistant(.init(content: .textContent(message.content)))
                }
            }
        }
        
        // Enhanced tool handling with structured outputs
        let openAITools = tools?.map { tool in
            return ChatQuery.ChatCompletionToolParam(
                function: .init(
                    name: tool.function.name,
                    description: tool.function.description,
                    parameters: convertJSONSchemaToAnyJSONSchema(tool.function.parameters)
                )
            )
        }
        
        let query = ChatQuery(
            messages: openAIMessages,
            model: Model(model),
            maxCompletionTokens: maxTokens,
            temperature: temperature,
            tools: openAITools
        )
        
        // Enhanced structured outputs are handled automatically by the OpenAI library
        
        let result = try await client.chats(query: query)
        
        // Convert OpenAI response back to our format
        guard let firstChoice = result.choices.first else {
            throw LLMError.invalidResponse
        }
        
        let responseMessage = ChatCompletionResponse.ResponseMessage(
            role: "assistant",
            content: firstChoice.message.content ?? "",
            toolCalls: firstChoice.message.toolCalls?.map { openAIToolCall in
                ToolCall(
                    id: openAIToolCall.id,
                    type: "function",
                    function: FunctionCall(
                        name: openAIToolCall.function.name,
                        arguments: openAIToolCall.function.arguments
                    )
                )
            }
        )
        
        let usage = result.usage.map { usage in
            ChatCompletionResponse.Usage(
                promptTokens: usage.promptTokens,
                completionTokens: usage.completionTokens,
                totalTokens: usage.totalTokens
            )
        }
        
        return ChatCompletionResponse(
            id: result.id,
            choices: [ChatCompletionResponse.Choice(
                message: responseMessage,
                finishReason: firstChoice.finishReason
            )],
            usage: usage
        )
    }
    
    func countTokens(messages: [Message]) async throws -> Int {
        // Rough estimation - OpenAI doesn't provide a direct token counting API
        // In production, you'd use a proper tokenizer library
        let totalCharacters = messages.reduce(0) { total, message in
            total + message.content.count
        }
        // Rough estimate: 1 token ≈ 4 characters
        return totalCharacters / 4
    }
    
    private func convertJSONSchemaToAnyJSONSchema(_ schema: JSONSchema) -> AnyJSONSchema {
        var schemaDict: JSONSchemaObject = [
            "type": AnyJSONDocument("object")
        ]
        
        if let properties = schema.properties {
            var propertiesDict: JSONSchemaObject = [:]
            for (key, prop) in properties {
                propertiesDict[key] = AnyJSONDocument(convertPropertyToJSONSchema(prop))
            }
            schemaDict["properties"] = AnyJSONDocument(propertiesDict)
        }
        
        if let required = schema.required {
            schemaDict["required"] = AnyJSONDocument(required)
        }
        
        return AnyJSONSchema(schema: schemaDict)
    }
    
    private func convertPropertyToJSONSchema(_ property: JSONSchema.Property) -> JSONSchemaObject {
        var propDict: JSONSchemaObject = [
            "type": AnyJSONDocument(property.type)
        ]
        
        if let description = property.description {
            propDict["description"] = AnyJSONDocument(description)
        }
        
        if property.type == "array", let items = property.items {
            propDict["items"] = AnyJSONDocument(["type": AnyJSONDocument(items.type)])
        }
        
        if property.type == "object", let subProperties = property.properties {
            var subPropsDict: JSONSchemaObject = [:]
            for (key, subProp) in subProperties {
                subPropsDict[key] = AnyJSONDocument(convertPropertyToJSONSchema(subProp))
            }
            propDict["properties"] = AnyJSONDocument(subPropsDict)
            
            if let required = property.required {
                propDict["required"] = AnyJSONDocument(required)
            }
        }
        
        return propDict
    }
}