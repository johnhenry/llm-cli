import SwiftUI
import FoundationModels

struct ContentView: View {
    @StateObject private var chatViewModel = ChatViewModel()
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            // Sidebar with conversation list
            SidebarView(viewModel: chatViewModel)
                .frame(minWidth: 200)
                .navigationSplitViewColumnWidth(min: 200, ideal: 250, max: 350)
        } detail: {
            // Main chat view
            ChatView(viewModel: chatViewModel)
        }
        .navigationSplitViewStyle(.balanced)
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ExportConversation"))) { _ in
            chatViewModel.exportCurrentConversation()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("CopyLastResponse"))) { _ in
            chatViewModel.copyLastResponse()
        }
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Picker("Model", selection: $chatViewModel.selectedModelSize) {
                    ForEach(ModelSize.allCases) { size in
                        Text(size.rawValue).tag(size)
                    }
                }
                .pickerStyle(.menu)
                .help("Select model size")
            }

            ToolbarItem(placement: .automatic) {
                Button(action: {
                    chatViewModel.showTimestamps.toggle()
                }) {
                    Label("Toggle Timestamps", systemImage: chatViewModel.showTimestamps ? "clock.fill" : "clock")
                }
                .help("Show/hide message timestamps")
                .onHover { hovering in
                    if hovering {
                        NSCursor.pointingHand.push()
                    } else {
                        NSCursor.pop()
                    }
                }
            }

            ToolbarItem(placement: .primaryAction) {
                Button(action: {
                    print("DEBUG: New conversation button clicked")
                    chatViewModel.newConversation()
                }) {
                    Label("New Conversation", systemImage: "square.and.pencil")
                }
                .help("Start a new conversation")
                .onHover { hovering in
                    if hovering {
                        NSCursor.pointingHand.push()
                    } else {
                        NSCursor.pop()
                    }
                }
            }
        }
    }
}

struct SidebarView: View {
    @ObservedObject var viewModel: ChatViewModel
    @State private var searchText = ""

    var filteredConversations: [Conversation] {
        if searchText.isEmpty {
            return viewModel.conversations
        }
        return viewModel.conversations.filter { conversation in
            conversation.title.localizedCaseInsensitiveContains(searchText) ||
            conversation.messages.contains { message in
                message.content.localizedCaseInsensitiveContains(searchText)
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("Conversations")
                    .font(.headline)
                Spacer()
            }
            .padding(.horizontal)
            .padding(.top)

            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search conversations...", text: $searchText)
                    .textFieldStyle(.plain)
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .onHover { hovering in
                        if hovering {
                            NSCursor.pointingHand.push()
                        } else {
                            NSCursor.pop()
                        }
                    }
                }
            }
            .padding(8)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .padding(.horizontal)
            .padding(.vertical, 8)

            // Conversation list
            List(selection: $viewModel.selectedConversationId) {
                ForEach(filteredConversations) { conversation in
                    ConversationRow(
                        conversation: conversation,
                        isSelected: viewModel.selectedConversationId == conversation.id,
                        viewModel: viewModel
                    )
                    .tag(conversation.id)
                    .contextMenu {
                        Button(role: .destructive) {
                            if let index = viewModel.conversations.firstIndex(where: { $0.id == conversation.id }) {
                                viewModel.deleteConversations(at: IndexSet(integer: index))
                            }
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
                .onDelete { indexSet in
                    // Convert filtered indices to original indices
                    let idsToDelete = indexSet.map { filteredConversations[$0].id }
                    let originalIndices = IndexSet(idsToDelete.compactMap { id in
                        viewModel.conversations.firstIndex(where: { $0.id == id })
                    })
                    viewModel.deleteConversations(at: originalIndices)
                }
            }
            .listStyle(.sidebar)

            // Status indicator
            StatusIndicator()
                .padding()
        }
    }
}

struct ConversationRow: View {
    let conversation: Conversation
    let isSelected: Bool
    @ObservedObject var viewModel: ChatViewModel
    @State private var isEditing = false
    @State private var editedTitle = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if isEditing {
                TextField("Conversation title", text: $editedTitle)
                    .font(.body)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .textFieldStyle(.plain)
                    .focused($isFocused)
                    .onSubmit {
                        saveEdit()
                    }
                    .onAppear {
                        editedTitle = conversation.title
                        isFocused = true
                    }
            } else {
                Text(conversation.title)
                    .font(.body)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .lineLimit(1)
                    .allowsHitTesting(false) // Don't intercept clicks
            }

            if let preview = conversation.messages.first?.content.prefix(50) {
                Text(preview)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .allowsHitTesting(false) // Don't intercept clicks
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            // Double-tap anywhere on row to edit
            if !isEditing {
                isEditing = true
            }
        }
        .onHover { hovering in
            if hovering {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
    }

    func saveEdit() {
        if !editedTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            viewModel.renameConversation(id: conversation.id, newTitle: editedTitle)
        }
        isEditing = false
    }
}

struct StatusIndicator: View {
    @State private var modelStatus: SystemLanguageModel.Availability = .unavailable(.deviceNotEligible)

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)

            Text(statusText)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .onAppear {
            checkStatus()
        }
    }

    private var statusColor: Color {
        switch modelStatus {
        case .available:
            return .green
        case .unavailable:
            return .red
        }
    }

    private var statusText: String {
        switch modelStatus {
        case .available:
            return "Model ready"
        case .unavailable(let reason):
            switch reason {
            case .deviceNotEligible:
                return "Device not eligible"
            case .appleIntelligenceNotEnabled:
                return "Apple Intelligence disabled"
            case .modelNotReady:
                return "Model not ready"
            @unknown default:
                return "Model unavailable"
            }
        }
    }

    private func checkStatus() {
        modelStatus = SystemLanguageModel.default.availability
    }
}
