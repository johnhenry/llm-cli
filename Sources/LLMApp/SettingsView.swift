import SwiftUI
import FoundationModels

struct SettingsView: View {
    @AppStorage("modelSize") private var modelSize = "medium"
    @AppStorage("temperature") private var temperature = 0.7
    @AppStorage("systemPrompt") private var systemPrompt = "You are a helpful AI assistant."

    @State private var modelStatus: SystemLanguageModel.Availability = .unavailable(.deviceNotEligible)

    var body: some View {
        TabView {
            // General Settings
            Form {
                Section("Model") {
                    Picker("Size", selection: $modelSize) {
                        Text("Small").tag("small")
                        Text("Medium").tag("medium")
                        Text("Large").tag("large")
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Temperature")
                            Spacer()
                            Text(String(format: "%.1f", temperature))
                                .foregroundStyle(.secondary)
                        }

                        Slider(value: $temperature, in: 0...2, step: 0.1)

                        Text("Controls randomness: lower is more focused, higher is more creative")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("System Prompt") {
                    TextEditor(text: $systemPrompt)
                        .frame(minHeight: 100)
                        .font(.body)
                }
            }
            .formStyle(.grouped)
            .tabItem {
                Label("General", systemImage: "gearshape")
            }

            // Status Tab
            Form {
                Section("Foundation Models Status") {
                    HStack {
                        Text("Status")
                        Spacer()
                        HStack(spacing: 8) {
                            Circle()
                                .fill(statusColor)
                                .frame(width: 8, height: 8)
                            Text(statusText)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if case .unavailable(let reason) = modelStatus {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(statusDescription(for: reason))
                                .font(.body)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section("About") {
                    LabeledContent("Version", value: "1.0")
                    LabeledContent("Platform", value: "macOS 26+")
                    Link("Documentation", destination: URL(string: "https://developer.apple.com/documentation/FoundationModels")!)
                }
            }
            .formStyle(.grouped)
            .tabItem {
                Label("Status", systemImage: "info.circle")
            }
            .onAppear {
                checkStatus()
            }
        }
        .frame(width: 500, height: 400)
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
            return "Available"
        case .unavailable:
            return "Unavailable"
        }
    }

    private func statusDescription(for reason: SystemLanguageModel.Availability.UnavailableReason) -> String {
        switch reason {
        case .deviceNotEligible:
            return "This device is not eligible for Foundation Models. Requires macOS 26+ and Apple Silicon."
        case .appleIntelligenceNotEnabled:
            return "Apple Intelligence is not enabled. Please enable it in System Settings."
        case .modelNotReady:
            return "The model is not ready yet. Please wait a few moments and try again."
        @unknown default:
            return "The model is currently unavailable."
        }
    }

    private func checkStatus() {
        modelStatus = SystemLanguageModel.default.availability
    }
}
