import Foundation
import MCP

// MARK: - Git Status Tool

struct GitStatusTool: ServerTool {
    let name = "git_status"
    let description = "Get git repository status"
    let inputSchema: [String: Value] = [
        "type": .string("object"),
        "properties": .object([:])
    ]

    @MainActor
    func execute(arguments: [String: Value]) async throws -> String {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        task.arguments = ["status", "--porcelain"]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe

        try task.run()
        task.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else {
            return "No changes"
        }

        return output.isEmpty ? "Working tree clean" : output
    }
}

// MARK: - Git Diff Tool

struct GitDiffTool: ServerTool {
    let name = "git_diff"
    let description = "Show git diff for staged or unstaged changes"
    let inputSchema: [String: Value] = [
        "type": .string("object"),
        "properties": .object([
            "path": .object([
                "type": .string("string"),
                "description": .string("Optional file path to diff")
            ]),
            "staged": .object([
                "type": .string("boolean"),
                "description": .string("Show staged changes (default: false)")
            ])
        ])
    ]

    @MainActor
    func execute(arguments: [String: Value]) async throws -> String {
        var args = ["diff"]

        if let stagedValue = arguments["staged"], case .bool(let staged) = stagedValue, staged {
            args.append("--cached")
        }

        if let pathValue = arguments["path"], case .string(let path) = pathValue {
            args.append(path)
        }

        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        task.arguments = args

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe

        try task.run()
        task.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else {
            return "No changes"
        }

        return Sandbox.truncateResult(output.isEmpty ? "No changes" : output)
    }
}

// MARK: - Git Log Tool

struct GitLogTool: ServerTool {
    let name = "git_log"
    let description = "Show git commit history"
    let inputSchema: [String: Value] = [
        "type": .string("object"),
        "properties": .object([
            "limit": .object([
                "type": .string("number"),
                "description": .string("Number of commits to show (default: 10)")
            ])
        ])
    ]

    @MainActor
    func execute(arguments: [String: Value]) async throws -> String {
        var limit = 10
        if let limitValue = arguments["limit"], case .int(let limitNum) = limitValue {
            limit = Int(limitNum)
        }

        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        task.arguments = ["log", "--oneline", "-n", String(limit)]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe

        try task.run()
        task.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else {
            return "No commits"
        }

        return output
    }
}

// MARK: - Git Commit Tool

struct GitCommitTool: ServerTool {
    let name = "git_commit"
    let description = "Create a git commit"
    let inputSchema: [String: Value] = [
        "type": .string("object"),
        "properties": .object([
            "message": .object([
                "type": .string("string"),
                "description": .string("Commit message")
            ]),
            "files": .object([
                "type": .string("array"),
                "description": .string("Optional list of files to commit (default: all staged)")
            ])
        ]),
        "required": .array([.string("message")])
    ]

    @MainActor
    func execute(arguments: [String: Value]) async throws -> String {
        guard let messageValue = arguments["message"], case .string(let message) = messageValue else {
            throw MCPError.invalidArguments("message must be a string")
        }

        // Request confirmation
        try await Sandbox.requestConfirmation(
            operation: "git_commit",
            details: "Message: \(message)"
        )

        // Add files if specified
        if let filesValue = arguments["files"], case .array(let filesArray) = filesValue {
            let files = filesArray.compactMap { value -> String? in
                if case .string(let file) = value {
                    return file
                }
                return nil
            }

            for file in files {
                let addTask = Process()
                addTask.executableURL = URL(fileURLWithPath: "/usr/bin/git")
                addTask.arguments = ["add", file]
                try addTask.run()
                addTask.waitUntilExit()
            }
        }

        // Create commit
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        task.arguments = ["commit", "-m", message]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe

        try task.run()
        task.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else {
            return "Commit created"
        }

        return output
    }
}
