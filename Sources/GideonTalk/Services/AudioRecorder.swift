import Foundation
import AVFoundation

actor AudioRecorder {
    static let shared = AudioRecorder()
    
    private var audioEngine: AVAudioEngine?
    private var audioFile: AVAudioFile?
    private var recordingURL: URL?
    
    private init() {}
    
    func startRecording() {
        // macOS doesn't use AVAudioSession - direct audio engine setup
        audioEngine = AVAudioEngine()
        guard let engine = audioEngine else { return }
        
        let inputNode = engine.inputNode
        
        // Configure format: 16kHz mono for STT
        let format = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: 16000, channels: 1, interleaved: true)!
        
        // Create temp file
        let tempDir = FileManager.default.temporaryDirectory
        recordingURL = tempDir.appendingPathComponent("recording_\(UUID().uuidString).wav")
        
        guard let url = recordingURL else { return }
        
        // Create audio file
        audioFile = try? AVAudioFile(forWriting: url, settings: format.settings)
        
        // Install tap on input node
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            try? self?.audioFile?.write(from: buffer)
        }
        
        try? engine.start()
    }
    
    func stopRecording() -> Data {
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        
        defer {
            audioEngine = nil
            audioFile = nil
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
    
    func getCurrentLevel() -> Float {
        guard let engine = audioEngine else { return 0 }
        let node = engine.inputNode
        let bus = 0
        
        // Get power level
        node.installTap(onBus: bus, bufferSize: 1024, format: node.outputFormat(forBus: bus)) { _, _ in }
        
        // Simple approximation using RMS would need actual buffer processing
        // For now, return 0 and implement proper level monitoring later
        return 0
    }
}
