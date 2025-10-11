import Foundation

/// Adapter that wraps an MCP tool to work with our Tool protocol
final class MCPToolAdapter: Tool {
    let name: String
    let description: String
    private let client: MCPClientWrapper
    private let mcpTool: MCPTool

    init(mcpTool: MCPTool, client: MCPClientWrapper) {
        self.name = mcpTool.name
        self.description = mcpTool.description
        self.mcpTool = mcpTool
        self.client = client
    }

    func execute(arguments: [String: Any]) async throws -> String {
        // Call the MCP tool with the provided arguments
        let result = try await client.callTool(name: mcpTool.name, arguments: arguments)
        return result
    }
}

/// Manager for loading and registering MCP tools with an LLM
final class MCPToolManager {
    @MainActor
    static func loadToolsFromServer(serverName: String) async throws -> (MCPClientWrapper, [MCPToolAdapter]) {
        // Get server configuration
        guard let config = MCPConfigStore.shared.getServer(named: serverName) else {
            throw MCPError.serverNotConfigured(serverName)
        }

        // Create client and connect
        let client = MCPClientWrapper(serverName: serverName, config: config)
        try await client.connect()

        // List available tools
        let mcpTools = try await client.listTools()

        // Create adapters
        let adapters = mcpTools.map { mcpTool in
            MCPToolAdapter(mcpTool: mcpTool, client: client)
        }

        return (client, adapters)
    }

    @MainActor
    static func registerMCPTools(llm: LLM, serverName: String) async throws -> MCPClientWrapper {
        let (client, adapters) = try await loadToolsFromServer(serverName: serverName)

        for adapter in adapters {
            llm.registerTool(adapter)
        }

        return client
    }
}
