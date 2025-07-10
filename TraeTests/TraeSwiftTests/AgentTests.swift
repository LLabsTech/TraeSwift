import XCTest
@testable import TraeSwift

// Mock LLM Client for testing
class MockLLMClient: LLMClient {
    var mockResponse: ChatCompletionResponse?
    var shouldThrowError = false
    
    func chat(messages: [Message], tools: [ToolDefinition]?, temperature: Double?, maxTokens: Int?) async throws -> ChatCompletionResponse {
        if shouldThrowError {
            throw LLMError.invalidResponse
        }
        
        return mockResponse ?? ChatCompletionResponse(
            id: "test-response",
            choices: [
                ChatCompletionResponse.Choice(
                    message: ChatCompletionResponse.ResponseMessage(
                        role: "assistant",
                        content: "Test response",
                        toolCalls: nil
                    ),
                    finishReason: "stop"
                )
            ],
            usage: ChatCompletionResponse.Usage(
                promptTokens: 10,
                completionTokens: 5,
                totalTokens: 15
            )
        )
    }
    
    func countTokens(messages: [Message]) async throws -> Int {
        return messages.reduce(0) { total, message in
            total + message.content.count / 4
        }
    }
}

// Mock Tool for testing
final class MockTool: Tool, @unchecked Sendable {
    let name: String = "mock_tool"
    let description: String = "A mock tool for testing"
    let parameters: JSONSchema = JSONSchema(
        type: "object",
        properties: [
            "input": JSONSchema.Property(
                type: "string",
                description: "Test input",
                items: nil,
                properties: nil,
                required: nil
            )
        ],
        required: ["input"]
    )
    
    var mockResult: String = "Mock tool executed successfully"
    var shouldThrowError = false
    
    func execute(arguments: String) async throws -> String {
        if shouldThrowError {
            throw ToolError.executionFailed("Mock tool error")
        }
        return mockResult
    }
}

final class AgentTests: XCTestCase {
    
    func testBaseAgentInitialization() {
        let mockClient = MockLLMClient()
        let config = FullConfig()
        let tools: [Tool] = [MockTool()]
        
        let agent = BaseAgent(
            name: "TestAgent",
            systemPrompt: "You are a helpful assistant",
            tools: tools,
            llmClient: mockClient,
            config: config
        )
        
        XCTAssertEqual(agent.name, "TestAgent")
        XCTAssertEqual(agent.systemPrompt, "You are a helpful assistant")
        XCTAssertEqual(agent.tools.count, 1)
        XCTAssertTrue(agent.llmClient is MockLLMClient)
    }
    
    func testTraeAgentCreation() throws {
        let config = FullConfig(
            defaultProvider: "anthropic",
            modelProviders: [
                "anthropic": ModelParameters(
                    model: "claude-sonnet-4-20250514",
                    apiKey: "test-key"
                )
            ]
        )
        
        let agent = try TraeAgent.create(from: config)
        
        XCTAssertEqual(agent.name, "TraeAgent")
        XCTAssertFalse(agent.systemPrompt.isEmpty)
        XCTAssertTrue(agent.tools.count > 0)
        
        // Check that all expected tools are present
        let toolNames = agent.tools.map { $0.name }
        XCTAssertTrue(toolNames.contains("bash"))
        XCTAssertTrue(toolNames.contains("run"))
        XCTAssertTrue(toolNames.contains("text_editor"))
        XCTAssertTrue(toolNames.contains("json_edit_tool"))
        XCTAssertTrue(toolNames.contains("sequentialthinking"))
        XCTAssertTrue(toolNames.contains("task_done"))
    }
    
    func testAgentStepCreation() {
        let step = AgentStep(
            stepNumber: 1,
            state: .thinking,
            thought: "Analyzing the problem"
        )
        
        XCTAssertEqual(step.stepNumber, 1)
        XCTAssertEqual(step.state, .thinking)
        XCTAssertEqual(step.thought, "Analyzing the problem")
        XCTAssertNil(step.toolCalls)
        XCTAssertNil(step.toolResults)
        XCTAssertNil(step.error)
    }
    
    func testAgentStepWithToolCalls() {
        let functionCall = FunctionCall(name: "test_tool", arguments: "{}")
        let toolCall = ToolCall(id: "call_1", type: "function", function: functionCall)
        
        let step = AgentStep(
            stepNumber: 2,
            state: .callingTool,
            toolCalls: [toolCall]
        )
        
        XCTAssertEqual(step.stepNumber, 2)
        XCTAssertEqual(step.state, .callingTool)
        XCTAssertEqual(step.toolCalls?.count, 1)
        XCTAssertEqual(step.toolCalls?.first?.id, "call_1")
    }
    
    func testAgentStepWithError() {
        let step = AgentStep(
            stepNumber: 3,
            state: .error,
            error: "Something went wrong"
        )
        
        XCTAssertEqual(step.stepNumber, 3)
        XCTAssertEqual(step.state, .error)
        XCTAssertEqual(step.error, "Something went wrong")
    }
    
    func testAgentExecutionCreation() {
        let steps = [
            AgentStep(stepNumber: 1, state: .thinking),
            AgentStep(stepNumber: 2, state: .completed)
        ]
        
        let execution = AgentExecution(
            task: "Test task",
            steps: steps,
            finalResult: "Task completed",
            success: true,
            executionTime: 10.5
        )
        
        XCTAssertEqual(execution.task, "Test task")
        XCTAssertEqual(execution.steps.count, 2)
        XCTAssertEqual(execution.finalResult, "Task completed")
        XCTAssertEqual(execution.success, true)
        XCTAssertEqual(execution.executionTime, 10.5)
    }
    
    func testAgentErrorTypes() {
        let errors: [AgentError] = [
            .executionFailed("Test failure"),
            .maxIterationsReached,
            .configurationError("Bad config"),
            .llmError("LLM failed"),
            .toolError("Tool failed")
        ]
        
        XCTAssertEqual(errors[0].message, "Execution failed: Test failure")
        XCTAssertEqual(errors[1].message, "Maximum iterations reached")
        XCTAssertEqual(errors[2].message, "Configuration error: Bad config")
        XCTAssertEqual(errors[3].message, "LLM error: LLM failed")
        XCTAssertEqual(errors[4].message, "Tool error: Tool failed")
    }
    
    func testLLMResponseCreation() {
        let response = LLMResponse(
            content: "Hello, world!",
            usage: LLMUsage(inputTokens: 10, outputTokens: 5),
            model: "test-model",
            finishReason: "stop"
        )
        
        XCTAssertEqual(response.content, "Hello, world!")
        XCTAssertEqual(response.usage?.inputTokens, 10)
        XCTAssertEqual(response.usage?.outputTokens, 5)
        XCTAssertEqual(response.model, "test-model")
        XCTAssertEqual(response.finishReason, "stop")
    }
    
    func testToolResultCreation() {
        let result = ToolResult(
            toolCallId: "call_123",
            content: "Tool executed successfully",
            error: nil
        )
        
        XCTAssertEqual(result.toolCallId, "call_123")
        XCTAssertEqual(result.content, "Tool executed successfully")
        XCTAssertNil(result.error)
    }
    
    func testToolResultWithError() {
        let result = ToolResult(
            toolCallId: "call_456",
            content: "Tool failed",
            error: "Invalid input"
        )
        
        XCTAssertEqual(result.toolCallId, "call_456")
        XCTAssertEqual(result.content, "Tool failed")
        XCTAssertEqual(result.error, "Invalid input")
    }
}