import Foundation

struct GenerateCommand {
    static func run(args: [String]) async {
        let output = OutputHandler()

        // Parse arguments
        var prompt = ""
        var template: String?
        var modelSize: ModelSize = .medium
        var useContext = false
        var fileInput: String?

        // Check for default model from environment
        if let envModel = ProcessInfo.processInfo.environment["LLM_MODEL"] {
            modelSize = ModelSize(rawValue: envModel) ?? .medium
        }

        var i = 0
        while i < args.count {
            let arg = args[i]

            switch arg {
            case "--file", "-f":
                i += 1
                if i < args.count {
                    fileInput = args[i]
                }
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

        // Handle file input
        if let filePath = fileInput {
            do {
                let url = URL(fileURLWithPath: filePath)
                prompt = try String(contentsOf: url, encoding: .utf8)
            } catch {
                output.printError(error)
                return
            }
        }

        // Check for stdin input if no prompt provided
        if prompt.isEmpty {
            // isatty returns 0 if stdin is piped (not a terminal)
            if isatty(FileHandle.standardInput.fileDescriptor) == 0 {
                if let stdinData = try? FileHandle.standardInput.readToEnd(),
                   let stdinText = String(data: stdinData, encoding: .utf8) {
                    prompt = stdinText.trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
        }

        // Handle multiline input with triple quotes
        if prompt.hasPrefix("\"\"\"") && prompt.hasSuffix("\"\"\"") {
            prompt = String(prompt.dropFirst(3).dropLast(3)).trimmingCharacters(in: .whitespacesAndNewlines)
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
          --file, -f <path>        Read prompt from file
          --template, -t <name>    Use a prompt template
          --model, -m <size>       Model size (small, medium, large)
          --context, -c            Include conversation history
          --json                   Output in JSON format

        Multiline Input:
          Use triple quotes: llm generate \"\"\"line1
          line2
          line3\"\"\"

        Examples:
          llm generate "Explain Swift concurrency"
          llm generate -f prompt.txt
          echo "What is AI?" | llm generate
          llm generate --template summarize "Text to summarize"
          llm generate --json "Write a haiku about macOS"
        """)
    }
}
