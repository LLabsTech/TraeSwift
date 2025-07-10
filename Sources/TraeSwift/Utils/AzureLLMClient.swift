import Foundation
import OpenAI

class AzureLLMClient: LLMClient {
    private let client: OpenAI
    private let model: String
    
    init(apiKey: String, model: String, baseURL: String, apiVersion: String = "2024-03-01-preview") {
        // Azure OpenAI uses a different URL structure
        let azureConfig = OpenAI.Configuration(
            token: apiKey,
            host: URL(string: baseURL)?.host ?? "api.openai.com",
            scheme: "https"
        )
        
        self.client = OpenAI(configuration: azureConfig)
        self.model = model
    }
    
    func chat(messages: [Message], tools: [ToolDefinition]?, temperature: Double?, maxTokens: Int?) async throws -> ChatCompletionResponse {
        // Convert our Message format to OpenAI's ChatQuery.ChatCompletionMessageParam
        let openAIMessages = messages.map { message -> ChatQuery.ChatCompletionMessageParam in
            switch message.role {
            case .system:
                return .system(.init(content: .textContent(message.content)))
            case .user:
                if let toolCallId = message.toolCallId {
                    return .tool(.init(content: .textContent(message.content), toolCallId: toolCallId))
                } else {
                    return .user(.init(content: .string(message.content)))
                }
            case .assistant:
                if let toolCalls = message.toolCalls {
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
        
        // Convert tools if provided
        let openAITools = tools?.map { tool in
            ChatQuery.ChatCompletionToolParam(
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
        // Rough estimation - same as OpenAI
        let totalCharacters = messages.reduce(0) { total, message in
            total + message.content.count
        }
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