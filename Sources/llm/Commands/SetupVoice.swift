import Foundation
import AppKit
import Speech
import AVFoundation

struct SetupVoiceCommand {
    static func run(args: [String]) async {
        print("""
        🎤 Voice Setup Helper

        This will trigger permission dialogs for microphone and speech recognition.

        Since this is a CLI app, we need to do this in two steps:

        Step 1: Test microphone access (this will trigger the permission dialog)
        Step 2: Request speech recognition authorization

        Press Enter to continue...
        """)

        _ = readLine()

        print("\n📍 Step 1: Testing microphone access...")
        print("You should see a permission dialog pop up.\n")

        // Try to access the microphone - this will trigger the permission dialog
        do {
            let audioEngine = AVAudioEngine()
            let inputNode = audioEngine.inputNode

            print("Setting up audio input...")
            let recordingFormat = inputNode.outputFormat(forBus: 0)

            inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, time in
                // Just testing - we don't need to do anything with the buffer
            }

            audioEngine.prepare()
            try audioEngine.start()

            print("✅ Microphone access granted!")
            print("Recording for 2 seconds to test...")

            // Record for 2 seconds
            try await Task.sleep(nanoseconds: 2_000_000_000)

            audioEngine.stop()
            inputNode.removeTap(onBus: 0)

            print("✅ Microphone test complete!\n")

        } catch {
            print("❌ Microphone access failed: \(error.localizedDescription)")
            print("\nPlease grant microphone permission when prompted.")
            print("If you didn't see a dialog, check System Settings > Privacy & Security > Microphone\n")
            return
        }

        print("📍 Step 2: Requesting speech recognition authorization...")
        print("This may trigger a permission dialog, or you may need to grant it manually.\n")

        // Try to request speech recognition - this might crash on CLI apps
        do {
            // First check current status
            let currentStatus = SFSpeechRecognizer.authorizationStatus()
            print("Current speech recognition status: \(statusString(currentStatus))")

            if currentStatus == .authorized {
                print("✅ Speech recognition already authorized!")
                print("\n🎉 Voice setup complete! You can now use voice features:")
                print("  llm chat --voice")
                print("  llm voice")
                return
            }

            if currentStatus == .denied || currentStatus == .restricted {
                print("\n⚠️  Speech recognition is \(currentStatus == .denied ? "denied" : "restricted")")
                printManualSteps()
                return
            }

            // Try to request - this might fail/crash on CLI
            print("\nAttempting to request authorization...")
            print("(This may not work for CLI apps)\n")

            // Use a Task with timeout to avoid hanging
            let result = try await withThrowingTaskGroup(of: Bool.self) { group in
                group.addTask {
                    await withCheckedContinuation { continuation in
                        SFSpeechRecognizer.requestAuthorization { status in
                            continuation.resume(returning: status == .authorized)
                        }
                    }
                }

                // Add timeout
                group.addTask {
                    try await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
                    return false
                }

                // Return first result
                if let authorized = try await group.next() {
                    group.cancelAll()
                    return authorized
                }
                return false
            }

            if result {
                print("✅ Speech recognition authorized!")
                print("\n🎉 Voice setup complete! You can now use voice features:")
                print("  llm chat --voice")
                print("  llm voice")
            } else {
                print("⏱️  Request timed out or permission not granted")
                printManualSteps()
            }

        } catch {
            print("\n⚠️  Automatic authorization request failed (expected for CLI apps)")
            printManualSteps()
        }
    }

    static func printManualSteps() {
        print("\n📋 Speech recognition permissions cannot be requested from CLI apps.")
        print("\n✨ Solution: Use the Permission Helper GUI app")
        print("\n1. Build and run the helper app:")
        print("   ./build-permission-helper.sh")
        print("\n2. In the helper app, click both buttons:")
        print("   - Grant Microphone Access")
        print("   - Grant Speech Recognition")
        print("\n3. Close the helper app")
        print("\n4. Now you can use voice features:")
        print("   llm chat --voice")
        print("   llm voice")
        print("\nThe helper app is a simple GUI that can properly request permissions,")
        print("making them available to your CLI tool in the terminal.")
    }

    static func statusString(_ status: SFSpeechRecognizerAuthorizationStatus) -> String {
        switch status {
        case .notDetermined:
            return "Not Determined (0)"
        case .denied:
            return "Denied (1)"
        case .restricted:
            return "Restricted (2)"
        case .authorized:
            return "Authorized (3)"
        @unknown default:
            return "Unknown (\(status.rawValue))"
        }
    }

    static func printUsage() {
        print("""
        Usage: llm setup-voice

        Interactive helper to grant microphone and speech recognition permissions.

        This will:
        1. Trigger the microphone permission dialog
        2. Request speech recognition authorization
        3. Test that both are working

        Example:
          llm setup-voice
        """)
    }
}
