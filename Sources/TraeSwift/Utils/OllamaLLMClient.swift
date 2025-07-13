import Foundation

class OllamaLLMClient: LLMClient {
    private let baseURL: String
    private let model: String
    private let urlSession: URLSession
    
    init(model: String = "llama3.1", baseURL: String = "http://localhost:11434") {
        self.model = model
        self.baseURL = baseURL
        
        // Configure URLSession with extended timeouts for LLM responses
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 300.0 // 5 minutes
        config.timeoutIntervalForResource = 600.0 // 10 minutes
        self.urlSession = URLSession(configuration: config)
    }
    
    func chat(messages: [Message], tools: [ToolDefinition]?, temperature: Double?, maxTokens: Int?) async throws -> ChatCompletionResponse {
        let url = URL(string: "\(baseURL)/api/chat")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Convert messages to Ollama format
        let ollamaMessages = convertMessagesToOllamaFormat(messages)
        
        var requestBody: [String: Any] = [
            "model": model,
            "messages": ollamaMessages,
            "stream": false
        ]
        
        if let temperature = temperature {
            requestBody["options"] = [
                "temperature": temperature,
                "num_predict": maxTokens ?? 4096
            ]
        }
        
        if let tools = tools {
            requestBody["tools"] = convertToolsToOllamaFormat(tools)
        }
        
        let jsonData = try JSONSerialization.data(withJSONObject: requestBody)
        request.httpBody = jsonData
        
        let (data, response) = try await urlSession.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw LLMError.networkError(NSError(domain: "InvalidResponse", code: 0))
        }
        
        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw LLMError.apiError("HTTP \(httpResponse.statusCode): \(errorMessage)")
        }
        
        // Parse Ollama response and convert to our format
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw LLMError.invalidResponse
        }
        
        return try parseOllamaResponse(json)
    }
    
    func countTokens(messages: [Message]) async throws -> Int {
        // Rough estimation for Ollama models
        let totalCharacters = messages.reduce(0) { total, message in
            total + message.content.count
        }
        // Llama models use roughly 1 token per 4 characters
        return totalCharacters / 4
    }
    
    private func convertMessagesToOllamaFormat(_ messages: [Message]) -> [[String: Any]] {
        var ollamaMessages: [[String: Any]] = []
        
        for message in messages {
            switch message.role {
            case .system:
                ollamaMessages.append([
                    "role": "system",
                    "content": message.content
                ])
            case .user:
                if let toolCallId = message.toolCallId {
                    // This is a tool result - Ollama handles this as a user message
                    ollamaMessages.append([
                        "role": "user",
                        "content": "Tool result (id: \(toolCallId)): \(message.content)"
                    ])
                } else {
                    ollamaMessages.append([
                        "role": "user",
                        "content": message.content
                    ])
                }
            case .assistant:
                var content = message.content
                
                if let toolCalls = message.toolCalls {
                    for toolCall in toolCalls {
                        content += "\n\nTool call: \(toolCall.function.name)(\(toolCall.function.arguments))"
                    }
                }
                
                ollamaMessages.append([
                    "role": "assistant",
                    "content": content
                ])
            }
        }
        
        return ollamaMessages
    }
    
    private func convertToolsToOllamaFormat(_ tools: [ToolDefinition]) -> [[String: Any]] {
        return tools.map { tool in
            [
                "type": "function",
                "function": [
                    "name": tool.function.name,
                    "description": tool.function.description,
                    "parameters": convertJSONSchemaToOllamaSchema(tool.function.parameters)
                ]
            ]
        }
    }
    
    private func convertJSONSchemaToOllamaSchema(_ schema: JSONSchema) -> [String: Any] {
        var ollamaSchema: [String: Any] = [
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
            ollamaSchema["properties"] = propertiesDict
        }
        
        if let required = schema.required {
            ollamaSchema["required"] = required
        }
        
        return ollamaSchema
    }
    
    private func parseOllamaResponse(_ json: [String: Any]) throws -> ChatCompletionResponse {
        guard let message = json["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw LLMError.invalidResponse
        }
        
        // Parse tool calls from content if present
        var actualContent = content
        var toolCalls: [ToolCall] = []
        
        // Simple parsing for tool calls in content
        if content.contains("Tool call:") {
            let lines = content.components(separatedBy: "\n")
            var contentLines: [String] = []
            
            for line in lines {
                if line.hasPrefix("Tool call:") {
                    // Extract tool call information
                    let toolCallInfo = String(line.dropFirst("Tool call:".count)).trimmingCharacters(in: .whitespaces)
                    if let openParen = toolCallInfo.firstIndex(of: "("),
                       let closeParen = toolCallInfo.lastIndex(of: ")") {
                        let functionName = String(toolCallInfo[..<openParen])
                        let arguments = String(toolCallInfo[toolCallInfo.index(after: openParen)..<closeParen])
                        
                        toolCalls.append(ToolCall(
                            id: "call_\(UUID().uuidString)",
                            type: "function",
                            function: FunctionCall(name: functionName, arguments: arguments)
                        ))
                    }
                } else {
                    contentLines.append(line)
                }
            }
            
            actualContent = contentLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        // Ollama doesn't provide detailed usage statistics
        let usage = ChatCompletionResponse.Usage(
            promptTokens: 0,
            completionTokens: 0,
            totalTokens: 0
        )
        
        let responseMessage = ChatCompletionResponse.ResponseMessage(
            role: "assistant",
            content: actualContent.isEmpty ? nil : actualContent,
            toolCalls: toolCalls.isEmpty ? nil : toolCalls
        )
        
        return ChatCompletionResponse(
            id: UUID().uuidString,
            choices: [ChatCompletionResponse.Choice(
                message: responseMessage,
                finishReason: json["done"] as? Bool == true ? "stop" : nil
            )],
            usage: usage
        )
    }
}