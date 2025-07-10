import Foundation

/// Simple .env file loader to match Python's dotenv behavior
class DotEnvLoader {
    
    /// Load environment variables from a .env file
    /// Does not override existing environment variables
    static func loadDotEnv(from path: String = ".env") {
        let url = URL(fileURLWithPath: path)
        
        guard FileManager.default.fileExists(atPath: path) else {
            // .env file not found - this is not an error, just continue
            return
        }
        
        do {
            let content = try String(contentsOf: url, encoding: .utf8)
            parseDotEnvContent(content)
        } catch {
            print("Warning: Could not load .env file from \(path): \(error)")
        }
    }
    
    /// Parse .env file content and set environment variables
    private static func parseDotEnvContent(_ content: String) {
        let lines = content.components(separatedBy: .newlines)
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Skip empty lines and comments
            if trimmed.isEmpty || trimmed.hasPrefix("#") {
                continue
            }
            
            // Parse KEY=VALUE format
            if let equalsIndex = trimmed.firstIndex(of: "=") {
                let key = String(trimmed[..<equalsIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
                let value = String(trimmed[trimmed.index(after: equalsIndex)...]).trimmingCharacters(in: .whitespacesAndNewlines)
                
                // Remove quotes if present
                let cleanValue = removeQuotes(from: value)
                
                // Only set if not already in environment (don't override existing vars)
                if ProcessInfo.processInfo.environment[key] == nil {
                    setenv(key, cleanValue, 0)
                }
            }
        }
    }
    
    /// Remove surrounding quotes from a string
    private static func removeQuotes(from value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if (trimmed.hasPrefix("\"") && trimmed.hasSuffix("\"")) ||
           (trimmed.hasPrefix("'") && trimmed.hasSuffix("'")) {
            return String(trimmed.dropFirst().dropLast())
        }
        
        return trimmed
    }
}