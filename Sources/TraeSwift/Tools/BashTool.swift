import Foundation
import ShellOut

struct BashToolArguments: Codable {
    let command: String
    let timeout: Int?
    let captureOutput: Bool?
    let workingDirectory: String?
}

final class BashTool: Tool, @unchecked Sendable {
    let name = "bash"
    let description = "Execute bash commands in a persistent shell session with enhanced features"
    let parameters = JSONSchema(
        type: "object",
        properties: [
            "command": JSONSchema.Property(
                type: "string",
                description: "The bash command to execute. Use 'cd <directory>' to change working directory persistently.",
                items: nil,
                properties: nil,
                required: nil
            ),
            "timeout": JSONSchema.Property(
                type: "integer",
                description: "Optional timeout in seconds for the command (default: 30)",
                items: nil,
                properties: nil,
                required: nil
            ),
            "captureOutput": JSONSchema.Property(
                type: "boolean",
                description: "Whether to capture output (default: true)",
                items: nil,
                properties: nil,
                required: nil
            ),
            "workingDirectory": JSONSchema.Property(
                type: "string",
                description: "Optional working directory for this specific command",
                items: nil,
                properties: nil,
                required: nil
            )
        ],
        required: ["command"]
    )
    
    private var currentWorkingDirectory: String
    private var environmentVariables: [String: String] = [:]
    private var persistentSession: Bool = true
    
    init(workingDirectory: String = FileManager.default.currentDirectoryPath) {
        self.currentWorkingDirectory = workingDirectory
        
        // Initialize with current environment
        self.environmentVariables = ProcessInfo.processInfo.environment
    }
    
    func execute(arguments: String) async throws -> String {
        // Parse JSON arguments
        guard let data = arguments.data(using: .utf8) else {
            throw ToolError.invalidArguments("Could not convert arguments to data")
        }
        
        let decoder = JSONDecoder()
        let args: BashToolArguments
        do {
            args = try decoder.decode(BashToolArguments.self, from: data)
        } catch {
            throw ToolError.invalidArguments("Invalid JSON arguments: \(error.localizedDescription)")
        }
        
        // Handle persistent cd commands
        if args.command.hasPrefix("cd ") {
            return try await handleChangeDirectory(command: args.command)
        }
        
        // Handle environment variable exports
        if args.command.hasPrefix("export ") {
            return try await handleExportVariable(command: args.command)
        }
        
        // Determine working directory for this command
        let executionDirectory = args.workingDirectory ?? currentWorkingDirectory
        let timeout = args.timeout ?? 30
        let captureOutput = args.captureOutput ?? true
        
        // Execute command with enhanced error handling and timeout
        do {
            let output = try await executeWithTimeout(
                command: args.command,
                at: executionDirectory,
                timeout: timeout,
                captureOutput: captureOutput
            )
            
            return formatOutput(output, captureOutput: captureOutput)
        } catch {
            throw error
        }
    }
    
    // MARK: - Private Helper Methods
    
    private func handleChangeDirectory(command: String) async throws -> String {
        let path = String(command.dropFirst(3)).trimmingCharacters(in: .whitespacesAndNewlines)
        let targetPath: String
        
        if path.hasPrefix("/") {
            // Absolute path
            targetPath = path
        } else if path.hasPrefix("~") {
            // Home directory path
            let homeDirectory = FileManager.default.homeDirectoryForCurrentUser.path
            targetPath = path.replacingOccurrences(of: "~", with: homeDirectory)
        } else {
            // Relative path
            targetPath = URL(fileURLWithPath: currentWorkingDirectory).appendingPathComponent(path).path
        }
        
        // Verify directory exists
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: targetPath, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            throw ToolError.executionFailed("Directory does not exist: \(targetPath)")
        }
        
        // Update working directory
        currentWorkingDirectory = targetPath
        return "Changed directory to: \(currentWorkingDirectory)"
    }
    
    private func handleExportVariable(command: String) async throws -> String {
        let exportString = String(command.dropFirst(7)).trimmingCharacters(in: .whitespacesAndNewlines)
        
        if let equalsIndex = exportString.firstIndex(of: "=") {
            let varName = String(exportString[..<equalsIndex])
            let varValue = String(exportString[exportString.index(after: equalsIndex)...])
            
            // Remove quotes if present
            let cleanValue = varValue.trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
            
            environmentVariables[varName] = cleanValue
            return "Exported \(varName)=\(cleanValue)"
        } else {
            throw ToolError.invalidArguments("Invalid export syntax: \(command)")
        }
    }
    
    private func executeWithTimeout(command: String, at directory: String, timeout: Int, captureOutput: Bool) async throws -> String {
        return try await withThrowingTaskGroup(of: String.self) { group in
            // Add the main execution task
            group.addTask {
                return try await self.executeCommand(command: command, at: directory, captureOutput: captureOutput)
            }
            
            // Add timeout task
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(timeout) * 1_000_000_000)
                throw ToolError.executionFailed("Command timed out after \(timeout) seconds")
            }
            
            // Return the result of whichever task completes first
            guard let result = try await group.next() else {
                throw ToolError.executionFailed("No result from command execution")
            }
            
            // Cancel the other task
            group.cancelAll()
            return result
        }
    }
    
    private func executeCommand(command: String, at directory: String, captureOutput: Bool) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            do {
                // Build process with custom environment
                let process = Process()
                
                // Detect shell and platform
                let shell = detectShell()
                process.executableURL = URL(fileURLWithPath: shell)
                process.arguments = ["-c", command]
                process.currentDirectoryURL = URL(fileURLWithPath: directory)
                
                // Set environment variables
                process.environment = environmentVariables
                
                let outputPipe = Pipe()
                let errorPipe = Pipe()
                
                if captureOutput {
                    process.standardOutput = outputPipe
                    process.standardError = errorPipe
                }
                
                try process.run()
                process.waitUntilExit()
                
                if captureOutput {
                    let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                    let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                    
                    let output = String(data: outputData, encoding: .utf8) ?? ""
                    let errorOutput = String(data: errorData, encoding: .utf8) ?? ""
                    
                    if process.terminationStatus != 0 {
                        let errorMessage = """
                        Command failed with exit code \(process.terminationStatus)
                        Command: \(command)
                        Working Directory: \(directory)
                        Output: \(output)
                        Error: \(errorOutput)
                        """
                        continuation.resume(throwing: ToolError.executionFailed(errorMessage))
                    } else {
                        let combinedOutput = output + (errorOutput.isEmpty ? "" : "\nSTDERR:\n\(errorOutput)")
                        continuation.resume(returning: combinedOutput)
                    }
                } else {
                    if process.terminationStatus != 0 {
                        continuation.resume(throwing: ToolError.executionFailed("Command failed with exit code \(process.terminationStatus)"))
                    } else {
                        continuation.resume(returning: "Command executed successfully")
                    }
                }
            } catch {
                continuation.resume(throwing: ToolError.executionFailed("Failed to execute command: \(error.localizedDescription)"))
            }
        }
    }
    
    private func detectShell() -> String {
        // Check for common shells in order of preference
        let possibleShells = ["/bin/bash", "/bin/zsh", "/bin/sh"]
        
        for shell in possibleShells {
            if FileManager.default.fileExists(atPath: shell) {
                return shell
            }
        }
        
        // Fallback to system shell
        return ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/sh"
    }
    
    private func formatOutput(_ output: String, captureOutput: Bool) -> String {
        if !captureOutput {
            return "Command executed successfully"
        }
        
        if output.isEmpty {
            return "Command executed successfully (no output)"
        }
        
        // Limit output length to prevent overwhelming responses
        let maxLength = 2000
        if output.count > maxLength {
            return String(output.prefix(maxLength)) + "\n... (output truncated, \(output.count - maxLength) more characters)"
        }
        
        return output
    }
    
    // MARK: - Public Helper Methods
    
    /// Get the current working directory
    func getCurrentWorkingDirectory() -> String {
        return currentWorkingDirectory
    }
    
    /// Get current environment variables
    func getEnvironmentVariables() -> [String: String] {
        return environmentVariables
    }
    
    /// Reset session state
    func resetSession() {
        currentWorkingDirectory = FileManager.default.currentDirectoryPath
        environmentVariables = ProcessInfo.processInfo.environment
    }
}