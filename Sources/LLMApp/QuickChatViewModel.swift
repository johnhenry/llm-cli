import Foundation
import SwiftUI
import FoundationModels

@MainActor
class QuickChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var isGenerating = false

    private var session: LanguageModelSession?

    init() {
        initializeSession()
    }

    func initializeSession() {
        let model = SystemLanguageModel.default
        session = try? LanguageModelSession(model: model)
    }

    func clearMessages() {
        messages = []
    }

    func sendMessage(_ text: String) async {
        // Add user message
        let userMessage = ChatMessage(role: .user, content: text)
        messages.append(userMessage)

        isGenerating = true

        // Generate response
        do {
            guard let session = session else {
                throw QuickChatError.sessionNotInitialized
            }

            // Build context
            var prompt = ""
            for message in messages {
                prompt += "[\(message.role.rawValue)]: \(message.content)\n"
            }
            prompt += "[assistant]: "

            var responseText = ""

            // Stream the response
            let stream = session.streamResponse(to: prompt)
            for try await partialResponse in stream {
                responseText = partialResponse.content

                // Update the assistant message in real-time
                if let lastIndex = messages.lastIndex(where: { $0.role == .assistant && $0.id == messages.last?.id }) {
                    messages[lastIndex] = ChatMessage(
                        id: messages[lastIndex].id,
                        role: .assistant,
                        content: responseText
                    )
                } else {
                    let assistantMessage = ChatMessage(role: .assistant, content: responseText)
                    messages.append(assistantMessage)
                }
            }

        } catch {
            let errorMessage = ChatMessage(role: .assistant, content: "Error: \(error.localizedDescription)")
            messages.append(errorMessage)
        }

        isGenerating = false
    }
}

enum QuickChatError: Error {
    case sessionNotInitialized
}
