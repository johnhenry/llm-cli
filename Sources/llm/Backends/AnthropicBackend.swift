import Foundation

/// Backend implementation using Anthropic's Claude API via direct HTTP calls
final class AnthropicBackend: LLMBackend {
    private let apiKey: String
    private let modelName: String
    private let instructions: String?
    private let apiURL = URL(string: "https://api.anthropic.com/v1/messages")!

    init(size: ModelSize, instructions: String?) async throws {
        // Get API key from environment
        guard let apiKey = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"] else {
            throw LLMError.modelNotAvailable("ANTHROPIC_API_KEY environment variable not set")
        }

        self.apiKey = apiKey
        self.modelName = size.anthropicModel
        self.instructions = instructions
    }

    func generateText(from prompt: String, temperature: Double, tools: [any Tool]) async throws -> String {
        var messages: [[String: Any]] = [
            ["role": "user", "content": prompt]
        ]

        // Build tools for Anthropic
        let anthropicTools: [[String: Any]] = tools.map { tool in
            [
                "name": tool.name,
                "description": tool.description,
                "input_schema": [
                    "type": "object",
                    "properties": [:] as [String: Any],
                    "required": []
                ]
            ]
        }

        // Keep making requests until we get a final answer (handle tool calls)
        var maxIterations = 10
        var finalResponse = ""

        while maxIterations > 0 {
            maxIterations -= 1

            // Build request body
            var requestBody: [String: Any] = [
                "model": modelName,
                "max_tokens": 4096,
                "messages": messages,
                "temperature": temperature
            ]

            if let instructions = instructions {
                requestBody["system"] = instructions
            }

            if !anthropicTools.isEmpty {
                requestBody["tools"] = anthropicTools
            }

            // Make API request
            var request = URLRequest(url: apiURL)
            request.httpMethod = "POST"
            request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
            request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
            request.setValue("application/json", forHTTPHeaderField: "content-type")
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw LLMError.generationFailed("Invalid response from Anthropic API")
            }

            guard httpResponse.statusCode == 200 else {
                let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                throw LLMError.generationFailed("Anthropic API error (\(httpResponse.statusCode)): \(errorMessage)")
            }

            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                throw LLMError.generationFailed("Failed to parse Anthropic response")
            }

            // Extract content and stop reason
            guard let content = json["content"] as? [[String: Any]],
                  let stopReason = json["stop_reason"] as? String else {
                throw LLMError.generationFailed("Invalid response format from Anthropic")
            }

            // Process content
            var toolCalls: [[String: Any]] = []

            for block in content {
                if let type = block["type"] as? String {
                    switch type {
                    case "text":
                        if let text = block["text"] as? String {
                            finalResponse += text
                        }

                    case "tool_use":
                        toolCalls.append(block)

                    default:
                        break
                    }
                }
            }

            // Check if we're done
            if stopReason == "end_turn" || stopReason == "max_tokens" || stopReason == "stop_sequence" {
                return finalResponse
            }

            // Handle tool calls
            if stopReason == "tool_use" && !toolCalls.isEmpty {
                // Add assistant's response to messages
                messages.append(["role": "assistant", "content": content])

                // Execute tools and collect results
                var toolResults: [[String: Any]] = []

                for toolCall in toolCalls {
                    guard let toolName = toolCall["name"] as? String,
                          let toolId = toolCall["id"] as? String,
                          let input = toolCall["input"] as? [String: Any] else {
                        continue
                    }

                    // Find and execute the tool
                    guard let tool = tools.first(where: { $0.name == toolName }) else {
                        throw LLMError.generationFailed("Tool not found: \(toolName)")
                    }

                    let result = try await tool.execute(arguments: input)

                    toolResults.append([
                        "type": "tool_result",
                        "tool_use_id": toolId,
                        "content": result
                    ])
                }

                // Add tool results as user message
                if !toolResults.isEmpty {
                    messages.append(["role": "user", "content": toolResults])
                }

                // Continue loop to get next response
                continue
            }

            // Unknown stop reason
            return finalResponse
        }

        throw LLMError.generationFailed("Maximum tool use iterations exceeded")
    }

    nonisolated func streamText(from prompt: String, temperature: Double, tools: [any Tool]) -> AsyncThrowingStream<String, Error> {
        // Streaming implementation similar to generateText but with SSE
        // For simplicity, we'll use non-streaming for now
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let text = try await generateText(from: prompt, temperature: temperature, tools: tools)
                    continuation.yield(text)
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    func prewarm() {
        // No prewarming needed for API-based backend
    }
}

// Extension to map ModelSize to Anthropic models
extension ModelSize {
    var anthropicModel: String {
        switch self {
        case .small:
            return "claude-3-haiku-20240307"
        case .medium:
            return "claude-3-5-sonnet-20241022"
        case .large:
            return "claude-3-5-sonnet-20241022" // Could use opus when needed
        }
    }
}
