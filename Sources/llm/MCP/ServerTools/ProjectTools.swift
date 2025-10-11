import Foundation
import MCP

// MARK: - Todo Model

struct Todo: Codable, Identifiable {
    let id: String
    var title: String
    var description: String?
    var status: TodoStatus
    var priority: TodoPriority
    var createdAt: Date
    var updatedAt: Date
    var tags: [String]

    enum TodoStatus: String, Codable {
        case pending
        case inProgress = "in_progress"
        case completed
        case cancelled
    }

    enum TodoPriority: String, Codable {
        case low
        case medium
        case high
    }

    init(title: String, description: String? = nil, status: TodoStatus = .pending, priority: TodoPriority = .medium, tags: [String] = []) {
        self.id = UUID().uuidString
        self.title = title
        self.description = description
        self.status = status
        self.priority = priority
        self.createdAt = Date()
        self.updatedAt = Date()
        self.tags = tags
    }
}

// MARK: - Todo Store

@MainActor
final class TodoStore {
    static let shared = TodoStore()
    private let fileURL: URL
    private var todos: [Todo] = []

    private init() {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        let dataDir = homeDir.appendingPathComponent(".config/llm-cli")
        try? FileManager.default.createDirectory(at: dataDir, withIntermediateDirectories: true)

        self.fileURL = dataDir.appendingPathComponent("todos.json")
        self.load()
    }

    func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            todos = []
            return
        }

        do {
            let data = try Data(contentsOf: fileURL)
            todos = try JSONDecoder().decode([Todo].self, from: data)
        } catch {
            print("Warning: Could not load todos, starting fresh")
            todos = []
        }
    }

    func save() throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(todos)
        try data.write(to: fileURL)
    }

    func create(_ todo: Todo) throws {
        todos.append(todo)
        try save()
    }

    func list(status: Todo.TodoStatus? = nil, tag: String? = nil) -> [Todo] {
        var filtered = todos

        if let status = status {
            filtered = filtered.filter { $0.status == status }
        }

        if let tag = tag {
            filtered = filtered.filter { $0.tags.contains(tag) }
        }

        return filtered.sorted { $0.createdAt > $1.createdAt }
    }

    func get(id: String) -> Todo? {
        return todos.first { $0.id == id }
    }

    func update(id: String, modifier: (inout Todo) throws -> Void) throws {
        guard let index = todos.firstIndex(where: { $0.id == id }) else {
            throw MCPError.toolCallFailed("Todo not found: \(id)")
        }

        try modifier(&todos[index])
        todos[index].updatedAt = Date()
        try save()
    }

    func delete(id: String) throws {
        guard let index = todos.firstIndex(where: { $0.id == id }) else {
            throw MCPError.toolCallFailed("Todo not found: \(id)")
        }

        todos.remove(at: index)
        try save()
    }
}

// MARK: - Create Todo Tool

struct CreateTodoTool: ServerTool {
    let name = "create_todo"
    let description = "Create a new todo item"
    let inputSchema: [String: Value] = [
        "type": .string("object"),
        "properties": .object([
            "title": .object([
                "type": .string("string"),
                "description": .string("Todo title")
            ]),
            "description": .object([
                "type": .string("string"),
                "description": .string("Optional detailed description")
            ]),
            "priority": .object([
                "type": .string("string"),
                "description": .string("Priority: low, medium, or high (default: medium)")
            ]),
            "tags": .object([
                "type": .string("array"),
                "description": .string("Optional tags for organization"),
                "items": .object([
                    "type": .string("string")
                ])
            ])
        ]),
        "required": .array([.string("title")])
    ]

    @MainActor
    func execute(arguments: [String: Value]) async throws -> String {
        guard let titleValue = arguments["title"], case .string(let title) = titleValue else {
            throw MCPError.invalidArguments("title must be a string")
        }

        var description: String?
        if let descValue = arguments["description"], case .string(let desc) = descValue {
            description = desc
        }

        var priority = Todo.TodoPriority.medium
        if let priorityValue = arguments["priority"], case .string(let priorityStr) = priorityValue {
            switch priorityStr.lowercased() {
            case "low":
                priority = .low
            case "high":
                priority = .high
            default:
                priority = .medium
            }
        }

        var tags: [String] = []
        if let tagsValue = arguments["tags"], case .array(let tagsArray) = tagsValue {
            tags = tagsArray.compactMap { value in
                if case .string(let tag) = value {
                    return tag
                }
                return nil
            }
        }

        let todo = Todo(title: title, description: description, priority: priority, tags: tags)
        try TodoStore.shared.create(todo)

        return """
        ✅ Created todo:
        ID: \(todo.id)
        Title: \(todo.title)
        Priority: \(todo.priority.rawValue)
        Status: \(todo.status.rawValue)
        Tags: \(tags.isEmpty ? "none" : tags.joined(separator: ", "))
        """
    }
}

// MARK: - List Todos Tool

struct ListTodosTool: ServerTool {
    let name = "list_todos"
    let description = "List todos with optional filtering"
    let inputSchema: [String: Value] = [
        "type": .string("object"),
        "properties": .object([
            "status": .object([
                "type": .string("string"),
                "description": .string("Filter by status: pending, in_progress, completed, cancelled")
            ]),
            "tag": .object([
                "type": .string("string"),
                "description": .string("Filter by tag")
            ])
        ])
    ]

    @MainActor
    func execute(arguments: [String: Value]) async throws -> String {
        var status: Todo.TodoStatus?
        if let statusValue = arguments["status"], case .string(let statusStr) = statusValue {
            switch statusStr.lowercased() {
            case "pending":
                status = .pending
            case "in_progress":
                status = .inProgress
            case "completed":
                status = .completed
            case "cancelled":
                status = .cancelled
            default:
                throw MCPError.invalidArguments("Invalid status: \(statusStr)")
            }
        }

        var tag: String?
        if let tagValue = arguments["tag"], case .string(let tagStr) = tagValue {
            tag = tagStr
        }

        let todos = TodoStore.shared.list(status: status, tag: tag)

        if todos.isEmpty {
            return "No todos found"
        }

        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short

        var result = "Found \(todos.count) todo(s):\n\n"

        for (index, todo) in todos.enumerated() {
            result += "[\(index + 1)] \(todo.title)\n"
            result += "    ID: \(todo.id)\n"
            result += "    Status: \(todo.status.rawValue)\n"
            result += "    Priority: \(todo.priority.rawValue)\n"
            if let description = todo.description {
                result += "    Description: \(description)\n"
            }
            if !todo.tags.isEmpty {
                result += "    Tags: \(todo.tags.joined(separator: ", "))\n"
            }
            result += "    Created: \(formatter.string(from: todo.createdAt))\n"
            result += "\n"
        }

        return result
    }
}

// MARK: - Update Todo Tool

struct UpdateTodoTool: ServerTool {
    let name = "update_todo"
    let description = "Update a todo item"
    let inputSchema: [String: Value] = [
        "type": .string("object"),
        "properties": .object([
            "id": .object([
                "type": .string("string"),
                "description": .string("Todo ID")
            ]),
            "title": .object([
                "type": .string("string"),
                "description": .string("New title")
            ]),
            "description": .object([
                "type": .string("string"),
                "description": .string("New description")
            ]),
            "status": .object([
                "type": .string("string"),
                "description": .string("New status: pending, in_progress, completed, cancelled")
            ]),
            "priority": .object([
                "type": .string("string"),
                "description": .string("New priority: low, medium, high")
            ]),
            "tags": .object([
                "type": .string("array"),
                "description": .string("New tags (replaces existing)"),
                "items": .object([
                    "type": .string("string")
                ])
            ])
        ]),
        "required": .array([.string("id")])
    ]

    @MainActor
    func execute(arguments: [String: Value]) async throws -> String {
        guard let idValue = arguments["id"], case .string(let id) = idValue else {
            throw MCPError.invalidArguments("id must be a string")
        }

        var updates: [String] = []

        try TodoStore.shared.update(id: id) { todo in
            if let titleValue = arguments["title"], case .string(let title) = titleValue {
                todo.title = title
                updates.append("title")
            }

            if let descValue = arguments["description"], case .string(let description) = descValue {
                todo.description = description
                updates.append("description")
            }

            if let statusValue = arguments["status"], case .string(let statusStr) = statusValue {
                switch statusStr.lowercased() {
                case "pending":
                    todo.status = .pending
                case "in_progress":
                    todo.status = .inProgress
                case "completed":
                    todo.status = .completed
                case "cancelled":
                    todo.status = .cancelled
                default:
                    throw MCPError.invalidArguments("Invalid status: \(statusStr)")
                }
                updates.append("status")
            }

            if let priorityValue = arguments["priority"], case .string(let priorityStr) = priorityValue {
                switch priorityStr.lowercased() {
                case "low":
                    todo.priority = .low
                case "medium":
                    todo.priority = .medium
                case "high":
                    todo.priority = .high
                default:
                    throw MCPError.invalidArguments("Invalid priority: \(priorityStr)")
                }
                updates.append("priority")
            }

            if let tagsValue = arguments["tags"], case .array(let tagsArray) = tagsValue {
                todo.tags = tagsArray.compactMap { value in
                    if case .string(let tag) = value {
                        return tag
                    }
                    return nil
                }
                updates.append("tags")
            }
        }

        return """
        ✅ Updated todo \(id)
        Updated fields: \(updates.joined(separator: ", "))
        """
    }
}

// MARK: - Delete Todo Tool

struct DeleteTodoTool: ServerTool {
    let name = "delete_todo"
    let description = "Delete a todo item"
    let inputSchema: [String: Value] = [
        "type": .string("object"),
        "properties": .object([
            "id": .object([
                "type": .string("string"),
                "description": .string("Todo ID to delete")
            ])
        ]),
        "required": .array([.string("id")])
    ]

    @MainActor
    func execute(arguments: [String: Value]) async throws -> String {
        guard let idValue = arguments["id"], case .string(let id) = idValue else {
            throw MCPError.invalidArguments("id must be a string")
        }

        try TodoStore.shared.delete(id: id)

        return "✅ Deleted todo \(id)"
    }
}
