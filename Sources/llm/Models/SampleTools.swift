import Foundation

// Sample tool: Get current time
final class GetCurrentTimeTool: Tool {
    let name = "getCurrentTime"
    let description = "Returns the current system time"

    func execute(arguments: [String: Any]) async throws -> String {
        let now = Date()
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        return formatter.string(from: now)
    }
}

// Sample tool: Get weather (mock data)
final class GetWeatherTool: Tool {
    let name = "getWeather"
    let description = "Gets weather information for a location"

    func execute(arguments: [String: Any]) async throws -> String {
        guard let location = arguments["location"] as? String else {
            throw LLMError.invalidConfiguration
        }

        // In real implementation, this would call a weather API
        return "Weather in \(location): Partly cloudy, 72°F"
    }
}

// Sample tool: Search files
final class SearchFilesTool: Tool {
    let name = "searchFiles"
    let description = "Searches for files in the current directory"

    func execute(arguments: [String: Any]) async throws -> String {
        guard let pattern = arguments["pattern"] as? String else {
            throw LLMError.invalidConfiguration
        }

        // In real implementation, this would search the file system
        let fileManager = FileManager.default
        let currentPath = fileManager.currentDirectoryPath

        do {
            let files = try fileManager.contentsOfDirectory(atPath: currentPath)
            let matching = files.filter { $0.contains(pattern) }

            if matching.isEmpty {
                return "No files found matching '\(pattern)'"
            } else {
                return "Found \(matching.count) file(s): \(matching.joined(separator: ", "))"
            }
        } catch {
            return "Error searching files: \(error.localizedDescription)"
        }
    }
}
