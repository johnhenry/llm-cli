import Foundation
import FoundationModels

enum ModelSize: String {
    case small = "foundation-small"
    case medium = "foundation-medium"
    case large = "foundation-large"

    var systemModel: SystemLanguageModel {
        // All sizes currently map to default model
        // Future: could support specialized models
        return SystemLanguageModel.default
    }
}

struct GenerationResult: Codable {
    let tokens: [String]
    let text: String
    let elapsed: Double
}

enum LLMError: Error {
    case modelNotAvailable(String)
    case generationFailed(String)
    case invalidConfiguration
}

final class LLM: @unchecked Sendable {
    let size: ModelSize
    private let session: LanguageModelSession
    private var customTools: [any Tool] = []

    init(size: ModelSize = .medium, instructions: String? = nil) throws {
        self.size = size

        let model = size.systemModel

        // Check availability
        switch model.availability {
        case .available:
            break
        case .unavailable(let reason):
            switch reason {
            case .deviceNotEligible:
                throw LLMError.modelNotAvailable("Device not eligible for Foundation Models")
            case .appleIntelligenceNotEnabled:
                throw LLMError.modelNotAvailable("Apple Intelligence is not enabled")
            case .modelNotReady:
                throw LLMError.modelNotAvailable("Model is not ready yet")
            @unknown default:
                throw LLMError.modelNotAvailable("Model unavailable: \(reason)")
            }
        }

        // Create session with optional instructions
        if let instructions = instructions {
            self.session = LanguageModelSession(
                model: model,
                instructions: { instructions }
            )
        } else {
            self.session = LanguageModelSession(model: model)
        }
    }

    func generateText(from prompt: String, temperature: Double = 0.7) async throws -> String {
        do {
            let options = GenerationOptions(temperature: temperature)
            let response = try await session.respond(to: prompt, options: options)
            return response.content
        } catch {
            throw LLMError.generationFailed(error.localizedDescription)
        }
    }

    nonisolated func streamText(from prompt: String) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let stream = session.streamResponse(to: prompt)
                    var lastContent = ""

                    for try await partialResponse in stream {
                        let currentContent = partialResponse.content
                        // Yield only the new content (delta)
                        if currentContent.count > lastContent.count {
                            let newContent = String(currentContent.dropFirst(lastContent.count))
                            continuation.yield(newContent)
                            lastContent = currentContent
                        }
                    }

                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
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
        session.prewarm()
    }
}
