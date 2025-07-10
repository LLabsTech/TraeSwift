import XCTest
@testable import TraeSwift

final class MessageTests: XCTestCase {
    
    func testMessageInitialization() {
        let message = Message(
            role: .user,
            content: "Hello, how are you?"
        )
        
        XCTAssertEqual(message.role, .user)
        XCTAssertEqual(message.content, "Hello, how are you?")
        XCTAssertNil(message.toolCalls)
        XCTAssertNil(message.toolCallId)
    }
    
    func testMessageWithToolCall() {
        let functionCall = FunctionCall(
            name: "test_function",
            arguments: "{\"param\": \"value\"}"
        )
        
        let toolCall = ToolCall(
            id: "call_123",
            type: "function",
            function: functionCall
        )
        
        let message = Message(
            role: .assistant,
            content: "I'll help you with that.",
            toolCalls: [toolCall]
        )
        
        XCTAssertEqual(message.role, .assistant)
        XCTAssertEqual(message.content, "I'll help you with that.")
        XCTAssertEqual(message.toolCalls?.count, 1)
        XCTAssertEqual(message.toolCalls?.first?.id, "call_123")
        XCTAssertEqual(message.toolCalls?.first?.function.name, "test_function")
    }
    
    func testMessageWithToolCallId() {
        let message = Message(
            role: .user,
            content: "Function executed successfully",
            toolCallId: "call_123"
        )
        
        XCTAssertEqual(message.role, .user)
        XCTAssertEqual(message.content, "Function executed successfully")
        XCTAssertEqual(message.toolCallId, "call_123")
        XCTAssertNil(message.toolCalls)
    }
    
    func testMessageRoleRawValues() {
        XCTAssertEqual(MessageRole.system.rawValue, "system")
        XCTAssertEqual(MessageRole.user.rawValue, "user")
        XCTAssertEqual(MessageRole.assistant.rawValue, "assistant")
    }
    
    func testFunctionCallInitialization() {
        let functionCall = FunctionCall(
            name: "get_weather",
            arguments: "{\"location\": \"San Francisco\"}"
        )
        
        XCTAssertEqual(functionCall.name, "get_weather")
        XCTAssertEqual(functionCall.arguments, "{\"location\": \"San Francisco\"}")
    }
    
    func testToolCallInitialization() {
        let functionCall = FunctionCall(
            name: "calculator",
            arguments: "{\"operation\": \"add\", \"numbers\": [1, 2]}"
        )
        
        let toolCall = ToolCall(
            id: "call_456",
            type: "function",
            function: functionCall
        )
        
        XCTAssertEqual(toolCall.id, "call_456")
        XCTAssertEqual(toolCall.type, "function")
        XCTAssertEqual(toolCall.function.name, "calculator")
        XCTAssertEqual(toolCall.function.arguments, "{\"operation\": \"add\", \"numbers\": [1, 2]}")
    }
    
    func testToolDefinitionInitialization() {
        let jsonSchema = JSONSchema(
            type: "object",
            properties: [
                "location": JSONSchema.Property(
                    type: "string",
                    description: "The location to get weather for",
                    items: nil,
                    properties: nil,
                    required: nil
                )
            ],
            required: ["location"]
        )
        
        let functionDefinition = ToolDefinition.FunctionDefinition(
            name: "get_weather",
            description: "Get the current weather for a location",
            parameters: jsonSchema
        )
        
        let toolDefinition = ToolDefinition(function: functionDefinition)
        
        XCTAssertEqual(toolDefinition.function.name, "get_weather")
        XCTAssertEqual(toolDefinition.function.description, "Get the current weather for a location")
        XCTAssertEqual(toolDefinition.function.parameters.type, "object")
        XCTAssertEqual(toolDefinition.function.parameters.required, ["location"])
    }
    
    func testChatCompletionResponse() {
        let responseMessage = ChatCompletionResponse.ResponseMessage(
            role: "assistant",
            content: "Hello! How can I help you today?",
            toolCalls: nil
        )
        
        let choice = ChatCompletionResponse.Choice(
            message: responseMessage,
            finishReason: "stop"
        )
        
        let usage = ChatCompletionResponse.Usage(
            promptTokens: 10,
            completionTokens: 15,
            totalTokens: 25
        )
        
        let response = ChatCompletionResponse(
            id: "chatcmpl-123",
            choices: [choice],
            usage: usage
        )
        
        XCTAssertEqual(response.id, "chatcmpl-123")
        XCTAssertEqual(response.choices.count, 1)
        XCTAssertEqual(response.choices.first?.message.role, "assistant")
        XCTAssertEqual(response.choices.first?.message.content, "Hello! How can I help you today?")
        XCTAssertEqual(response.choices.first?.finishReason, "stop")
        XCTAssertEqual(response.usage?.promptTokens, 10)
        XCTAssertEqual(response.usage?.completionTokens, 15)
        XCTAssertEqual(response.usage?.totalTokens, 25)
    }
}