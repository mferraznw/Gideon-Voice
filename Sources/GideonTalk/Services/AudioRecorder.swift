import Foundation
@preconcurrency import AVFoundation
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
        let nativeFormat = inputNode.inputFormat(forBus: 0)

        // Create temp file
        let tempDir = FileManager.default.temporaryDirectory
        recordingURL = tempDir.appendingPathComponent("recording_\(UUID().uuidString).caf")
        guard let url = recordingURL else { return }

        do {
            audioFile = try AVAudioFile(forWriting: url, settings: nativeFormat.settings)
        } catch {
            AppLogger.shared.error("AudioRecorder failed to create native audio file: \(error.localizedDescription)")
            return
        }
        let recordingFile = audioFile

        AppLogger.shared.info("AudioRecorder start: recording native format \(nativeFormat.sampleRate)Hz channels=\(nativeFormat.channelCount)")

        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 4096, format: nativeFormat) { [weak self] buffer, _ in
            try? recordingFile?.write(from: buffer)

            let rms = Self.rms(for: buffer)
            let db = Self.decibels(fromRMS: rms)

            Task { @MainActor [weak self] in
                guard let self else { return }
                self.updateMicLevels(db: db)
                self.checkSilence(db: db)
            }
        }

        do {
            try engine.start()
            isRecording = true
        } catch {
            AppLogger.shared.error("AudioRecorder failed to start engine: \(error.localizedDescription)")
        }
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

        guard let url = recordingURL else {
            return Data()
        }

        let convertedURL = url.deletingPathExtension().appendingPathExtension("wav")

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/afconvert")
        process.arguments = [
            "-f", "WAVE",
            "-d", "LEI16@16000",
            "-c", "1",
            url.path,
            convertedURL.path
        ]

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            AppLogger.shared.error("AudioRecorder failed to run afconvert: \(error.localizedDescription)")
            return Data()
        }

        guard process.terminationStatus == 0 else {
            AppLogger.shared.error("AudioRecorder afconvert failed with exit code \(process.terminationStatus)")
            return Data()
        }

        guard let data = try? Data(contentsOf: convertedURL) else {
            AppLogger.shared.error("AudioRecorder failed to read converted WAV")
            return Data()
        }

        try? FileManager.default.removeItem(at: url)
        try? FileManager.default.removeItem(at: convertedURL)
        recordingURL = nil

        AppLogger.shared.info("AudioRecorder stop: afconvert produced \(data.count) bytes of 16kHz mono WAV")

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
                AppLogger.shared.info("Silence auto-stop triggered after \(timeout)s")
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
