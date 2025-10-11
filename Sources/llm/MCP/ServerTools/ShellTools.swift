import Foundation
import MCP

// MARK: - Execute Bash Tool

struct ExecuteBashTool: ServerTool {
    let name = "execute_bash"
    let description = "Execute a bash command with sandboxing and timeout"
    let inputSchema: [String: Value] = [
        "type": .string("object"),
        "properties": .object([
            "command": .object([
                "type": .string("string"),
                "description": .string("Bash command to execute")
            ]),
            "timeout": .object([
                "type": .string("number"),
                "description": .string("Optional timeout in seconds (default: 30)")
            ])
        ]),
        "required": .array([.string("command")])
    ]

    @MainActor
    func execute(arguments: [String: Value]) async throws -> String {
        guard case .string(let command) = arguments["command"] else {
            throw MCPError.invalidArguments("command must be a string")
        }

        let config = SecurityConfigStore.shared.getConfig().shellOperations

        // Validate command
        let validCommand = try Sandbox.validateCommand(command, config: config)

        // Get timeout
        var timeout = config.timeout
        if let timeoutValue = arguments["timeout"], case .int(let timeoutNum) = timeoutValue {
            timeout = Int(timeoutNum)
        }

        // Request confirmation if required
        if config.requireConfirmation {
            try await Sandbox.requestConfirmation(
                operation: "execute_bash",
                details: "Command: \(validCommand)\nTimeout: \(timeout)s"
            )
        }

        // Execute command with timeout
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/bash")
        task.arguments = ["-c", validCommand]

        // Sanitize environment
        var env = ProcessInfo.processInfo.environment
        env.removeValue(forKey: "AWS_ACCESS_KEY_ID")
        env.removeValue(forKey: "AWS_SECRET_ACCESS_KEY")
        env.removeValue(forKey: "GITHUB_TOKEN")
        task.environment = env

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe

        try task.run()

        // Wait with timeout
        var timedOut = false
        let timeoutTask = Task {
            try? await Task.sleep(for: .seconds(timeout))
            if task.isRunning {
                timedOut = true
                task.terminate()
            }
        }

        task.waitUntilExit()
        timeoutTask.cancel()

        if timedOut {
            throw SandboxError.timeout
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else {
            return "Command completed with no output"
        }

        let result = """
        Exit code: \(task.terminationStatus)
        Output:
        \(output)
        """

        return Sandbox.truncateResult(result)
    }
}
