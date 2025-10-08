import Foundation

struct GenerateCommand {
    static func run(args: [String]) async {
        let output = OutputHandler()

        // Parse arguments
        var prompt = ""
        var template: String?
        var modelSize: ModelSize = .medium
        var useContext = false

        var i = 0
        while i < args.count {
            let arg = args[i]

            switch arg {
            case "--template", "-t":
                i += 1
                if i < args.count {
                    template = args[i]
                }
            case "--model", "-m":
                i += 1
                if i < args.count {
                    modelSize = ModelSize(rawValue: args[i]) ?? .medium
                }
            case "--context", "-c":
                useContext = true
            case "--json":
                // Already handled by OutputMode.detect()
                break
            default:
                if !arg.hasPrefix("-") {
                    prompt = arg
                }
            }
            i += 1
        }

        // Load template if specified
        if let templateName = template {
            do {
                let templateContent = try PromptTemplates.load(named: templateName)
                prompt = templateContent + "\n" + prompt
            } catch {
                output.printError(error)
                return
            }
        }

        // Add context if requested
        if useContext {
            let context = await HistoryStore.shared.getContext()
            if !context.isEmpty {
                prompt = context + "\n[user]: " + prompt
            }
        }

        // Generate
        do {
            let llm = try LLM(size: modelSize)

            if output.mode == .json {
                // Generate complete response for JSON output
                let result = try await llm.streamJSON(from: prompt)
                try output.printResult(result)
            } else {
                // Stream for human-readable output
                for try await token in llm.streamText(from: prompt) {
                    output.printStream(token)
                }
                print() // Newline at end
            }

        } catch {
            output.printError(error)
        }
    }

    static func printUsage() {
        print("""
        Usage: llm generate [options] <prompt>

        Options:
          --template, -t <name>    Use a prompt template
          --model, -m <size>       Model size (small, medium, large)
          --context, -c            Include conversation history
          --json                   Output in JSON format

        Examples:
          llm generate "Explain Swift concurrency"
          llm generate --template summarize "Text to summarize"
          llm generate --json "Write a haiku about macOS"
        """)
    }
}
