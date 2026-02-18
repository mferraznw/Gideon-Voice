import SwiftUI
import Carbon
import AppKit
import UniformTypeIdentifiers

struct SettingsView: View {
    @StateObject private var config = ConfigManager.shared
    @State private var isCapturingHotkey = false
    @State private var hotkeyMonitor: Any?
    
    var body: some View {
        Form {
            Section("Keyboard") {
                TextField("Hotkey", text: $config.hotkeyString)
                    .disabled(true)
                Button(isCapturingHotkey ? "Press keys..." : "Re-record Hotkey") {
                    startHotkeyCapture()
                }
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
                Text("\(String(format: "%.1f", config.ttsSpeed))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Section("Appearance") {
                HStack {
                    TextField("Avatar Path", text: $config.avatarPath)
                    Button("Browse") {
                        chooseAvatar()
                    }
                }
                Slider(value: $config.silenceTimeout, in: 0.5...5.0, step: 0.5) {
                    Text("Silence Timeout: \(String(format: "%.1f", config.silenceTimeout))s")
                }
                Text("\(String(format: "%.1f", config.silenceTimeout))s")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Slider(value: $config.autoFadeDelay, in: 1.0...10.0, step: 0.5) {
                    Text("Auto-fade Delay: \(String(format: "%.1f", config.autoFadeDelay))s")
                }
                Text("\(String(format: "%.1f", config.autoFadeDelay))s")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Section("System") {
                Toggle("Launch at Login", isOn: $config.launchAtLogin)
            }
        }
        .formStyle(.grouped)
        .frame(width: 400, height: 500)
        .onDisappear {
            config.saveSettings()
            stopHotkeyCapture()
        }
        .onChange(of: config.gatewayURL) { config.saveSettings() }
        .onChange(of: config.gatewayTokenString) { config.saveSettings() }
        .onChange(of: config.sttURL) { config.saveSettings() }
        .onChange(of: config.ttsURL) { config.saveSettings() }
        .onChange(of: config.ttsSpeed) { config.saveSettings() }
        .onChange(of: config.model) { config.saveSettings() }
        .onChange(of: config.avatarPath) { config.saveSettings() }
        .onChange(of: config.silenceTimeout) { config.saveSettings() }
        .onChange(of: config.autoFadeDelay) { config.saveSettings() }
        .onChange(of: config.launchAtLogin) { config.saveSettings() }
    }

    private func startHotkeyCapture() {
        stopHotkeyCapture()
        isCapturingHotkey = true

        hotkeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let modifiers = carbonModifiers(from: event.modifierFlags)

            guard modifiers & UInt32(cmdKey) != 0 else {
                return nil
            }

            let display = displayHotkey(for: event.keyCode, modifiers: modifiers)
            config.updateHotkey(display: display, keyCode: UInt32(event.keyCode), modifiers: modifiers)
            NotificationCenter.default.post(name: .hotkeyDidChange, object: nil)
            stopHotkeyCapture()
            return nil
        }
    }

    private func stopHotkeyCapture() {
        if let hotkeyMonitor {
            NSEvent.removeMonitor(hotkeyMonitor)
            self.hotkeyMonitor = nil
        }
        isCapturingHotkey = false
    }

    private func chooseAvatar() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.png, .jpeg, .image]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true

        if panel.runModal() == .OK, let url = panel.url {
            config.avatarPath = url.path
            config.saveSettings()
        }
    }

    private func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var value: UInt32 = 0
        if flags.contains(.command) { value |= UInt32(cmdKey) }
        if flags.contains(.shift) { value |= UInt32(shiftKey) }
        if flags.contains(.option) { value |= UInt32(optionKey) }
        if flags.contains(.control) { value |= UInt32(controlKey) }
        return value
    }

    private func displayHotkey(for keyCode: UInt16, modifiers: UInt32) -> String {
        var parts: [String] = []
        if modifiers & UInt32(controlKey) != 0 { parts.append("Ctrl") }
        if modifiers & UInt32(optionKey) != 0 { parts.append("Option") }
        if modifiers & UInt32(shiftKey) != 0 { parts.append("Shift") }
        if modifiers & UInt32(cmdKey) != 0 { parts.append("Cmd") }
        parts.append(Self.keyName(for: keyCode))
        return parts.joined(separator: "+")
    }

    private static func keyName(for keyCode: UInt16) -> String {
        switch keyCode {
        case 0: return "A"
        case 1: return "S"
        case 2: return "D"
        case 3: return "F"
        case 4: return "H"
        case 5: return "G"
        case 6: return "Z"
        case 7: return "X"
        case 8: return "C"
        case 9: return "V"
        case 11: return "B"
        case 12: return "Q"
        case 13: return "W"
        case 14: return "E"
        case 15: return "R"
        case 16: return "Y"
        case 17: return "T"
        default: return "Key\(keyCode)"
        }
    }
}
