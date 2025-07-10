import XCTest
@testable import TraeSwift

final class TraeSwiftTests: XCTestCase {
    
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        XCTAssertEqual(1 + 1, 2)
    }
    
    func testAgentStateEnum() {
        // Test all agent states are properly defined
        let allStates: [AgentState] = [.idle, .thinking, .callingTool, .reflecting, .completed, .error]
        XCTAssertEqual(allStates.count, 6)
        
        // Test raw values
        XCTAssertEqual(AgentState.idle.rawValue, "idle")
        XCTAssertEqual(AgentState.thinking.rawValue, "thinking")
        XCTAssertEqual(AgentState.callingTool.rawValue, "calling_tool")
        XCTAssertEqual(AgentState.reflecting.rawValue, "reflecting")
        XCTAssertEqual(AgentState.completed.rawValue, "completed")
        XCTAssertEqual(AgentState.error.rawValue, "error")
    }
    
    func testLLMUsageAddition() {
        let usage1 = LLMUsage(inputTokens: 100, outputTokens: 50)
        let usage2 = LLMUsage(inputTokens: 200, outputTokens: 75)
        
        let combined = usage1 + usage2
        
        XCTAssertEqual(combined.inputTokens, 300)
        XCTAssertEqual(combined.outputTokens, 125)
        XCTAssertEqual(combined.cacheCreationInputTokens, 0)
        XCTAssertEqual(combined.cacheReadInputTokens, 0)
        XCTAssertEqual(combined.reasoningTokens, 0)
    }
}