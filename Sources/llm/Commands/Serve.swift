import Foundation
import Network

struct ServeCommand {
    static func run(args: [String]) async {
        let output = OutputHandler()

        // Parse arguments
        var port: UInt16 = 8765
        var modelSize: ModelSize = .medium

        var i = 0
        while i < args.count {
            let arg = args[i]

            switch arg {
            case "--port", "-p":
                i += 1
                if i < args.count, let portValue = UInt16(args[i]) {
                    port = portValue
                }
            case "--model", "-m":
                i += 1
                if i < args.count {
                    modelSize = ModelSize(rawValue: args[i]) ?? .medium
                }
            default:
                break
            }
            i += 1
        }

        output.printMessage("🧠 Starting LLM API server...")
        output.printMessage("   Model: \(modelSize.rawValue)")
        output.printMessage("   Port: \(port)")
        output.printMessage("   Endpoint: http://127.0.0.1:\(port)")
        output.printMessage("\nPress Ctrl+C to stop\n")

        do {
            let llm = try LLM(size: modelSize)
            try await startServer(port: port, llm: llm, output: output)
        } catch {
            output.printError(error)
        }
    }

    private static func startServer(port: UInt16, llm: LLM, output: OutputHandler) async throws {
        guard let nwPort = NWEndpoint.Port(rawValue: port) else {
            throw LLMError.invalidConfiguration
        }
        let listener = try NWListener(using: .tcp, on: nwPort)

        listener.newConnectionHandler = { connection in
            connection.start(queue: .global())

            Task {
                await handleConnection(connection, llm: llm, output: output)
            }
        }

        listener.stateUpdateHandler = { state in
            switch state {
            case .ready:
                output.printMessage("✅ Server is ready and listening")
            case .failed(let error):
                output.printError(error)
            default:
                break
            }
        }

        listener.start(queue: .global())

        // Keep the server running indefinitely
        while true {
            try await Task.sleep(for: .seconds(3600)) // Sleep for 1 hour at a time
        }
    }

    private static func handleConnection(_ connection: NWConnection, llm: LLM, output: OutputHandler) async {
        do {
            // Receive HTTP request
            guard let data = try await receiveData(from: connection),
                  let request = String(data: data, encoding: .utf8) else {
                connection.cancel()
                return
            }

            // Parse HTTP request to extract body
            let prompt = parseHTTPBody(from: request)

            if prompt.isEmpty {
                let response = createHTTPResponse(statusCode: 400, body: "{\"error\": \"No prompt provided\"}")
                connection.send(content: response.data(using: .utf8), completion: .contentProcessed { _ in
                    connection.cancel()
                })
                return
            }

            output.printMessage("📨 Request: \(prompt.prefix(50))...")

            // Generate response
            let result = try await llm.streamJSON(from: prompt)

            // Encode as JSON
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let jsonData = try encoder.encode(result)
            let jsonString = String(data: jsonData, encoding: .utf8) ?? "{}"

            // Send HTTP response
            let response = createHTTPResponse(statusCode: 200, body: jsonString)
            connection.send(content: response.data(using: .utf8), completion: .contentProcessed { _ in
                connection.cancel()
            })

            output.printMessage("✅ Response sent (\(result.elapsed)s)\n")

        } catch {
            let errorResponse = createHTTPResponse(statusCode: 500, body: "{\"error\": \"\(error.localizedDescription)\"}")
            connection.send(content: errorResponse.data(using: .utf8), completion: .contentProcessed { _ in
                connection.cancel()
            })
        }
    }

    private static func receiveData(from connection: NWConnection) async throws -> Data? {
        return try await withCheckedThrowingContinuation { continuation in
            connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { data, _, isComplete, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                if let data = data {
                    continuation.resume(returning: data)
                } else if isComplete {
                    continuation.resume(returning: nil)
                } else {
                    continuation.resume(returning: Data())
                }
            }
        }
    }

    private static func parseHTTPBody(from request: String) -> String {
        // Simple HTTP body extraction
        let lines = request.components(separatedBy: "\r\n")

        if let emptyLineIndex = lines.firstIndex(where: { $0.isEmpty }) {
            let bodyLines = lines[(emptyLineIndex + 1)...]
            return bodyLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return ""
    }

    private static func createHTTPResponse(statusCode: Int, body: String) -> String {
        let statusText = statusCode == 200 ? "OK" : (statusCode == 400 ? "Bad Request" : "Internal Server Error")

        return """
        HTTP/1.1 \(statusCode) \(statusText)\r
        Content-Type: application/json\r
        Content-Length: \(body.utf8.count)\r
        Access-Control-Allow-Origin: *\r
        Connection: close\r
        \r
        \(body)
        """
    }

    static func printUsage() {
        print("""
        Usage: llm serve [options]

        Options:
          --port, -p <port>     Port to listen on (default: 8765)
          --model, -m <size>    Model size (small, medium, large)

        Examples:
          llm serve
          llm serve --port 9000
          llm serve --model large --port 8080
        """)
    }
}
