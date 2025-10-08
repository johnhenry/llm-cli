import Foundation
import FoundationModels

struct VoiceCommand {
    static func run(args: [String]) async {
        let output = OutputHandler()

        // Parse arguments
        var modelSize: ModelSize = .medium
        var prompt: String?
        var listenMode = false

        var i = 0
        while i < args.count {
            let arg = args[i]

            switch arg {
            case "--model", "-m":
                i += 1
                if i < args.count {
                    modelSize = ModelSize(rawValue: args[i]) ?? .medium
                }
            case "--listen", "-l":
                listenMode = true
            default:
                // Any non-flag argument is the prompt
                if !arg.hasPrefix("-") {
                    prompt = arg
                }
            }
            i += 1
        }

        do {
            let voiceHandler = VoiceHandler()

            // Request authorization
            let authorized = await voiceHandler.requestSpeechRecognitionAuthorization()
            guard authorized else {
                output.printMessage("❌ Speech recognition authorization denied")
                output.printMessage("Please enable microphone access in System Settings > Privacy & Security")
                return
            }

            if listenMode {
                // Just listen and transcribe
                output.printMessage("🎤 Listening... (speak now)\n")
                let transcription = try await voiceHandler.recordUntilSilence(timeout: 2.0)
                print(transcription)
            } else if let textPrompt = prompt {
                // Speak the provided text
                output.printMessage("🔊 Speaking...\n")
                await voiceHandler.speak(textPrompt)
                output.printMessage("✅ Done")
            } else {
                // Interactive: listen, send to LLM, speak response
                output.printMessage("🎤 Voice mode - Ask a question\n")
                output.printMessage("🎤 Listening... (speak now)")

                let userInput = try await voiceHandler.recordUntilSilence(timeout: 2.0)

                guard !userInput.isEmpty else {
                    output.printMessage("No speech detected")
                    return
                }

                output.printMessage("You said: \(userInput)\n")

                // Generate response
                let llm = try LLM(size: modelSize)
                print("Assistant: ", terminator: "")
                var responseText = ""

                for try await token in llm.streamText(from: userInput) {
                    print(token, terminator: "")
                    fflush(stdout)
                    responseText += token
                }
                print("\n")

                // Speak the response
                output.printMessage("🔊 Speaking response...")
                await voiceHandler.speak(responseText.trimmingCharacters(in: .whitespaces))
                output.printMessage("✅ Done")
            }

        } catch {
            output.printError(error)
        }
    }

    static func printUsage() {
        print("""
        Usage: llm voice [options] [text]

        Voice interaction modes:

        1. Interactive (default):
           Ask a question via voice, get spoken response
           llm voice

        2. Listen mode:
           Record speech and output transcription
           llm voice --listen

        3. Speak mode:
           Speak provided text
           llm voice "Hello, world!"

        Options:
          --model, -m <size>    Model size for interactive mode (small, medium, large)
          --listen, -l          Just transcribe speech to text

        Examples:
          llm voice                           # Interactive: ask and hear response
          llm voice --listen                  # Transcribe speech to text
          llm voice "Welcome to LLM CLI"      # Speak this text
          llm voice --model large             # Interactive with large model
        """)
    }
}
