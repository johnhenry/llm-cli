import Foundation

struct PromptTemplates {
    static let templatesDir: URL = {
        // Check for templates in project directory first
        let currentDir = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let projectTemplates = currentDir.appendingPathComponent("Templates")

        if FileManager.default.fileExists(atPath: projectTemplates.path) {
            return projectTemplates
        }

        // Fall back to system templates
        return URL(fileURLWithPath: "/usr/local/share/llm-cli/templates")
    }()

    static func load(named name: String) throws -> String {
        let templateURL = templatesDir.appendingPathComponent("\(name).txt")

        guard FileManager.default.fileExists(atPath: templateURL.path) else {
            throw TemplateError.notFound(name)
        }

        return try String(contentsOf: templateURL, encoding: .utf8)
    }

    static func list() -> [String] {
        guard let contents = try? FileManager.default.contentsOfDirectory(atPath: templatesDir.path) else {
            return []
        }

        return contents
            .filter { $0.hasSuffix(".txt") }
            .map { $0.replacingOccurrences(of: ".txt", with: "") }
    }

    static func exists(named name: String) -> Bool {
        let templateURL = templatesDir.appendingPathComponent("\(name).txt")
        return FileManager.default.fileExists(atPath: templateURL.path)
    }
}

enum TemplateError: Error {
    case notFound(String)

    var localizedDescription: String {
        switch self {
        case .notFound(let name):
            return "Template '\(name)' not found in \(PromptTemplates.templatesDir.path)"
        }
    }
}
