import Foundation

struct TextEditorArguments: Codable {
    let command: String
    let path: String
    let content: String?
    
    // For str_replace
    let oldStr: String?
    let newStr: String?
    
    // For insert
    let lineNumber: Int?
    let newText: String?
    
    // For view
    let viewRange: [Int]?
    
    enum CodingKeys: String, CodingKey {
        case command
        case path
        case content
        case oldStr = "old_str"
        case newStr = "new_str"
        case lineNumber = "line_number"
        case newText = "new_text"
        case viewRange = "view_range"
    }
}

final class TextEditorTool: Tool, @unchecked Sendable {
    let name = "text_editor"
    let description = """
    Advanced text editor for viewing and editing files with line-based operations
    
    IMPORTANT: All paths must be absolute (starting with /), not relative.
    
    Supported operations:
    - view: Display file contents with line numbers, optionally within a range
    - create: Create a new file (fails if file already exists)
    - str_replace: Replace exact text with new text (must be unique match)
    - insert: Insert text at a specific line number
    
    Examples:
    - View entire file: {"command": "view", "path": "/path/to/file.txt"}
    - View lines 1-50: {"command": "view", "path": "/path/to/file.txt", "view_range": [1, 50]}
    - View from line 20 to end: {"command": "view", "path": "/path/to/file.txt", "view_range": [20, -1]}
    - Create file: {"command": "create", "path": "/path/to/new.txt", "content": "Initial content"}
    - Replace text: {"command": "str_replace", "path": "/path/to/file.txt", "old_str": "old text", "new_str": "new text"}
    - Insert at line 5: {"command": "insert", "path": "/path/to/file.txt", "line_number": 5, "new_text": "inserted line"}
    
    The str_replace operation requires an exact, unique match. If the old_str appears multiple times
    or doesn't appear at all, the operation will fail with a detailed error message.
    
    Line numbers are 1-indexed. Use -1 as the end line in view_range to read to the end of file.
    """
    
    let parameters = JSONSchema(
        type: "object",
        properties: [
            "command": JSONSchema.Property(
                type: "string",
                description: "The operation to perform (view, create, str_replace, insert)",
                items: nil,
                properties: nil,
                required: nil
            ),
            "path": JSONSchema.Property(
                type: "string",
                description: "Absolute path to the file (must start with /)",
                items: nil,
                properties: nil,
                required: nil
            ),
            "content": JSONSchema.Property(
                type: "string",
                description: "Content for create command",
                items: nil,
                properties: nil,
                required: nil
            ),
            "old_str": JSONSchema.Property(
                type: "string",
                description: "Exact text to replace (must match exactly and be unique)",
                items: nil,
                properties: nil,
                required: nil
            ),
            "new_str": JSONSchema.Property(
                type: "string",
                description: "New text to replace with",
                items: nil,
                properties: nil,
                required: nil
            ),
            "line_number": JSONSchema.Property(
                type: "integer",
                description: "Line number for insert operation (1-indexed)",
                items: nil,
                properties: nil,
                required: nil
            ),
            "new_text": JSONSchema.Property(
                type: "string",
                description: "Text to insert at the specified line",
                items: nil,
                properties: nil,
                required: nil
            ),
            "view_range": JSONSchema.Property(
                type: "array",
                description: "Array of [start_line, end_line] for view command. Use -1 for end_line to read to end",
                items: nil,
                properties: nil,
                required: nil
            )
        ],
        required: ["command", "path"]
    )
    
    private let maxFileLines = 10000
    private let contextLines = 3
    
    func execute(arguments: String) async throws -> String {
        // Parse arguments
        guard let data = arguments.data(using: .utf8) else {
            throw ToolError.invalidArguments("Could not convert arguments to data")
        }
        
        let decoder = JSONDecoder()
        let args: TextEditorArguments
        do {
            args = try decoder.decode(TextEditorArguments.self, from: data)
        } catch {
            throw ToolError.invalidArguments("Invalid JSON arguments: \(error.localizedDescription)")
        }
        
        // Validate absolute path
        guard args.path.hasPrefix("/") else {
            throw ToolError.invalidArguments("Path must be absolute (start with /), got: \(args.path)")
        }
        
        let url = URL(fileURLWithPath: args.path)
        
        switch args.command.lowercased() {
        case "view":
            return try await performView(url: url, viewRange: args.viewRange)
        case "create":
            return try await performCreate(url: url, content: args.content)
        case "str_replace":
            return try await performStrReplace(url: url, oldStr: args.oldStr, newStr: args.newStr)
        case "insert":
            return try await performInsert(url: url, lineNumber: args.lineNumber, newText: args.newText)
        default:
            throw ToolError.invalidArguments("Unknown command: \(args.command). Supported commands: view, create, str_replace, insert")
        }
    }
    
    private func performView(url: URL, viewRange: [Int]?) async throws -> String {
        // Check if it's a directory
        let fileManager = FileManager.default
        var isDirectory: ObjCBool = false
        
        if fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) && isDirectory.boolValue {
            // List directory contents
            let contents = try fileManager.contentsOfDirectory(atPath: url.path)
            let sortedContents = contents.sorted()
            
            var result = "Directory contents of \(url.path):\n"
            for item in sortedContents {
                let itemPath = url.appendingPathComponent(item)
                var itemIsDirectory: ObjCBool = false
                fileManager.fileExists(atPath: itemPath.path, isDirectory: &itemIsDirectory)
                let indicator = itemIsDirectory.boolValue ? "/" : ""
                result += "\(item)\(indicator)\n"
            }
            return result
        }
        
        // It's a file
        guard fileManager.fileExists(atPath: url.path) else {
            throw ToolError.executionFailed("File not found: \(url.path)")
        }
        
        let content = try String(contentsOf: url, encoding: .utf8)
        let lines = content.components(separatedBy: .newlines)
        
        // Handle empty file
        if lines.isEmpty || (lines.count == 1 && lines[0].isEmpty) {
            return "File \(url.path) is empty."
        }
        
        // Apply view range if specified
        let (startLine, endLine) = parseViewRange(viewRange, totalLines: lines.count)
        let viewLines = Array(lines[startLine-1..<endLine])
        
        // Format with line numbers
        var result = "File: \(url.path)\n"
        if viewRange != nil {
            result += "Lines \(startLine)-\(endLine) of \(lines.count):\n"
        } else {
            result += "Total lines: \(lines.count)\n"
        }
        
        // Check if file is too large
        if lines.count > maxFileLines && viewRange == nil {
            result += "⚠️  File is large (\(lines.count) lines). Consider using view_range to view specific sections.\n"
            result += "Showing first \(maxFileLines) lines:\n"
        }
        
        result += "\n"
        
        for (index, line) in viewLines.enumerated() {
            let lineNumber = startLine + index
            result += "\(lineNumber)→\(line)\n"
        }
        
        // Add truncation notice if needed
        if lines.count > maxFileLines && viewRange == nil {
            result += "\n⚠️  File truncated. \(lines.count - maxFileLines) more lines not shown."
        }
        
        return result
    }
    
    private func performCreate(url: URL, content: String?) async throws -> String {
        guard let content = content else {
            throw ToolError.invalidArguments("content is required for create command")
        }
        
        // Check if file already exists
        if FileManager.default.fileExists(atPath: url.path) {
            throw ToolError.executionFailed("File already exists: \(url.path). Use str_replace or a different command to modify existing files.")
        }
        
        // Create parent directories if needed
        let parentURL = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: parentURL, withIntermediateDirectories: true, attributes: nil)
        
        // Write the file
        try content.write(to: url, atomically: true, encoding: .utf8)
        
        let lines = content.components(separatedBy: .newlines)
        return "File created successfully: \(url.path)\nContent (\(lines.count) lines):\n\n" + formatContentWithLineNumbers(content)
    }
    
    private func performStrReplace(url: URL, oldStr: String?, newStr: String?) async throws -> String {
        guard let oldStr = oldStr else {
            throw ToolError.invalidArguments("old_str is required for str_replace command")
        }
        
        guard let newStr = newStr else {
            throw ToolError.invalidArguments("new_str is required for str_replace command")
        }
        
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw ToolError.executionFailed("File not found: \(url.path)")
        }
        
        let content = try String(contentsOf: url, encoding: .utf8)
        
        // Check if old_str exists and count occurrences
        let occurrences = content.components(separatedBy: oldStr).count - 1
        
        if occurrences == 0 {
            throw ToolError.executionFailed("Text not found in file: '\(oldStr)'\n\nFile content preview:\n\(getContentPreview(content))")
        }
        
        if occurrences > 1 {
            let contexts = findAllOccurrences(of: oldStr, in: content)
            var errorMessage = "Multiple occurrences (\(occurrences)) of text found. Please be more specific.\n\nFound at:\n"
            for (index, context) in contexts.enumerated() {
                errorMessage += "\nOccurrence \(index + 1):\n\(context)\n"
            }
            throw ToolError.executionFailed(errorMessage)
        }
        
        // Perform replacement
        let newContent = content.replacingOccurrences(of: oldStr, with: newStr)
        
        // Write back to file
        try newContent.write(to: url, atomically: true, encoding: .utf8)
        
        // Generate success message with context
        let context = getReplacementContext(oldStr: oldStr, newStr: newStr, in: content)
        
        return "Text replaced successfully in \(url.path)\n\nReplacement:\n\(context)"
    }
    
    private func performInsert(url: URL, lineNumber: Int?, newText: String?) async throws -> String {
        guard let lineNumber = lineNumber else {
            throw ToolError.invalidArguments("line_number is required for insert command")
        }
        
        guard let newText = newText else {
            throw ToolError.invalidArguments("new_text is required for insert command")
        }
        
        guard lineNumber >= 1 else {
            throw ToolError.invalidArguments("line_number must be >= 1, got: \(lineNumber)")
        }
        
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw ToolError.executionFailed("File not found: \(url.path)")
        }
        
        let content = try String(contentsOf: url, encoding: .utf8)
        var lines = content.components(separatedBy: .newlines)
        
        // Handle empty file case
        if lines.count == 1 && lines[0].isEmpty {
            lines = []
        }
        
        // Validate line number
        if lineNumber > lines.count + 1 {
            throw ToolError.invalidArguments("line_number \(lineNumber) is beyond end of file (file has \(lines.count) lines)")
        }
        
        // Insert the new text
        let insertIndex = lineNumber - 1
        lines.insert(newText, at: insertIndex)
        
        let newContent = lines.joined(separator: "\n")
        
        // Write back to file
        try newContent.write(to: url, atomically: true, encoding: .utf8)
        
        // Generate success message with context
        let context = getInsertionContext(lineNumber: lineNumber, newText: newText, lines: lines)
        
        return "Text inserted successfully in \(url.path) at line \(lineNumber)\n\nResult:\n\(context)"
    }
    
    // MARK: - Helper Methods
    
    private func parseViewRange(_ viewRange: [Int]?, totalLines: Int) -> (start: Int, end: Int) {
        guard let range = viewRange, range.count >= 2 else {
            return (1, min(totalLines, maxFileLines))
        }
        
        let startLine = max(1, range[0])
        let endLine = range[1] == -1 ? totalLines : min(totalLines, range[1])
        
        return (startLine, max(startLine, endLine))
    }
    
    private func formatContentWithLineNumbers(_ content: String) -> String {
        let lines = content.components(separatedBy: .newlines)
        var result = ""
        
        for (index, line) in lines.enumerated() {
            result += "\(index + 1)→\(line)\n"
        }
        
        return result
    }
    
    private func getContentPreview(_ content: String, maxLines: Int = 10) -> String {
        let lines = content.components(separatedBy: .newlines)
        let previewLines = Array(lines.prefix(maxLines))
        
        var result = ""
        for (index, line) in previewLines.enumerated() {
            result += "\(index + 1)→\(line)\n"
        }
        
        if lines.count > maxLines {
            result += "... (\(lines.count - maxLines) more lines)"
        }
        
        return result
    }
    
    private func findAllOccurrences(of searchText: String, in content: String) -> [String] {
        let lines = content.components(separatedBy: .newlines)
        var contexts: [String] = []
        
        for (lineIndex, line) in lines.enumerated() {
            if line.contains(searchText) {
                let context = getLineContext(lineIndex: lineIndex, lines: lines, searchText: searchText)
                contexts.append(context)
            }
        }
        
        return contexts
    }
    
    private func getLineContext(lineIndex: Int, lines: [String], searchText: String) -> String {
        let startLine = max(0, lineIndex - contextLines)
        let endLine = min(lines.count - 1, lineIndex + contextLines)
        
        var context = ""
        for i in startLine...endLine {
            let lineNumber = i + 1
            let prefix = i == lineIndex ? "→ " : "  "
            context += "\(prefix)\(lineNumber)→\(lines[i])\n"
        }
        
        return context
    }
    
    private func getReplacementContext(oldStr: String, newStr: String, in content: String) -> String {
        let lines = content.components(separatedBy: .newlines)
        
        for (lineIndex, line) in lines.enumerated() {
            if line.contains(oldStr) {
                let beforeContext = getLineContext(lineIndex: lineIndex, lines: lines, searchText: oldStr)
                
                // Generate after context
                let newContent = content.replacingOccurrences(of: oldStr, with: newStr)
                let newLines = newContent.components(separatedBy: .newlines)
                let afterContext = getLineContext(lineIndex: lineIndex, lines: newLines, searchText: newStr)
                
                return "Before:\n\(beforeContext)\nAfter:\n\(afterContext)"
            }
        }
        
        return "Replacement completed"
    }
    
    private func getInsertionContext(lineNumber: Int, newText: String, lines: [String]) -> String {
        let contextStart = max(0, lineNumber - contextLines - 1)
        let contextEnd = min(lines.count - 1, lineNumber + contextLines - 1)
        
        var context = ""
        for i in contextStart...contextEnd {
            let actualLineNumber = i + 1
            let prefix = actualLineNumber == lineNumber ? "→ " : "  "
            context += "\(prefix)\(actualLineNumber)→\(lines[i])\n"
        }
        
        return context
    }
}