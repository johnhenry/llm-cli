import Foundation

struct MCPCommand {
    @MainActor
    static func run(args: [String]) async {
        let output = OutputHandler()

        // Show help if no subcommand
        guard !args.isEmpty else {
            printUsage()
            return
        }

        let subcommand = args[0]
        let subArgs = Array(args.dropFirst())

        switch subcommand {
        case "list-servers", "ls":
            listServers(output: output)

        case "add-server", "add":
            await addServer(args: subArgs, output: output)

        case "remove-server", "remove", "rm":
            removeServer(args: subArgs, output: output)

        case "list-tools", "tools":
            await listTools(args: subArgs, output: output)

        case "call-tool", "call":
            await callTool(args: subArgs, output: output)

        case "test":
            await testServer(args: subArgs, output: output)

        case "config":
            showConfig(output: output)

        case "help", "--help", "-h":
            printUsage()

        default:
            output.printMessage("Unknown subcommand: \(subcommand)")
            output.printMessage("Run 'llm mcp help' for usage information")
        }
    }

    @MainActor
    private static func listServers(output: OutputHandler) {
        let servers = MCPConfigStore.shared.listServers()

        if servers.isEmpty {
            output.printMessage("📦 No MCP servers configured")
            output.printMessage("\nAdd a server with: llm mcp add-server <name> <command> [args...]")
            return
        }

        output.printMessage("📦 Configured MCP Servers:\n")
        for server in servers {
            output.printMessage("  • \(server.name)")
            output.printMessage("    Command: \(server.command) \(server.args.joined(separator: " "))")
            if let env = server.env, !env.isEmpty {
                output.printMessage("    Environment: \(env.count) variable(s)")
            }
            output.printMessage("")
        }
    }

    @MainActor
    private static func addServer(args: [String], output: OutputHandler) async {
        guard args.count >= 2 else {
            output.printMessage("Usage: llm mcp add-server <name> <command> [args...]")
            output.printMessage("\nExample:")
            output.printMessage("  llm mcp add-server my-server npx -y @modelcontextprotocol/server-filesystem /path/to/dir")
            return
        }

        let name = args[0]
        let command = args[1]
        let commandArgs = Array(args.dropFirst(2))

        let server = MCPServerConfig(
            name: name,
            command: command,
            args: commandArgs
        )

        do {
            try MCPConfigStore.shared.addServer(server)
            output.printMessage("✅ Added MCP server '\(name)'")
            output.printMessage("\nTest it with: llm mcp test \(name)")
        } catch {
            output.printError(error)
        }
    }

    @MainActor
    private static func removeServer(args: [String], output: OutputHandler) {
        guard let name = args.first else {
            output.printMessage("Usage: llm mcp remove-server <name>")
            return
        }

        do {
            try MCPConfigStore.shared.removeServer(named: name)
            output.printMessage("✅ Removed MCP server '\(name)'")
        } catch {
            output.printError(error)
        }
    }

    @MainActor
    private static func listTools(args: [String], output: OutputHandler) async {
        guard let serverName = args.first else {
            output.printMessage("Usage: llm mcp list-tools <server-name>")
            output.printMessage("\nAvailable servers:")
            listServers(output: output)
            return
        }

        guard let config = MCPConfigStore.shared.getServer(named: serverName) else {
            output.printMessage("⚠️  Server '\(serverName)' not found")
            output.printMessage("\nAvailable servers:")
            listServers(output: output)
            return
        }

        output.printMessage("🔧 Loading tools from '\(serverName)'...\n")

        do {
            let client = MCPClientWrapper(serverName: serverName, config: config)
            let tools = try await client.listTools()

            if tools.isEmpty {
                output.printMessage("No tools available from this server")
                return
            }

            output.printMessage("Available Tools (\(tools.count)):\n")
            for (index, tool) in tools.enumerated() {
                output.printMessage("\(index + 1). \(tool.name)")
                output.printMessage("   \(tool.description)")
                output.printMessage("")
            }

            await client.disconnect()
        } catch {
            output.printError(error)
        }
    }

    @MainActor
    private static func callTool(args: [String], output: OutputHandler) async {
        guard args.count >= 2 else {
            output.printMessage("Usage: llm mcp call-tool <server-name> <tool-name> [json-arguments]")
            output.printMessage("\nExample:")
            output.printMessage("  llm mcp call-tool my-server read_file '{\"path\": \"/etc/hosts\"}'")
            return
        }

        let serverName = args[0]
        let toolName = args[1]
        let jsonArgs = args.count > 2 ? args[2] : "{}"

        guard let config = MCPConfigStore.shared.getServer(named: serverName) else {
            output.printMessage("⚠️  Server '\(serverName)' not found")
            return
        }

        do {
            let client = MCPClientWrapper(serverName: serverName, config: config)

            // Parse JSON arguments
            var arguments: [String: Any] = [:]
            if let data = jsonArgs.data(using: .utf8),
               let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                arguments = parsed
            }

            output.printMessage("🔧 Calling tool '\(toolName)' on '\(serverName)'...\n")

            let result = try await client.callTool(name: toolName, arguments: arguments)
            output.printMessage("Result:")
            output.printMessage("────────────────────────────────")
            output.printMessage(result)
            output.printMessage("────────────────────────────────")

            await client.disconnect()
        } catch {
            output.printError(error)
        }
    }

    @MainActor
    private static func testServer(args: [String], output: OutputHandler) async {
        guard let serverName = args.first else {
            output.printMessage("Usage: llm mcp test <server-name>")
            return
        }

        guard let config = MCPConfigStore.shared.getServer(named: serverName) else {
            output.printMessage("⚠️  Server '\(serverName)' not found")
            return
        }

        output.printMessage("🧪 Testing MCP server '\(serverName)'...\n")
        output.printMessage("Command: \(config.command) \(config.args.joined(separator: " "))\n")

        do {
            let client = MCPClientWrapper(serverName: serverName, config: config)
            try await client.connect()
            output.printMessage("✅ Connection successful")

            let tools = try await client.listTools()
            output.printMessage("✅ Found \(tools.count) tool(s)")

            if !tools.isEmpty {
                output.printMessage("\nAvailable tools:")
                for tool in tools.prefix(5) {
                    output.printMessage("  • \(tool.name)")
                }
                if tools.count > 5 {
                    output.printMessage("  ... and \(tools.count - 5) more")
                }
            }

            await client.disconnect()
            output.printMessage("\n✅ Test completed successfully")
        } catch {
            output.printMessage("❌ Test failed")
            output.printError(error)
        }
    }

    @MainActor
    private static func showConfig(output: OutputHandler) {
        let configStore = MCPConfigStore.shared
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        let configPath = homeDir.appendingPathComponent(".config/llm-cli/mcp-servers.json").path

        output.printMessage("⚙️  MCP Configuration\n")
        output.printMessage("Config file: \(configPath)")
        output.printMessage("Servers: \(configStore.listServers().count)\n")

        if FileManager.default.fileExists(atPath: configPath) {
            do {
                let content = try String(contentsOfFile: configPath, encoding: .utf8)
                output.printMessage("Current configuration:")
                output.printMessage("────────────────────────────────")
                output.printMessage(content)
                output.printMessage("────────────────────────────────")
            } catch {
                output.printMessage("Could not read config file: \(error.localizedDescription)")
            }
        } else {
            output.printMessage("No configuration file found (will be created on first server add)")
        }
    }

    static func printUsage() {
        print("""
        Usage: llm mcp <subcommand> [options]

        Subcommands:
          list-servers, ls              List configured MCP servers
          add-server <name> <cmd>       Add a new MCP server
          remove-server <name>          Remove an MCP server
          list-tools <server>           List tools from a server
          call-tool <server> <tool>     Call a tool directly
          test <server>                 Test connection to a server
          config                        Show configuration
          help                          Show this help message

        Examples:
          # Add an MCP server
          llm mcp add-server filesystem npx -y @modelcontextprotocol/server-filesystem /tmp

          # List configured servers
          llm mcp list-servers

          # List tools from a server
          llm mcp list-tools filesystem

          # Test a server
          llm mcp test filesystem

          # Call a tool
          llm mcp call-tool filesystem read_file '{"path": "/tmp/test.txt"}'

          # Use MCP tools in chat (coming soon)
          llm chat --mcp-server filesystem

        MCP Server Examples:
          # Filesystem access
          llm mcp add-server fs npx -y @modelcontextprotocol/server-filesystem /path/to/dir

          # GitHub integration
          llm mcp add-server github npx -y @modelcontextprotocol/server-github

          # SQLite database
          llm mcp add-server db npx -y @modelcontextprotocol/server-sqlite path/to/db.sqlite

        Configuration:
          Servers are stored in: ~/.config/llm-cli/mcp-servers.json
        """)
    }
}
