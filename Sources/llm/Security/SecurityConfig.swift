import Foundation

struct FileOperationsConfig: Codable {
    var allowedPaths: [String]
    var deniedPaths: [String]
    var requireConfirmation: [String]
    var maxFileSize: Int // bytes

    static let `default` = FileOperationsConfig(
        allowedPaths: ["$HOME/Documents", "$HOME/Projects", "$HOME/Desktop"],
        deniedPaths: ["$HOME/.ssh", "$HOME/.aws", "$HOME/.config", "/etc", "/var", "/usr"],
        requireConfirmation: ["write_file", "edit_file", "execute_bash"],
        maxFileSize: 10485760 // 10MB
    )
}

struct ShellOperationsConfig: Codable {
    var allowedCommands: [String]
    var deniedCommands: [String]
    var requireConfirmation: Bool
    var timeout: Int // seconds

    static let `default` = ShellOperationsConfig(
        allowedCommands: ["git", "ls", "cat", "grep", "find", "echo", "pwd", "which"],
        deniedCommands: ["rm", "sudo", "curl", "wget", "chmod", "chown", "kill"],
        requireConfirmation: true,
        timeout: 30
    )
}

struct WebOperationsConfig: Codable {
    var httpsOnly: Bool
    var maxResponseSize: Int // bytes
    var rateLimit: Int // requests per minute
    var timeout: Int // seconds

    static let `default` = WebOperationsConfig(
        httpsOnly: true,
        maxResponseSize: 1048576, // 1MB
        rateLimit: 10,
        timeout: 30
    )
}

struct SecurityConfiguration: Codable {
    var fileOperations: FileOperationsConfig
    var shellOperations: ShellOperationsConfig
    var webOperations: WebOperationsConfig
    var enabled: Bool

    static let `default` = SecurityConfiguration(
        fileOperations: .default,
        shellOperations: .default,
        webOperations: .default,
        enabled: true
    )
}

@MainActor
final class SecurityConfigStore {
    static let shared = SecurityConfigStore()

    private let configURL: URL
    private var configuration: SecurityConfiguration

    private init() {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        let configDir = homeDir.appendingPathComponent(".config/llm-cli")

        // Create directory if needed
        try? FileManager.default.createDirectory(at: configDir, withIntermediateDirectories: true)

        self.configURL = configDir.appendingPathComponent("security.json")

        // Load or create default config
        if FileManager.default.fileExists(atPath: configURL.path) {
            do {
                let data = try Data(contentsOf: configURL)
                self.configuration = try JSONDecoder().decode(SecurityConfiguration.self, from: data)
            } catch {
                print("Warning: Could not load security config, using defaults: \(error.localizedDescription)")
                self.configuration = .default
                try? self.save()
            }
        } else {
            self.configuration = .default
            try? self.save()
        }
    }

    func getConfig() -> SecurityConfiguration {
        return configuration
    }

    func updateConfig(_ config: SecurityConfiguration) throws {
        self.configuration = config
        try save()
    }

    private func save() throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(configuration)
        try data.write(to: configURL, options: .atomic)
    }

    func expandPath(_ path: String) -> String {
        var expanded = path
        if expanded.hasPrefix("$HOME") {
            let homeDir = FileManager.default.homeDirectoryForCurrentUser.path
            expanded = expanded.replacingOccurrences(of: "$HOME", with: homeDir)
        } else if expanded.hasPrefix("~") {
            let homeDir = FileManager.default.homeDirectoryForCurrentUser.path
            expanded = expanded.replacingOccurrences(of: "~", with: homeDir)
        }
        return expanded
    }
}
