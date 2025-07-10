import Foundation

/// Advanced error reflection and retry system to handle failures intelligently
class ErrorReflectionSystem {
    
    private let llmClient: LLMClient
    private let maxReflectionDepth: Int
    private let retryStrategies: [RetryStrategy]
    
    init(llmClient: LLMClient, maxReflectionDepth: Int = 3) {
        self.llmClient = llmClient
        self.maxReflectionDepth = maxReflectionDepth
        self.retryStrategies = [
            NetworkRetryStrategy(),
            ToolExecutionRetryStrategy(),
            LLMParsingRetryStrategy(),
            RateLimitRetryStrategy()
        ]
    }
    
    /// Reflect on an error and suggest recovery actions
    func reflectOnError(
        error: Error,
        context: ErrorContext,
        attempt: Int = 1
    ) async throws -> ErrorReflection {
        
        // Check if we've exceeded reflection depth
        guard attempt <= maxReflectionDepth else {
            return ErrorReflection(
                errorType: .criticalFailure,
                suggestion: "Maximum reflection depth reached. Manual intervention required.",
                shouldRetry: false,
                retryDelay: nil,
                recoveryActions: []
            )
        }
        
        // Analyze error type and context
        let errorAnalysis = analyzeError(error: error, context: context)
        
        // Get automated recovery if possible
        if let quickRecovery = attemptQuickRecovery(analysis: errorAnalysis) {
            return quickRecovery
        }
        
        // Use LLM for deeper reflection
        return try await performLLMReflection(
            analysis: errorAnalysis,
            context: context,
            attempt: attempt
        )
    }
    
    /// Execute a retry with the suggested strategy
    func executeRetry(
        reflection: ErrorReflection,
        originalAction: () async throws -> String
    ) async throws -> String {
        
        // Apply recovery actions first
        for action in reflection.recoveryActions {
            try await executeRecoveryAction(action)
        }
        
        // Wait for retry delay if specified
        if let delay = reflection.retryDelay {
            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }
        
        // Execute the retry
        return try await originalAction()
    }
    
    // MARK: - Private Methods
    
    private func analyzeError(error: Error, context: ErrorContext) -> ErrorAnalysis {
        var analysis = ErrorAnalysis()
        
        // Categorize error type
        if let toolError = error as? ToolError {
            analysis.category = .toolExecution
            analysis.specificError = toolError
            analysis.isRetryable = true
        } else if let llmError = error as? LLMError {
            analysis.category = .llmCommunication
            analysis.specificError = llmError
            analysis.isRetryable = shouldRetryLLMError(llmError)
        } else if error is DecodingError {
            analysis.category = .parsing
            analysis.specificError = error
            analysis.isRetryable = true
        } else {
            analysis.category = .unknown
            analysis.specificError = error
            analysis.isRetryable = false
        }
        
        // Analyze context patterns
        analysis.contextPatterns = extractContextPatterns(context: context)
        analysis.previousFailures = context.previousErrors.count
        analysis.hasRepeatedFailures = hasRepeatedFailurePattern(context: context)
        
        return analysis
    }
    
    private func attemptQuickRecovery(analysis: ErrorAnalysis) -> ErrorReflection? {
        // Check each retry strategy
        for strategy in retryStrategies {
            if strategy.canHandle(analysis: analysis) {
                return strategy.createReflection(analysis: analysis)
            }
        }
        
        return nil
    }
    
    private func performLLMReflection(
        analysis: ErrorAnalysis,
        context: ErrorContext,
        attempt: Int
    ) async throws -> ErrorReflection {
        
        let reflectionPrompt = buildReflectionPrompt(analysis: analysis, context: context, attempt: attempt)
        
        let messages = [
            Message(role: .system, content: getReflectionSystemPrompt()),
            Message(role: .user, content: reflectionPrompt)
        ]
        
        let response = try await llmClient.chat(
            messages: messages,
            tools: nil,
            temperature: 0.1, // Low temperature for analytical tasks
            maxTokens: 1000
        )
        
        guard let content = response.choices.first?.message.content else {
            throw LLMError.invalidResponse
        }
        
        return parseReflectionResponse(content: content, analysis: analysis)
    }
    
    private func shouldRetryLLMError(_ error: LLMError) -> Bool {
        switch error {
        case .networkError(_), .apiError(_):
            return true
        case .invalidResponse, .missingAPIKey, .unsupportedModel:
            return false
        }
    }
    
    private func extractContextPatterns(context: ErrorContext) -> [String] {
        var patterns: [String] = []
        
        // Look for repeated error messages
        let errorMessages = context.previousErrors.map { $0.localizedDescription }
        let uniqueMessages = Set(errorMessages)
        if uniqueMessages.count < errorMessages.count {
            patterns.append("repeated_error_messages")
        }
        
        // Look for tool-specific patterns
        if context.lastToolUsed != nil {
            patterns.append("tool_execution_context")
        }
        
        // Look for time-based patterns
        if context.executionTime > 60 {
            patterns.append("long_execution_time")
        }
        
        return patterns
    }
    
    private func hasRepeatedFailurePattern(context: ErrorContext) -> Bool {
        guard context.previousErrors.count >= 2 else { return false }
        
        let recentErrors = Array(context.previousErrors.suffix(2))
        return type(of: recentErrors[0]) == type(of: recentErrors[1])
    }
    
    private func buildReflectionPrompt(analysis: ErrorAnalysis, context: ErrorContext, attempt: Int) -> String {
        return """
        I need help analyzing and recovering from an error that occurred during task execution.
        
        Error Details:
        - Type: \(analysis.category)
        - Error: \(analysis.specificError?.localizedDescription ?? "Unknown error")
        - Attempt: \(attempt)/\(maxReflectionDepth)
        - Previous failures: \(analysis.previousFailures)
        
        Context:
        - Task: \(context.currentTask)
        - Step: \(context.currentStep)
        - Last tool used: \(context.lastToolUsed ?? "None")
        - Execution time: \(context.executionTime)s
        - Context patterns: \(analysis.contextPatterns.joined(separator: ", "))
        
        Recent errors: \(context.previousErrors.map { $0.localizedDescription }.joined(separator: "; "))
        
        Please provide:
        1. Root cause analysis
        2. Recommended recovery actions
        3. Whether to retry and after what delay
        4. Alternative approaches if retry fails
        
        Respond in JSON format with the structure:
        {
          "rootCause": "string",
          "shouldRetry": boolean,
          "retryDelay": number_or_null,
          "recoveryActions": ["action1", "action2"],
          "alternatives": ["alt1", "alt2"],
          "confidence": number_0_to_1
        }
        """
    }
    
    private func getReflectionSystemPrompt() -> String {
        return """
        You are an expert error analysis system for AI agents. Your job is to analyze failures and suggest intelligent recovery strategies.
        
        Focus on:
        - Identifying patterns in failures
        - Suggesting specific, actionable recovery steps
        - Determining optimal retry timing
        - Providing alternative approaches when retries are unlikely to succeed
        
        Be precise and practical in your recommendations.
        """
    }
    
    private func parseReflectionResponse(content: String, analysis: ErrorAnalysis) -> ErrorReflection {
        do {
            guard let data = content.data(using: .utf8),
                  let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                throw NSError(domain: "ParsingError", code: 1)
            }
            
            let shouldRetry = json["shouldRetry"] as? Bool ?? analysis.isRetryable
            let retryDelay = json["retryDelay"] as? Double
            let recoveryActions = (json["recoveryActions"] as? [String] ?? []).map(RecoveryAction.init)
            
            let errorType: ErrorReflection.ErrorType
            if analysis.hasRepeatedFailures {
                errorType = .recurringFailure
            } else if analysis.isRetryable {
                errorType = .transientFailure
            } else {
                errorType = .permanentFailure
            }
            
            return ErrorReflection(
                errorType: errorType,
                suggestion: json["rootCause"] as? String ?? "Unknown error occurred",
                shouldRetry: shouldRetry,
                retryDelay: retryDelay,
                recoveryActions: recoveryActions
            )
            
        } catch {
            // Fallback to basic reflection
            return ErrorReflection(
                errorType: analysis.isRetryable ? .transientFailure : .permanentFailure,
                suggestion: "Failed to parse detailed reflection. Basic recovery attempted.",
                shouldRetry: analysis.isRetryable,
                retryDelay: 1.0,
                recoveryActions: []
            )
        }
    }
    
    private func executeRecoveryAction(_ action: RecoveryAction) async throws {
        switch action.type {
        case .resetState:
            // Reset any stateful components if needed
            break
        case .clearCache:
            // Clear any caches if applicable
            break
        case .changeApproach:
            // This would need to be handled at a higher level
            break
        case .validateInput:
            // Perform input validation
            break
        case .custom(let command):
            // Execute custom recovery command
            print("Executing recovery action: \(command)")
        }
    }
}

// MARK: - Supporting Types

struct ErrorContext {
    let currentTask: String
    let currentStep: Int
    let lastToolUsed: String?
    let executionTime: TimeInterval
    let previousErrors: [Error]
}

struct ErrorAnalysis {
    var category: ErrorCategory = .unknown
    var specificError: Error?
    var isRetryable: Bool = false
    var contextPatterns: [String] = []
    var previousFailures: Int = 0
    var hasRepeatedFailures: Bool = false
}

enum ErrorCategory {
    case toolExecution
    case llmCommunication
    case parsing
    case network
    case unknown
}

struct ErrorReflection {
    enum ErrorType {
        case transientFailure
        case permanentFailure
        case recurringFailure
        case criticalFailure
    }
    
    let errorType: ErrorType
    let suggestion: String
    let shouldRetry: Bool
    let retryDelay: Double?
    let recoveryActions: [RecoveryAction]
}

struct RecoveryAction {
    enum ActionType {
        case resetState
        case clearCache
        case changeApproach
        case validateInput
        case custom(String)
    }
    
    let type: ActionType
    
    init(_ description: String) {
        switch description.lowercased() {
        case "reset state", "reset_state":
            self.type = .resetState
        case "clear cache", "clear_cache":
            self.type = .clearCache
        case "change approach", "change_approach":
            self.type = .changeApproach
        case "validate input", "validate_input":
            self.type = .validateInput
        default:
            self.type = .custom(description)
        }
    }
}

// MARK: - Retry Strategies

protocol RetryStrategy {
    func canHandle(analysis: ErrorAnalysis) -> Bool
    func createReflection(analysis: ErrorAnalysis) -> ErrorReflection
}

struct NetworkRetryStrategy: RetryStrategy {
    func canHandle(analysis: ErrorAnalysis) -> Bool {
        return analysis.category == .network || 
               (analysis.category == .llmCommunication && 
                analysis.specificError is LLMError)
    }
    
    func createReflection(analysis: ErrorAnalysis) -> ErrorReflection {
        let delay = min(pow(2.0, Double(analysis.previousFailures)), 30.0) // Exponential backoff, max 30s
        
        return ErrorReflection(
            errorType: .transientFailure,
            suggestion: "Network connectivity issue detected. Retrying with exponential backoff.",
            shouldRetry: analysis.previousFailures < 5,
            retryDelay: delay,
            recoveryActions: []
        )
    }
}

struct ToolExecutionRetryStrategy: RetryStrategy {
    func canHandle(analysis: ErrorAnalysis) -> Bool {
        return analysis.category == .toolExecution
    }
    
    func createReflection(analysis: ErrorAnalysis) -> ErrorReflection {
        return ErrorReflection(
            errorType: .transientFailure,
            suggestion: "Tool execution failed. Retrying with cleaned inputs.",
            shouldRetry: analysis.previousFailures < 3,
            retryDelay: 0.5,
            recoveryActions: [RecoveryAction("validate_input")]
        )
    }
}

struct LLMParsingRetryStrategy: RetryStrategy {
    func canHandle(analysis: ErrorAnalysis) -> Bool {
        return analysis.category == .parsing
    }
    
    func createReflection(analysis: ErrorAnalysis) -> ErrorReflection {
        return ErrorReflection(
            errorType: .transientFailure,
            suggestion: "Response parsing failed. Retrying with structured output request.",
            shouldRetry: analysis.previousFailures < 2,
            retryDelay: 0.1,
            recoveryActions: []
        )
    }
}

struct RateLimitRetryStrategy: RetryStrategy {
    func canHandle(analysis: ErrorAnalysis) -> Bool {
        if let llmError = analysis.specificError as? LLMError,
           case .apiError(let message) = llmError {
            return message.contains("rate_limit") || message.contains("429")
        }
        return false
    }
    
    func createReflection(analysis: ErrorAnalysis) -> ErrorReflection {
        return ErrorReflection(
            errorType: .transientFailure,
            suggestion: "Rate limit exceeded. Waiting before retry.",
            shouldRetry: true,
            retryDelay: 60.0, // Wait 1 minute for rate limits
            recoveryActions: []
        )
    }
}