import Foundation

struct TaskDoneArguments: Codable {
    let output: String?
}

final class TaskDoneTool: Tool, @unchecked Sendable {
    let name = "task_done"
    let description = "Mark the current task as complete and optionally provide output"
    let parameters = JSONSchema(
        type: "object",
        properties: [
            "output": JSONSchema.Property(
                type: "string",
                description: "Optional output or result of the completed task",
                items: nil,
                properties: nil,
                required: nil
            )
        ],
        required: []
    )
    
    func execute(arguments: String) async throws -> String {
        // Parse JSON arguments
        guard let data = arguments.data(using: .utf8) else {
            throw ToolError.invalidArguments("Could not convert arguments to data")
        }
        
        let decoder = JSONDecoder()
        let args: TaskDoneArguments
        do {
            args = try decoder.decode(TaskDoneArguments.self, from: data)
        } catch {
            throw ToolError.invalidArguments("Invalid JSON arguments: \(error.localizedDescription)")
        }
        
        if let output = args.output {
            return "Task completed successfully. Output: \(output)"
        } else {
            return "Task completed successfully."
        }
    }
}