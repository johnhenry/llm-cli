import Foundation
import MCP

@MainActor
struct ServeMCPCommand {
    static func run(args: [String]) async {
        // Parse arguments
        var verbose = false
        var i = 0
        while i < args.count {
            let arg = args[i]
            switch arg {
            case "--verbose", "-v":
                verbose = true
            case "--help", "-h":
                printHelp()
                return
            default:
                if arg.hasPrefix("--") {
                    print("Unknown option: \(arg)")
                    printHelp()
                    return
                }
            }
            i += 1
        }

        // Log to stderr if verbose (stdout is used for MCP protocol)
        func log(_ message: String) {
            if verbose {
                fputs("[\(Date())] \(message)\n", stderr)
                fflush(stderr)
            }
        }

        log("Starting llm-cli MCP server...")

        // Create server
        let server = MCPServerWrapper(name: "llm-cli", version: "1.0.0")

        // Register all tools
        log("Registering tools...")

        // File operations
        server.registerTool(ReadFileTool())
        server.registerTool(WriteFileTool())
        server.registerTool(EditFileTool())
        server.registerTool(GlobFilesTool())
        server.registerTool(GrepFilesTool())
        log("  Registered 5 file operation tools")

        // Shell operations
        server.registerTool(ExecuteBashTool())
        log("  Registered 1 shell tool")

        // Git operations
        server.registerTool(GitStatusTool())
        server.registerTool(GitDiffTool())
        server.registerTool(GitLogTool())
        server.registerTool(GitCommitTool())
        log("  Registered 4 git tools")

        // Web operations
        server.registerTool(WebSearchTool())
        server.registerTool(WebFetchTool())
        log("  Registered 2 web tools")

        // LLM operations
        server.registerTool(LLMGenerateTool())
        log("  Registered 1 LLM tool")

        // Project operations
        server.registerTool(CreateTodoTool())
        server.registerTool(ListTodosTool())
        server.registerTool(UpdateTodoTool())
        server.registerTool(DeleteTodoTool())
        log("  Registered 4 project tools")

        log("Total: 17 tools registered")

        // Setup signal handlers for graceful shutdown
        let signalSource = DispatchSource.makeSignalSource(signal: SIGINT, queue: .main)
        signalSource.setEventHandler {
            log("Received SIGINT, shutting down...")
            exit(0)
        }
        signalSource.resume()
        signal(SIGINT, SIG_IGN)

        // Create stdio transport
        let transport = StdioTransport()

        // Start server
        log("Server starting on stdio transport...")
        log("Security config: \(SecurityConfigStore.shared.getConfig().enabled ? "enabled" : "disabled")")

        do {
            try await server.start(transport: transport)
            log("Server started successfully")
        } catch {
            fputs("Error starting server: \(error.localizedDescription)\n", stderr)
            exit(1)
        }
    }

    static func printHelp() {
        print("""
        Usage: llm serve-mcp [OPTIONS]

        Start an MCP server exposing llm-cli tools via stdio transport.

        OPTIONS:
            -v, --verbose       Enable verbose logging to stderr
            -h, --help          Show this help message

        DESCRIPTION:
            This command starts an MCP (Model Context Protocol) server that exposes
            llm-cli's tools to external MCP clients. The server uses stdio transport
            for communication.

        AVAILABLE TOOLS (17 total):
            File Operations (5):
                • read_file      - Read file contents with line numbers
                • write_file     - Create or overwrite files
                • edit_file      - Replace strings in files
                • glob_files     - Find files by pattern
                • grep_files     - Search file contents

            Shell Operations (1):
                • execute_bash   - Execute bash commands with sandboxing

            Git Operations (4):
                • git_status     - Repository status
                • git_diff       - Show diffs
                • git_log        - Commit history
                • git_commit     - Create commits

            Web Operations (2):
                • web_search     - Search using DuckDuckGo
                • web_fetch      - Fetch web content

            LLM Operations (1):
                • llm_generate   - Generate text with Foundation Models

            Project Operations (4):
                • create_todo    - Create todo items
                • list_todos     - List todos with filtering
                • update_todo    - Update todo properties
                • delete_todo    - Delete todos

        SECURITY:
            All tools are protected by the security sandbox configured in
            ~/.config/llm-cli/security.json

            Sensitive operations may require interactive confirmation.

        CONFIGURATION:
            To use this server with an MCP client, add to your client config:

            {
              "mcpServers": {
                "llm-cli": {
                  "command": "llm",
                  "args": ["serve-mcp"]
                }
              }
            }

        EXAMPLES:
            # Start server with verbose logging
            llm serve-mcp --verbose

            # Start server (for use by MCP client)
            llm serve-mcp

        SEE ALSO:
            llm chat --mcp-server <name>     Use MCP tools in chat
            llm generate --mcp-server <name> Use MCP tools in generation
        """)
    }
}
