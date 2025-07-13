import Foundation

class GoogleLLMClient: LLMClient {
    private let apiKey: String
    private let baseURL: String
    private let model: String
    private let urlSession: URLSession
    
    init(apiKey: String, model: String = "gemini-1.5-pro-002", baseURL: String = "https://generativelanguage.googleapis.com") {
        self.apiKey = apiKey
        self.model = model
        self.baseURL = baseURL
        
        // Configure URLSession with extended timeouts for LLM responses
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 300.0 // 5 minutes
        config.timeoutIntervalForResource = 600.0 // 10 minutes
        self.urlSession = URLSession(configuration: config)
    }
    
    func chat(messages: [Message], tools: [ToolDefinition]?, temperature: Double?, maxTokens: Int?) async throws -> ChatCompletionResponse {
        let url = URL(string: "\(baseURL)/v1beta/models/\(model):generateContent?key=\(apiKey)")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Convert messages to Google format
        let googleContent = convertMessagesToGoogleFormat(messages)
        
        var requestBody: [String: Any] = [
            "contents": googleContent,
            "generationConfig": [
                "maxOutputTokens": maxTokens ?? 4096,
                "temperature": temperature ?? 0.5
            ]
        ]
        
        if let tools = tools {
            requestBody["tools"] = [
                "functionDeclarations": convertToolsToGoogleFormat(tools)
            ]
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
        
        // Parse Google response and convert to our format
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw LLMError.invalidResponse
        }
        
        return try parseGoogleResponse(json)
    }
    
    func countTokens(messages: [Message]) async throws -> Int {
        // Rough estimation for Google Gemini
        let totalCharacters = messages.reduce(0) { total, message in
            total + message.content.count
        }
        // Gemini uses roughly 1 token per 4 characters
        return totalCharacters / 4
    }
    
    private func convertMessagesToGoogleFormat(_ messages: [Message]) -> [[String: Any]] {
        var googleContent: [[String: Any]] = []
        
        for message in messages {
            switch message.role {
            case .system:
                // Google handles system messages as user messages with special formatting
                googleContent.append([
                    "role": "user",
                    "parts": [
                        ["text": "System: \(message.content)"]
                    ]
                ])
            case .user:
                if let toolCallId = message.toolCallId {
                    // This is a tool result
                    googleContent.append([
                        "role": "function",
                        "parts": [
                            [
                                "functionResponse": [
                                    "name": "function_call_\(toolCallId)",
                                    "response": ["result": message.content]
                                ]
                            ]
                        ]
                    ])
                } else {
                    googleContent.append([
                        "role": "user",
                        "parts": [
                            ["text": message.content]
                        ]
                    ])
                }
            case .assistant:
                var parts: [[String: Any]] = []
                
                if !message.content.isEmpty {
                    parts.append(["text": message.content])
                }
                
                if let toolCalls = message.toolCalls {
                    for toolCall in toolCalls {
                        if let argsData = toolCall.function.arguments.data(using: .utf8),
                           let args = try? JSONSerialization.jsonObject(with: argsData) as? [String: Any] {
                            parts.append([
                                "functionCall": [
                                    "name": toolCall.function.name,
                                    "args": args
                                ]
                            ])
                        }
                    }
                }
                
                googleContent.append([
                    "role": "model",
                    "parts": parts
                ])
            }
        }
        
        return googleContent
    }
    
    private func convertToolsToGoogleFormat(_ tools: [ToolDefinition]) -> [[String: Any]] {
        return tools.map { tool in
            [
                "name": tool.function.name,
                "description": tool.function.description,
                "parameters": convertJSONSchemaToGoogleSchema(tool.function.parameters)
            ]
        }
    }
    
    private func convertJSONSchemaToGoogleSchema(_ schema: JSONSchema) -> [String: Any] {
        var googleSchema: [String: Any] = [
            "type": schema.type.uppercased()
        ]
        
        if let properties = schema.properties {
            var propertiesDict: [String: Any] = [:]
            for (key, prop) in properties {
                propertiesDict[key] = [
                    "type": prop.type.uppercased(),
                    "description": prop.description ?? ""
                ]
            }
            googleSchema["properties"] = propertiesDict
        }
        
        if let required = schema.required {
            googleSchema["required"] = required
        }
        
        return googleSchema
    }
    
    private func parseGoogleResponse(_ json: [String: Any]) throws -> ChatCompletionResponse {
        guard let candidates = json["candidates"] as? [[String: Any]],
              let firstCandidate = candidates.first,
              let content = firstCandidate["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]] else {
            throw LLMError.invalidResponse
        }
        
        var responseContent = ""
        var toolCalls: [ToolCall] = []
        
        for part in parts {
            if let text = part["text"] as? String {
                responseContent += text
            } else if let functionCall = part["functionCall"] as? [String: Any],
                      let name = functionCall["name"] as? String,
                      let args = functionCall["args"] {
                let argumentsData = try JSONSerialization.data(withJSONObject: args)
                let argumentsString = String(data: argumentsData, encoding: .utf8) ?? "{}"
                
                toolCalls.append(ToolCall(
                    id: "call_\(UUID().uuidString)",
                    type: "function",
                    function: FunctionCall(name: name, arguments: argumentsString)
                ))
            }
        }
        
        // Google doesn't provide detailed usage statistics in the same format
        let usage = ChatCompletionResponse.Usage(
            promptTokens: 0,
            completionTokens: 0,
            totalTokens: 0
        )
        
        let responseMessage = ChatCompletionResponse.ResponseMessage(
            role: "assistant",
            content: responseContent.isEmpty ? nil : responseContent,
            toolCalls: toolCalls.isEmpty ? nil : toolCalls
        )
        
        let finishReason = firstCandidate["finishReason"] as? String
        
        return ChatCompletionResponse(
            id: UUID().uuidString,
            choices: [ChatCompletionResponse.Choice(
                message: responseMessage,
                finishReason: finishReason
            )],
            usage: usage
        )
    }
}