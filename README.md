# Trae Swift Agent

[![Swift 6.1+](https://img.shields.io/badge/Swift-6.1+-orange.svg)](https://swift.org/download/) [![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT) ![Beta](https://img.shields.io/badge/Status-Beta-blue) [![Built with Swift](https://img.shields.io/badge/Built%20with-Swift-orange.svg)](https://swift.org/)

**Trae Swift Agent** is a high-performance, type-safe Swift implementation of the Trae Agent - an LLM-based agent for general purpose software engineering tasks. It provides a powerful CLI interface that can understand natural language instructions and execute complex software engineering workflows using various tools and LLM providers.

**Project Status:** This Swift implementation has achieved **100% feature parity** with the original Python Trae Agent. All core functionality, LLM providers, tools, and user interfaces have been successfully migrated while leveraging Swift's modern concurrency and type safety features.

**Difference with Other CLI Agents:** Trae Swift Agent offers a transparent, modular architecture that researchers and developers can easily modify, extend, and analyze, making it an ideal platform for **studying AI agent architectures, conducting ablation studies, and developing novel agent capabilities**. This ***research-friendly design*** combined with Swift's performance benefits enables the academic and open-source communities to contribute to and build upon the foundational agent framework, fostering innovation in the rapidly evolving field of AI agents.

## 🎯 Python → Swift: Complete Feature Parity

| Feature | Python | Swift | Status |
|---------|---------|--------|---------|
| CLI Commands | ✅ run, interactive, show-config | ✅ run, interactive, show-config, tools | ✅ 100% |
| LLM Providers | ✅ 7 providers | ✅ 7 providers | ✅ 100% |
| Tools | ✅ 6 tools | ✅ 6 tools + enhancements | ✅ 100%+ |
| JSONPath Support | ✅ Full support | ✅ Full support (Sextant) | ✅ 100% |
| Parallel Execution | ✅ Via asyncio | ✅ Via TaskGroup | ✅ 100% |
| Error Recovery | ✅ Basic retry | ✅ LLM-powered reflection | ✅ 100%+ |
| Environment Config | ✅ .env + variables | ✅ .env + variables | ✅ 100% |
| Trajectory Recording | ✅ JSON format | ✅ Compatible JSON | ✅ 100% |
| Lakeview | ✅ Step summaries | ✅ Step summaries | ✅ 100% |
| Performance | 🐍 Interpreted | ⚡ Compiled binary | 🚀 Enhanced |

## ✨ Features

- 🌊 **Lakeview**: Provides short and concise summarisation for agent steps
- 🤖 **Multi-LLM Support**: Works with OpenAI, Anthropic, Doubao, Azure, OpenRouter, Ollama and Google Gemini APIs
- 🛠️ **Rich Tool Ecosystem**: File editing, bash execution, sequential thinking, JSON manipulation with JSONPath, and more
- 🎯 **Interactive Mode**: Conversational interface for iterative development
- 📊 **Trajectory Recording**: Detailed logging of all agent actions for debugging and analysis
- ⚙️ **Flexible Configuration**: JSON-based configuration with environment variable support
- 🚀 **Easy Installation**: Simple build and run with Swift Package Manager
- ⚡ **Performance Benefits**: Compiled binary with zero runtime overhead and memory safety
- 🔐 **Type Safety**: Compile-time error prevention with Swift's strong type system
- 🧵 **Modern Concurrency**: Thread-safe execution with async/await and actors

## 🚀 Quick Start

### Requirements

- Swift 6.1+ (install from [swift.org](https://swift.org/download/))
- macOS 13+, Ubuntu 20.04+, or Windows 10+ with Swift toolchain

### Installation

```bash
# Clone the repository
git clone https://github.com/yourusername/TraeSwift.git
cd TraeSwift

# Build the project
swift build -c release

# Create an alias for easier usage (optional)
alias trae-swift=".build/release/TraeSwift"

# Run the binary
.build/release/TraeSwift --help
# Or with alias: trae-swift --help
```

### Basic Usage

```bash
# Run a simple task
./trae-swift run "Create a hello world Python script"

# Run with Doubao
./trae-swift run "Create a hello world Python script" --provider doubao --model doubao-pro-4k

# Run with Google Gemini
./trae-swift run "Create a hello world Python script" --provider google --model gemini-2.5-flash

# Alternative: Run directly with Swift
swift run TraeSwift run "Create a hello world Python script"
```

### Setup API Keys

We recommend configuring Trae Swift Agent using the config file (see Configuration section below).

You can also set your API keys as environment variables:

```bash
# For OpenAI
export OPENAI_API_KEY="your-openai-api-key"

# For Anthropic
export ANTHROPIC_API_KEY="your-anthropic-api-key"

# For Doubao (also works with other OpenAI-compatible model providers)
export DOUBAO_API_KEY="your-doubao-api-key"
export DOUBAO_BASE_URL="your-model-provider-base-url"

# For OpenRouter
export OPENROUTER_API_KEY="your-openrouter-api-key"

# For Google Gemini
export GOOGLE_API_KEY="your-google-api-key"

# Optional: For OpenRouter rankings
export OPENROUTER_SITE_URL="https://your-site.com"
export OPENROUTER_SITE_NAME="Your App Name"

# Optional: If you want to use a specific openai compatible api provider
export OPENAI_BASE_URL="your-openai-compatible-api-base-url"
```

The Swift implementation supports `.env` files (similar to python-dotenv) to keep your API keys secure. Simply create a `.env` file in your project root:

```bash
ANTHROPIC_API_KEY="your-api-key"
OPENAI_API_KEY="your-api-key"
```

## 📖 Usage

### Command Line Interface

The main entry point is the `trae-swift` command with several subcommands:

#### `trae-swift run` - Execute a Task

```bash
# Basic task execution
./trae-swift run "Create a Python script that calculates fibonacci numbers"

# With specific provider and model
./trae-swift run "Fix the bug in main.py" --provider anthropic --model claude-sonnet-4-20250514

# Using OpenRouter with any supported model
./trae-swift run "Optimize this code" --provider openrouter --model "openai/gpt-4o"
./trae-swift run "Add documentation" --provider openrouter --model "anthropic/claude-3.5-sonnet"

# Using Google Gemini
./trae-swift run "Implement a data parsing function" --provider google --model gemini-2.5-pro

# With verbose output
./trae-swift run "Refactor the database module" --verbose

# Save trajectory for debugging
./trae-swift run "Update the API endpoints" --trajectory debug_session.json
```

#### `trae-swift interactive` - Interactive Mode

```bash
# Start interactive session
./trae-swift interactive

# With custom configuration
./trae-swift interactive --provider openai --model gpt-4o
```

In interactive mode, you can:
- Type any task description to execute it
- Use `status` to see agent information
- Use `help` for available commands
- Use `clear` to clear the screen
- Use `exit` or `quit` to end the session

#### `trae-swift show-config` - Configuration Status

```bash
./trae-swift show-config

# With custom config file
./trae-swift show-config --config my_config.json
```

### Configuration

Trae Swift Agent uses the same JSON configuration format as the Python version (`trae_config.json`):

```json
{
  "default_provider": "anthropic",
  "max_steps": 20,
  "enable_lakeview": true,
  "model_providers": {
    "openai": {
      "api_key": "your_openai_api_key",
      "model": "gpt-4o",
      "max_tokens": 128000,
      "temperature": 0.5,
      "top_p": 1.0,
      "top_k": 0,
      "parallel_tool_calls": false,
      "max_retries": 10
    },
    "anthropic": {
      "api_key": "your_anthropic_api_key",
      "model": "claude-sonnet-4-20250514",
      "max_tokens": 4096,
      "temperature": 0.5,
      "top_p": 1.0,
      "top_k": 0,
      "parallel_tool_calls": false,
      "max_retries": 10
    },
    "google": {
      "api_key": "your_google_api_key",
      "model": "gemini-1.5-pro-002",
      "max_tokens": 128000,
      "temperature": 0.5,
      "top_p": 1.0,
      "top_k": 0,
      "parallel_tool_calls": false,
      "max_retries": 10
    },
    "azure": {
      "api_key": "your_azure_api_key",
      "base_url": "your_azure_endpoint",
      "api_version": "2024-03-01-preview",
      "model": "gpt-4o",
      "max_tokens": 4096,
      "temperature": 0.5,
      "top_p": 1.0,
      "top_k": 0,
      "parallel_tool_calls": false,
      "max_retries": 10
    },
    "ollama": {
      "api_key": "ollama",
      "base_url": "http://localhost:11434",
      "model": "llama3.1",
      "max_tokens": 4096,
      "temperature": 0.5,
      "top_p": 1.0,
      "top_k": 0,
      "parallel_tool_calls": false,
      "max_retries": 10
    },
    "openrouter": {
      "api_key": "your_openrouter_api_key",
      "model": "anthropic/claude-3.5-sonnet",
      "max_tokens": 4096,
      "temperature": 0.5,
      "top_p": 1.0,
      "top_k": 0,
      "parallel_tool_calls": false,
      "max_retries": 10
    },
    "doubao": {
      "api_key": "your_doubao_api_key",
      "base_url": "https://ark.cn-beijing.volces.com/api/v3",
      "model": "doubao-pro-4k",
      "max_tokens": 8192,
      "temperature": 0.5,
      "top_p": 1.0,
      "parallel_tool_calls": false,
      "max_retries": 20
    }
  },
  "lakeview_config": {
    "model_provider": "anthropic",
    "model_name": "claude-sonnet-4-20250514"
  }
}
```

**Configuration Priority:**
The Swift implementation follows the same priority order as Python:
1. Command-line arguments (`--provider`, `--model`) - highest priority
2. Environment variables (e.g., `ANTHROPIC_API_KEY`)
3. Configuration file values (`trae_config.json`)
4. Default values - lowest priority

This ensures that you can easily override settings without modifying configuration files.

## 🛠️ Available Tools

Trae Swift Agent includes all tools from the Python version:

### **BashTool** - Execute Shell Commands
Execute shell commands with enhanced features:
- Persistent working directory across commands
- Environment variable management
- Timeout support
- Cross-platform shell detection

### **RunTool** - Advanced Command Execution
Execute complex shell commands with:
- Output truncation (16,000 characters with continuation notice)
- Enhanced error handling and recovery
- Session restart capabilities
- Detailed error reporting

### **TextEditorTool** - File Operations
Comprehensive file editing capabilities:
- `view` - Display file contents with line numbers and ranges
- `create` - Create new files with content
- `str_replace` - Replace text in files (matches Python's str_replace_based_edit_tool)
- `insert` - Insert text at specific line numbers
- Directory listing and file management

### **JSONEditTool** - JSON Manipulation with JSONPath
Advanced JSON editing with full JSONPath support:
- `view` - Display JSON content or query with JSONPath expressions
- `set` - Update values at JSONPath locations
- `add` - Add new elements to objects or arrays
- `remove` - Delete elements at specified paths
- Full JSONPath query support (e.g., `$.users[?(@.age > 25)].name`)

### **SequentialThinkingTool** - Structured Problem Solving
Multi-step reasoning and analysis:
- Problem breakdown into steps
- Iterative thinking with revisions
- Hypothesis generation and testing
- Progress tracking

### **TaskDoneTool** - Task Completion
Signal task completion with results:
- Mark tasks as complete
- Provide final summaries
- Return execution results

## 📊 Enhanced Features in Swift Version

### **Superior Performance**
- **Compiled Binary**: No interpreter overhead, faster startup and execution
- **Memory Efficiency**: Swift's automatic memory management with no garbage collection pauses
- **Concurrent Execution**: Modern async/await with strict concurrency checking

### **Enhanced Error Handling**
- **Type Safety**: Compile-time error prevention
- **Structured Error Types**: `AgentError`, `ToolError`, `LLMError` with detailed context
- **Graceful Recovery**: Sophisticated error recovery mechanisms with reflection

### **Advanced Console Output**
- **Real-time Progress**: Live updating console with colored output
- **Step Visualization**: Detailed step tracking with state transitions
- **Token Usage**: Comprehensive token usage tracking and display
- **LakeView Integration**: AI-enhanced step descriptions (when enabled)

### **Robust Trajectory Recording**
- **Comprehensive Logging**: All agent steps, LLM interactions, and tool usage
- **JSON Export**: Compatible with Python trajectory format
- **Session Management**: Per-session trajectory recording in interactive mode
- **Metadata Tracking**: Timestamps, token counts, execution metrics

## 🏗️ Architecture

### **Swift-Specific Improvements**

#### **Type-Safe LLM Client Architecture**
```swift
protocol LLMClient {
    func chat(messages: [Message], tools: [ToolDefinition]?, 
              temperature: Double?, maxTokens: Int?) async throws -> ChatCompletionResponse
    func countTokens(messages: [Message]) async throws -> Int
}
```

#### **Actor-Based Concurrency**
- `CLIConsole` implemented as actor for thread-safe UI updates
- `LakeView` with async task management for non-blocking AI enhancement
- Strict concurrency checking prevents data races

#### **Factory Pattern for LLM Providers**
```swift
class LLMClientFactory {
    static func createClient(from config: FullConfig, provider: String?) throws -> LLMClient
}
```

#### **Enhanced Tool Protocol**
```swift
protocol Tool {
    var name: String { get }
    var description: String { get }
    var parameters: JSONSchema { get }
    func execute(arguments: String) async throws -> String
}
```

### **State Management**
- Sophisticated state transitions: `thinking` → `calling_tool` → `reflecting` → `completed`
- Real-time state updates to console
- Comprehensive step recording with metadata

## 📋 Feature Parity Status

### ✅ **100% Feature Parity Achieved**

The Swift implementation now provides complete feature parity with the Python Trae Agent:

- **CLI Interface**: All commands (`run`, `interactive`, `show-config`, `tools`) with identical functionality
- **LLM Providers**: All 7 providers (OpenAI, Anthropic, Azure, Google, Ollama, OpenRouter, Doubao)
- **Configuration System**: JSON config with environment variable overrides and .env file support
- **Agent Execution**: Complete state management with thinking → calling_tool → reflecting → completed flow
- **Console Output**: Real-time progress display with colors, formatting, and Lakeview integration
- **Trajectory Recording**: Comprehensive execution logging compatible with Python format
- **Interactive Mode**: Full conversational interface with all Python commands
- **Tool System**: All 6 tools with enhanced implementations:
  - BashTool with persistent sessions and environment variables
  - RunTool with output truncation and error recovery
  - TextEditorTool with str_replace, insert, and view ranges
  - JSONEditTool with full JSONPath support using Sextant library
  - SequentialThinkingTool with iterative reasoning
  - TaskDoneTool for completion signaling
- **Error Handling**: Advanced error reflection system with LLM-powered recovery
- **Parallel Execution**: Safe concurrent tool execution using Swift's TaskGroup
- **Provider Optimizations**: Native tool support for Anthropic, structured outputs for OpenAI
- **Environment Resolution**: Complete priority system (CLI > ENV > Config > Default)

### 🚀 **Swift-Specific Enhancements**

Beyond parity, the Swift implementation offers:
- **Compile-time Safety**: Type errors caught before runtime
- **Memory Efficiency**: No garbage collection pauses
- **Native Performance**: Zero interpreter overhead
- **Thread Safety**: Guaranteed by Swift's actor model and sendable protocols
- **Cross-platform Binary**: Single executable for macOS, Linux, and Windows

## 🧪 Testing

```bash
# Run all tests
swift test

# Run tests with verbose output
swift test --verbose

# Run specific test targets
swift test --filter TraeSwiftTests
```

## 🤝 Contributing

The Swift implementation welcomes contributions! Please follow these guidelines:

### **Development Setup**
```bash
# Clone and setup
git clone https://github.com/yourusername/TraeSwift.git
cd TraeSwift

# Build in debug mode
swift build

# Run tests
swift test

# Format code (if you have swift-format installed)
swift-format --in-place --recursive Sources/ Tests/
```

### **Swift-Specific Guidelines**
- Follow Swift API design guidelines
- Use Swift 6 strict concurrency features
- Add comprehensive tests for new functionality
- Maintain compatibility with Python configuration format
- Update documentation for new features
- Ensure cross-platform compatibility

### **Code Style**
- Use Swift naming conventions (camelCase, PascalCase)
- Prefer value types (structs) over reference types when appropriate
- Use `async/await` for asynchronous operations
- Implement proper error handling with typed errors
- Add documentation comments for public APIs

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- **Original Trae Agent Team**: For creating the excellent Python implementation that served as the foundation
- **Swift Community**: For building the powerful tools and libraries that made this migration possible
- **Anthropic**: For the anthropic-quickstart project that influenced the tool ecosystem design
- **All Contributors**: Who help improve and maintain this Swift implementation

## 🔗 Related Projects

- [**Original Trae Agent (Python)**](https://github.com/bytedance/trae-agent): The original Python implementation
- [**Swift Argument Parser**](https://github.com/apple/swift-argument-parser): CLI interface framework
- [**ShellOut**](https://github.com/JohnSundell/ShellOut): Shell command execution library
- [**OpenAI Swift**](https://github.com/MacPaw/OpenAI): OpenAI API client for Swift
