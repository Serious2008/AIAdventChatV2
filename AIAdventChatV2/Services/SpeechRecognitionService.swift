//
//  SpeechRecognitionService.swift
//  AIAdventChatV2
//
//  Service for speech-to-text recognition using Apple Speech Framework
//

import Foundation
import Speech
import AVFoundation

// MARK: - Errors

enum SpeechRecognitionError: Error, LocalizedError {
    case notAuthorized
    case recognizerUnavailable
    case audioEngineError
    case recognitionFailed(String)

    var errorDescription: String? {
        switch self {
        case .notAuthorized:
            return "Нет разрешения на использование микрофона или распознавания речи"
        case .recognizerUnavailable:
            return "Распознавание речи недоступно для выбранного языка"
        case .audioEngineError:
            return "Ошибка аудио движка"
        case .recognitionFailed(let message):
            return "Ошибка распознавания: \(message)"
        }
    }
}

// MARK: - Speech Recognition Service

class SpeechRecognitionService: ObservableObject {

    // MARK: - Published Properties

    @Published var isRecording: Bool = false
    @Published var recognizedText: String = ""
    @Published var error: String?
    @Published var isAuthorized: Bool = false

    // MARK: - Private Properties

    private let speechRecognizer: SFSpeechRecognizer?
    private let audioEngine = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?

    // MARK: - Init

    init(locale: Locale = Locale(identifier: "ru-RU")) {
        speechRecognizer = SFSpeechRecognizer(locale: locale)

        // Check initial authorization
        Task {
            await checkAuthorization()
        }
    }

    // MARK: - Authorization

    /// Check current authorization status
    private func checkAuthorization() async {
        let speechStatus = SFSpeechRecognizer.authorizationStatus()

        await MainActor.run {
            self.isAuthorized = (speechStatus == .authorized)
        }
    }

    /// Request authorization for speech recognition and microphone
    func requestAuthorization() async -> Bool {
        print("🎤 Requesting speech recognition authorization...")

        // Request Speech Recognition authorization
        let speechAuth = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }

        guard speechAuth else {
            print("❌ Speech recognition not authorized")
            await MainActor.run {
                self.error = "Нет разрешения на распознавание речи"
                self.isAuthorized = false
            }
            return false
        }

        // Request Microphone authorization (macOS doesn't require explicit permission)
        #if os(iOS)
        let micAuth = await AVAudioSession.sharedInstance().requestRecordPermission()
        guard micAuth else {
            print("❌ Microphone not authorized")
            await MainActor.run {
                self.error = "Нет разрешения на использование микрофона"
                self.isAuthorized = false
            }
            return false
        }
        #else
        // On macOS, microphone permission is handled by the system automatically
        let micAuth = true
        #endif

        guard micAuth else {
            print("❌ Microphone not authorized")
            await MainActor.run {
                self.error = "Нет разрешения на использование микрофона"
                self.isAuthorized = false
            }
            return false
        }

        print("✅ Authorization granted")
        await MainActor.run {
            self.isAuthorized = true
            self.error = nil
        }

        return true
    }

    // MARK: - Recording Control

    /// Start recording and speech recognition
    func startRecording() throws {
        print("🎤 Starting recording...")

        // Check if recognizer is available
        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
            print("❌ Speech recognizer unavailable")
            throw SpeechRecognitionError.recognizerUnavailable
        }

        // Cancel any ongoing task
        if recognitionTask != nil {
            recognitionTask?.cancel()
            recognitionTask = nil
        }

        // Configure audio session (iOS only)
        #if os(iOS)
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        #endif
        // Note: On macOS, audio engine handles permissions automatically

        // Create recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()

        guard let recognitionRequest = recognitionRequest else {
            print("❌ Unable to create recognition request")
            throw SpeechRecognitionError.audioEngineError
        }

        recognitionRequest.shouldReportPartialResults = true

        // If using on-device recognition (iOS 13+, macOS 10.15+)
        if #available(macOS 10.15, *) {
            recognitionRequest.requiresOnDeviceRecognition = false // Allow server-based for better accuracy
        }

        // Get input node
        let inputNode = audioEngine.inputNode

        // Start recognition task
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }

            var isFinal = false

            if let result = result {
                // Update recognized text
                let transcription = result.bestTranscription.formattedString

                Task { @MainActor in
                    self.recognizedText = transcription
                    print("📝 Recognized: \(transcription)")
                }

                isFinal = result.isFinal
            }

            if error != nil || isFinal {
                // Stop audio engine
                self.audioEngine.stop()
                inputNode.removeTap(onBus: 0)

                self.recognitionRequest = nil
                self.recognitionTask = nil

                Task { @MainActor in
                    self.isRecording = false

                    if let error = error {
                        print("❌ Recognition error: \(error.localizedDescription)")
                        self.error = error.localizedDescription
                    } else {
                        print("✅ Recognition completed")
                    }
                }
            }
        }

        // Configure audio format
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            self.recognitionRequest?.append(buffer)
        }

        // Start audio engine
        audioEngine.prepare()
        try audioEngine.start()

        // Update state
        Task { @MainActor in
            self.isRecording = true
            self.recognizedText = ""
            self.error = nil
        }

        print("✅ Recording started")
    }

    /// Stop recording and finalize recognition
    func stopRecording() {
        print("⏹ Stopping recording...")

        // Stop audio engine
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }

        // End recognition request
        recognitionRequest?.endAudio()

        // Deactivate audio session (iOS only)
        #if os(iOS)
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        #endif

        // Update state
        Task { @MainActor in
            self.isRecording = false
        }

        print("✅ Recording stopped")
    }

    /// Cancel recording without sending
    func cancelRecording() {
        print("❌ Cancelling recording...")

        // Cancel recognition task
        recognitionTask?.cancel()
        recognitionTask = nil

        // Stop recording
        stopRecording()

        // Clear recognized text
        Task { @MainActor in
            self.recognizedText = ""
        }
    }

    // MARK: - Language Support

    /// Get available languages for speech recognition
    static func availableLanguages() -> [Locale] {
        return SFSpeechRecognizer.supportedLocales().sorted { locale1, locale2 in
            let name1 = locale1.localizedString(forIdentifier: locale1.identifier) ?? locale1.identifier
            let name2 = locale2.localizedString(forIdentifier: locale2.identifier) ?? locale2.identifier
            return name1 < name2
        }
    }

    /// Change recognition language
    func changeLanguage(to locale: Locale) {
        // This requires reinitializing the service
        // For now, just log
        print("🌍 Language change requested to: \(locale.identifier)")
        print("⚠️ Language change requires app restart")
    }
}
