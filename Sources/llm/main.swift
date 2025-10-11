import Foundation

// Entry point
let args = Array(CommandLine.arguments.dropFirst())

// Show help if no command provided
guard !args.isEmpty else {
    LLMCli.printHelp()
    Foundation.exit(0)
}

let command = args[0]
let commandArgs = Array(args.dropFirst())

Task {
    await LLMCli.run(command: command, args: commandArgs)
    Foundation.exit(0)
}

dispatchMain()

struct LLMCli {
    static func run(command: String, args: [String]) async {
        switch command {
        case "generate", "gen", "g":
            if args.contains("--help") || args.contains("-h") {
                GenerateCommand.printUsage()
            } else {
                await GenerateCommand.run(args: args)
            }

        case "chat", "c":
            if args.contains("--help") || args.contains("-h") {
                ChatCommand.printUsage()
            } else {
                await ChatCommand.run(args: args)
            }

        case "tools", "t":
            if args.contains("--help") || args.contains("-h") {
                ToolsCommand.printUsage()
            } else {
                await ToolsCommand.run(args: args)
            }

        case "serve", "s":
            if args.contains("--help") || args.contains("-h") {
                ServeCommand.printUsage()
            } else {
                await ServeCommand.run(args: args)
            }

        case "serve-mcp":
            await ServeMCPCommand.run(args: args)

        case "templates":
            await templatesCommand(args: args)

        case "history", "hist":
            await historyCommand(args: args)

        case "status":
            if args.contains("--help") || args.contains("-h") {
                StatusCommand.printUsage()
            } else {
                await StatusCommand.run(args: args)
            }

        case "ls", "list":
            await listCommand(args: args)

        case "run":
            // llm run [model] - shortcut for llm chat --model [model]
            if args.isEmpty {
                await ChatCommand.run(args: [])
            } else {
                let modelArg = args[0]
                let chatArgs = ["--model", modelArg] + Array(args.dropFirst())
                await ChatCommand.run(args: chatArgs)
            }

        case "ps":
            await psCommand(args: args)

        case "stop":
            await stopCommand(args: args)

        case "mcp":
            await MCPCommand.run(args: args)

        case "help", "--help", "-h":
            printHelp()

        case "version", "--version", "-v":
            printVersion()

        default:
            print("Unknown command: \(command)")
            print("Run 'llm help' for usage information")
            Foundation.exit(1)
        }
    }

    static func printHelp() {
        print("""
        llm-cli - Local AI Command-Line Interface

        Usage: llm <command> [options]

        Commands:
          run [model]           Start chat with optional model (shortcut)
          generate, gen, g      Generate text from a prompt
          chat, c               Interactive conversation mode
          ls, list              List available models
          ps                    Show active model sessions
          stop                  Stop running sessions
          tools, t              Manage and demonstrate tool calling
          mcp                   Manage Model Context Protocol servers
          serve, s              Start HTTP API server
          serve-mcp             Start MCP server (expose llm-cli tools)
          templates             Manage prompt templates
          history, hist         View or clear conversation history
          status                Check Foundation Models availability
          version, -v           Show version information
          help, -h              Show this help message

        Examples:
          llm run large
          llm ls
          llm ps
          llm stop --servers
          llm generate "Explain Swift concurrency"
          llm generate -f prompt.txt
          echo "Hello" | llm generate
          llm chat
          llm chat --mcp-server filesystem
          llm mcp list-servers
          llm serve --port 8765
          llm serve-mcp

        For command-specific help:
          llm <command> --help

        Environment Variables:
          LLM_OUTPUT=json       Output in JSON format
          LLM_MODEL=<size>      Default model size (small, medium, large)
        """)
    }

    static func printVersion() {
        print("llm-cli version 1.0")
        print("macOS 26 / Tahoe")
        print("Using Apple Foundation Models")
    }

    static func templatesCommand(args: [String]) async {
        let output = OutputHandler()

        // Show help
        if args.contains("--help") || args.contains("-h") {
            output.printMessage("""
            Usage: llm templates [options] [name]

            Options:
              --list, -l          List all available templates (default)
              --add, -a <name>    Create a new template (opens editor)
              --view, -v <name>   View template content
              --remove, -r <name> Remove a template
              --edit, -e <name>   Edit an existing template

            Examples:
              llm templates --list
              llm templates --add my-template
              llm templates --view summarize
              llm templates --edit code-review
              llm templates --remove my-template
            """)
            return
        }

        // List templates (default)
        if args.isEmpty || args.contains("--list") || args.contains("-l") {
            output.printMessage("📝 Available Templates:\n")
            let templates = PromptTemplates.list()

            if templates.isEmpty {
                output.printMessage("No templates found in \(PromptTemplates.templatesDir.path)")
                output.printMessage("\nCreate one with: llm templates --add <name>")
            } else {
                for template in templates {
                    output.printMessage("  • \(template)")
                }
                output.printMessage("\nUse with: llm generate --template <name> \"Your prompt\"")
            }
            return
        }

        // Add template
        if args.contains("--add") || args.contains("-a") {
            guard let nameIndex = args.firstIndex(where: { $0 == "--add" || $0 == "-a" }),
                  nameIndex + 1 < args.count else {
                output.printMessage("Error: Template name required")
                output.printMessage("Usage: llm templates --add <name>")
                return
            }

            let name = args[nameIndex + 1]
            let fileName = name.hasSuffix(".txt") ? name : "\(name).txt"
            let filePath = PromptTemplates.templatesDir.appendingPathComponent(fileName)

            // Check if template already exists
            if FileManager.default.fileExists(atPath: filePath.path) {
                output.printMessage("⚠️  Template '\(name)' already exists")
                output.printMessage("Use --edit to modify it or --remove to delete it")
                return
            }

            // Create template directory if needed
            try? FileManager.default.createDirectory(at: PromptTemplates.templatesDir, withIntermediateDirectories: true)

            // Create initial content
            let initialContent = "# \(name) template\n# Write your prompt template here\n"
            try? initialContent.write(to: filePath, atomically: true, encoding: .utf8)

            // Open in default editor
            let editor = ProcessInfo.processInfo.environment["EDITOR"] ?? "nano"
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            task.arguments = [editor, filePath.path]
            task.standardInput = FileHandle.standardInput
            task.standardOutput = FileHandle.standardOutput
            task.standardError = FileHandle.standardError

            do {
                try task.run()
                task.waitUntilExit()

                if task.terminationStatus == 0 {
                    output.printMessage("✅ Template '\(name)' created successfully")
                    output.printMessage("Location: \(filePath.path)")
                } else {
                    output.printMessage("⚠️  Editor exited with non-zero status")
                }
            } catch {
                output.printError(error)
            }
            return
        }

        // View template
        if args.contains("--view") || args.contains("-v") {
            guard let nameIndex = args.firstIndex(where: { $0 == "--view" || $0 == "-v" }),
                  nameIndex + 1 < args.count else {
                output.printMessage("Error: Template name required")
                output.printMessage("Usage: llm templates --view <name>")
                return
            }

            let name = args[nameIndex + 1]
            do {
                let content = try PromptTemplates.load(named: name)
                output.printMessage("📄 Template: \(name)\n")
                output.printMessage("────────────────────────────────")
                output.printMessage(content)
                output.printMessage("────────────────────────────────")
            } catch {
                output.printMessage("⚠️  Template '\(name)' not found")
                output.printMessage("Available templates: \(PromptTemplates.list().joined(separator: ", "))")
            }
            return
        }

        // Edit template
        if args.contains("--edit") || args.contains("-e") {
            guard let nameIndex = args.firstIndex(where: { $0 == "--edit" || $0 == "-e" }),
                  nameIndex + 1 < args.count else {
                output.printMessage("Error: Template name required")
                output.printMessage("Usage: llm templates --edit <name>")
                return
            }

            let name = args[nameIndex + 1]
            let fileName = name.hasSuffix(".txt") ? name : "\(name).txt"
            let filePath = PromptTemplates.templatesDir.appendingPathComponent(fileName)

            // Check if template exists
            guard FileManager.default.fileExists(atPath: filePath.path) else {
                output.printMessage("⚠️  Template '\(name)' not found")
                output.printMessage("Available templates: \(PromptTemplates.list().joined(separator: ", "))")
                output.printMessage("\nCreate with: llm templates --add \(name)")
                return
            }

            // Open in default editor
            let editor = ProcessInfo.processInfo.environment["EDITOR"] ?? "nano"
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            task.arguments = [editor, filePath.path]
            task.standardInput = FileHandle.standardInput
            task.standardOutput = FileHandle.standardOutput
            task.standardError = FileHandle.standardError

            do {
                try task.run()
                task.waitUntilExit()

                if task.terminationStatus == 0 {
                    output.printMessage("✅ Template '\(name)' updated successfully")
                } else {
                    output.printMessage("⚠️  Editor exited with non-zero status")
                }
            } catch {
                output.printError(error)
            }
            return
        }

        // Remove template
        if args.contains("--remove") || args.contains("-r") {
            guard let nameIndex = args.firstIndex(where: { $0 == "--remove" || $0 == "-r" }),
                  nameIndex + 1 < args.count else {
                output.printMessage("Error: Template name required")
                output.printMessage("Usage: llm templates --remove <name>")
                return
            }

            let name = args[nameIndex + 1]
            let fileName = name.hasSuffix(".txt") ? name : "\(name).txt"
            let filePath = PromptTemplates.templatesDir.appendingPathComponent(fileName)

            // Check if template exists
            guard FileManager.default.fileExists(atPath: filePath.path) else {
                output.printMessage("⚠️  Template '\(name)' not found")
                output.printMessage("Available templates: \(PromptTemplates.list().joined(separator: ", "))")
                return
            }

            // Remove file
            do {
                try FileManager.default.removeItem(at: filePath)
                output.printMessage("✅ Template '\(name)' removed successfully")
            } catch {
                output.printError(error)
            }
            return
        }

        // Default: show help
        output.printMessage("""
        Usage: llm templates [options] [name]

        Options:
          --list, -l          List all available templates (default)
          --add, -a <name>    Create a new template
          --view, -v <name>   View template content
          --remove, -r <name> Remove a template
          --edit, -e <name>   Edit an existing template

        Examples:
          llm templates --list
          llm templates --add my-template
          llm templates --view summarize
        """)
    }

    static func historyCommand(args: [String]) async {
        let output = OutputHandler()

        if args.contains("--clear") || args.contains("-c") {
            await HistoryStore.shared.clear()
            output.printMessage("🗑️  Conversation history cleared")
        } else if args.isEmpty || args.contains("--show") || args.contains("-s") {
            let messages = await HistoryStore.shared.getMessages()

            if messages.isEmpty {
                output.printMessage("No conversation history")
            } else {
                output.printMessage("📜 Conversation History (\(messages.count) messages):\n")

                let formatter = DateFormatter()
                formatter.dateStyle = .short
                formatter.timeStyle = .short

                for message in messages {
                    let timestamp = formatter.string(from: message.timestamp)
                    let emoji = message.role == "user" ? "👤" : "🤖"
                    output.printMessage("\(emoji) [\(message.role)] - \(timestamp)")
                    output.printMessage("   \(message.content.prefix(100))\(message.content.count > 100 ? "..." : "")\n")
                }
            }
        } else {
            output.printMessage("""
            Usage: llm history [options]

            Options:
              --show, -s     Show conversation history (default)
              --clear, -c    Clear conversation history

            Examples:
              llm history
              llm history --clear
            """)
        }
    }

    static func listCommand(args: [String]) async {
        let output = OutputHandler()

        output.printMessage("""
        📋 Available Foundation Models:

        Model     Size      Memory    Performance
        ────────────────────────────────────────────────
        small     ~1B       Low       Fast, basic tasks
        medium    ~3B       Moderate  Balanced (default)
        large     ~8B       High      Best quality*

        * Requires Apple Silicon with sufficient RAM

        Usage:
          llm chat --model large
          llm run small
          llm generate --model medium "Your prompt"

        Set default with: export LLM_MODEL=large
        """)
    }

    static func psCommand(args: [String]) async {
        let output = OutputHandler()

        output.printMessage("🔄 Active Sessions:\n")

        // Check for running server processes
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        task.arguments = ["pgrep", "-fl", "llm"]

        let pipe = Pipe()
        task.standardOutput = pipe

        do {
            try task.run()
            task.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let outputString = String(data: data, encoding: .utf8), !outputString.isEmpty {
                let lines = outputString.components(separatedBy: .newlines).filter { !$0.isEmpty }

                for line in lines {
                    // Parse process info
                    if line.contains("llm serve") || line.contains("llm s ") {
                        let components = line.components(separatedBy: " ")
                        if let pid = components.first {
                            let portInfo = line.contains("--port") ? "custom port" : "port 8765"
                            output.printMessage("  • Server (PID \(pid)) - \(portInfo)")
                        }
                    } else if line.contains("llm chat") || line.contains("llm c ") || line.contains("llm run") {
                        let components = line.components(separatedBy: " ")
                        if let pid = components.first {
                            output.printMessage("  • Chat session (PID \(pid))")
                        }
                    } else if line.contains("llm generate") || line.contains("llm gen") || line.contains("llm g ") {
                        let components = line.components(separatedBy: " ")
                        if let pid = components.first {
                            output.printMessage("  • Generate task (PID \(pid))")
                        }
                    }
                }

                if lines.isEmpty {
                    output.printMessage("No active sessions")
                }
            } else {
                output.printMessage("No active sessions")
            }
        } catch {
            output.printMessage("No active sessions")
        }
    }

    static func stopCommand(args: [String]) async {
        let output = OutputHandler()

        // Show help if requested
        if args.contains("--help") || args.contains("-h") {
            output.printMessage("""
            Usage: llm stop [options] [PID]

            Options:
              --all         Stop all llm sessions
              --servers     Stop all server processes only

            Examples:
              llm stop 12345          Stop process with PID 12345
              llm stop --all          Stop all llm processes
              llm stop --servers      Stop all servers

            Tip: Use 'llm ps' to see active sessions and their PIDs
            """)
            return
        }

        // Handle --all flag
        if args.contains("--all") {
            output.printMessage("🛑 Stopping all llm sessions...")

            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            task.arguments = ["pkill", "llm"]

            do {
                try task.run()
                task.waitUntilExit()

                if task.terminationStatus == 0 {
                    output.printMessage("✅ All sessions stopped")
                } else {
                    output.printMessage("No active sessions to stop")
                }
            } catch {
                output.printError(error)
            }
            return
        }

        // Handle --servers flag
        if args.contains("--servers") {
            output.printMessage("🛑 Stopping all server processes...")

            // Find PIDs of server processes (both "llm serve" and "llm s")
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            task.arguments = ["pgrep", "-fl", "llm"]

            let pipe = Pipe()
            task.standardOutput = pipe

            do {
                try task.run()
                task.waitUntilExit()

                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                if let outputString = String(data: data, encoding: .utf8), !outputString.isEmpty {
                    let lines = outputString.components(separatedBy: .newlines).filter { !$0.isEmpty }

                    // Filter for server processes only
                    var serverPids: [String] = []
                    for line in lines {
                        if line.contains("llm serve") || line.contains("llm s ") {
                            if let pid = line.components(separatedBy: " ").first {
                                serverPids.append(pid)
                            }
                        }
                    }

                    if serverPids.isEmpty {
                        output.printMessage("No server processes found")
                        return
                    }

                    // Kill each PID
                    for pid in serverPids {
                        let killTask = Process()
                        killTask.executableURL = URL(fileURLWithPath: "/usr/bin/env")
                        killTask.arguments = ["kill", pid]
                        try? killTask.run()
                        killTask.waitUntilExit()
                    }

                    output.printMessage("✅ Stopped \(serverPids.count) server process(es)")
                } else {
                    output.printMessage("No server processes found")
                }
            } catch {
                output.printError(error)
            }
            return
        }

        // Handle specific PID
        if !args.isEmpty, let pid = args.first, !pid.hasPrefix("-") {
            output.printMessage("🛑 Stopping process \(pid)...")

            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            task.arguments = ["kill", pid]

            do {
                try task.run()
                task.waitUntilExit()

                if task.terminationStatus == 0 {
                    output.printMessage("✅ Process \(pid) stopped")
                } else {
                    output.printMessage("⚠️  Could not stop process \(pid). Process may not exist or you may lack permissions.")
                }
            } catch {
                output.printError(error)
            }
            return
        }

        // No valid arguments provided
        output.printMessage("""
        Usage: llm stop [options] [PID]

        Options:
          --all         Stop all llm sessions
          --servers     Stop all server processes only

        Examples:
          llm stop 12345          Stop process with PID 12345
          llm stop --all          Stop all llm processes
          llm stop --servers      Stop all servers

        Tip: Use 'llm ps' to see active sessions and their PIDs
        For more help: llm stop --help
        """)
    }
}
