import Cocoa
import Speech
import AVFoundation

class PermissionHelperApp: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    var statusLabel: NSTextField!

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Create window
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 300),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.title = "LLM CLI - Voice Permission Setup"

        // Create UI
        let contentView = NSView(frame: window.contentView!.bounds)
        window.contentView = contentView

        // Title
        let title = NSTextField(labelWithString: "🎤 Voice Permission Setup")
        title.font = NSFont.systemFont(ofSize: 20, weight: .bold)
        title.frame = NSRect(x: 50, y: 220, width: 400, height: 30)
        contentView.addSubview(title)

        // Instructions
        let instructions = NSTextField(labelWithString: """
        This helper will request microphone and speech recognition permissions.

        Click the buttons below and allow permissions when prompted.
        """)
        instructions.font = NSFont.systemFont(ofSize: 13)
        instructions.frame = NSRect(x: 50, y: 150, width: 400, height: 60)
        instructions.alignment = .center
        contentView.addSubview(instructions)

        // Status label
        statusLabel = NSTextField(labelWithString: "Ready to setup permissions")
        statusLabel.frame = NSRect(x: 50, y: 120, width: 400, height: 20)
        statusLabel.alignment = .center
        statusLabel.textColor = .secondaryLabelColor
        contentView.addSubview(statusLabel)

        // Microphone button
        let micButton = NSButton(frame: NSRect(x: 150, y: 80, width: 200, height: 30))
        micButton.title = "Grant Microphone Access"
        micButton.bezelStyle = .rounded
        micButton.target = self
        micButton.action = #selector(requestMicrophoneAccess)
        contentView.addSubview(micButton)

        // Speech button
        let speechButton = NSButton(frame: NSRect(x: 150, y: 40, width: 200, height: 30))
        speechButton.title = "Grant Speech Recognition"
        speechButton.bezelStyle = .rounded
        speechButton.target = self
        speechButton.action = #selector(requestSpeechAccess)
        contentView.addSubview(speechButton)

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc func requestMicrophoneAccess() {
        statusLabel.stringValue = "Requesting microphone access..."

        let audioEngine = AVAudioEngine()
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, time in
            // Just testing
        }

        do {
            audioEngine.prepare()
            try audioEngine.start()

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                audioEngine.stop()
                inputNode.removeTap(onBus: 0)
                self.statusLabel.stringValue = "✅ Microphone access granted!"
                self.statusLabel.textColor = .systemGreen
            }
        } catch {
            statusLabel.stringValue = "❌ Microphone access failed"
            statusLabel.textColor = .systemRed
        }
    }

    @objc func requestSpeechAccess() {
        statusLabel.stringValue = "Requesting speech recognition..."

        SFSpeechRecognizer.requestAuthorization { status in
            DispatchQueue.main.async {
                switch status {
                case .authorized:
                    self.statusLabel.stringValue = "✅ Speech recognition granted! You can close this window."
                    self.statusLabel.textColor = .systemGreen

                    // Show success dialog
                    let alert = NSAlert()
                    alert.messageText = "Success!"
                    alert.informativeText = """
                    Both permissions are now granted.

                    You can now use voice features in the terminal:
                      llm chat --voice
                      llm voice
                    """
                    alert.alertStyle = .informational
                    alert.addButton(withTitle: "OK")
                    alert.runModal()

                case .denied:
                    self.statusLabel.stringValue = "❌ Speech recognition denied"
                    self.statusLabel.textColor = .systemRed
                case .restricted:
                    self.statusLabel.stringValue = "❌ Speech recognition restricted"
                    self.statusLabel.textColor = .systemRed
                case .notDetermined:
                    self.statusLabel.stringValue = "⚠️ Permission not determined"
                    self.statusLabel.textColor = .systemOrange
                @unknown default:
                    self.statusLabel.stringValue = "❌ Unknown status"
                    self.statusLabel.textColor = .systemRed
                }
            }
        }
    }
}

// Main entry point
let app = NSApplication.shared
let delegate = PermissionHelperApp()
app.delegate = delegate
app.run()
