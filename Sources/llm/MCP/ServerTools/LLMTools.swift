import Foundation
import MCP

// MARK: - LLM Generate Tool

struct LLMGenerateTool: ServerTool {
    let name = "llm_generate"
    let description = "Generate text using Foundation Models LLM"
    let inputSchema: [String: Value] = [
        "type": .string("object"),
        "properties": .object([
            "prompt": .object([
                "type": .string("string"),
                "description": .string("Text prompt for generation")
            ]),
            "temperature": .object([
                "type": .string("number"),
                "description": .string("Temperature for sampling (default: 0.7)")
            ]),
            "model_size": .object([
                "type": .string("string"),
                "description": .string("Model size: small, medium, or large (default: medium)")
            ])
        ]),
        "required": .array([.string("prompt")])
    ]

    @MainActor
    func execute(arguments: [String: Value]) async throws -> String {
        guard let promptValue = arguments["prompt"], case .string(let prompt) = promptValue else {
            throw MCPError.invalidArguments("prompt must be a string")
        }

        var temperature = 0.7
        if let tempValue = arguments["temperature"] {
            if case .double(let temp) = tempValue {
                temperature = temp
            } else if case .int(let temp) = tempValue {
                temperature = Double(temp)
            }
        }

        var modelSize = ModelSize.medium
        if let sizeValue = arguments["model_size"], case .string(let sizeStr) = sizeValue {
            switch sizeStr.lowercased() {
            case "small":
                modelSize = .small
            case "large":
                modelSize = .large
            default:
                modelSize = .medium
            }
        }

        // Create LLM instance
        let llm = try await LLM(size: modelSize)

        // Generate
        do {
            let response = try await llm.generateText(from: prompt, temperature: temperature)

            return """
            Generated text:
            \(response)

            (model: \(modelSize.rawValue), temperature: \(temperature))
            """
        } catch {
            throw MCPError.toolCallFailed("LLM generation failed: \(error.localizedDescription)")
        }
    }
}

// Note: Chat tool removed since the LLM API doesn't support multi-turn conversations
// through a single method. Use multiple generate calls instead.
