import SwiftUI
import FoundationModels
import MarkdownUI

struct ChatView: View {
    @ObservedObject var viewModel: ChatViewModel
    @State private var inputText = ""
    @FocusState private var isInputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 16) {
                        if viewModel.currentMessages.isEmpty {
                            // Empty state
                            VStack(spacing: 16) {
                                Image(systemName: "brain.head.profile")
                                    .font(.system(size: 60))
                                    .foregroundStyle(.secondary)

                                Text("Start a conversation")
                                    .font(.title2)
                                    .foregroundStyle(.secondary)

                                Text("Type your message below to begin")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .padding()
                        } else {
                            ForEach(Array(viewModel.currentMessages.enumerated()), id: \.element.id) { index, message in
                                MessageBubble(
                                    message: message,
                                    messageIndex: index,
                                    viewModel: viewModel
                                )
                                .id(message.id)
                            }

                            if viewModel.isGenerating {
                                TypingIndicator()
                            }
                        }
                    }
                    .padding()
                }
                .onChange(of: viewModel.currentMessages.count) { _, _ in
                    if let lastMessage = viewModel.currentMessages.last {
                        withAnimation {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
            }

            Divider()

            // Input area
            HStack(alignment: .bottom, spacing: 12) {
                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.ultraThinMaterial)

                    TextField("Ask anything...", text: $inputText, axis: .vertical)
                        .textFieldStyle(.plain)
                        .focused($isInputFocused)
                        .lineLimit(1...6)
                        .padding(8)
                        .onSubmit {
                            sendMessage()
                        }
                }
                .fixedSize(horizontal: false, vertical: true)

                Button(action: sendMessage) {
                    Image(systemName: inputText.isEmpty ? "arrow.up.circle" : "arrow.up.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(inputText.isEmpty ? Color.secondary : Color.blue)
                        .symbolEffect(.bounce, value: !inputText.isEmpty)
                }
                .buttonStyle(.plain)
                .disabled(inputText.isEmpty || viewModel.isGenerating)
                .opacity((inputText.isEmpty || viewModel.isGenerating) ? 0.5 : 1.0)
                .onHover { hovering in
                    if hovering && !inputText.isEmpty && !viewModel.isGenerating {
                        NSCursor.pointingHand.push()
                    } else {
                        NSCursor.pop()
                    }
                }
            }
            .padding(12)
            .background(.regularMaterial)
        }
        .onAppear {
            isInputFocused = true
        }
    }

    private func sendMessage() {
        print("DEBUG: sendMessage called")
        guard !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            print("DEBUG: Input text is empty, returning")
            return
        }

        let message = inputText
        print("DEBUG: Sending message: \(message)")
        inputText = ""

        Task {
            print("DEBUG: Calling viewModel.sendMessage")
            await viewModel.sendMessage(message)
            print("DEBUG: viewModel.sendMessage completed")
        }
    }
}

struct MessageBubble: View {
    let message: ChatMessage
    let messageIndex: Int
    @ObservedObject var viewModel: ChatViewModel

    @ViewBuilder
    var messageContent: some View {
        // Use MarkdownUI for proper markdown rendering with transparent background
        Markdown(message.content)
            .markdownTheme(.gitHub)
            .markdownTextStyle {
                if message.role == .user {
                    ForegroundColor(.white)
                } else {
                    ForegroundColor(.primary)
                }
            }
            .markdownBlockStyle(\.codeBlock) { configuration in
                configuration.label
                    .padding()
                    .background(Color.clear)
            }
            .textSelection(.enabled)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if message.role == .user {
                Spacer()
            }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                messageContent
                    .padding(12)
                    .background(backgroundColor)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .contextMenu {
                        Button(action: copyMessage) {
                            Label("Copy Message", systemImage: "doc.on.doc")
                        }
                        Button(action: {
                            viewModel.forkConversation(from: messageIndex)
                        }) {
                            Label("Fork from Here", systemImage: "arrow.triangle.branch")
                        }
                    }

                // Mini toolbar with copy button and timestamp
                if viewModel.showTimestamps {
                    HStack(spacing: 8) {
                        Button(action: copyMessage) {
                            Image(systemName: "doc.on.doc")
                                .font(.caption2)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                        .help("Copy message")
                        .onHover { hovering in
                            if hovering {
                                NSCursor.pointingHand.push()
                            } else {
                                NSCursor.pop()
                            }
                        }

                        Text(message.timestamp, style: .time)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 4)
                }
            }

            if message.role == .assistant {
                Spacer()
            }
        }
    }

    func copyMessage() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(message.content, forType: .string)
    }

    private var backgroundColor: some ShapeStyle {
        message.role == .user ? AnyShapeStyle(Color.blue) : AnyShapeStyle(.thickMaterial)
    }
}

struct TypingIndicator: View {
    @State private var dotCount = 0
    let timer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack {
            HStack(spacing: 4) {
                ForEach(0..<3) { index in
                    Circle()
                        .fill(.secondary)
                        .frame(width: 8, height: 8)
                        .opacity(index < dotCount ? 1.0 : 0.3)
                }
            }
            .padding(12)
            .background(Color(.controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 16))

            Spacer()
        }
        .onReceive(timer) { _ in
            dotCount = (dotCount + 1) % 4
        }
    }
}
