import Foundation

protocol BaseLLMClient {
    var trajectoryRecorder: TrajectoryRecorder? { get set }
    
    func setTrajectoryRecorder(_ recorder: TrajectoryRecorder?)
    func setChatHistory(_ messages: [LLMMessage])
    func chat(messages: [LLMMessage], modelParameters: ModelParameters, tools: [Tool]?, reuseHistory: Bool) async throws -> LLMResponse
    func supportsToolCalling(modelParameters: ModelParameters) -> Bool
}

extension BaseLLMClient {
    func setTrajectoryRecorder(_ recorder: TrajectoryRecorder?) {
        // Default implementation - can be overridden
    }
    
    func setChatHistory(_ messages: [LLMMessage]) {
        // Default implementation - can be overridden
    }
    
    func supportsToolCalling(modelParameters: ModelParameters) -> Bool {
        // Default implementation - most modern models support tool calling
        return true
    }
}