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
        shouldContinueConversation = false
        AudioPlayer.shared.stop()
        if AudioRecorder.shared.isRecording {
            _ = AudioRecorder.shared.stopRecording()
        }
        StateManager.shared.state = .idle
        AppLogger.shared.info("Overlay dismissed; continuous loop stopped")
    }
    
    func toggleListening() {
        let stateManager = StateManager.shared
        
        switch stateManager.state {
        case .idle:
            shouldContinueConversation = true
            AppLogger.shared.info("Hotkey/menu toggle: start listening")
            startListening()
        case .listening:
            shouldContinueConversation = false
            AppLogger.shared.info("Hotkey/menu toggle: stop listening")
            stopListeningAndProcess()
        case .thinking, .speaking, .error:
            shouldContinueConversation = false
            AudioPlayer.shared.stop()
            overlayWindow.hide()
            stateManager.state = .idle
            AppLogger.shared.info("Hotkey/menu toggle: interrupted active turn")
        }
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
        Task {
            let audioData = AudioRecorder.shared.stopRecording()
            await processAudio(audioData)
        }
    }
    
    private func processAudio(_ data: Data) async {
        let config = ConfigManager.shared
        let sttURL = config.sttURL
        let gatewayURL = config.gatewayURL
        let token = config.gatewayToken ?? GatewayConfig.readToken() ?? ""
        let model = config.model.isEmpty ? "anthropic/claude-opus-4-6" : config.model
        let ttsURL = config.ttsURL
        let ttsSpeed = config.ttsSpeed
        
        do {
            guard !data.isEmpty else {
                StateManager.shared.state = .idle
                AppLogger.shared.warn("Audio buffer empty after recording")
                return
            }

            // STT
            let transcript = try await STTService.shared.transcribe(audio: data, url: sttURL)
            AppLogger.shared.info("STT success: \(transcript.count) chars")
            StateManager.shared.currentTranscript = transcript
            
            // Add to conversation history
            ConversationManager.shared.addMessage(role: "user", content: transcript)
            
            // Chat
            let response = try await ChatService.shared.chat(
                messages: ConversationManager.shared.getMessages(),
                baseURL: gatewayURL,
                token: token,
                model: model
            )
            AppLogger.shared.info("Chat success: \(response.count) chars")
            
            // Add response to history
            ConversationManager.shared.addMessage(role: "assistant", content: response)
            
            StateManager.shared.currentResponse = response
            StateManager.shared.state = .speaking
            
            // TTS
            let audioData = try await TTSService.shared.synthesize(text: response, url: ttsURL, speed: ttsSpeed)
            AppLogger.shared.info("TTS success: \(audioData.count) bytes")
            
            AudioPlayer.shared.play(data: audioData) {
                Task { @MainActor in
                    StateManager.shared.state = .idle
                    self.overlayWindow.hide(after: ConfigManager.shared.autoFadeDelay)
                    AppLogger.shared.info("Conversation turn completed")

                    if ConfigManager.shared.continuousMode && self.shouldContinueConversation {
                        AppLogger.shared.info("Continuous mode waiting 0.5s before re-listen")
                        try? await Task.sleep(nanoseconds: 500_000_000)

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
            StateManager.shared.state = .idle
            StateManager.shared.error = error.localizedDescription
            AppLogger.shared.error("Conversation pipeline failed: \(error.localizedDescription)")
        }
    }
}
