import Foundation

struct TraeConfig: Codable {
    let maxInputTokens: Int?
    let temperature: Double?
    let topP: Double?
    let responseModel: String?
    let cachePrompt: Bool?
    let openaiApiKey: String?
    let openaiApiBase: String?
    let openaiDefaultHeaders: [String: String]?
    let openaiCompatible: Bool?
    let anthropicApiKey: String?
    let anthropicApiBase: String?
    let anthropicApiVersion: String?
    let openrouterApiKey: String?
    let azureApiKey: String?
    let azureApiBase: String?
    let azureApiVersion: String?
    let azureDeploymentName: String?
    let doubaoApiKey: String?
    let doubaoModelEndpointId: String?
    let doubaoApiBase: String?
    let ollamaApiBase: String?
    let googleApiKey: String?
    let googleApiBase: String?
    let contextProtocol: String?
    
    enum CodingKeys: String, CodingKey {
        case maxInputTokens = "max_input_tokens"
        case temperature
        case topP = "top_p"
        case responseModel = "response_model"
        case cachePrompt = "cache_prompt"
        case openaiApiKey = "openai_api_key"
        case openaiApiBase = "openai_api_base"
        case openaiDefaultHeaders = "openai_default_headers"
        case openaiCompatible = "openai_compatible"
        case anthropicApiKey = "anthropic_api_key"
        case anthropicApiBase = "anthropic_api_base"
        case anthropicApiVersion = "anthropic_api_version"
        case openrouterApiKey = "openrouter_api_key"
        case azureApiKey = "azure_api_key"
        case azureApiBase = "azure_api_base"
        case azureApiVersion = "azure_api_version"
        case azureDeploymentName = "azure_deployment_name"
        case doubaoApiKey = "doubao_api_key"
        case doubaoModelEndpointId = "doubao_model_endpoint_id"
        case doubaoApiBase = "doubao_api_base"
        case ollamaApiBase = "ollama_api_base"
        case googleApiKey = "google_api_key"
        case googleApiBase = "google_api_base"
        case contextProtocol = "context_protocol"
    }
    
    init() {
        self.maxInputTokens = 8192
        self.temperature = 0.7
        self.topP = nil
        self.responseModel = nil
        self.cachePrompt = true
        self.openaiApiKey = nil
        self.openaiApiBase = nil
        self.openaiDefaultHeaders = nil
        self.openaiCompatible = false
        self.anthropicApiKey = nil
        self.anthropicApiBase = nil
        self.anthropicApiVersion = nil
        self.openrouterApiKey = nil
        self.azureApiKey = nil
        self.azureApiBase = nil
        self.azureApiVersion = nil
        self.azureDeploymentName = nil
        self.doubaoApiKey = nil
        self.doubaoModelEndpointId = nil
        self.doubaoApiBase = nil
        self.ollamaApiBase = nil
        self.googleApiKey = nil
        self.googleApiBase = nil
        self.contextProtocol = nil
    }
}
