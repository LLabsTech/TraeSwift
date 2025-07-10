import XCTest
@testable import TraeSwift

final class ConfigManagerTests: XCTestCase {
    
    func testDefaultModelProviders() {
        let defaultProviders = FullConfig.defaultModelProviders()
        
        XCTAssertEqual(defaultProviders.count, 1)
        XCTAssertNotNil(defaultProviders["anthropic"])
        
        let anthropicConfig = defaultProviders["anthropic"]!
        XCTAssertEqual(anthropicConfig.model, "claude-sonnet-4-20250514")
        XCTAssertEqual(anthropicConfig.maxTokens, 4096)
        XCTAssertEqual(anthropicConfig.temperature, 0.5)
        XCTAssertEqual(anthropicConfig.topP, 1.0)
        XCTAssertEqual(anthropicConfig.topK, 0)
        XCTAssertEqual(anthropicConfig.parallelToolCalls, false)
        XCTAssertEqual(anthropicConfig.maxRetries, 10)
        XCTAssertEqual(anthropicConfig.baseUrl, "https://api.anthropic.com")
    }
    
    func testFullConfigInitialization() {
        let config = FullConfig()
        
        XCTAssertEqual(config.defaultProvider, "anthropic")
        XCTAssertEqual(config.maxSteps, 20)
        XCTAssertEqual(config.enableLakeview, true)
        XCTAssertEqual(config.modelProviders.count, 1)
        XCTAssertNil(config.lakeviewConfig)
    }
    
    func testModelParametersInitialization() {
        let params = ModelParameters(
            model: "test-model",
            apiKey: "test-key",
            maxTokens: 1000,
            temperature: 0.7
        )
        
        XCTAssertEqual(params.model, "test-model")
        XCTAssertEqual(params.apiKey, "test-key")
        XCTAssertEqual(params.maxTokens, 1000)
        XCTAssertEqual(params.temperature, 0.7)
        XCTAssertEqual(params.topP, 1.0)
        XCTAssertEqual(params.topK, 0)
        XCTAssertEqual(params.parallelToolCalls, false)
        XCTAssertEqual(params.maxRetries, 10)
        XCTAssertNil(params.baseUrl)
        XCTAssertNil(params.apiVersion)
    }
    
    func testLakeviewConfigInitialization() {
        let lakeviewConfig = LakeviewConfig(
            modelProvider: "openai",
            modelName: "gpt-4"
        )
        
        XCTAssertEqual(lakeviewConfig.modelProvider, "openai")
        XCTAssertEqual(lakeviewConfig.modelName, "gpt-4")
    }
}