import Foundation

class AnthropicLLMClient: LLMClient {
    private let apiKey: String
    private let baseURL: String
    private let model: String
    private let supportsNativeTools: Bool
    private let maxRetries: Int
    private let urlSession: URLSession
    
    init(apiKey: String, model: String = "claude-sonnet-4-20250514", baseURL: String = "https://api.anthropic.com", maxRetries: Int = 3) {
        self.apiKey = apiKey
        self.model = model
        self.baseURL = baseURL
        self.maxRetries = maxRetries
        
        // Configure URLSession with extended timeouts for LLM responses
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 300.0 // 5 minutes
        config.timeoutIntervalForResource = 600.0 // 10 minutes
        self.urlSession = URLSession(configuration: config)
        
        // Enable native tools for Claude models that support them
        self.supportsNativeTools = model.contains("claude-3") || model.contains("claude-sonnet") || model.contains("claude-haiku") || model.contains("claude-opus")
    }
    
    func chat(messages: [Message], tools: [ToolDefinition]?, temperature: Double?, maxTokens: Int?) async throws -> ChatCompletionResponse {
        // Implement retry logic for robustness
        var lastError: Error?
        
        for attempt in 0..<maxRetries {
            do {
                return try await performChatRequest(messages: messages, tools: tools, temperature: temperature, maxTokens: maxTokens)
            } catch let error as LLMError {
                lastError = error
                
                // Only retry on network errors and rate limits
                switch error {
                case .networkError(_):
                    let backoffDelay = pow(2.0, Double(attempt)) * 0.5 // Exponential backoff
                    try await Task.sleep(nanoseconds: UInt64(backoffDelay * 1_000_000_000))
                    continue
                case .apiError(let message) where message.contains("rate_limit") || message.contains("429"):
                    let backoffDelay = pow(2.0, Double(attempt)) * 0.5 // Exponential backoff
                    try await Task.sleep(nanoseconds: UInt64(backoffDelay * 1_000_000_000))
                    continue
                default:
                    throw error // Don't retry on other errors
                }
            } catch {
                lastError = error
                break // Don't retry on unexpected errors
            }
        }
        
        throw lastError ?? LLMError.networkError(NSError(domain: "UnknownError", code: 0))
    }
    
    private func performChatRequest(messages: [Message], tools: [ToolDefinition]?, temperature: Double?, maxTokens: Int?) async throws -> ChatCompletionResponse {
        let url = URL(string: "\(baseURL)/v1/messages")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.addValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        
        // Add system message handling for Anthropic
        let systemMessage = messages.first { $0.role == .system }?.content
        let anthropicMessages = convertMessagesToAnthropicFormat(messages)
        
        var requestBody: [String: Any] = [
            "model": model,
            "messages": anthropicMessages,
            "max_tokens": maxTokens ?? 4096
        ]
        
        // Add system message if present
        if let systemMessage = systemMessage, !systemMessage.isEmpty {
            requestBody["system"] = systemMessage
        }
        
        if let temperature = temperature {
            requestBody["temperature"] = temperature
        }
        
        // Enhanced tool handling with native tool support
        if let tools = tools, !tools.isEmpty {
            if supportsNativeTools {
                requestBody["tools"] = convertToolsToAnthropicFormat(tools)
                // Add tool choice preference for better control
                requestBody["tool_choice"] = ["type": "auto"]
            } else {
                requestBody["tools"] = convertToolsToAnthropicFormat(tools)
            }
        }
        
        let jsonData = try JSONSerialization.data(withJSONObject: requestBody)
        request.httpBody = jsonData
        
        let (data, response) = try await urlSession.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw LLMError.networkError(NSError(domain: "InvalidResponse", code: 0))
        }
        
        if httpResponse.statusCode == 429 {
            throw LLMError.apiError("rate_limit_exceeded")
        }
        
        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw LLMError.apiError("HTTP \(httpResponse.statusCode): \(errorMessage)")
        }
        
        // Parse Anthropic response and convert to our format
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw LLMError.invalidResponse
        }
        
        return try parseAnthropicResponse(json)
    }
    
    func countTokens(messages: [Message]) async throws -> Int {
        // Rough estimation for Anthropic
        let totalCharacters = messages.reduce(0) { total, message in
            total + message.content.count
        }
        // Anthropic uses roughly 1 token per 3.5 characters
        return Int(Double(totalCharacters) / 3.5)
    }
    
    private func convertMessagesToAnthropicFormat(_ messages: [Message]) -> [[String: Any]] {
        var anthropicMessages: [[String: Any]] = []
        
        for message in messages {
            switch message.role {
            case .system:
                // Anthropic handles system messages differently - they go in a separate field
                continue
            case .user:
                if let toolCallId = message.toolCallId {
                    // This is a tool result
                    anthropicMessages.append([
                        "role": "user",
                        "content": [
                            [
                                "type": "tool_result",
                                "tool_use_id": toolCallId,
                                "content": message.content
                            ]
                        ]
                    ])
                } else {
                    anthropicMessages.append([
                        "role": "user",
                        "content": message.content
                    ])
                }
            case .assistant:
                var content: [Any] = []
                
                if !message.content.isEmpty {
                    content.append([
                        "type": "text",
                        "text": message.content
                    ])
                }
                
                if let toolCalls = message.toolCalls {
                    for toolCall in toolCalls {
                        content.append([
                            "type": "tool_use",
                            "id": toolCall.id,
                            "name": toolCall.function.name,
                            "input": (try? JSONSerialization.jsonObject(with: toolCall.function.arguments.data(using: .utf8) ?? Data())) ?? [:]
                        ])
                    }
                }
                
                anthropicMessages.append([
                    "role": "assistant",
                    "content": content
                ])
            }
        }
        
        return anthropicMessages
    }
    
    private func convertToolsToAnthropicFormat(_ tools: [ToolDefinition]) -> [[String: Any]] {
        return tools.map { tool in
            [
                "name": tool.function.name,
                "description": tool.function.description,
                "input_schema": convertJSONSchemaToAnthropicSchema(tool.function.parameters)
            ]
        }
    }
    
    private func convertJSONSchemaToAnthropicSchema(_ schema: JSONSchema) -> [String: Any] {
        var anthropicSchema: [String: Any] = [
            "type": schema.type
        ]
        
        if let properties = schema.properties {
            var propertiesDict: [String: Any] = [:]
            for (key, prop) in properties {
                propertiesDict[key] = [
                    "type": prop.type,
                    "description": prop.description ?? ""
                ]
            }
            anthropicSchema["properties"] = propertiesDict
        }
        
        if let required = schema.required {
            anthropicSchema["required"] = required
        }
        
        return anthropicSchema
    }
    
    private func parseAnthropicResponse(_ json: [String: Any]) throws -> ChatCompletionResponse {
        guard let content = json["content"] as? [[String: Any]] else {
            throw LLMError.invalidResponse
        }
        
        var responseContent = ""
        var toolCalls: [ToolCall] = []
        
        for contentItem in content {
            if let type = contentItem["type"] as? String {
                switch type {
                case "text":
                    if let text = contentItem["text"] as? String {
                        responseContent += text
                    }
                case "tool_use":
                    if let id = contentItem["id"] as? String,
                       let name = contentItem["name"] as? String,
                       let input = contentItem["input"] {
                        let argumentsData = try JSONSerialization.data(withJSONObject: input)
                        let argumentsString = String(data: argumentsData, encoding: .utf8) ?? "{}"
                        
                        toolCalls.append(ToolCall(
                            id: id,
                            type: "function",
                            function: FunctionCall(name: name, arguments: argumentsString)
                        ))
                    }
                default:
                    // Handle other content types silently
                    break
                }
            }
        }
        
        let usageDict = json["usage"] as? [String: Any]
        let inputTokens = usageDict?["input_tokens"] as? Int ?? 0
        let outputTokens = usageDict?["output_tokens"] as? Int ?? 0
        
        let usage = ChatCompletionResponse.Usage(
            promptTokens: inputTokens,
            completionTokens: outputTokens,
            totalTokens: inputTokens + outputTokens
        )
        
        let responseMessage = ChatCompletionResponse.ResponseMessage(
            role: "assistant",
            content: responseContent.isEmpty ? nil : responseContent,
            toolCalls: toolCalls.isEmpty ? nil : toolCalls
        )
        
        return ChatCompletionResponse(
            id: json["id"] as? String ?? UUID().uuidString,
            choices: [ChatCompletionResponse.Choice(
                message: responseMessage,
                finishReason: json["stop_reason"] as? String
            )],
            usage: usage
        )
    }
}