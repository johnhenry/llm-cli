import Foundation

enum OutputMode {
    case human
    case json

    static func detect() -> OutputMode {
        // Check --json flag
        if CommandLine.arguments.contains("--json") {
            return .json
        }

        // Check LLM_OUTPUT environment variable
        if let envOutput = ProcessInfo.processInfo.environment["LLM_OUTPUT"],
           envOutput.lowercased() == "json" {
            return .json
        }

        return .human
    }
}

struct OutputHandler {
    let mode: OutputMode

    init(mode: OutputMode = .detect()) {
        self.mode = mode
    }

    func printStream(_ text: String) {
        switch mode {
        case .human:
            print(text, terminator: "")
            fflush(stdout)
        case .json:
            // For streaming in JSON mode, we'll buffer
            break
        }
    }

    func printResult(_ result: GenerationResult) throws {
        switch mode {
        case .human:
            print(result.text)
        case .json:
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(result)
            if let jsonString = String(data: data, encoding: .utf8) {
                print(jsonString)
            }
        }
    }

    func printError(_ error: Error) {
        switch mode {
        case .human:
            print("Error: \(error.localizedDescription)", to: &stderrStream)
        case .json:
            let errorDict: [String: String] = ["error": error.localizedDescription]
            if let data = try? JSONEncoder().encode(errorDict),
               let jsonString = String(data: data, encoding: .utf8) {
                print(jsonString)
            }
        }
    }

    func printMessage(_ message: String) {
        switch mode {
        case .human:
            print(message)
        case .json:
            // Skip informational messages in JSON mode
            break
        }
    }
}

// Helper for stderr
struct StderrOutputStream: TextOutputStream {
    mutating func write(_ string: String) {
        fputs(string, stderr)
    }
}

nonisolated(unsafe) var stderrStream = StderrOutputStream()
