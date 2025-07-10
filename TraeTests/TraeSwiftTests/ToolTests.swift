import XCTest
@testable import TraeSwift

final class ToolTests: XCTestCase {
    
    func testBashToolProperties() {
        let bashTool = BashTool()
        
        XCTAssertEqual(bashTool.name, "bash")
        XCTAssertFalse(bashTool.description.isEmpty)
        XCTAssertEqual(bashTool.parameters.type, "object")
        XCTAssertNotNil(bashTool.parameters.properties)
        XCTAssertEqual(bashTool.parameters.required, ["command"])
    }
    
    func testRunToolProperties() {
        let runTool = RunTool()
        
        XCTAssertEqual(runTool.name, "run")
        XCTAssertFalse(runTool.description.isEmpty)
        XCTAssertEqual(runTool.parameters.type, "object")
        XCTAssertNotNil(runTool.parameters.properties)
        XCTAssertEqual(runTool.parameters.required, ["command"])
    }
    
    func testTextEditorToolProperties() {
        let textEditorTool = TextEditorTool()
        
        XCTAssertEqual(textEditorTool.name, "text_editor")
        XCTAssertFalse(textEditorTool.description.isEmpty)
        XCTAssertEqual(textEditorTool.parameters.type, "object")
        XCTAssertNotNil(textEditorTool.parameters.properties)
        XCTAssertEqual(textEditorTool.parameters.required, ["command", "path"])
    }
    
    func testJSONEditToolProperties() {
        let jsonEditTool = JSONEditTool()
        
        XCTAssertEqual(jsonEditTool.name, "json_edit_tool")
        XCTAssertFalse(jsonEditTool.description.isEmpty)
        XCTAssertEqual(jsonEditTool.parameters.type, "object")
        XCTAssertNotNil(jsonEditTool.parameters.properties)
        XCTAssertEqual(jsonEditTool.parameters.required, ["operation", "file_path"])
    }
    
    func testSequentialThinkingToolProperties() {
        let sequentialThinkingTool = SequentialThinkingTool()
        
        XCTAssertEqual(sequentialThinkingTool.name, "sequentialthinking")
        XCTAssertFalse(sequentialThinkingTool.description.isEmpty)
        XCTAssertEqual(sequentialThinkingTool.parameters.type, "object")
        XCTAssertNotNil(sequentialThinkingTool.parameters.properties)
        XCTAssertEqual(sequentialThinkingTool.parameters.required, ["thought", "next_thought_needed", "thought_number", "total_thoughts"])
    }
    
    func testTaskDoneToolProperties() {
        let taskDoneTool = TaskDoneTool()
        
        XCTAssertEqual(taskDoneTool.name, "task_done")
        XCTAssertFalse(taskDoneTool.description.isEmpty)
        XCTAssertEqual(taskDoneTool.parameters.type, "object")
        XCTAssertNotNil(taskDoneTool.parameters.properties)
        XCTAssertEqual(taskDoneTool.parameters.required, [])
    }
    
    func testToolDefinitionConversion() {
        let bashTool = BashTool()
        let toolDefinition = bashTool.toToolDefinition()
        
        XCTAssertEqual(toolDefinition.function.name, "bash")
        XCTAssertEqual(toolDefinition.function.description, bashTool.description)
        XCTAssertEqual(toolDefinition.function.parameters.type, "object")
    }
    
    func testSequentialThinkingToolExecution() async throws {
        let tool = SequentialThinkingTool()
        let arguments = """
        {
            "thought": "I need to analyze this problem step by step.",
            "next_thought_needed": false,
            "thought_number": 1,
            "total_thoughts": 1
        }
        """
        
        let result = try await tool.execute(arguments: arguments)
        XCTAssertFalse(result.isEmpty)
        XCTAssertTrue(result.contains("Sequential thinking step completed"))
    }
    
    func testTaskDoneToolExecution() async throws {
        let tool = TaskDoneTool()
        let arguments = """
        {
            "output": "Task completed successfully"
        }
        """
        
        let result = try await tool.execute(arguments: arguments)
        XCTAssertFalse(result.isEmpty)
        XCTAssertTrue(result.contains("Task completed successfully"))
    }
}