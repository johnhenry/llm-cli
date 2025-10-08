import Foundation

struct ChatCommand {
    static func run(args: [String]) async {
        let output = OutputHandler()

        // Parse arguments
        var modelSize: ModelSize = .medium
        var voiceMode = false

        var i = 0
        while i < args.count {
            let arg = args[i]

            switch arg {
            case "--model", "-m":
                i += 1
                if i < args.count {
                    modelSize = ModelSize(rawValue: args[i]) ?? .medium
                }
            case "--voice", "-v":
                voiceMode = true
            case "--clear":
                await HistoryStore.shared.clear()
                output.printMessage("💬 Conversation history cleared")
                return
            default:
                break
            }
            i += 1
        }

        if voiceMode {
            output.printMessage("🎤 Voice chat mode started. Say 'exit' or 'quit' to end.\n")
            await runVoiceChat(modelSize: modelSize, output: output)
        } else {
            output.printMessage("💬 Chat mode started. Type 'exit' or 'quit' to end, 'clear' to reset history.\n")
            await runTextChat(modelSize: modelSize, output: output)
        }
    }

    private static func runTextChat(modelSize: ModelSize, output: OutputHandler) async {
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

    private static func runVoiceChat(modelSize: ModelSize, output: OutputHandler) async {
        do {
            output.printMessage("Initializing LLM...")
            let llm = try LLM(size: modelSize)
            output.printMessage("✅ LLM initialized")

            output.printMessage("Initializing voice handler...")
            let voiceHandler = VoiceHandler()
            output.printMessage("✅ Voice handler initialized")

            // Request authorization
            output.printMessage("Requesting speech recognition authorization...")
            let authorized = await voiceHandler.requestSpeechRecognitionAuthorization()
            guard authorized else {
                output.printMessage("❌ Speech recognition authorization denied")
                output.printMessage("Please enable microphone access in System Settings > Privacy & Security")
                return
            }
            output.printMessage("✅ Authorization granted")

            output.printMessage("🎤 Listening... Speak your message.\n")

            while true {
                do {
                    // Record user speech
                    output.printMessage("🎤 Recording... (speak now)")
                    let userInput = try await voiceHandler.recordUntilSilence(timeout: 2.0)

                    guard !userInput.isEmpty else {
                        continue
                    }

                    output.printMessage("You said: \(userInput)\n")

                    // Check for exit commands
                    let trimmed = userInput.trimmingCharacters(in: .whitespaces).lowercased()
                    if trimmed.contains("exit") || trimmed.contains("quit") || trimmed.contains("goodbye") {
                        await voiceHandler.speak("Goodbye!")
                        output.printMessage("👋 Goodbye!")
                        break
                    }

                    if trimmed.contains("clear history") {
                        await HistoryStore.shared.clear()
                        await voiceHandler.speak("Conversation history cleared")
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
                    print("\n")

                    // Speak the response
                    await voiceHandler.speak(responseText.trimmingCharacters(in: .whitespaces))

                    // Add assistant response to history
                    await HistoryStore.shared.addMessage(role: "assistant", content: responseText.trimmingCharacters(in: .whitespaces))

                    print() // Extra newline for spacing
                } catch {
                    output.printMessage("Error in voice interaction: \(error.localizedDescription)")
                    continue
                }
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
          --voice, -v           Enable voice chat mode
          --clear               Clear conversation history and exit

        Interactive commands:
          Text mode:
            exit, quit          Exit chat mode
            clear               Clear conversation history

          Voice mode:
            Say "exit", "quit", or "goodbye"    Exit voice chat
            Say "clear history"                 Clear conversation history

        Examples:
          llm chat                    # Text chat
          llm chat --voice            # Voice chat
          llm chat --model large -v   # Voice chat with large model
          llm chat --clear            # Clear history
        """)
    }
}
