import Foundation

/// Protocol for LLM backend implementations
protocol LLMBackend: Sendable {
    /// Initialize the backend with model size and optional instructions
    init(size: ModelSize, instructions: String?) async throws

    /// Generate text from a prompt
    func generateText(from prompt: String, temperature: Double, tools: [any Tool]) async throws -> String

    /// Stream text generation
    func streamText(from prompt: String, temperature: Double, tools: [any Tool]) -> AsyncThrowingStream<String, Error>

    /// Warm up the model (optional)
    func prewarm()
}

/// Factory for creating LLM backends
enum LLMBackendFactory {
    enum BackendType: String {
        case foundationModels = "foundationmodels"
        case anthropic = "anthropic"

        static var `default`: BackendType {
            // Check environment variable
            if let envBackend = ProcessInfo.processInfo.environment["LLM_BACKEND"]?.lowercased() {
                return BackendType(rawValue: envBackend) ?? .foundationModels
            }
            return .foundationModels
        }
    }

    static func createBackend(type: BackendType, size: ModelSize, instructions: String?) async throws -> any LLMBackend {
        switch type {
        case .foundationModels:
            return try await FoundationModelsBackend(size: size, instructions: instructions)
        case .anthropic:
            return try await AnthropicBackend(size: size, instructions: instructions)
        }
    }
}

/// Protocol that all tools must conform to
protocol Tool: Sendable {
    var name: String { get }
    var description: String { get }

    /// Execute the tool with JSON arguments
    func execute(arguments: [String: Any]) async throws -> String
}

/// Wrapper to make FoundationModels tools (with @Generable) conform to our Tool protocol
struct ToolWrapper: Tool {
    let name: String
    let description: String
    private let executor: @Sendable ([String: Any]) async throws -> String

    init<T: FoundationModelsTool>(wrapping tool: T) {
        self.name = tool.name
        self.description = tool.description
        self.executor = { args in
            // This will be implemented to bridge to FoundationModels tool calling
            try await tool.executeWithJSON(arguments: args)
        }
    }

    func execute(arguments: [String: Any]) async throws -> String {
        try await executor(arguments)
    }
}

/// Marker protocol for FoundationModels-style tools
protocol FoundationModelsTool: Sendable {
    var name: String { get }
    var description: String { get }
    func executeWithJSON(arguments: [String: Any]) async throws -> String
}
