import Foundation
import AVFoundation

@MainActor
class AudioPlayer: NSObject, ObservableObject {
    static let shared = AudioPlayer()
    
    private var player: AVAudioPlayer?
    private var completionHandler: (() -> Void)?
    private var levelTimer: Timer?
    
    @Published var isPlaying = false
    @Published var currentLevel: Float = 0
    
    private override init() {
        super.init()
    }
    
    func play(data: Data, completion: (() -> Void)? = nil) {
        do {
            player = try AVAudioPlayer(data: data)
            player?.delegate = self
            player?.prepareToPlay()
            completionHandler = completion
            isPlaying = true
            player?.play()
            
            // Start level monitoring
            startLevelMonitoring()
        } catch {
            print("AudioPlayer error: \(error)")
            completion?()
        }
    }
    
    func stop() {
        player?.stop()
        player = nil
        isPlaying = false
        levelTimer?.invalidate()
        levelTimer = nil
    }
    
    private func startLevelMonitoring() {
        levelTimer?.invalidate()
        levelTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] timer in
            Task { @MainActor in
                guard let self = self, self.isPlaying else {
                    timer.invalidate()
                    return
                }
                self.currentLevel = Float.random(in: 0.3...1.0)
            }
        }
    }
}

extension AudioPlayer: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            self.isPlaying = false
            self.levelTimer?.invalidate()
            self.levelTimer = nil
            self.completionHandler?()
            self.completionHandler = nil
        }
    }
}
