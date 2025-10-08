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

        case "voice":
            if args.contains("--help") || args.contains("-h") {
                VoiceCommand.printUsage()
            } else {
                await VoiceCommand.run(args: args)
            }

        case "setup-voice":
            if args.contains("--help") || args.contains("-h") {
                SetupVoiceCommand.printUsage()
            } else {
                await SetupVoiceCommand.run(args: args)
            }

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
          generate, gen, g      Generate text from a prompt
          chat, c               Interactive conversation mode
          voice                 Voice interaction mode
          setup-voice           Setup voice permissions (run first!)
          tools, t              Manage and demonstrate tool calling
          serve, s              Start HTTP API server
          templates             Manage prompt templates
          history, hist         View or clear conversation history
          status                Check Foundation Models availability
          version, -v           Show version information
          help, -h              Show this help message

        Examples:
          llm setup-voice                 # First time setup for voice
          llm status
          llm generate "Explain Swift concurrency"
          llm chat
          llm chat --voice                # Voice chat (after setup-voice)
          llm voice                       # Quick voice question
          llm voice --listen              # Speech to text
          llm serve --port 8765
          llm tools --list

        For command-specific help:
          llm <command> --help

        Environment Variables:
          LLM_OUTPUT=json       Output in JSON format
        """)
    }

    static func printVersion() {
        print("llm-cli version 1.0")
        print("macOS 26 / Tahoe")
        print("Using Apple Foundation Models")
    }

    static func templatesCommand(args: [String]) async {
        let output = OutputHandler()

        if args.isEmpty || args.contains("--list") || args.contains("-l") {
            output.printMessage("📝 Available Templates:\n")
            let templates = PromptTemplates.list()

            if templates.isEmpty {
                output.printMessage("No templates found in \(PromptTemplates.templatesDir.path)")
            } else {
                for template in templates {
                    output.printMessage("  • \(template)")
                }
            }
        } else {
            output.printMessage("""
            Usage: llm templates [options]

            Options:
              --list, -l    List all available templates

            Examples:
              llm templates --list
            """)
        }
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
}
