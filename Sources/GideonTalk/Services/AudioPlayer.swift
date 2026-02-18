import Foundation
import AVFoundation
import SwiftUI

@MainActor
class AudioPlayer: NSObject, ObservableObject {
    static let shared = AudioPlayer()
    
    private var player: AVAudioPlayer?
    private var completionHandler: (() -> Void)?
    private var levelTimer: Timer?
    private var segmentQueue: [Data] = []
    private var queueCompletion: (() -> Void)?
    private var queueClosed = false
    private var isQueueMode = false
    private var needsStartupWarmup = true
    
    @Published var isPlaying = false
    @Published var currentLevel: Float = 0
    @Published var levels: [CGFloat] = Array(repeating: 0.08, count: 5)
    
    private override init() {
        super.init()
    }
    
    func play(data: Data, completion: (() -> Void)? = nil) {
        stop()
        isQueueMode = false
        queueCompletion = nil
        queueClosed = true
        needsStartupWarmup = true
        completionHandler = completion
        startPlayback(data: data, applyWarmupDelay: true)
    }

    func playQueue(segments: [Data], completion: (() -> Void)? = nil) {
        stop()
        isQueueMode = true
        queueClosed = false
        segmentQueue = segments
        queueCompletion = completion
        needsStartupWarmup = true
        playNextSegmentIfNeeded()
    }

    func enqueueSegment(_ data: Data) {
        if !isQueueMode {
            playQueue(segments: [data], completion: nil)
            return
        }

        segmentQueue.append(data)
        playNextSegmentIfNeeded()
    }

    func finishQueue(completion: (() -> Void)? = nil) {
        if let completion {
            queueCompletion = completion
        }
        queueClosed = true
        playNextSegmentIfNeeded()
    }

    private func startPlayback(data: Data, applyWarmupDelay: Bool) {
        do {
            player = try AVAudioPlayer(data: data)
            player?.delegate = self
            player?.volume = Float(ConfigManager.shared.playbackVolume)
            player?.isMeteringEnabled = true
            player?.prepareToPlay()
            isPlaying = true

            let playerRef = player
            let startPlaybackBlock = { [weak self] in
                guard let self, self.player === playerRef else { return }
                self.player?.play()
                AppLogger.shared.info("AudioPlayer play: \(data.count) bytes")
                self.startLevelMonitoring()
            }

            if applyWarmupDelay {
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 50_000_000)
                    startPlaybackBlock()
                }
            } else {
                startPlaybackBlock()
            }
        } catch {
            AppLogger.shared.error("AudioPlayer failed: \(error.localizedDescription)")
            if isQueueMode {
                playNextSegmentIfNeeded()
            } else {
                completionHandler?()
                completionHandler = nil
            }
        }
    }
    
    func stop() {
        player?.stop()
        player = nil
        isPlaying = false
        AppLogger.shared.info("AudioPlayer stop")
        currentLevel = 0
        levels = Array(repeating: 0.08, count: 5)
        levelTimer?.invalidate()
        levelTimer = nil
        segmentQueue.removeAll()
        queueClosed = true
        isQueueMode = false
        needsStartupWarmup = true
        queueCompletion = nil
        completionHandler = nil
    }

    private func playNextSegmentIfNeeded() {
        guard isQueueMode else { return }
        guard !isPlaying else { return }

        if !segmentQueue.isEmpty {
            let next = segmentQueue.removeFirst()
            let applyWarmup = needsStartupWarmup
            needsStartupWarmup = false
            startPlayback(data: next, applyWarmupDelay: applyWarmup)
            return
        }

        guard queueClosed else { return }

        isQueueMode = false
        let completion = queueCompletion
        queueCompletion = nil
        completion?()
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
            AppLogger.shared.info("AudioPlayer finished: success=\(flag)")
            self.player = nil
            self.isPlaying = false
            self.currentLevel = 0
            self.levels = Array(repeating: 0.08, count: 5)
            self.levelTimer?.invalidate()
            self.levelTimer = nil

            if self.isQueueMode {
                self.playNextSegmentIfNeeded()
            } else {
                self.completionHandler?()
                self.completionHandler = nil
            }
        }
    }
}
