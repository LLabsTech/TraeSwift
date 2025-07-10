import Foundation

struct ModelParameters: Codable {
    let model: String
    let apiKey: String
    let maxTokens: Int
    let temperature: Double
    let topP: Double
    let topK: Int
    let parallelToolCalls: Bool
    let maxRetries: Int
    let baseUrl: String?
    let apiVersion: String?
    let candidateCount: Int?
    let stopSequences: [String]?
    
    enum CodingKeys: String, CodingKey {
        case model
        case apiKey = "api_key"
        case maxTokens = "max_tokens"
        case temperature
        case topP = "top_p"
        case topK = "top_k"
        case parallelToolCalls = "parallel_tool_calls"
        case maxRetries = "max_retries"
        case baseUrl = "base_url"
        case apiVersion = "api_version"
        case candidateCount = "candidate_count"
        case stopSequences = "stop_sequences"
    }
    
    init(model: String, apiKey: String, maxTokens: Int = 4096, temperature: Double = 0.5, topP: Double = 1.0, topK: Int = 0, parallelToolCalls: Bool = false, maxRetries: Int = 10, baseUrl: String? = nil, apiVersion: String? = nil, candidateCount: Int? = nil, stopSequences: [String]? = nil) {
        self.model = model
        self.apiKey = apiKey
        self.maxTokens = maxTokens
        self.temperature = temperature
        self.topP = topP
        self.topK = topK
        self.parallelToolCalls = parallelToolCalls
        self.maxRetries = maxRetries
        self.baseUrl = baseUrl
        self.apiVersion = apiVersion
        self.candidateCount = candidateCount
        self.stopSequences = stopSequences
    }
}

struct LakeviewConfig: Codable {
    let modelProvider: String
    let modelName: String
    
    enum CodingKeys: String, CodingKey {
        case modelProvider = "model_provider"
        case modelName = "model_name"
    }
}

struct FullConfig: Codable {
    var defaultProvider: String
    let maxSteps: Int
    let enableLakeview: Bool
    var modelProviders: [String: ModelParameters]
    let lakeviewConfig: LakeviewConfig?
    
    enum CodingKeys: String, CodingKey {
        case defaultProvider = "default_provider"
        case maxSteps = "max_steps"
        case enableLakeview = "enable_lakeview"
        case modelProviders = "model_providers"
        case lakeviewConfig = "lakeview_config"
    }
    
    init(defaultProvider: String = "anthropic", maxSteps: Int = 20, enableLakeview: Bool = true, modelProviders: [String: ModelParameters] = [:], lakeviewConfig: LakeviewConfig? = nil) {
        self.defaultProvider = defaultProvider
        self.maxSteps = maxSteps
        self.enableLakeview = enableLakeview
        self.modelProviders = modelProviders.isEmpty ? Self.defaultModelProviders() : modelProviders
        self.lakeviewConfig = lakeviewConfig
    }
    
    static func defaultModelProviders() -> [String: ModelParameters] {
        return [
            "anthropic": ModelParameters(
                model: "claude-sonnet-4-20250514",
                apiKey: "",
                maxTokens: 4096,
                temperature: 0.5,
                topP: 1.0,
                topK: 0,
                parallelToolCalls: false,
                maxRetries: 10,
                baseUrl: "https://api.anthropic.com"
            )
        ]
    }
}