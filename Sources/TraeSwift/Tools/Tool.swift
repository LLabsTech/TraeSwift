import Foundation

protocol Tool: Sendable {
    var name: String { get }
    var description: String { get }
    var parameters: JSONSchema { get }
    
    func execute(arguments: String) async throws -> String
}

extension Tool {
    func toToolDefinition() -> ToolDefinition {
        return ToolDefinition(
            function: ToolDefinition.FunctionDefinition(
                name: name,
                description: description,
                parameters: parameters
            )
        )
    }
}

enum ToolError: Error {
    case invalidArguments(String)
    case executionFailed(String)
    case notImplemented
}