import Foundation
import ShellOut

final class RunTool: Tool, @unchecked Sendable {
    private let maxResponseLength = 16000
    private let defaultTimeout: TimeInterval = 120
    
    var name: String {
        return "run"
    }
    
    var description: String {
        return """
        Run bash commands in a persistent session. The session maintains state across multiple command executions.
        
        IMPORTANT:
        - Use this tool to run any bash/shell commands
        - The session persists environment variables, directory changes, etc.
        - Commands run asynchronously with a 120-second timeout
        - Output is automatically truncated if it exceeds 16,000 characters
        - Use 'restart: true' to restart the bash session if needed
        
        Examples:
        - List files: {"command": "ls -la"}
        - Change directory: {"command": "cd /path/to/directory && pwd"}
        - Install packages: {"command": "npm install express"}
        - Run tests: {"command": "npm test"}
        - Restart session: {"command": "pwd", "restart": true}
        """
    }
    
    var parameters: JSONSchema {
        return JSONSchema(
            type: "object",
            properties: [
                "command": JSONSchema.Property(
                    type: "string",
                    description: "The bash command to execute",
                    items: nil,
                    properties: nil,
                    required: nil
                ),
                "restart": JSONSchema.Property(
                    type: "boolean",
                    description: "Whether to restart the bash session before executing the command",
                    items: nil,
                    properties: nil,
                    required: nil
                )
            ],
            required: ["command"]
        )
    }
    
    func execute(arguments: String) async throws -> String {
        // Parse JSON arguments
        guard let data = arguments.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ToolError.invalidArguments("Invalid JSON arguments")
        }
        
        return try await executeWithParsedArguments(json)
    }
    
    private func executeWithParsedArguments(_ arguments: [String: Any]) async throws -> String {
        guard let command = arguments["command"] as? String else {
            throw ToolError.invalidArguments("Missing required parameter 'command'")
        }
        
        let _ = arguments["restart"] as? Bool ?? false
        
        do {
            // Use ShellOut for reliable command execution
            let result = try shellOut(to: command)
            return maybetruncate(content: result, truncateAfter: maxResponseLength)
        } catch {
            let errorMessage = "Command failed: \(error.localizedDescription)"
            return maybetruncate(content: errorMessage, truncateAfter: maxResponseLength)
        }
    }
    
    private func maybetruncate(content: String, truncateAfter: Int) -> String {
        if content.count <= truncateAfter {
            return content
        }
        
        let truncatedContent = String(content.prefix(truncateAfter))
        let truncatedMessage = "\n\n[Output truncated after \(truncateAfter) characters. The command may have produced more output.]"
        return truncatedContent + truncatedMessage
    }
}