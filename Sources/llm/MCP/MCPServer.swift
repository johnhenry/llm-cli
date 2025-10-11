import Foundation
import MCP

final class MCPServerWrapper: @unchecked Sendable {
    private let server: Server
    private var tools: [any ServerTool] = []

    init(name: String = "llm-cli", version: String = "1.0.0") {
        self.server = Server(
            name: name,
            version: version,
            capabilities: .init(
                tools: .init(listChanged: false)
            )
        )
    }

    func registerTool(_ tool: any ServerTool) {
        tools.append(tool)
    }

    func start(transport: StdioTransport) async throws {
        // Register list tools handler
        await server.withMethodHandler(ListTools.self) { [weak self] _ in
            guard let self = self else {
                return .init(tools: [])
            }

            let mcpTools = self.tools.map { tool in
                MCP.Tool(
                    name: tool.name,
                    description: tool.description,
                    inputSchema: .object(tool.inputSchema)
                )
            }

            return .init(tools: mcpTools)
        }

        // Register call tool handler
        await server.withMethodHandler(CallTool.self) { [weak self] request in
            guard let self = self else {
                return .init(content: [.text("Server not initialized")], isError: true)
            }

            // Find the tool
            guard let tool = self.tools.first(where: { $0.name == request.name }) else {
                return .init(
                    content: [.text("Tool '\(request.name)' not found")],
                    isError: true
                )
            }

            // Execute the tool
            do {
                let result = try await tool.execute(arguments: request.arguments ?? [:])
                return .init(
                    content: [.text(result)],
                    isError: false
                )
            } catch {
                return .init(
                    content: [.text("Error: \(error.localizedDescription)")],
                    isError: true
                )
            }
        }

        // Start the server
        try await server.start(transport: transport)
    }
}

// Protocol for server-side tools
protocol ServerTool {
    var name: String { get }
    var description: String { get }
    var inputSchema: [String: Value] { get }

    func execute(arguments: [String: Value]) async throws -> String
}
