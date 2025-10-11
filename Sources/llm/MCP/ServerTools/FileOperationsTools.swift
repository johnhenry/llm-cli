import Foundation
import MCP

// MARK: - Read File Tool

struct ReadFileTool: ServerTool {
    let name = "read_file"
    let description = "Read contents of a file with optional line range"
    let inputSchema: [String: Value] = [
        "type": .string("object"),
        "properties": .object([
            "path": .object([
                "type": .string("string"),
                "description": .string("Path to the file to read")
            ]),
            "offset": .object([
                "type": .string("number"),
                "description": .string("Optional starting line number (0-indexed)")
            ]),
            "limit": .object([
                "type": .string("number"),
                "description": .string("Optional maximum number of lines to read")
            ])
        ]),
        "required": .array([.string("path")])
    ]

    @MainActor
    func execute(arguments: [String: Value]) async throws -> String {
        guard let pathValue = arguments["path"], case .string(let path) = pathValue else {
            throw MCPError.invalidArguments("path must be a string")
        }

        let config = SecurityConfigStore.shared.getConfig().fileOperations

        // Validate path
        let validPath = try Sandbox.validatePath(path, config: config)

        // Check file size
        try Sandbox.checkFileSize(validPath, maxSize: config.maxFileSize)

        // Read file
        let content = try String(contentsOfFile: validPath, encoding: .utf8)
        let lines = content.components(separatedBy: .newlines)

        // Apply offset/limit if specified
        var offset = 0
        var limit = lines.count

        if let offsetValue = arguments["offset"], case .int(let offsetNum) = offsetValue {
            offset = Int(offsetNum)
        }

        if let limitValue = arguments["limit"], case .int(let limitNum) = limitValue {
            limit = Int(limitNum)
        }

        let endIndex = min(offset + limit, lines.count)
        let selectedLines = Array(lines[offset..<endIndex])

        // Format with line numbers
        var result = ""
        for (index, line) in selectedLines.enumerated() {
            let lineNum = offset + index + 1
            result += String(format: "%5d→%@\n", lineNum, line)
        }

        return Sandbox.truncateResult(result)
    }
}

// MARK: - Write File Tool

struct WriteFileTool: ServerTool {
    let name = "write_file"
    let description = "Create or overwrite a file with content"
    let inputSchema: [String: Value] = [
        "type": .string("object"),
        "properties": .object([
            "path": .object([
                "type": .string("string"),
                "description": .string("Path to the file to write")
            ]),
            "content": .object([
                "type": .string("string"),
                "description": .string("Content to write to the file")
            ])
        ]),
        "required": .array([.string("path"), .string("content")])
    ]

    @MainActor
    func execute(arguments: [String: Value]) async throws -> String {
        guard let pathValue = arguments["path"], case .string(let path) = pathValue,
              let contentValue = arguments["content"], case .string(let content) = contentValue else {
            throw MCPError.invalidArguments("path and content must be strings")
        }

        let config = SecurityConfigStore.shared.getConfig().fileOperations

        // Validate path
        let validPath = try Sandbox.validatePath(path, config: config)

        // Request confirmation if required
        if Sandbox.shouldConfirm(operation: "write_file", config: config) {
            try await Sandbox.requestConfirmation(
                operation: "write_file",
                details: "Write to: \(validPath)\nSize: \(content.count) bytes"
            )
        }

        // Write file
        try content.write(toFile: validPath, atomically: true, encoding: .utf8)

        return "✅ Successfully wrote \(content.count) bytes to \(validPath)"
    }
}

// MARK: - Edit File Tool

struct EditFileTool: ServerTool {
    let name = "edit_file"
    let description = "Replace a string in a file"
    let inputSchema: [String: Value] = [
        "type": .string("object"),
        "properties": .object([
            "path": .object([
                "type": .string("string"),
                "description": .string("Path to the file to edit")
            ]),
            "old_string": .object([
                "type": .string("string"),
                "description": .string("String to replace")
            ]),
            "new_string": .object([
                "type": .string("string"),
                "description": .string("Replacement string")
            ])
        ]),
        "required": .array([.string("path"), .string("old_string"), .string("new_string")])
    ]

    @MainActor
    func execute(arguments: [String: Value]) async throws -> String {
        guard let pathValue = arguments["path"], case .string(let path) = pathValue,
              let oldValue = arguments["old_string"], case .string(let oldString) = oldValue,
              let newValue = arguments["new_string"], case .string(let newString) = newValue else {
            throw MCPError.invalidArguments("path, old_string, and new_string must be strings")
        }

        let config = SecurityConfigStore.shared.getConfig().fileOperations

        // Validate path
        let validPath = try Sandbox.validatePath(path, config: config)

        // Check file size
        try Sandbox.checkFileSize(validPath, maxSize: config.maxFileSize)

        // Read file
        var content = try String(contentsOfFile: validPath, encoding: .utf8)

        // Find occurrences
        let occurrences = content.components(separatedBy: oldString).count - 1
        guard occurrences > 0 else {
            throw MCPError.toolCallFailed("String not found in file")
        }

        // Request confirmation if required
        if Sandbox.shouldConfirm(operation: "edit_file", config: config) {
            try await Sandbox.requestConfirmation(
                operation: "edit_file",
                details: "File: \(validPath)\nReplace \(occurrences) occurrence(s) of:\n\"\(oldString)\"\nwith:\n\"\(newString)\""
            )
        }

        // Perform replacement
        content = content.replacingOccurrences(of: oldString, with: newString)

        // Write back
        try content.write(toFile: validPath, atomically: true, encoding: .utf8)

        return "✅ Replaced \(occurrences) occurrence(s) in \(validPath)"
    }
}

// MARK: - Glob Files Tool

struct GlobFilesTool: ServerTool {
    let name = "glob_files"
    let description = "Find files matching a glob pattern"
    let inputSchema: [String: Value] = [
        "type": .string("object"),
        "properties": .object([
            "pattern": .object([
                "type": .string("string"),
                "description": .string("Glob pattern (e.g., **/*.swift)")
            ]),
            "path": .object([
                "type": .string("string"),
                "description": .string("Optional directory to search in (defaults to current)")
            ])
        ]),
        "required": .array([.string("pattern")])
    ]

    @MainActor
    func execute(arguments: [String: Value]) async throws -> String {
        guard let patternValue = arguments["pattern"], case .string(let pattern) = patternValue else {
            throw MCPError.invalidArguments("pattern must be a string")
        }

        var searchPath = FileManager.default.currentDirectoryPath
        if let pathValue = arguments["path"], case .string(let path) = pathValue {
            searchPath = path
        }

        let config = SecurityConfigStore.shared.getConfig().fileOperations

        // Validate path
        let validPath = try Sandbox.validatePath(searchPath, config: config)

        // Use find command to glob
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/find")
        task.arguments = [validPath, "-name", pattern]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe

        try task.run()
        task.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else {
            return "No files found"
        }

        let files = output.components(separatedBy: .newlines).filter { !$0.isEmpty }

        return Sandbox.truncateResult("""
        Found \(files.count) file(s):
        \(files.joined(separator: "\n"))
        """)
    }
}

// MARK: - Grep Files Tool

struct GrepFilesTool: ServerTool {
    let name = "grep_files"
    let description = "Search file contents with regex pattern"
    let inputSchema: [String: Value] = [
        "type": .string("object"),
        "properties": .object([
            "pattern": .object([
                "type": .string("string"),
                "description": .string("Regex pattern to search for")
            ]),
            "path": .object([
                "type": .string("string"),
                "description": .string("Optional file or directory to search in")
            ]),
            "case_insensitive": .object([
                "type": .string("boolean"),
                "description": .string("Case insensitive search")
            ])
        ]),
        "required": .array([.string("pattern")])
    ]

    @MainActor
    func execute(arguments: [String: Value]) async throws -> String {
        guard let patternValue = arguments["pattern"], case .string(let pattern) = patternValue else {
            throw MCPError.invalidArguments("pattern must be a string")
        }

        var searchPath = FileManager.default.currentDirectoryPath
        if let pathValue = arguments["path"], case .string(let path) = pathValue {
            searchPath = path
        }

        let config = SecurityConfigStore.shared.getConfig().fileOperations

        // Validate path
        let validPath = try Sandbox.validatePath(searchPath, config: config)

        // Build grep command
        var args = ["-r", "-n", pattern, validPath]

        if let caseValue = arguments["case_insensitive"], case .bool(let insensitive) = caseValue, insensitive {
            args.insert("-i", at: 0)
        }

        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/grep")
        task.arguments = args

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe

        try task.run()
        task.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8), !output.isEmpty else {
            return "No matches found"
        }

        return Sandbox.truncateResult(output)
    }
}
