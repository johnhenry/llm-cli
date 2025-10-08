import Foundation
import AVFoundation
import Speech

// Voice handler for speech-to-text and text-to-speech
final class VoiceHandler: NSObject, @unchecked Sendable {
    private let speechSynthesizer = AVSpeechSynthesizer()
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()

    private var recordingCompletion: ((String) -> Void)?

    override init() {
        super.init()

        // Initialize speech recognizer for US English
        self.speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    }

    // MARK: - Text to Speech

    func speak(_ text: String, rate: Float = AVSpeechUtteranceDefaultSpeechRate) async {
        return await withCheckedContinuation { continuation in
            let utterance = AVSpeechUtterance(string: text)
            utterance.rate = rate
            utterance.voice = AVSpeechSynthesisVoice(language: "en-US")

            // Create a delegate to know when speaking finishes
            let delegate = SpeechDelegate {
                continuation.resume()
            }

            speechSynthesizer.delegate = delegate
            speechSynthesizer.speak(utterance)

            // Keep delegate alive
            objc_setAssociatedObject(speechSynthesizer, "delegate", delegate, .OBJC_ASSOCIATION_RETAIN)
        }
    }

    func stopSpeaking() {
        speechSynthesizer.stopSpeaking(at: .immediate)
    }

    // MARK: - Speech to Text

    func requestSpeechRecognitionAuthorization() async -> Bool {
        // Check if speech recognizer is available first
        guard speechRecognizer != nil else {
            print("⚠️  Speech recognizer not available")
            return false
        }

        // Check current authorization status first
        let currentStatus = SFSpeechRecognizer.authorizationStatus()
        print("Current authorization status: \(currentStatus.rawValue)")

        // If already authorized, return true
        if currentStatus == .authorized {
            return true
        }

        // If already denied or restricted, return false
        if currentStatus == .denied || currentStatus == .restricted {
            print("⚠️  Speech recognition is \(currentStatus == .denied ? "denied" : "restricted")")
            printPermissionInstructions()
            return false
        }

        // Status is .notDetermined
        // CLI apps can't show the authorization dialog properly, so we need to guide the user
        print("\n⚠️  Speech recognition permissions not yet granted.")
        print("\n🔧 Please run the setup command first:")
        print("  llm setup-voice")
        print("\nThis will guide you through granting the necessary permissions.")
        print("\nAlternatively, use text-only mode:")
        print("  llm chat  (without --voice flag)")

        return false
    }

    private func printPermissionInstructions() {
        print("")
        print("To grant permissions manually:")
        print("  1. Open System Settings")
        print("  2. Go to Privacy & Security > Microphone")
        print("  3. Find and enable your terminal app (Terminal, iTerm2, etc.)")
        print("  4. Go to Privacy & Security > Speech Recognition")
        print("  5. Find and enable your terminal app")
        print("  6. Restart your terminal and try again")
    }

    func startRecording() async throws -> AsyncThrowingStream<String, Error> {
        // Check authorization
        guard await requestSpeechRecognitionAuthorization() else {
            throw VoiceError.authorizationDenied
        }

        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
            throw VoiceError.recognizerNotAvailable
        }

        // Cancel any ongoing recognition
        if let task = recognitionTask {
            task.cancel()
            recognitionTask = nil
        }

        // Note: Audio session configuration not needed on macOS
        // AVAudioSession is iOS-only

        // Create recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            throw VoiceError.unableToCreateRequest
        }

        recognitionRequest.shouldReportPartialResults = true

        // Get audio input
        let inputNode = audioEngine.inputNode

        return AsyncThrowingStream { continuation in
            // Create recognition task
            self.recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { result, error in
                if let result = result {
                    let transcription = result.bestTranscription.formattedString
                    continuation.yield(transcription)

                    // If result is final, finish
                    if result.isFinal {
                        continuation.finish()
                    }
                }

                if let error = error {
                    continuation.finish(throwing: error)
                }
            }

            // Configure audio format
            let recordingFormat = inputNode.outputFormat(forBus: 0)
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
                recognitionRequest.append(buffer)
            }

            // Start audio engine
            self.audioEngine.prepare()
            do {
                try self.audioEngine.start()
            } catch {
                continuation.finish(throwing: error)
            }
        }
    }

    func stopRecording() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
    }

    // MARK: - Convenience: Record until silence

    func recordUntilSilence(timeout: TimeInterval = 3.0) async throws -> String {
        var lastTranscription = ""
        var lastUpdateTime = Date()

        let stream = try await startRecording()

        for try await transcription in stream {
            lastTranscription = transcription
            lastUpdateTime = Date()

            // Check for silence timeout
            if Date().timeIntervalSince(lastUpdateTime) > timeout {
                break
            }
        }

        stopRecording()
        return lastTranscription
    }
}

// MARK: - Speech Delegate

private final class SpeechDelegate: NSObject, AVSpeechSynthesizerDelegate, @unchecked Sendable {
    let completion: @Sendable () -> Void

    init(completion: @escaping @Sendable () -> Void) {
        self.completion = completion
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        completion()
    }
}

// MARK: - Errors

enum VoiceError: Error, LocalizedError {
    case authorizationDenied
    case recognizerNotAvailable
    case unableToCreateRequest
    case audioEngineError

    var errorDescription: String? {
        switch self {
        case .authorizationDenied:
            return "Speech recognition authorization denied"
        case .recognizerNotAvailable:
            return "Speech recognizer not available"
        case .unableToCreateRequest:
            return "Unable to create speech recognition request"
        case .audioEngineError:
            return "Audio engine error"
        }
    }
}
