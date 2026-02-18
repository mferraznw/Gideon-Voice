import SwiftUI

struct SettingsView: View {
    @StateObject private var config = ConfigManager.shared
    
    var body: some View {
        Form {
            Section("Keyboard") {
                TextField("Hotkey", text: $config.hotkeyString)
                    .disabled(true)
                Text("Press Cmd+Shift+G to toggle listening")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Section("Endpoints") {
                TextField("Gateway URL", text: $config.gatewayURL)
                SecureField("Gateway Token", text: $config.gatewayTokenString)
                TextField("STT URL", text: $config.sttURL)
                TextField("TTS URL", text: $config.ttsURL)
            }
            
            Section("Voice") {
                TextField("Model", text: $config.model)
                Slider(value: $config.ttsSpeed, in: 0.5...2.0, step: 0.1) {
                    Text("TTS Speed: \(String(format: "%.1f", config.ttsSpeed))")
                }
            }
            
            Section("Appearance") {
                TextField("Avatar Path", text: $config.avatarPath)
                Slider(value: $config.silenceTimeout, in: 0.5...5.0, step: 0.5) {
                    Text("Silence Timeout: \(String(format: "%.1f", config.silenceTimeout))s")
                }
                Slider(value: $config.autoFadeDelay, in: 1.0...10.0, step: 0.5) {
                    Text("Auto-fade Delay: \(String(format: "%.1f", config.autoFadeDelay))s")
                }
            }
            
            Section("System") {
                Toggle("Launch at Login", isOn: $config.launchAtLogin)
            }
        }
        .formStyle(.grouped)
        .frame(width: 400, height: 500)
    }
}
