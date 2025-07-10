import Foundation

enum ConfigError: Error {
    case fileNotFound
    case invalidJSON
    case decodingError(Error)
    case missingProvider(String)
}

class ConfigManager {
    
    /// Environment variable mapping for each provider (matches Python implementation)
    private static let providerEnvMapping: [String: ProviderEnvVars] = [
        "openai": ProviderEnvVars(
            apiKey: "OPENAI_API_KEY",
            baseUrl: "OPENAI_API_BASE",
            apiVersion: nil
        ),
        "anthropic": ProviderEnvVars(
            apiKey: "ANTHROPIC_API_KEY",
            baseUrl: "ANTHROPIC_API_BASE",
            apiVersion: nil
        ),
        "azure": ProviderEnvVars(
            apiKey: "AZURE_OPENAI_API_KEY",
            baseUrl: "AZURE_OPENAI_ENDPOINT",
            apiVersion: "AZURE_OPENAI_API_VERSION"
        ),
        "google": ProviderEnvVars(
            apiKey: "GOOGLE_API_KEY",
            baseUrl: "GOOGLE_API_BASE",
            apiVersion: nil
        ),
        "ollama": ProviderEnvVars(
            apiKey: nil, // Ollama doesn't use API keys
            baseUrl: "OLLAMA_BASE_URL",
            apiVersion: nil
        ),
        "openrouter": ProviderEnvVars(
            apiKey: "OPENROUTER_API_KEY",
            baseUrl: "OPENROUTER_BASE_URL",
            apiVersion: nil
        ),
        "doubao": ProviderEnvVars(
            apiKey: "DOUBAO_API_KEY",
            baseUrl: "DOUBAO_BASE_URL",
            apiVersion: nil
        )
    ]
    
    static func loadConfig(from path: String, cliProvider: String? = nil, cliModel: String? = nil) throws -> FullConfig {
        // Step 1: Load .env file (matches Python's load_dotenv())
        DotEnvLoader.loadDotEnv()
        
        // Step 2: Load base config from file or use defaults
        var config = loadConfigFromFile(path: path)
        
        // Step 3: Apply CLI overrides first (highest priority)
        if let cliProvider = cliProvider {
            config.defaultProvider = cliProvider
        }
        
        // Step 4: Resolve all configuration values with proper priority
        config = resolveFullConfiguration(config: config, cliModel: cliModel)
        
        return config
    }
    
    /// Load configuration from JSON file or return defaults
    private static func loadConfigFromFile(path: String) -> FullConfig {
        let url = URL(fileURLWithPath: path)
        
        guard FileManager.default.fileExists(atPath: path) else {
            print("Configuration file not found at: \(path)")
            print("Using default configuration.")
            return FullConfig()
        }
        
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            return try decoder.decode(FullConfig.self, from: data)
        } catch let error as DecodingError {
            print("Failed to decode config: \(error)")
            print("Using default configuration.")
            return FullConfig()
        } catch {
            print("Error loading config file: \(error)")
            print("Using default configuration.")
            return FullConfig()
        }
    }
    
    /// Resolve complete configuration using Python's priority system
    private static func resolveFullConfiguration(config: FullConfig, cliModel: String?) -> FullConfig {
        var resolvedConfig = config
        var resolvedProviders: [String: ModelParameters] = [:]
        
        // Resolve each provider's configuration
        for (providerName, provider) in config.modelProviders {
            let envVars = providerEnvMapping[providerName]
            
            let resolvedProvider = ModelParameters(
                model: resolveConfigValue(
                    cliValue: cliModel,
                    configValue: provider.model,
                    envVar: nil // Model typically comes from CLI or config, not env
                ) ?? provider.model,
                
                apiKey: resolveConfigValue(
                    cliValue: nil, // API keys don't come from CLI for security
                    configValue: provider.apiKey,
                    envVar: envVars?.apiKey
                ) ?? provider.apiKey,
                
                maxTokens: resolveConfigValue(
                    cliValue: nil,
                    configValue: provider.maxTokens,
                    envVar: nil
                ) ?? provider.maxTokens,
                
                temperature: resolveConfigValue(
                    cliValue: nil,
                    configValue: provider.temperature,
                    envVar: nil
                ) ?? provider.temperature,
                
                topP: resolveConfigValue(
                    cliValue: nil,
                    configValue: provider.topP,
                    envVar: nil
                ) ?? provider.topP,
                
                topK: resolveConfigValue(
                    cliValue: nil,
                    configValue: provider.topK,
                    envVar: nil
                ) ?? provider.topK,
                
                parallelToolCalls: resolveConfigValue(
                    cliValue: nil,
                    configValue: provider.parallelToolCalls,
                    envVar: nil
                ) ?? provider.parallelToolCalls,
                
                maxRetries: resolveConfigValue(
                    cliValue: nil,
                    configValue: provider.maxRetries,
                    envVar: nil
                ) ?? provider.maxRetries,
                
                baseUrl: resolveConfigValue(
                    cliValue: nil,
                    configValue: provider.baseUrl,
                    envVar: envVars?.baseUrl
                ),
                
                apiVersion: resolveConfigValue(
                    cliValue: nil,
                    configValue: provider.apiVersion,
                    envVar: envVars?.apiVersion
                ),
                
                candidateCount: resolveConfigValue(
                    cliValue: nil,
                    configValue: provider.candidateCount,
                    envVar: nil
                ),
                
                stopSequences: resolveConfigValue(
                    cliValue: nil,
                    configValue: provider.stopSequences,
                    envVar: nil
                )
            )
            
            resolvedProviders[providerName] = resolvedProvider
        }
        
        // Also resolve any missing providers that might be specified in environment variables
        for (providerName, envVars) in providerEnvMapping {
            if resolvedProviders[providerName] == nil,
               let envApiKey = envVars.apiKey,
               ProcessInfo.processInfo.environment[envApiKey] != nil {
                
                // Create a default provider configuration from environment
                let defaultProvider = createDefaultProvider(
                    providerName: providerName,
                    envVars: envVars,
                    cliModel: cliModel
                )
                resolvedProviders[providerName] = defaultProvider
            }
        }
        
        resolvedConfig.modelProviders = resolvedProviders
        
        return resolvedConfig
    }
    
    /// Create a default provider configuration from environment variables
    private static func createDefaultProvider(providerName: String, envVars: ProviderEnvVars, cliModel: String?) -> ModelParameters {
        let apiKey = ProcessInfo.processInfo.environment[envVars.apiKey ?? ""] ?? ""
        let baseUrl = envVars.baseUrl != nil ? ProcessInfo.processInfo.environment[envVars.baseUrl!] : nil
        let apiVersion = envVars.apiVersion != nil ? ProcessInfo.processInfo.environment[envVars.apiVersion!] : nil
        
        // Default models for each provider
        let defaultModels: [String: String] = [
            "openai": "gpt-4o",
            "anthropic": "claude-sonnet-4-20250514",
            "azure": "gpt-4o",
            "google": "gemini-1.5-pro-002",
            "ollama": "llama3.1",
            "openrouter": "anthropic/claude-3.5-sonnet",
            "doubao": "doubao-pro-4k"
        ]
        
        let model = cliModel ?? defaultModels[providerName] ?? "unknown"
        
        return ModelParameters(
            model: model,
            apiKey: apiKey,
            maxTokens: 4096,
            temperature: 0.5,
            topP: 1.0,
            topK: 0,
            parallelToolCalls: false,
            maxRetries: 10,
            baseUrl: baseUrl,
            apiVersion: apiVersion,
            candidateCount: nil,
            stopSequences: nil
        )
    }
    
    static func loadLegacyConfig(from path: String) throws -> TraeConfig {
        // Fallback for old TraeConfig format
        let url = URL(fileURLWithPath: path)
        
        guard FileManager.default.fileExists(atPath: path) else {
            return TraeConfig()
        }
        
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            return try decoder.decode(TraeConfig.self, from: data)
        } catch {
            throw ConfigError.decodingError(error)
        }
    }
    
    static func printConfig(_ config: FullConfig) {
        print("=== Trae Agent Configuration ===")
        print("Default Provider: \(config.defaultProvider)")
        print("Max Steps: \(config.maxSteps)")
        print("Enable Lakeview: \(config.enableLakeview)")
        print("\nModel Providers:")
        
        for (name, provider) in config.modelProviders.sorted(by: { $0.key < $1.key }) {
            print("  \(name):")
            print("    Model: \(provider.model)")
            print("    API Key: \(provider.apiKey.isEmpty ? "Not set" : "***")")
            if let baseUrl = provider.baseUrl {
                print("    Base URL: \(baseUrl)")
            }
            if let apiVersion = provider.apiVersion {
                print("    API Version: \(apiVersion)")
            }
            print("    Max Tokens: \(provider.maxTokens)")
            print("    Temperature: \(provider.temperature)")
            print("    Parallel Tool Calls: \(provider.parallelToolCalls)")
            print("    Max Retries: \(provider.maxRetries)")
        }
        
        if let lakeviewConfig = config.lakeviewConfig {
            print("\nLakeview Configuration:")
            print("  Provider: \(lakeviewConfig.modelProvider)")
            print("  Model: \(lakeviewConfig.modelName)")
        }
    }
    
    /// Generic configuration value resolution with proper priority
    /// Priority: CLI args > Environment variables > Config file > Defaults
    static func resolveConfigValue<T>(
        cliValue: T?,
        configValue: T?,
        envVar: String? = nil
    ) -> T? {
        // Priority: CLI > ENV > Config
        if let cliValue = cliValue {
            return cliValue
        }
        
        if let envVar = envVar,
           let envValue = ProcessInfo.processInfo.environment[envVar] {
            // Try to convert string env var to appropriate type
            if T.self == String.self {
                return envValue as? T
            } else if T.self == Int.self {
                return Int(envValue) as? T
            } else if T.self == Double.self {
                return Double(envValue) as? T
            } else if T.self == Bool.self {
                let boolValue = envValue.lowercased() == "true" || envValue == "1"
                return boolValue as? T
            } else if T.self == [String].self {
                // Handle arrays by splitting on commas
                let array = envValue.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                return array as? T
            }
        }
        
        return configValue
    }
}

/// Environment variable configuration for each provider
private struct ProviderEnvVars {
    let apiKey: String?
    let baseUrl: String?
    let apiVersion: String?
}