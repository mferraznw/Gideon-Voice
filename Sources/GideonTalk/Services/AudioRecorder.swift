import Foundation
import AVFoundation
import SwiftUI

@MainActor
final class AudioRecorder: ObservableObject {
    static let shared = AudioRecorder()

    @Published var micLevels: [CGFloat] = Array(repeating: 0.08, count: 7)
    @Published var isRecording = false

    var onSilenceDetected: (() -> Void)?

    private var audioEngine: AVAudioEngine?
    private var audioFile: AVAudioFile?
    private var recordingURL: URL?
    private var silenceStart: Date?
    private var hasAutoStopped = false

    private let silenceThresholdDB: Float = -40
    
    private init() {}

    func startRecording() {
        guard !isRecording else { return }

        silenceStart = nil
        hasAutoStopped = false
        micLevels = Array(repeating: 0.08, count: 7)

        audioEngine = AVAudioEngine()
        guard let engine = audioEngine else { return }

        let inputNode = engine.inputNode
        let format = inputNode.inputFormat(forBus: 0)

        // Create temp file
        let tempDir = FileManager.default.temporaryDirectory
        recordingURL = tempDir.appendingPathComponent("recording_\(UUID().uuidString).wav")

        guard let url = recordingURL else { return }

        // Create audio file
        audioFile = try? AVAudioFile(forWriting: url, settings: format.settings)
        let recordingFile = audioFile

        inputNode.removeTap(onBus: 0)

        // Install tap on input node
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            try? recordingFile?.write(from: buffer)

            let rms = Self.rms(for: buffer)
            let db = Self.decibels(fromRMS: rms)

            Task { @MainActor [weak self] in
                guard let self else { return }
                self.updateMicLevels(db: db)
                self.checkSilence(db: db)
            }
        }

        try? engine.start()
        isRecording = true
    }

    func stopRecording() -> Data {
        guard isRecording else { return Data() }

        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)

        defer {
            audioEngine = nil
            audioFile = nil
            silenceStart = nil
            hasAutoStopped = false
            isRecording = false
            micLevels = Array(repeating: 0.08, count: 7)
        }

        guard let url = recordingURL,
              let data = try? Data(contentsOf: url) else {
            return Data()
        }

        // Clean up temp file
        try? FileManager.default.removeItem(at: url)
        recordingURL = nil

        return data
    }

    private func updateMicLevels(db: Float) {
        let normalized = max(0.02, min(1.0, (db + 50) / 50))
        let shaped = [0.62, 0.78, 0.93, 1.0, 0.93, 0.78, 0.62].map { CGFloat(normalized) * $0 }
        micLevels = shaped
    }

    private func checkSilence(db: Float) {
        let timeout = ConfigManager.shared.silenceTimeout
        guard timeout > 0 else { return }

        if db < silenceThresholdDB {
            if silenceStart == nil {
                silenceStart = Date()
            }

            if let silenceStart,
               !hasAutoStopped,
               Date().timeIntervalSince(silenceStart) >= timeout {
                hasAutoStopped = true
                onSilenceDetected?()
            }
        } else {
            silenceStart = nil
        }
    }

    nonisolated private static func rms(for buffer: AVAudioPCMBuffer) -> Float {
        guard let channelData = buffer.floatChannelData?[0] else { return 0 }
        let frames = Int(buffer.frameLength)
        guard frames > 0 else { return 0 }

        var sum: Float = 0
        for index in 0..<frames {
            let sample = channelData[index]
            sum += sample * sample
        }
        return sqrt(sum / Float(frames))
    }

    nonisolated private static func decibels(fromRMS rms: Float) -> Float {
        guard rms > 0 else { return -160 }
        return 20 * log10(rms)
    }
}
