import Foundation
import SwiftUI
import FoundationModels

@MainActor
class ChatViewModel: ObservableObject {
    @Published var conversations: [Conversation] = []
    @Published var selectedConversationId: UUID?
    @Published var isGenerating = false
    @Published var selectedModelSize: ModelSize = .medium
    @Published var showTimestamps = true

    private var session: LanguageModelSession?

    var currentMessages: [ChatMessage] {
        guard let selectedId = selectedConversationId,
              let conversation = conversations.first(where: { $0.id == selectedId }) else {
            return []
        }
        return conversation.messages
    }

    var lastAssistantMessage: String? {
        currentMessages.last(where: { $0.role == .assistant })?.content
    }

    func copyLastResponse() {
        guard let lastResponse = lastAssistantMessage else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(lastResponse, forType: .string)
    }

    init() {
        print("DEBUG: ChatViewModel.init() called")
        loadConversations()
        print("DEBUG: Loaded \(conversations.count) conversations")
        initializeSession()

        // Create initial conversation if none exist
        if conversations.isEmpty {
            print("DEBUG: No conversations found, creating initial conversation")
            newConversation()
        } else if selectedConversationId == nil {
            print("DEBUG: Setting selected ID to first conversation")
            selectedConversationId = conversations.first?.id
        }
        print("DEBUG: ChatViewModel initialization complete. Selected ID: \(selectedConversationId?.uuidString ?? "nil")")
    }

    func initializeSession() {
        let model = SystemLanguageModel.default
        session = try? LanguageModelSession(model: model)
    }

    func newConversation() {
        print("DEBUG: Creating new conversation")
        let conversation = Conversation()
        print("DEBUG: Conversation created with ID: \(conversation.id)")
        conversations.insert(conversation, at: 0)
        print("DEBUG: Total conversations: \(conversations.count)")
        selectedConversationId = conversation.id
        print("DEBUG: Selected ID: \(selectedConversationId?.uuidString ?? "nil")")
        saveConversations()
        print("DEBUG: Conversations saved")
    }

    func deleteConversations(at offsets: IndexSet) {
        conversations.remove(atOffsets: offsets)
        if conversations.isEmpty {
            newConversation()
        } else if selectedConversationId == nil || !conversations.contains(where: { $0.id == selectedConversationId }) {
            selectedConversationId = conversations.first?.id
        }
        saveConversations()
    }

    func renameConversation(id: UUID, newTitle: String) {
        guard let index = conversations.firstIndex(where: { $0.id == id }) else { return }
        conversations[index].title = newTitle
        saveConversations()
    }

    func exportCurrentConversation() {
        guard let selectedId = selectedConversationId,
              let conversation = conversations.first(where: { $0.id == selectedId }) else {
            return
        }

        var markdown = "# \(conversation.title)\n\n"
        markdown += "Exported: \(Date().formatted())\n\n"
        markdown += "---\n\n"

        for message in conversation.messages {
            let role = message.role == .user ? "**You**" : "**Assistant**"
            markdown += "\(role):\n\n\(message.content)\n\n---\n\n"
        }

        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.plainText]
        savePanel.nameFieldStringValue = "\(conversation.title).md"
        savePanel.message = "Export conversation to Markdown"

        savePanel.begin { response in
            if response == .OK, let url = savePanel.url {
                try? markdown.write(to: url, atomically: true, encoding: .utf8)
            }
        }
    }

    func forkConversation(from messageIndex: Int) {
        guard let selectedId = selectedConversationId,
              let conversation = conversations.first(where: { $0.id == selectedId }),
              messageIndex < conversation.messages.count else {
            return
        }

        // Create new conversation with messages up to and including the selected message
        let forkedMessages = Array(conversation.messages.prefix(messageIndex + 1))
        let newConversation = Conversation(
            title: "\(conversation.title) (forked)",
            messages: forkedMessages
        )

        conversations.insert(newConversation, at: 0)
        selectedConversationId = newConversation.id
        saveConversations()
    }

    func sendMessage(_ text: String) async {
        print("DEBUG: ViewModel.sendMessage called with: \(text)")
        print("DEBUG: Selected conversation ID: \(selectedConversationId?.uuidString ?? "nil")")
        print("DEBUG: Total conversations: \(conversations.count)")

        guard let selectedId = selectedConversationId,
              let index = conversations.firstIndex(where: { $0.id == selectedId }) else {
            print("DEBUG: ERROR - No selected conversation or conversation not found")
            return
        }

        print("DEBUG: Found conversation at index \(index)")

        // Add user message
        let userMessage = ChatMessage(role: .user, content: text)
        conversations[index].messages.append(userMessage)
        conversations[index].updatedAt = Date()

        print("DEBUG: User message added. Total messages: \(conversations[index].messages.count)")

        // Update title if first message
        if conversations[index].messages.count == 1 {
            conversations[index].title = String(text.prefix(50))
            print("DEBUG: Updated conversation title to: \(conversations[index].title)")
        }

        isGenerating = true
        print("DEBUG: Set isGenerating = true")
        saveConversations()

        // Generate response
        do {
            guard let session = session else {
                throw LLMError.invalidConfiguration
            }

            // Build context from conversation history
            var prompt = ""
            for message in conversations[index].messages {
                prompt += "[\(message.role.rawValue)]: \(message.content)\n"
            }
            prompt += "[assistant]: "

            // Create a new assistant message for this response
            let assistantMessage = ChatMessage(role: .assistant, content: "")
            conversations[index].messages.append(assistantMessage)
            let assistantMessageIndex = conversations[index].messages.count - 1

            // Stream the response
            let stream = session.streamResponse(to: prompt)
            for try await partialResponse in stream {
                // Update the specific assistant message we just created
                conversations[index].messages[assistantMessageIndex] = ChatMessage(
                    id: assistantMessage.id,
                    role: .assistant,
                    content: partialResponse.content
                )
            }

            conversations[index].updatedAt = Date()
            saveConversations()

        } catch {
            let errorMessage = ChatMessage(role: .assistant, content: "Error: \(error.localizedDescription)")
            conversations[index].messages.append(errorMessage)
        }

        isGenerating = false
    }

    // MARK: - Persistence

    private var conversationsURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDir = appSupport.appendingPathComponent("com.llm-cli.app", isDirectory: true)
        try? FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)
        return appDir.appendingPathComponent("conversations.json")
    }

    private func loadConversations() {
        guard FileManager.default.fileExists(atPath: conversationsURL.path) else { return }

        do {
            let data = try Data(contentsOf: conversationsURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            conversations = try decoder.decode([Conversation].self, from: data)
        } catch {
            print("Failed to load conversations: \(error)")
        }
    }

    private func saveConversations() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(conversations)
            try data.write(to: conversationsURL)
        } catch {
            print("Failed to save conversations: \(error)")
        }
    }
}

// Simplified error handling
enum LLMError: Error {
    case invalidConfiguration
}
