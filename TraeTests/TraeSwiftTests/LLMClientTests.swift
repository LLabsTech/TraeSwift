import XCTest
@testable import TraeSwift

final class LLMClientTests: XCTestCase {
    
    func testLLMClientFactoryWithOpenAI() throws {
        let modelParams = ModelParameters(
            model: "gpt-4",
            apiKey: "test-key"
        )
        
        let config = FullConfig(
            defaultProvider: "openai",
            modelProviders: ["openai": modelParams]
        )
        
        let client = try LLMClientFactory.createClient(from: config, provider: "openai")
        XCTAssertTrue(client is OpenAILLMClient)
    }
    
    func testLLMClientFactoryWithAnthropic() throws {
        let modelParams = ModelParameters(
            model: "claude-sonnet-4-20250514",
            apiKey: "test-key"
        )
        
        let config = FullConfig(
            defaultProvider: "anthropic",
            modelProviders: ["anthropic": modelParams]
        )
        
        let client = try LLMClientFactory.createClient(from: config, provider: "anthropic")
        XCTAssertTrue(client is AnthropicLLMClient)
    }
    
    func testLLMClientFactoryWithAzure() throws {
        let modelParams = ModelParameters(
            model: "gpt-4",
            apiKey: "test-key",
            baseUrl: "https://test.openai.azure.com",
            apiVersion: "2024-03-01-preview"
        )
        
        let config = FullConfig(
            defaultProvider: "azure",
            modelProviders: ["azure": modelParams]
        )
        
        let client = try LLMClientFactory.createClient(from: config, provider: "azure")
        XCTAssertTrue(client is AzureLLMClient)
    }
    
    func testLLMClientFactoryWithGoogle() throws {
        let modelParams = ModelParameters(
            model: "gemini-1.5-pro-002",
            apiKey: "test-key"
        )
        
        let config = FullConfig(
            defaultProvider: "google",
            modelProviders: ["google": modelParams]
        )
        
        let client = try LLMClientFactory.createClient(from: config, provider: "google")
        XCTAssertTrue(client is GoogleLLMClient)
    }
    
    func testLLMClientFactoryWithOllama() throws {
        let modelParams = ModelParameters(
            model: "llama3.1",
            apiKey: "ollama",
            baseUrl: "http://localhost:11434"
        )
        
        let config = FullConfig(
            defaultProvider: "ollama",
            modelProviders: ["ollama": modelParams]
        )
        
        let client = try LLMClientFactory.createClient(from: config, provider: "ollama")
        XCTAssertTrue(client is OllamaLLMClient)
    }
    
    func testLLMClientFactoryWithOpenRouter() throws {
        let modelParams = ModelParameters(
            model: "anthropic/claude-3.5-sonnet",
            apiKey: "test-key"
        )
        
        let config = FullConfig(
            defaultProvider: "openrouter",
            modelProviders: ["openrouter": modelParams]
        )
        
        let client = try LLMClientFactory.createClient(from: config, provider: "openrouter")
        XCTAssertTrue(client is OpenRouterLLMClient)
    }
    
    func testLLMClientFactoryWithDoubao() throws {
        let modelParams = ModelParameters(
            model: "doubao-pro-4k",
            apiKey: "test-key",
            baseUrl: "https://ark.cn-beijing.volces.com/api/v3"
        )
        
        let config = FullConfig(
            defaultProvider: "doubao",
            modelProviders: ["doubao": modelParams]
        )
        
        let client = try LLMClientFactory.createClient(from: config, provider: "doubao")
        XCTAssertTrue(client is DoubaoLLMClient)
    }
    
    func testLLMClientFactoryWithMissingProvider() {
        let config = FullConfig(
            defaultProvider: "nonexistent",
            modelProviders: [:]
        )
        
        XCTAssertThrowsError(try LLMClientFactory.createClient(from: config, provider: "nonexistent")) { error in
            XCTAssertTrue(error is LLMError)
        }
    }
    
    func testLLMClientFactoryWithEmptyAPIKey() {
        let modelParams = ModelParameters(
            model: "gpt-4",
            apiKey: ""
        )
        
        let config = FullConfig(
            defaultProvider: "openai",
            modelProviders: ["openai": modelParams]
        )
        
        XCTAssertThrowsError(try LLMClientFactory.createClient(from: config, provider: "openai")) { error in
            XCTAssertTrue(error is LLMError)
        }
    }
    
    func testLLMClientFactoryUsesDefaultProvider() throws {
        let modelParams = ModelParameters(
            model: "claude-sonnet-4-20250514",
            apiKey: "test-key"
        )
        
        let config = FullConfig(
            defaultProvider: "anthropic",
            modelProviders: ["anthropic": modelParams]
        )
        
        let client = try LLMClientFactory.createClient(from: config)
        XCTAssertTrue(client is AnthropicLLMClient)
    }
}