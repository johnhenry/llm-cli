import SwiftUI
import AppKit

@main
struct LLMApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    init() {
        // Ensure app properly activates as a foreground application
        NSApplication.shared.setActivationPolicy(.regular)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 800, minHeight: 600)
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) {}

            CommandGroup(after: .textEditing) {
                Button("Copy Last Response") {
                    NotificationCenter.default.post(name: NSNotification.Name("CopyLastResponse"), object: nil)
                }
                .keyboardShortcut("c", modifiers: [.command, .shift])

                Divider()

                Button("Export Conversation...") {
                    NotificationCenter.default.post(name: NSNotification.Name("ExportConversation"), object: nil)
                }
                .keyboardShortcut("e", modifiers: [.command, .shift])
            }
        }

        Settings {
            SettingsView()
        }
    }
}
