import Foundation
import FoundationModels

struct StatusCommand {
    static func run(args: [String]) async {
        let output = OutputHandler()

        output.printMessage("🧠 Foundation Models Status\n")

        // Check default model
        let model = SystemLanguageModel.default
        output.printMessage("Model: SystemLanguageModel.default")

        switch model.availability {
        case .available:
            output.printMessage("Status: ✅ Available")
            output.printMessage("")
            output.printMessage("The Foundation Models framework is ready to use.")
            output.printMessage("You can now use commands like:")
            output.printMessage("  • llm generate \"Your prompt\"")
            output.printMessage("  • llm chat")
            output.printMessage("  • llm serve")

        case .unavailable(let reason):
            output.printMessage("Status: ❌ Unavailable")
            output.printMessage("")

            switch reason {
            case .deviceNotEligible:
                output.printMessage("Reason: Device not eligible")
                output.printMessage("")
                output.printMessage("Foundation Models requires:")
                output.printMessage("  • macOS 26 (Tahoe) or later")
                output.printMessage("  • Apple Silicon (M1/M2/M3/M4 or later)")

            case .appleIntelligenceNotEnabled:
                output.printMessage("Reason: Apple Intelligence not enabled")
                output.printMessage("")
                output.printMessage("Please enable Apple Intelligence in:")
                output.printMessage("  System Settings > Apple Intelligence")

            case .modelNotReady:
                output.printMessage("Reason: Model not ready")
                output.printMessage("")
                output.printMessage("The model is still being prepared.")
                output.printMessage("Please wait a few moments and try again.")

            @unknown default:
                output.printMessage("Reason: Unknown (\(reason))")
            }
        }

        output.printMessage("")
    }

    static func printUsage() {
        print("""
        Usage: llm status

        Check the availability of Foundation Models on this device.

        Examples:
          llm status
        """)
    }
}
