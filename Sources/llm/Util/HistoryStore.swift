import Foundation

struct Message: Codable {
    let role: String // "user" or "assistant"
    let content: String
    let timestamp: Date

    init(role: String, content: String) {
        self.role = role
        self.content = content
        self.timestamp = Date()
    }
}

struct ConversationHistory: Codable {
    var messages: [Message]

    init() {
        self.messages = []
    }
}

actor HistoryStore {
    static let shared = HistoryStore()

    private let historyPath: URL
    private var history: ConversationHistory

    private init() {
        // Create history directory if it doesn't exist
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        let historyDir = homeDir.appendingPathComponent(".local/share/llm")

        try? FileManager.default.createDirectory(at: historyDir, withIntermediateDirectories: true)

        self.historyPath = historyDir.appendingPathComponent("history.json")

        // Load existing history or create new
        if let data = try? Data(contentsOf: historyPath) {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            if let loaded = try? decoder.decode(ConversationHistory.self, from: data) {
                self.history = loaded
            } else {
                self.history = ConversationHistory()
            }
        } else {
            self.history = ConversationHistory()
        }
    }

    func addMessage(role: String, content: String) async {
        history.messages.append(Message(role: role, content: content))
        await save()
    }

    func getMessages() async -> [Message] {
        return history.messages
    }

    func getContext() async -> String {
        return history.messages.map { "[\($0.role)]: \($0.content)" }.joined(separator: "\n")
    }

    func clear() async {
        history.messages = []
        await save()
    }

    private func save() async {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(history)
            try data.write(to: historyPath)
        } catch {
            print("Warning: Failed to save history: \(error)", to: &stderrStream)
        }
    }
}
