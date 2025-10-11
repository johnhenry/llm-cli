import Foundation
import FoundationModels

// Extension to map ModelSize to SystemLanguageModel
extension ModelSize {
    var systemModel: SystemLanguageModel {
        // All sizes currently map to default model
        // Future: could support specialized models
        return SystemLanguageModel.default
    }
}

/// Backend implementation using Apple's FoundationModels framework
final class FoundationModelsBackend: LLMBackend {
    private let session: LanguageModelSession
    private let model: SystemLanguageModel

    init(size: ModelSize, instructions: String?) async throws {
        self.model = size.systemModel

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

    func generateText(from prompt: String, temperature: Double, tools: [any Tool]) async throws -> String {
        // Note: FoundationModels mock doesn't support tool calling yet
        // Tools are ignored in this implementation
        do {
            let options = GenerationOptions(temperature: temperature)
            let response = try await session.respond(to: prompt, options: options)
            return response.content
        } catch {
            throw LLMError.generationFailed(error.localizedDescription)
        }
    }

    nonisolated func streamText(from prompt: String, temperature: Double, tools: [any Tool]) -> AsyncThrowingStream<String, Error> {
        // Note: FoundationModels mock doesn't support tool calling yet
        // Tools are ignored in this implementation
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
                    // Check for context window errors
                    let errorMessage = error.localizedDescription.lowercased()
                    if errorMessage.contains("context") &&
                       (errorMessage.contains("window") || errorMessage.contains("size") || errorMessage.contains("length")) {
                        continuation.finish(throwing: LLMError.contextWindowExceeded)
                    } else {
                        continuation.finish(throwing: error)
                    }
                }
            }
        }
    }

    func prewarm() {
        session.prewarm()
    }
}
