import Foundation

struct ConsoleStep {
    let stepNumber: Int
    let state: AgentState
    let llmResponse: String?
    let toolCalls: [ToolCall]?
    let toolResults: [ToolExecutionResult]?
    let reflection: String?
    let error: String?
    let timestamp: Date
    
    init(stepNumber: Int, state: AgentState, llmResponse: String? = nil, toolCalls: [ToolCall]? = nil, toolResults: [ToolExecutionResult]? = nil, reflection: String? = nil, error: String? = nil) {
        self.stepNumber = stepNumber
        self.state = state
        self.llmResponse = llmResponse
        self.toolCalls = toolCalls
        self.toolResults = toolResults
        self.reflection = reflection
        self.error = error
        self.timestamp = Date()
    }
}

struct ToolExecutionResult {
    let toolName: String
    let success: Bool
    let result: String
    let error: String?
    
    init(toolName: String, success: Bool, result: String, error: String? = nil) {
        self.toolName = toolName
        self.success = success
        self.result = result
        self.error = error
    }
}

actor CLIConsole {
    private let config: FullConfig?
    private var consoleSteps: [Int: ConsoleStep] = [:]
    private var agentExecution: AgentExecution?
    private var isDisplayActive = false
    private var displayTask: Task<Void, Never>?
    private var lakeView: LakeView?
    private var lakeViewTasks: [Int: Task<LakeViewStep?, Never>] = [:]
    
    init(config: FullConfig?) {
        self.config = config
        
        // Initialize LakeView if enabled
        if let config = config, config.enableLakeview {
            do {
                self.lakeView = try LakeView(config: config)
            } catch {
                Swift.print("Warning: Failed to initialize LakeView: \(error)")
                self.lakeView = nil
            }
        }
    }
    
    func start() async {
        isDisplayActive = true
        displayTask = Task { [weak self] in
            await self?.startDisplayLoop()
        }
    }
    
    func stop() {
        isDisplayActive = false
        displayTask?.cancel()
        displayTask = nil
    }
    
    func updateStatus(agentStep: AgentStep, agentExecution: AgentExecution) {
        self.agentExecution = agentExecution
        
        let consoleStep = ConsoleStep(
            stepNumber: agentStep.stepNumber,
            state: agentStep.state,
            llmResponse: agentStep.llmResponse?.content,
            toolCalls: agentStep.toolCalls,
            toolResults: convertToolResults(agentStep.toolResults),
            reflection: agentStep.reflection,
            error: agentStep.error
        )
        
        consoleSteps[agentStep.stepNumber] = consoleStep
        
        // TODO: Re-enable LakeView async tasks after fixing concurrency issues
        // For now, LakeView is disabled to avoid data races
        /*
        if let lakeView = lakeView {
            let stepNumber = agentStep.stepNumber
            lakeViewTasks[stepNumber] = Task {
                do {
                    return try await lakeView.createLakeviewStep(agentStep)
                } catch {
                    Swift.print("LakeView error for step \(stepNumber): \(error)")
                    return nil
                }
            }
        }
        */
        
        printTaskProgress()
    }
    
    func print(_ message: String, color: ConsoleColor = .white) {
        let colorCode = color.ansiCode
        let resetCode = ConsoleColor.reset.ansiCode
        Swift.print("\(colorCode)\(message)\(resetCode)")
    }
    
    func printTaskDetails(task: String, workingDirectory: String, provider: String, model: String, maxSteps: Int, configPath: String?, trajectoryPath: String?) {
        print("\n" + "═".repeating(times: 80), color: .blue)
        print("🎯 TASK DETAILS", color: .blue)
        print("═".repeating(times: 80), color: .blue)
        
        print("Task: \(task)", color: .white)
        print("Working Directory: \(workingDirectory)", color: .cyan)
        print("Provider: \(provider)", color: .green)
        print("Model: \(model)", color: .green)
        print("Max Steps: \(maxSteps)", color: .yellow)
        
        if let configPath = configPath {
            print("Config: \(configPath)", color: .magenta)
        }
        
        if let trajectoryPath = trajectoryPath {
            print("Trajectory: \(trajectoryPath)", color: .magenta)
        }
        
        print("═".repeating(times: 80), color: .blue)
        print("")
    }
    
    private func startDisplayLoop() async {
        // Clear screen and hide cursor for better TUI experience
        Swift.print("\u{1B}[2J\u{1B}[H", terminator: "")
        Swift.print("\u{1B}[?25l", terminator: "") // Hide cursor
        fflush(stdout)
        
        while await getDisplayActive() {
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second for more responsive updates
            if await getDisplayActive() {
                await refreshDisplay()
            }
        }
        
        // Show cursor again when done
        Swift.print("\u{1B}[?25h", terminator: "")
        fflush(stdout)
    }
    
    private func getDisplayActive() async -> Bool {
        return isDisplayActive
    }
    
    private func refreshDisplay() async {
        // Move cursor to top-left and clear entire screen
        Swift.print("\u{1B}[H", terminator: "")
        
        // Get terminal dimensions (default to 80x24 if not available)
        let terminalWidth = getTerminalWidth()
        
        // Display current execution state
        await displayFullInterface(terminalWidth: terminalWidth)
        
        fflush(stdout)
    }
    
    private func displayFullInterface(terminalWidth: Int) async {
        guard let execution = agentExecution else { 
            print("Initializing agent...", color: .cyan)
            return 
        }
        
        // Header section
        displayHeader(execution: execution, width: terminalWidth)
        
        // Progress section
        displayProgressSection(execution: execution, width: terminalWidth)
        
        // Recent steps section (auto-scrolling, showing latest)
        displayRecentSteps(width: terminalWidth)
        
        // Footer with status
        displayFooter(execution: execution, width: terminalWidth)
    }
    
    private func displayHeader(execution: AgentExecution, width: Int) {
        let border = "═".repeating(times: min(width, 80))
        print(border, color: .blue)
        let title = "🤖 TRAE AGENT - TASK EXECUTION"
        let padding = max(0, (width - title.count) / 2)
        print(" ".repeating(times: padding) + title, color: .blue)
        print(border, color: .blue)
    }
    
    private func displayProgressSection(execution: AgentExecution, width: Int) {
        let progress = Double(execution.currentStep) / Double(execution.maxSteps)
        let barWidth = min(50, width - 20)
        let filledWidth = Int(progress * Double(barWidth))
        let progressBar = "█".repeating(times: filledWidth) + "░".repeating(times: barWidth - filledWidth)
        
        print("Progress: [\(progressBar)] \(execution.currentStep)/\(execution.maxSteps) (\(Int(progress * 100))%)", color: .yellow)
        print("Status: \(execution.status.uppercased())", color: getStatusColor(execution.status))
        
        if let startTime = execution.startTime {
            let duration = Date().timeIntervalSince(startTime)
            print("Runtime: \(formatDuration(duration))", color: .cyan)
        }
        
        print("─".repeating(times: min(width, 80)), color: .gray)
    }
    
    private func displayRecentSteps(width: Int) {
        let availableLines = getTerminalHeight() - 15 // Reserve space for header/footer
        let recentSteps = consoleSteps.values.sorted { $0.stepNumber > $1.stepNumber }.prefix(min(3, availableLines / 5))
        
        if !recentSteps.isEmpty {
            print("Recent Steps:", color: .white)
            for step in recentSteps {
                displayCompactStep(step, width: width)
            }
        }
    }
    
    private func displayCompactStep(_ step: ConsoleStep, width: Int) {
        let stateEmoji = getStateEmoji(step.state)
        let timestamp = formatTimestamp(step.timestamp)
        
        print("  \(stateEmoji) Step \(step.stepNumber) [\(timestamp)] - \(step.state.rawValue)", color: getStateColor(step.state))
        
        if let llmResponse = step.llmResponse, !llmResponse.isEmpty {
            let truncated = String(llmResponse.prefix(width - 8))
            print("    💭 \(truncated)\(llmResponse.count > width - 8 ? "..." : "")", color: .white)
        }
        
        if let toolCalls = step.toolCalls, !toolCalls.isEmpty {
            let toolNames = toolCalls.map { $0.function.name }.joined(separator: ", ")
            print("    🔧 Tools: \(toolNames)", color: .yellow)
        }
        
        if let error = step.error {
            let truncated = String(error.prefix(width - 8))
            print("    ❌ \(truncated)\(error.count > width - 8 ? "..." : "")", color: .red)
        }
    }
    
    private func displayFooter(execution: AgentExecution, width: Int) {
        print("─".repeating(times: min(width, 80)), color: .gray)
        let footer = "🚀 TraeSwift v0.1 | Press Ctrl+C to stop"
        print(footer, color: .gray)
    }
    
    private func getTerminalWidth() -> Int {
        // Try to get actual terminal width, fallback to 80
        if let columns = ProcessInfo.processInfo.environment["COLUMNS"],
           let width = Int(columns) {
            return width
        }
        return 80
    }
    
    private func getTerminalHeight() -> Int {
        // Try to get actual terminal height, fallback to 24
        if let lines = ProcessInfo.processInfo.environment["LINES"],
           let height = Int(lines) {
            return height
        }
        return 24
    }
    
    private func printTaskProgress() {
        guard let execution = agentExecution else { return }
        
        print("\n" + "─".repeating(times: 80), color: .cyan)
        print("📊 EXECUTION PROGRESS", color: .cyan)
        print("─".repeating(times: 80), color: .cyan)
        
        // Show execution summary
        print("Status: \(execution.status)", color: getStatusColor(execution.status))
        print("Steps: \(execution.currentStep)/\(execution.maxSteps)", color: .yellow)
        
        if let startTime = execution.startTime {
            let duration = Date().timeIntervalSince(startTime)
            print("Duration: \(formatDuration(duration))", color: .cyan)
        }
        
        // Show recent steps
        let recentSteps = consoleSteps.values.sorted { $0.stepNumber > $1.stepNumber }.prefix(3)
        
        for step in recentSteps {
            printStepSummary(step)
        }
        
        print("─".repeating(times: 80), color: .cyan)
    }
    
    private func printStepSummary(_ step: ConsoleStep) {
        // Check if LakeView task is completed for enhanced display
        if let lakeViewTask = lakeViewTasks[step.stepNumber], lakeViewTask.isCancelled == false {
            printLakeViewStepSummary(step, lakeViewTask: lakeViewTask)
        } else {
            printStandardStepSummary(step)
        }
    }
    
    private func printStandardStepSummary(_ step: ConsoleStep) {
        let stateEmoji = getStateEmoji(step.state)
        let stateColor = getStateColor(step.state)
        
        print("\n\(stateEmoji) Step \(step.stepNumber): \(step.state)", color: stateColor)
        
        if let llmResponse = step.llmResponse {
            let truncated = String(llmResponse.prefix(100))
            print("  💬 LLM: \(truncated)\(llmResponse.count > 100 ? "..." : "")", color: .white)
        }
        
        if let toolCalls = step.toolCalls, !toolCalls.isEmpty {
            for toolCall in toolCalls {
                print("  🔧 Tool: \(toolCall.function.name)", color: .yellow)
            }
        }
        
        if let toolResults = step.toolResults {
            for result in toolResults {
                let resultEmoji = result.success ? "✅" : "❌"
                let resultColor: ConsoleColor = result.success ? .green : .red
                print("  \(resultEmoji) \(result.toolName): \(result.success ? "Success" : "Failed")", color: resultColor)
            }
        }
        
        if let error = step.error {
            print("  ❌ Error: \(error)", color: .red)
        }
    }
    
    private func printLakeViewStepSummary(_ step: ConsoleStep, lakeViewTask: Task<LakeViewStep?, Never>) {
        let stateColor = getStateColor(step.state)
        
        // For now, show standard display and mention LakeView is processing
        // In a real implementation, this would check if the task is actually completed
        print("\n🔄 Step \(step.stepNumber): Processing with LakeView...", color: stateColor)
        
        // Fallback to standard display for now
        printStandardStepSummary(step)
    }
    
    func printExecutionSummary(_ execution: AgentExecution) {
        print("\n" + "═".repeating(times: 80), color: .green)
        print("🏁 EXECUTION SUMMARY", color: .green)
        print("═".repeating(times: 80), color: .green)
        
        print("Final Status: \(execution.status)", color: getStatusColor(execution.status))
        print("Total Steps: \(execution.currentStep)", color: .yellow)
        
        if let startTime = execution.startTime {
            let duration = Date().timeIntervalSince(startTime)
            print("Total Duration: \(formatDuration(duration))", color: .cyan)
        }
        
        if let usage = execution.tokenUsage {
            print("Token Usage:", color: .magenta)
            print("  Input: \(usage.promptTokens)", color: .white)
            print("  Output: \(usage.completionTokens)", color: .white)
            print("  Total: \(usage.totalTokens)", color: .white)
        }
        
        if let result = execution.result {
            print("Result: \(result)", color: .white)
        }
        
        print("═".repeating(times: 80), color: .green)
    }
    
    private func convertToolResults(_ results: [ToolResult]?) -> [ToolExecutionResult]? {
        guard let results = results else { return nil }
        
        return results.map { toolResult in
            ToolExecutionResult(
                toolName: "tool_\(toolResult.toolCallId)",
                success: toolResult.error == nil,
                result: toolResult.content,
                error: toolResult.error
            )
        }
    }
    
    private func getStateEmoji(_ state: AgentState) -> String {
        switch state {
        case .thinking: return "🤔"
        case .callingTool: return "🔧"
        case .reflecting: return "💭"
        case .completed: return "✅"
        case .error: return "❌"
        case .idle: return "⏸️"
        }
    }
    
    private func getStateColor(_ state: AgentState) -> ConsoleColor {
        switch state {
        case .thinking: return .blue
        case .callingTool: return .yellow
        case .reflecting: return .magenta
        case .completed: return .green
        case .error: return .red
        case .idle: return .white
        }
    }
    
    private func getStatusColor(_ status: String) -> ConsoleColor {
        switch status.lowercased() {
        case "completed", "success": return .green
        case "error", "failed": return .red
        case "running", "in_progress": return .yellow
        default: return .white
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    private func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }
}

enum ConsoleColor {
    case black, red, green, yellow, blue, magenta, cyan, white, gray, reset
    
    var ansiCode: String {
        switch self {
        case .black: return "\u{001B}[30m"
        case .red: return "\u{001B}[31m"
        case .green: return "\u{001B}[32m"
        case .yellow: return "\u{001B}[33m"
        case .blue: return "\u{001B}[34m"
        case .magenta: return "\u{001B}[35m"
        case .cyan: return "\u{001B}[36m"
        case .white: return "\u{001B}[37m"
        case .gray: return "\u{001B}[90m"
        case .reset: return "\u{001B}[0m"
        }
    }
}

extension String {
    func repeating(times: Int) -> String {
        return String(repeating: self, count: times)
    }
}