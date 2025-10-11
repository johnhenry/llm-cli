import Foundation
import MCP

final class MCPClientWrapper: @unchecked Sendable {
    let serverName: String
    let config: MCPServerConfig
    private let client: Client
    private var isConnected = false

    init(serverName: String, config: MCPServerConfig) {
        self.serverName = serverName
        self.config = config
        self.client = Client(name: "llm-cli", version: "1.0.0")
    }

    func connect() async throws {
        guard !isConnected else { return }

        // Create stdio transport
        let transport = StdioTransport()
        _ = try await client.connect(transport: transport)
        isConnected = true
    }

    func disconnect() async {
        if isConnected {
            await client.disconnect()
            isConnected = false
        }
    }

    func listTools() async throws -> [MCPTool] {
        try await connect()

        let (tools, _) = try await client.listTools()

        return tools.map { tool in
            MCPTool(
                name: tool.name,
                description: tool.description ?? "No description"
            )
        }
    }

    func callTool(name: String, arguments: [String: Any]) async throws -> String {
        try await connect()

        // Convert [String: Any] to JSON and parse as Value
        let jsonData = try JSONSerialization.data(withJSONObject: arguments)
        let decoder = JSONDecoder()
        let mcpArguments = try decoder.decode([String: Value].self, from: jsonData)

        let (content, isError) = try await client.callTool(
            name: name,
            arguments: mcpArguments
        )

        if isError == true {
            // Convert content to string for error message
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            if let data = try? encoder.encode(content),
               let string = String(data: data, encoding: .utf8) {
                throw MCPError.toolCallFailed("Tool returned error: \(string)")
            } else {
                throw MCPError.toolCallFailed("Tool returned error")
            }
        }

        // Convert content to string
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        guard let data = try? encoder.encode(content),
              let result = String(data: data, encoding: .utf8) else {
            throw MCPError.toolCallFailed("Could not format tool result")
        }

        return result
    }
}

struct MCPTool: Sendable {
    let name: String
    let description: String
}

enum MCPError: Error, LocalizedError {
    case serverNotConfigured(String)
    case connectionFailed(String)
    case toolCallFailed(String)
    case invalidArguments(String)

    var errorDescription: String? {
        switch self {
        case .serverNotConfigured(let name):
            return "MCP server '\(name)' is not configured. Use 'llm mcp add-server' to add it."
        case .connectionFailed(let reason):
            return "Failed to connect to MCP server: \(reason)"
        case .toolCallFailed(let reason):
            return "Tool call failed: \(reason)"
        case .invalidArguments(let reason):
            return "Invalid arguments: \(reason)"
        }
    }
}
