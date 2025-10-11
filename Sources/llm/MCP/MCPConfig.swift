import Foundation

struct MCPServerConfig: Codable {
    let name: String
    let command: String
    let args: [String]
    let env: [String: String]?

    init(name: String, command: String, args: [String] = [], env: [String: String]? = nil) {
        self.name = name
        self.command = command
        self.args = args
        self.env = env
    }
}

struct MCPConfiguration: Codable {
    var servers: [String: MCPServerConfig]

    init(servers: [String: MCPServerConfig] = [:]) {
        self.servers = servers
    }
}

@MainActor
final class MCPConfigStore {
    static let shared = MCPConfigStore()

    private let configURL: URL

    private init() {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        let configDir = homeDir.appendingPathComponent(".config/llm-cli")

        // Create directory if needed
        try? FileManager.default.createDirectory(at: configDir, withIntermediateDirectories: true)

        self.configURL = configDir.appendingPathComponent("mcp-servers.json")
    }

    func load() -> MCPConfiguration {
        guard FileManager.default.fileExists(atPath: configURL.path) else {
            return MCPConfiguration()
        }

        do {
            let data = try Data(contentsOf: configURL)
            let decoder = JSONDecoder()
            return try decoder.decode(MCPConfiguration.self, from: data)
        } catch {
            print("Warning: Could not load MCP configuration: \(error.localizedDescription)")
            return MCPConfiguration()
        }
    }

    func save(_ config: MCPConfiguration) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(config)
        try data.write(to: configURL, options: .atomic)
    }

    func addServer(_ server: MCPServerConfig) throws {
        var config = load()
        config.servers[server.name] = server
        try save(config)
    }

    func removeServer(named name: String) throws {
        var config = load()
        config.servers.removeValue(forKey: name)
        try save(config)
    }

    func getServer(named name: String) -> MCPServerConfig? {
        return load().servers[name]
    }

    func listServers() -> [MCPServerConfig] {
        return Array(load().servers.values).sorted { $0.name < $1.name }
    }
}
