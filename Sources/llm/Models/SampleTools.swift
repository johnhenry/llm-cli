import Foundation
import FoundationModels

// Sample tool: Get current time
final class GetCurrentTimeTool: Tool {
    let name = "getCurrentTime"
    let description = "Returns the current system time"

    @Generable
    struct Arguments {
        // No arguments needed
    }

    func call(arguments: Arguments) async throws -> GeneratedContent {
        let now = Date()
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        return GeneratedContent(formatter.string(from: now))
    }
}

// Sample tool: Get weather (mock data)
final class GetWeatherTool: Tool {
    let name = "getWeather"
    let description = "Gets weather information for a location"

    @Generable
    struct Arguments {
        @Guide(description: "Location to get weather for")
        let location: String
    }

    func call(arguments: Arguments) async throws -> GeneratedContent {
        // In real implementation, this would call a weather API
        return GeneratedContent("Weather in \(arguments.location): Partly cloudy, 72°F")
    }
}

// Sample tool: Search files
final class SearchFilesTool: Tool {
    let name = "searchFiles"
    let description = "Searches for files in the current directory"

    @Generable
    struct Arguments {
        @Guide(description: "File pattern to search for")
        let pattern: String
    }

    func call(arguments: Arguments) async throws -> GeneratedContent {
        // In real implementation, this would search the file system
        let fileManager = FileManager.default
        let currentPath = fileManager.currentDirectoryPath

        do {
            let files = try fileManager.contentsOfDirectory(atPath: currentPath)
            let matching = files.filter { $0.contains(arguments.pattern) }

            if matching.isEmpty {
                return GeneratedContent("No files found matching '\(arguments.pattern)'")
            } else {
                return GeneratedContent("Found \(matching.count) file(s): \(matching.joined(separator: ", "))")
            }
        } catch {
            return GeneratedContent("Error searching files: \(error.localizedDescription)")
        }
    }
}
