import SwiftUI
import Combine

@main
struct GideonTalkApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var overlayWindow: OverlayWindow!
    var menuBarManager: MenuBarManager!
    var hotkeyManager: HotkeyManager!
    private var cancellables = Set<AnyCancellable>()
    private var shouldContinueConversation = false
    private var processingTask: Task<Void, Never>?
    private var activeConversationID = UUID()
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        AppLogger.shared.startNewLaunchLog()
        AppLogger.shared.info("Log path: \(AppLogger.shared.logPath)")

        // Set as accessory (menu bar only, no Dock icon)
        NSApp.setActivationPolicy(.accessory)
        
        // Initialize managers
        menuBarManager = MenuBarManager()
        overlayWindow = OverlayWindow()
        hotkeyManager = HotkeyManager()

        AudioRecorder.shared.onSilenceDetected = { [weak self] in
            guard let self else { return }
            guard StateManager.shared.state == .listening else { return }
            AppLogger.shared.info("Silence callback received in AppDelegate")
            self.stopListeningAndProcess()
        }

        StateManager.shared.$state
            .receive(on: RunLoop.main)
            .sink { [weak self] state in
                self?.menuBarManager.updateIcon(for: state)
            }
            .store(in: &cancellables)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleToggleNotification),
            name: .toggleListening,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleHotkeyChangedNotification),
            name: .hotkeyDidChange,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleOverlayDismissNotification),
            name: .overlayDidDismiss,
            object: nil
        )
        
        // Setup hotkey callback
        hotkeyManager.onToggle = { [weak self] in
            Task { @MainActor in
                self?.toggleListening()
            }
        }
        
        // Try to start hotkey
        hotkeyManager.start()
        AppLogger.shared.info("Application did finish launching")
    }

    func applicationWillTerminate(_ notification: Notification) {
        AppLogger.shared.info("Application will terminate")
        hotkeyManager.stop()
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func handleToggleNotification() {
        toggleListening()
    }

    @objc private func handleHotkeyChangedNotification() {
        hotkeyManager.updateHotkey(
            keyCode: ConfigManager.shared.hotkeyKeyCode,
            modifiers: ConfigManager.shared.hotkeyModifiers
        )
    }

    @objc private func handleOverlayDismissNotification() {
        stopAllAndGoIdle(reason: "Overlay dismissed")
    }
    
    func toggleListening() {
        let stateManager = StateManager.shared
        
        switch stateManager.state {
        case .idle:
            shouldContinueConversation = true
            AppLogger.shared.info("Hotkey/menu toggle: start listening")
            startListening()
        case .listening, .thinking, .speaking, .error:
            stopAllAndGoIdle(reason: "Hotkey/menu toggle stop")
        }
    }

    private func stopAllAndGoIdle(reason: String) {
        shouldContinueConversation = false
        activeConversationID = UUID()
        processingTask?.cancel()
        processingTask = nil
        AudioPlayer.shared.stop()
        if AudioRecorder.shared.isRecording {
            _ = AudioRecorder.shared.stopRecording()
        }
        StateManager.shared.state = .idle
        overlayWindow.hide()
        AppLogger.shared.info("\(reason); moved to idle")
    }
    
    private func startListening() {
        StateManager.shared.currentTranscript = ""
        StateManager.shared.currentResponse = ""
        StateManager.shared.error = nil
        StateManager.shared.state = .listening
        overlayWindow.show()
        AudioRecorder.shared.startRecording()
        AppLogger.shared.info("Listening started")
    }
    
    private func stopListeningAndProcess() {
        guard AudioRecorder.shared.isRecording else { return }
        StateManager.shared.state = .thinking
        AppLogger.shared.info("Listening stopped; processing audio")
        let audioData = AudioRecorder.shared.stopRecording()
        let conversationID = UUID()
        activeConversationID = conversationID
        processingTask?.cancel()
        processingTask = Task { [weak self] in
            await self?.processAudio(audioData, conversationID: conversationID)
        }
    }
    
    private func processAudio(_ data: Data, conversationID: UUID) async {
        guard !Task.isCancelled, conversationID == activeConversationID else { return }
        defer {
            if conversationID == activeConversationID {
                processingTask = nil
            }
        }

        let config = ConfigManager.shared
        let sttURL = config.sttURL
        let gatewayURL = config.gatewayURL
        let token = config.gatewayToken ?? GatewayConfig.readToken() ?? ""
        let model = config.model.isEmpty ? "anthropic/claude-opus-4-6" : config.model
        let ttsURL = config.ttsURL
        let ttsSpeed = config.ttsSpeed
        let orderedAudio = OrderedAudioSegments()
        var synthesisTasks: [Task<Void, Never>] = []
        var sentenceIndex = 0

        func queueSentenceForTTS(_ raw: String) {
            let sentence = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !sentence.isEmpty else { return }

            let index = sentenceIndex
            sentenceIndex += 1

            let task = Task {
                do {
                    let segment = try await TTSService.shared.synthesize(text: sentence, url: ttsURL, speed: ttsSpeed)
                    let readySegments = await orderedAudio.insert(index: index, data: segment)

                    await MainActor.run {
                        if !readySegments.isEmpty {
                            if StateManager.shared.state != .speaking {
                                StateManager.shared.state = .speaking
                            }
                            for item in readySegments {
                                AudioPlayer.shared.enqueueSegment(item)
                            }
                        }
                    }
                } catch {
                    AppLogger.shared.error("TTS segment failed: \(error.localizedDescription)")
                }
            }

            synthesisTasks.append(task)
        }
        
        do {
            guard !data.isEmpty else {
                guard conversationID == activeConversationID else { return }
                StateManager.shared.state = .idle
                AppLogger.shared.warn("Audio buffer empty after recording")
                return
            }

            // STT
            let transcript = try await STTService.shared.transcribe(audio: data, url: sttURL)
            guard !Task.isCancelled, conversationID == activeConversationID else { return }
            AppLogger.shared.info("STT success: \(transcript.count) chars")
            StateManager.shared.currentTranscript = transcript
            
            // Add to conversation history
            ConversationManager.shared.addMessage(role: "user", content: transcript)
            
            AudioPlayer.shared.playQueue(segments: [])

            // Chat streaming + sentence TTS
            let response: String
            do {
                response = try await ChatService.shared.chatStreaming(
                    messages: ConversationManager.shared.getMessages(),
                    baseURL: gatewayURL,
                    token: token,
                    model: model,
                    onPartial: { partial in
                        StateManager.shared.currentResponse = partial
                    },
                    onSentence: { sentence in
                        queueSentenceForTTS(sentence)
                    }
                )
                guard !Task.isCancelled, conversationID == activeConversationID else { return }
                AppLogger.shared.info("Streaming chat success: \(response.count) chars")
            } catch {
                AppLogger.shared.warn("Streaming chat failed, using fallback: \(error.localizedDescription)")
                let fallbackResponse = try await ChatService.shared.chat(
                    messages: ConversationManager.shared.getMessages(),
                    baseURL: gatewayURL,
                    token: token,
                    model: model
                )
                response = fallbackResponse
                StateManager.shared.currentResponse = fallbackResponse

                for sentence in Self.splitIntoSentences(fallbackResponse) {
                    queueSentenceForTTS(sentence)
                }

                if synthesisTasks.isEmpty {
                    queueSentenceForTTS(fallbackResponse)
                }
            }

            guard !Task.isCancelled, conversationID == activeConversationID else { return }
            
            // Add response to history
            ConversationManager.shared.addMessage(role: "assistant", content: response)

            if StateManager.shared.currentResponse.isEmpty {
                StateManager.shared.currentResponse = response
            }

            for task in synthesisTasks {
                await task.value
            }

            guard !Task.isCancelled, conversationID == activeConversationID else { return }

            AudioPlayer.shared.finishQueue {
                Task { @MainActor in
                    guard conversationID == self.activeConversationID else { return }
                    StateManager.shared.state = .idle
                    self.overlayWindow.hide(after: ConfigManager.shared.autoFadeDelay)
                    AppLogger.shared.info("Conversation turn completed")

                    if ConfigManager.shared.continuousMode && self.shouldContinueConversation {
                        AppLogger.shared.info("Continuous mode waiting 0.3s before re-listen")
                        try? await Task.sleep(nanoseconds: 300_000_000)

                        guard ConfigManager.shared.continuousMode,
                              self.shouldContinueConversation,
                              StateManager.shared.state == .idle else {
                            AppLogger.shared.info("Continuous mode re-listen cancelled")
                            return
                        }

                        self.startListening()
                    }
                }
            }
        } catch {
            guard conversationID == activeConversationID else { return }
            StateManager.shared.state = .idle
            StateManager.shared.error = error.localizedDescription
            AppLogger.shared.error("Conversation pipeline failed: \(error.localizedDescription)")
        }
    }

    private static func splitIntoSentences(_ text: String) -> [String] {
        var sentences: [String] = []
        var buffer = text
        let delimiters = [". ", "! ", "? ", "\n"]

        while true {
            var earliest: Range<String.Index>?
            for delimiter in delimiters {
                guard let range = buffer.range(of: delimiter) else { continue }
                if let earliest, range.lowerBound >= earliest.lowerBound { continue }
                earliest = range
            }

            guard let range = earliest else { break }

            let sentenceEnd: String.Index
            if buffer[range].hasSuffix("\n") {
                sentenceEnd = range.lowerBound
            } else {
                sentenceEnd = buffer.index(after: range.lowerBound)
            }

            let sentence = String(buffer[..<sentenceEnd]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !sentence.isEmpty {
                sentences.append(sentence)
            }
            buffer = String(buffer[range.upperBound...])
        }

        let trailing = buffer.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trailing.isEmpty {
            sentences.append(trailing)
        }
        return sentences
    }
}

private actor OrderedAudioSegments {
    private var nextExpectedIndex = 0
    private var buffered: [Int: Data] = [:]

    func insert(index: Int, data: Data) -> [Data] {
        buffered[index] = data
        var ordered: [Data] = []

        while let next = buffered.removeValue(forKey: nextExpectedIndex) {
            ordered.append(next)
            nextExpectedIndex += 1
        }

        return ordered
    }
}
