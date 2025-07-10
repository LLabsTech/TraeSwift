import Foundation

class LLMClientFactory {
    static func createClient(from config: FullConfig, provider: String? = nil) throws -> LLMClient {
        let selectedProvider = provider ?? config.defaultProvider
        
        guard let modelParams = config.modelProviders[selectedProvider] else {
            throw LLMError.missingAPIKey
        }
        
        guard !modelParams.apiKey.isEmpty else {
            throw LLMError.missingAPIKey
        }
        
        switch selectedProvider {
        case "openai":
            return OpenAILLMClient(
                apiKey: modelParams.apiKey,
                model: modelParams.model,
                baseURL: modelParams.baseUrl,
                maxRetries: modelParams.maxRetries
            )
        case "anthropic":
            return AnthropicLLMClient(
                apiKey: modelParams.apiKey,
                model: modelParams.model,
                baseURL: modelParams.baseUrl ?? "https://api.anthropic.com",
                maxRetries: modelParams.maxRetries
            )
        case "azure":
            return AzureLLMClient(
                apiKey: modelParams.apiKey,
                model: modelParams.model,
                baseURL: modelParams.baseUrl ?? "",
                apiVersion: modelParams.apiVersion ?? "2024-03-01-preview"
            )
        case "google":
            return GoogleLLMClient(
                apiKey: modelParams.apiKey,
                model: modelParams.model,
                baseURL: modelParams.baseUrl ?? "https://generativelanguage.googleapis.com"
            )
        case "ollama":
            return OllamaLLMClient(
                model: modelParams.model,
                baseURL: modelParams.baseUrl ?? "http://localhost:11434"
            )
        case "openrouter":
            return OpenRouterLLMClient(
                apiKey: modelParams.apiKey,
                model: modelParams.model,
                baseURL: modelParams.baseUrl ?? "https://openrouter.ai/api/v1"
            )
        case "doubao":
            return DoubaoLLMClient(
                apiKey: modelParams.apiKey,
                model: modelParams.model,
                baseURL: modelParams.baseUrl ?? "https://ark.cn-beijing.volces.com/api/v3"
            )
        default:
            throw LLMError.unsupportedModel
        }
    }
    
    // Legacy support for old TraeConfig format
    static func createLegacyClient(from config: TraeConfig) throws -> LLMClient {
        if let apiKey = config.openaiApiKey {
            return OpenAILLMClient(
                apiKey: apiKey,
                model: config.responseModel ?? "gpt-4o-mini",
                baseURL: config.openaiApiBase
            )
        }
        
        throw LLMError.missingAPIKey
    }
}
