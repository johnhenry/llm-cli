import Foundation

enum ModelSize: String {
    case small = "foundation-small"
    case medium = "foundation-medium"
    case large = "foundation-large"
}

// Extension for Anthropic models (in AnthropicBackend.swift)
// Extension for FoundationModels will be added below

struct GenerationResult: Codable {
    let tokens: [String]
    let text: String
    let elapsed: Double
}

enum LLMError: Error, LocalizedError {
    case modelNotAvailable(String)
    case generationFailed(String)
    case invalidConfiguration
    case contextWindowExceeded

    var errorDescription: String? {
        switch self {
        case .modelNotAvailable(let reason):
            return "Model not available: \(reason)"
        case .generationFailed(let reason):
            return "Generation failed: \(reason)"
        case .invalidConfiguration:
            return "Invalid configuration"
        case .contextWindowExceeded:
            return "Context window exceeded. Try clearing history with 'llm history --clear' or use a shorter prompt."
        }
    }
}

final class LLM: @unchecked Sendable {
    let size: ModelSize
    private let backend: any LLMBackend
    private var customTools: [any Tool] = []

    init(size: ModelSize = .medium, instructions: String? = nil) async throws {
        self.size = size

        // Create backend using factory
        let backendType = LLMBackendFactory.BackendType.default
        self.backend = try await LLMBackendFactory.createBackend(
            type: backendType,
            size: size,
            instructions: instructions
        )
    }

    func generateText(from prompt: String, temperature: Double = 0.7) async throws -> String {
        return try await backend.generateText(
            from: prompt,
            temperature: temperature,
            tools: customTools
        )
    }

    nonisolated func streamText(from prompt: String) -> AsyncThrowingStream<String, Error> {
        return backend.streamText(
            from: prompt,
            temperature: 0.7,
            tools: customTools
        )
    }

    func streamJSON(from prompt: String) async throws -> GenerationResult {
        let startTime = Date()
        var tokens: [String] = []
        var fullText = ""

        for try await token in streamText(from: prompt) {
            tokens.append(token)
            fullText += token
        }

        let elapsed = Date().timeIntervalSince(startTime)
        return GenerationResult(tokens: tokens, text: fullText.trimmingCharacters(in: .whitespaces), elapsed: elapsed)
    }

    func registerTool(_ tool: any Tool) {
        customTools.append(tool)
    }

    func getTools() -> [any Tool] {
        return customTools
    }

    func prewarm() {
        backend.prewarm()
    }
}
