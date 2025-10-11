import Foundation
import MCP

// MARK: - Web Search Tool

struct WebSearchTool: ServerTool {
    let name = "web_search"
    let description = "Search the web using DuckDuckGo"
    let inputSchema: [String: Value] = [
        "type": .string("object"),
        "properties": .object([
            "query": .object([
                "type": .string("string"),
                "description": .string("Search query")
            ]),
            "limit": .object([
                "type": .string("number"),
                "description": .string("Maximum number of results (default: 10)")
            ])
        ]),
        "required": .array([.string("query")])
    ]

    @MainActor
    func execute(arguments: [String: Value]) async throws -> String {
        guard let queryValue = arguments["query"], case .string(let query) = queryValue else {
            throw MCPError.invalidArguments("query must be a string")
        }

        var limit = 10
        if let limitValue = arguments["limit"], case .int(let limitNum) = limitValue {
            limit = Int(limitNum)
        }

        let config = SecurityConfigStore.shared.getConfig().webOperations

        // Build DuckDuckGo instant answer API URL
        var components = URLComponents(string: "https://api.duckduckgo.com/")!
        components.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "format", value: "json"),
            URLQueryItem(name: "no_html", value: "1")
        ]

        guard let url = components.url else {
            throw MCPError.toolCallFailed("Invalid search URL")
        }

        // Create request with timeout
        var request = URLRequest(url: url)
        request.timeoutInterval = TimeInterval(config.timeout)

        // Execute request
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw MCPError.toolCallFailed("Invalid response")
        }

        guard httpResponse.statusCode == 200 else {
            throw MCPError.toolCallFailed("HTTP \(httpResponse.statusCode)")
        }

        // Check size limit
        if data.count > config.maxResponseSize {
            throw MCPError.toolCallFailed("Response too large: \(data.count) bytes")
        }

        // Parse JSON response
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw MCPError.toolCallFailed("Failed to parse response")
        }

        // Format results
        var results = "Search results for '\(query)':\n\n"

        if let abstract = json["Abstract"] as? String, !abstract.isEmpty {
            results += "Summary: \(abstract)\n"
            if let url = json["AbstractURL"] as? String {
                results += "Source: \(url)\n"
            }
            results += "\n"
        }

        if let relatedTopics = json["RelatedTopics"] as? [[String: Any]] {
            results += "Related topics:\n"
            let limitedTopics = Array(relatedTopics.prefix(limit))

            for (index, topic) in limitedTopics.enumerated() {
                if let text = topic["Text"] as? String {
                    results += "\(index + 1). \(text)\n"
                    if let url = topic["FirstURL"] as? String {
                        results += "   \(url)\n"
                    }
                }
            }
        }

        return Sandbox.truncateResult(results)
    }
}

// MARK: - Web Fetch Tool

struct WebFetchTool: ServerTool {
    let name = "web_fetch"
    let description = "Fetch content from a URL"
    let inputSchema: [String: Value] = [
        "type": .string("object"),
        "properties": .object([
            "url": .object([
                "type": .string("string"),
                "description": .string("URL to fetch")
            ])
        ]),
        "required": .array([.string("url")])
    ]

    @MainActor
    func execute(arguments: [String: Value]) async throws -> String {
        guard let urlValue = arguments["url"], case .string(let urlString) = urlValue else {
            throw MCPError.invalidArguments("url must be a string")
        }

        let config = SecurityConfigStore.shared.getConfig().webOperations

        // Validate URL
        guard let url = URL(string: urlString) else {
            throw MCPError.invalidArguments("Invalid URL")
        }

        // Enforce HTTPS if required
        if config.httpsOnly && url.scheme != "https" {
            throw MCPError.toolCallFailed("Only HTTPS URLs are allowed")
        }

        // Create request with timeout
        var request = URLRequest(url: url)
        request.timeoutInterval = TimeInterval(config.timeout)

        // Execute request
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw MCPError.toolCallFailed("Invalid response")
        }

        guard httpResponse.statusCode == 200 else {
            throw MCPError.toolCallFailed("HTTP \(httpResponse.statusCode)")
        }

        // Check size limit
        if data.count > config.maxResponseSize {
            throw MCPError.toolCallFailed("Response too large: \(data.count) bytes (max: \(config.maxResponseSize))")
        }

        // Try to decode as text
        guard let content = String(data: data, encoding: .utf8) else {
            throw MCPError.toolCallFailed("Response is not valid UTF-8 text")
        }

        // Basic HTML stripping (simple approach)
        var text = content
        if let contentType = httpResponse.mimeType, contentType.contains("html") {
            text = stripHTML(content)
        }

        return Sandbox.truncateResult("""
        URL: \(urlString)
        Status: \(httpResponse.statusCode)
        Content-Type: \(httpResponse.mimeType ?? "unknown")
        Size: \(data.count) bytes

        Content:
        \(text)
        """)
    }

    private func stripHTML(_ html: String) -> String {
        // Remove script and style tags with content
        var result = html
        result = result.replacingOccurrences(
            of: "<script[^>]*>[\\s\\S]*?</script>",
            with: "",
            options: .regularExpression
        )
        result = result.replacingOccurrences(
            of: "<style[^>]*>[\\s\\S]*?</style>",
            with: "",
            options: .regularExpression
        )

        // Remove all HTML tags
        result = result.replacingOccurrences(
            of: "<[^>]+>",
            with: "",
            options: .regularExpression
        )

        // Decode HTML entities (basic ones)
        result = result.replacingOccurrences(of: "&nbsp;", with: " ")
        result = result.replacingOccurrences(of: "&lt;", with: "<")
        result = result.replacingOccurrences(of: "&gt;", with: ">")
        result = result.replacingOccurrences(of: "&amp;", with: "&")
        result = result.replacingOccurrences(of: "&quot;", with: "\"")

        // Clean up whitespace
        result = result.replacingOccurrences(
            of: "\\s+",
            with: " ",
            options: .regularExpression
        )

        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
