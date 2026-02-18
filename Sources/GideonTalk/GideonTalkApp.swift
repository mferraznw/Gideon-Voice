import SwiftUI

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
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Set as accessory (menu bar only, no Dock icon)
        NSApp.setActivationPolicy(.accessory)
        
        // Initialize managers
        menuBarManager = MenuBarManager()
        overlayWindow = OverlayWindow()
        hotkeyManager = HotkeyManager()
        
        // Setup hotkey callback
        hotkeyManager.onToggle = { [weak self] in
            Task { @MainActor in
                self?.toggleListening()
            }
        }
        
        // Try to start hotkey
        hotkeyManager.start()
    }
    
    func toggleListening() {
        let stateManager = StateManager.shared
        
        switch stateManager.state {
        case .idle:
            startListening()
        case .listening:
            stopListeningAndProcess()
        default:
            break
        }
    }
    
    private func startListening() {
        StateManager.shared.state = .listening
        overlayWindow.show()
        Task {
            await AudioRecorder.shared.startRecording()
        }
    }
    
    private func stopListeningAndProcess() {
        StateManager.shared.state = .thinking
        Task {
            let audioData = await AudioRecorder.shared.stopRecording()
            await processAudio(audioData)
        }
    }
    
    private func processAudio(_ data: Data) async {
        let config = ConfigManager.shared
        let sttURL = config.sttURL
        let gatewayURL = config.gatewayURL
        let token = config.gatewayToken ?? GatewayConfig.readToken() ?? ""
        let model = config.model
        let ttsURL = config.ttsURL
        let ttsSpeed = config.ttsSpeed
        
        do {
            // STT
            let transcript = try await STTService.shared.transcribe(audio: data, url: sttURL)
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
            
            // Add response to history
            ConversationManager.shared.addMessage(role: "assistant", content: response)
            
            StateManager.shared.currentResponse = response
            StateManager.shared.state = .speaking
            
            // TTS
            let audioData = try await TTSService.shared.synthesize(text: response, url: ttsURL, speed: ttsSpeed)
            
            AudioPlayer.shared.play(data: audioData) {
                Task { @MainActor in
                    StateManager.shared.state = .idle
                    self.overlayWindow.hide(after: ConfigManager.shared.autoFadeDelay)
                }
            }
        } catch {
            StateManager.shared.state = .idle
            StateManager.shared.error = error.localizedDescription
        }
    }
}
