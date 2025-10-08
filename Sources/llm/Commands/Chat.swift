import Foundation

struct ChatCommand {
    static func run(args: [String]) async {
        let output = OutputHandler()

        // Parse arguments
        var modelSize: ModelSize = .medium

        var i = 0
        while i < args.count {
            let arg = args[i]

            switch arg {
            case "--model", "-m":
                i += 1
                if i < args.count {
                    modelSize = ModelSize(rawValue: args[i]) ?? .medium
                }
            case "--clear":
                await HistoryStore.shared.clear()
                output.printMessage("💬 Conversation history cleared")
                return
            default:
                break
            }
            i += 1
        }

        output.printMessage("💬 Chat mode started. Type 'exit' or 'quit' to end, 'clear' to reset history.\n")

        do {
            let llm = try LLM(size: modelSize)

            while true {
                // Read user input
                print("You: ", terminator: "")
                guard let userInput = readLine(), !userInput.isEmpty else {
                    continue
                }

                // Check for special commands
                let trimmed = userInput.trimmingCharacters(in: .whitespaces).lowercased()
                if trimmed == "exit" || trimmed == "quit" {
                    output.printMessage("\n👋 Goodbye!")
                    break
                }

                if trimmed == "clear" {
                    await HistoryStore.shared.clear()
                    output.printMessage("💬 Conversation history cleared\n")
                    continue
                }

                // Add user message to history
                await HistoryStore.shared.addMessage(role: "user", content: userInput)

                // Build prompt with context
                let context = await HistoryStore.shared.getContext()

                // Generate response
                print("Assistant: ", terminator: "")
                var responseText = ""

                for try await token in llm.streamText(from: context) {
                    print(token, terminator: "")
                    fflush(stdout)
                    responseText += token
                }
                print() // Newline

                // Add assistant response to history
                await HistoryStore.shared.addMessage(role: "assistant", content: responseText.trimmingCharacters(in: .whitespaces))

                print() // Extra newline for spacing
            }

        } catch {
            output.printError(error)
        }
    }

    static func printUsage() {
        print("""
        Usage: llm chat [options]

        Options:
          --model, -m <size>    Model size (small, medium, large)
          --clear               Clear conversation history and exit

        Interactive commands:
          exit, quit            Exit chat mode
          clear                 Clear conversation history

        Examples:
          llm chat
          llm chat --model large
          llm chat --clear
        """)
    }
}
