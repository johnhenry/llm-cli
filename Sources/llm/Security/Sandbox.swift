import Foundation

enum SandboxError: Error, LocalizedError {
    case pathNotAllowed(String)
    case pathDenied(String)
    case commandNotAllowed(String)
    case commandDenied(String)
    case fileTooLarge(Int, Int) // actual, max
    case operationCancelled
    case timeout

    var errorDescription: String? {
        switch self {
        case .pathNotAllowed(let path):
            return "Path '\(path)' is not in the allowed paths list"
        case .pathDenied(let path):
            return "Path '\(path)' is explicitly denied"
        case .commandNotAllowed(let cmd):
            return "Command '\(cmd)' is not in the allowed commands list"
        case .commandDenied(let cmd):
            return "Command '\(cmd)' is explicitly denied"
        case .fileTooLarge(let actual, let max):
            return "File size (\(actual) bytes) exceeds maximum allowed (\(max) bytes)"
        case .operationCancelled:
            return "Operation cancelled by user"
        case .timeout:
            return "Operation timed out"
        }
    }
}

@MainActor
struct Sandbox {

    // MARK: - Path Validation

    static func validatePath(_ path: String, config: FileOperationsConfig) throws -> String {
        // Resolve to absolute path
        let url = URL(fileURLWithPath: path)
        let absolutePath: String

        // Try to resolve real path (follows symlinks)
        if let realPath = try? FileManager.default.destinationOfSymbolicLink(atPath: url.path) {
            absolutePath = realPath
        } else {
            absolutePath = url.standardized.path
        }

        // Expand environment variables in config paths
        let expandedAllowed = config.allowedPaths.map { SecurityConfigStore.shared.expandPath($0) }
        let expandedDenied = config.deniedPaths.map { SecurityConfigStore.shared.expandPath($0) }

        // Check denied list first (takes precedence)
        for deniedPath in expandedDenied {
            if absolutePath.hasPrefix(deniedPath) {
                throw SandboxError.pathDenied(absolutePath)
            }
        }

        // Check allowed list
        var isAllowed = false
        for allowedPath in expandedAllowed {
            if absolutePath.hasPrefix(allowedPath) {
                isAllowed = true
                break
            }
        }

        if !isAllowed {
            throw SandboxError.pathNotAllowed(absolutePath)
        }

        return absolutePath
    }

    static func checkFileSize(_ path: String, maxSize: Int) throws {
        let attributes = try FileManager.default.attributesOfItem(atPath: path)
        if let fileSize = attributes[.size] as? Int {
            if fileSize > maxSize {
                throw SandboxError.fileTooLarge(fileSize, maxSize)
            }
        }
    }

    // MARK: - Command Validation

    static func validateCommand(_ command: String, config: ShellOperationsConfig) throws -> String {
        // Extract base command (first word)
        let components = command.split(separator: " ", maxSplits: 1)
        guard let baseCommand = components.first else {
            throw SandboxError.commandNotAllowed("")
        }

        let cmd = String(baseCommand)

        // Check denied list first
        for deniedCmd in config.deniedCommands {
            if cmd == deniedCmd || cmd.contains(deniedCmd) {
                throw SandboxError.commandDenied(cmd)
            }
        }

        // Check allowed list
        var isAllowed = false
        for allowedCmd in config.allowedCommands {
            if cmd == allowedCmd {
                isAllowed = true
                break
            }
        }

        if !isAllowed {
            throw SandboxError.commandNotAllowed(cmd)
        }

        // Check for dangerous patterns
        let dangerous = ["&&", ";", "|", ">", "<", "`", "$(", "rm -rf", "sudo"]
        for pattern in dangerous {
            if command.contains(pattern) {
                throw SandboxError.commandDenied("Command contains dangerous pattern: \(pattern)")
            }
        }

        return command
    }

    // MARK: - Confirmation Prompts

    static func requestConfirmation(operation: String, details: String) async throws {
        print("\n⚠️  Confirmation Required")
        print("Operation: \(operation)")
        print("Details: \(details)")
        print("Allow this operation? [y/N]: ", terminator: "")
        fflush(stdout)

        guard let response = readLine()?.trimmingCharacters(in: .whitespaces).lowercased() else {
            throw SandboxError.operationCancelled
        }

        if response != "y" && response != "yes" {
            throw SandboxError.operationCancelled
        }
    }

    static func shouldConfirm(operation: String, config: FileOperationsConfig) -> Bool {
        return config.requireConfirmation.contains(operation)
    }

    // MARK: - Result Truncation

    static func truncateResult(_ result: String, maxLength: Int = 10000) -> String {
        if result.count <= maxLength {
            return result
        }

        // Smart truncation: show beginning and end
        let halfLength = maxLength / 2 - 50
        let beginning = String(result.prefix(halfLength))
        let end = String(result.suffix(halfLength))

        return """
        \(beginning)

        ... [truncated \(result.count - maxLength) characters] ...

        \(end)
        """
    }
}
