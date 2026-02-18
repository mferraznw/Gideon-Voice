import Foundation
import AVFoundation
import SwiftUI

@MainActor
class AudioPlayer: NSObject, ObservableObject {
    static let shared = AudioPlayer()
    
    private var player: AVAudioPlayer?
    private var completionHandler: (() -> Void)?
    private var levelTimer: Timer?
    
    @Published var isPlaying = false
    @Published var currentLevel: Float = 0
    @Published var levels: [CGFloat] = Array(repeating: 0.08, count: 5)
    
    private override init() {
        super.init()
    }
    
    func play(data: Data, completion: (() -> Void)? = nil) {
        do {
            player = try AVAudioPlayer(data: data)
            player?.delegate = self
            player?.isMeteringEnabled = true
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
        currentLevel = 0
        levels = Array(repeating: 0.08, count: 5)
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

                self.player?.updateMeters()
                let avgPower = self.player?.averagePower(forChannel: 0) ?? -80
                let normalized = max(0.02, min(1.0, (avgPower + 60) / 60))

                self.currentLevel = normalized
                self.levels = [0.68, 0.86, 1.0, 0.86, 0.68].map { CGFloat(normalized) * $0 }
            }
        }
    }
}

extension AudioPlayer: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            self.isPlaying = false
            self.currentLevel = 0
            self.levels = Array(repeating: 0.08, count: 5)
            self.levelTimer?.invalidate()
            self.levelTimer = nil
            self.completionHandler?()
            self.completionHandler = nil
        }
    }
}
