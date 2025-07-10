import ArgumentParser
import Foundation

@main
struct TraeSwift: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "trae-swift",
        abstract: "A Swift implementation of Trae Agent for AI-assisted software engineering.",
        version: "0.1",
        subcommands: [Run.self, Interactive.self, ShowConfig.self, Tools.self]
    )
}

struct Run: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Execute a single task"
    )
    
    @Argument(help: "The task to execute")
    var task: String
    
    @Option(name: .shortAndLong, help: "Path to configuration file")
    var config: String = "trae_config.json"
    
    @Flag(name: .long, help: "Enable verbose console output")
    var verbose: Bool = false
    
    @Option(name: .long, help: "Path to save trajectory recording")
    var trajectory: String?
    
    @Option(name: .long, help: "LLM provider to use (overrides config)")
    var provider: String?
    
    @Option(name: .long, help: "Model name to use (overrides config)")
    var model: String?
    
    func run() async throws {
        print("🔧 Loading configuration from \(config)...")
        let configuration = try ConfigManager.loadConfig(from: config, cliProvider: provider, cliModel: model)
        
        print("🤖 Initializing Trae Agent...")
        let agent = try TraeAgent.create(from: configuration)
        
        // Setup console and trajectory recording if verbose mode is enabled
        let console: CLIConsole? = verbose ? CLIConsole(config: configuration) : nil
        let trajectoryRecorder: TrajectoryRecorder? = trajectory != nil ? TrajectoryRecorder(trajectoryPath: trajectory) : nil
        
        print("🚀 Executing task: \(task)\n")
        do {
            let result: String
            if verbose, let console = console {
                result = try await agent.runWithConsole(task: task, console: console, trajectoryRecorder: trajectoryRecorder)
            } else {
                result = try await agent.run(task: task)
            }
            
            print("\n✅ Task completed successfully!")
            print("📄 Result: \(result)")
            
            if let trajectoryPath = trajectoryRecorder?.getTrajectoryPath() {
                print("📊 Trajectory saved to: \(trajectoryPath)")
            }
        } catch {
            print("\n❌ Task failed: \(error)")
            throw error
        }
    }
}

struct Interactive: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Start interactive mode for conversational task execution"
    )
    
    @Option(name: .shortAndLong, help: "Path to configuration file")
    var config: String = "trae_config.json"
    
    @Flag(name: .long, help: "Enable verbose console output")
    var verbose: Bool = false
    
    @Option(name: .long, help: "Directory to save session trajectories")
    var trajectoryDir: String?
    
    @Option(name: .long, help: "LLM provider to use (overrides config)")
    var provider: String?
    
    @Option(name: .long, help: "Model name to use (overrides config)")
    var model: String?
    
    func run() async throws {
        print("🔧 Loading configuration from \(config)...")
        let configuration = try ConfigManager.loadConfig(from: config, cliProvider: provider, cliModel: model)
        
        print("🤖 Initializing Trae Agent...")
        let agent = try TraeAgent.create(from: configuration)
        
        print("🌟 Welcome to Trae Agent Interactive Mode!")
        print("💡 Type your tasks below. Use 'exit', 'quit', or Ctrl+C to end the session.")
        print("📝 Available commands:")
        print("   - help: Show this help message")
        print("   - config: Show current configuration")
        print("   - tools: List available tools")
        print("   - clear: Clear the screen")
        print("─".repeating(times: 60))
        
        var sessionNumber = 0
        
        while true {
            // Prompt for input
            print("\n🚀 Enter your task (or 'help' for commands):")
            print("> ", terminator: "")
            
            guard let input = readLine()?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !input.isEmpty else {
                continue
            }
            
            // Handle special commands
            switch input.lowercased() {
            case "exit", "quit":
                print("👋 Goodbye! Thanks for using Trae Agent.")
                return
                
            case "help":
                showHelp()
                continue
                
            case "config":
                print("\n📊 Current Configuration:")
                ConfigManager.printConfig(configuration)
                continue
                
            case "tools":
                showTools()
                continue
                
            case "clear":
                clearScreen()
                continue
                
            default:
                break
            }
            
            // Execute the task
            sessionNumber += 1
            
            // Setup trajectory recording for this session
            let trajectoryRecorder: TrajectoryRecorder?
            if let trajectoryDir = trajectoryDir {
                let sessionPath = "\(trajectoryDir)/session_\(sessionNumber)_\(dateTimestamp()).json"
                trajectoryRecorder = TrajectoryRecorder(trajectoryPath: sessionPath)
            } else {
                trajectoryRecorder = nil
            }
            
            // Setup console
            let console: CLIConsole? = verbose ? CLIConsole(config: configuration) : nil
            
            print("\n" + "─".repeating(times: 60))
            print("🎯 Executing Task #\(sessionNumber): \(input)")
            print("─".repeating(times: 60))
            
            do {
                let result: String
                if verbose, let console = console {
                    result = try await agent.runWithConsole(task: input, console: console, trajectoryRecorder: trajectoryRecorder)
                } else {
                    result = try await agent.run(task: input)
                }
                
                print("\n✅ Task #\(sessionNumber) completed successfully!")
                print("📄 Result: \(result)")
                
                if let trajectoryPath = trajectoryRecorder?.getTrajectoryPath() {
                    print("📊 Session trajectory saved to: \(trajectoryPath)")
                }
                
            } catch {
                print("\n❌ Task #\(sessionNumber) failed: \(error)")
                print("💡 Try rephrasing your task or check the configuration.")
            }
            
            print("\n" + "─".repeating(times: 60))
        }
    }
    
    private func showHelp() {
        print("\n📖 Trae Agent Interactive Mode Help")
        print("─".repeating(times: 40))
        print("Commands:")
        print("  help     - Show this help message")
        print("  config   - Display current configuration")
        print("  tools    - List available tools")
        print("  clear    - Clear the screen")
        print("  exit     - Exit interactive mode")
        print("  quit     - Exit interactive mode")
        print("")
        print("Usage:")
        print("  Just type your task and press Enter!")
        print("  Examples:")
        print("    - List files in current directory")
        print("    - Create a Python script that prints hello world")
        print("    - Fix the bug in main.py")
        print("    - Run the tests and show me the results")
    }
    
    private func showTools() {
        print("\n🔧 Available Tools:")
        print("─".repeating(times: 30))
        print("  • BashTool - Execute simple shell commands")
        print("  • RunTool - Execute complex shell commands with enhanced output")
        print("  • TextEditorTool - Edit text files")
        print("  • JSONEditTool - Edit JSON files with JSONPath support")
        print("  • SequentialThinkingTool - Multi-step reasoning and problem solving")
        print("  • TaskDoneTool - Mark task as complete")
    }
    
    private func clearScreen() {
        print("\u{001B}[2J\u{001B}[H", terminator: "")
    }
    
    private func dateTimestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        return formatter.string(from: Date())
    }
}

struct ShowConfig: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Display current configuration settings"
    )
    
    @Option(name: .shortAndLong, help: "Path to configuration file")
    var config: String = "trae_config.json"
    
    @Option(name: .long, help: "LLM provider to use (overrides config)")
    var provider: String?
    
    @Option(name: .long, help: "Model name to use (overrides config)")
    var model: String?
    
    func run() async throws {
        do {
            let configuration = try ConfigManager.loadConfig(from: config, cliProvider: provider, cliModel: model)
            ConfigManager.printConfig(configuration)
        } catch {
            print("Error loading configuration: \(error)")
        }
    }
}

struct Tools: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "List available tools"
    )
    
    func run() async throws {
        print("🔧 Available Tools:")
        print("─".repeating(times: 30))
        print("• BashTool - Execute simple shell commands")
        print("• RunTool - Execute complex shell commands with enhanced output handling")
        print("• TextEditorTool - Edit text files")
        print("• JSONEditTool - Edit JSON files with JSONPath support")
        print("• SequentialThinkingTool - Multi-step reasoning and problem solving")
        print("• TaskDoneTool - Mark task as complete")
        print("\n💡 Use the interactive mode to see these tools in action!")
    }
}
