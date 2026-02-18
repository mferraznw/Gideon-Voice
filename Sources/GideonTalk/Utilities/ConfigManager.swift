import Foundation
import ServiceManagement
import Carbon

@MainActor
class ConfigManager: ObservableObject {
    static let shared = ConfigManager()
    
    // Keys
    private let hotkeyKey = "hotkey"
    private let hotkeyKeyCodeKey = "hotkeyKeyCode"
    private let hotkeyModifiersKey = "hotkeyModifiers"
    private let gatewayURLKey = "gatewayURL"
    private let gatewayTokenKey = "gatewayToken"
    private let sttURLKey = "sttURL"
    private let ttsURLKey = "ttsURL"
    private let ttsSpeedKey = "ttsSpeed"
    private let modelKey = "model"
    private let avatarPathKey = "avatarPath"
    private let silenceTimeoutKey = "silenceTimeout"
    private let autoFadeDelayKey = "autoFadeDelay"
    private let launchAtLoginKey = "launchAtLogin"
    private let overlayOriginXKey = "overlayOriginX"
    private let overlayOriginYKey = "overlayOriginY"
    
    // Values with defaults
    @Published var hotkeyString: String = "Cmd+Shift+G"
    @Published var hotkeyKeyCode: UInt32 = 5
    @Published var hotkeyModifiers: UInt32 = UInt32(cmdKey | shiftKey)
    @Published var gatewayURL: String = "http://127.0.0.1:18789"
    @Published var gatewayTokenString: String = ""
    @Published var sttURL: String = "http://127.0.0.1:18790"
    @Published var ttsURL: String = "http://127.0.0.1:18790"
    @Published var ttsSpeed: Double = 1.0
    @Published var model: String = "anthropic/claude-opus-4-6"
    @Published var avatarPath: String = "~/Pictures/MyGideon.png"
    @Published var silenceTimeout: Double = 2.0
    @Published var autoFadeDelay: Double = 3.0
    @Published var launchAtLogin: Bool = false
    @Published var overlayOriginX: Double = 0
    @Published var overlayOriginY: Double = 0
    
    var gatewayToken: String? {
        if gatewayTokenString.isEmpty {
            return GatewayConfig.readToken()
        }
        return gatewayTokenString
    }
    
    private let defaults = UserDefaults.standard
    
    private init() {
        loadSettings()
    }
    
    func loadSettings() {
        hotkeyString = defaults.string(forKey: hotkeyKey) ?? hotkeyString
        if defaults.object(forKey: hotkeyKeyCodeKey) != nil {
            hotkeyKeyCode = UInt32(defaults.integer(forKey: hotkeyKeyCodeKey))
        }
        if defaults.object(forKey: hotkeyModifiersKey) != nil {
            hotkeyModifiers = UInt32(defaults.integer(forKey: hotkeyModifiersKey))
        }

        gatewayURL = defaults.string(forKey: gatewayURLKey) ?? gatewayURL
        gatewayTokenString = defaults.string(forKey: gatewayTokenKey) ?? ""
        sttURL = defaults.string(forKey: sttURLKey) ?? sttURL
        ttsURL = defaults.string(forKey: ttsURLKey) ?? ttsURL
        ttsSpeed = defaults.double(forKey: ttsSpeedKey)
        if ttsSpeed == 0 { ttsSpeed = 1.0 }
        model = defaults.string(forKey: modelKey) ?? model
        avatarPath = defaults.string(forKey: avatarPathKey) ?? avatarPath
        silenceTimeout = defaults.double(forKey: silenceTimeoutKey)
        if silenceTimeout == 0 { silenceTimeout = 2.0 }
        autoFadeDelay = defaults.double(forKey: autoFadeDelayKey)
        if autoFadeDelay == 0 { autoFadeDelay = 3.0 }
        launchAtLogin = defaults.bool(forKey: launchAtLoginKey)

        if defaults.object(forKey: overlayOriginXKey) != nil,
           defaults.object(forKey: overlayOriginYKey) != nil {
            overlayOriginX = defaults.double(forKey: overlayOriginXKey)
            overlayOriginY = defaults.double(forKey: overlayOriginYKey)
        }
    }
    
    func saveSettings() {
        defaults.set(hotkeyString, forKey: hotkeyKey)
        defaults.set(Int(hotkeyKeyCode), forKey: hotkeyKeyCodeKey)
        defaults.set(Int(hotkeyModifiers), forKey: hotkeyModifiersKey)
        defaults.set(gatewayURL, forKey: gatewayURLKey)
        defaults.set(gatewayTokenString, forKey: gatewayTokenKey)
        defaults.set(sttURL, forKey: sttURLKey)
        defaults.set(ttsURL, forKey: ttsURLKey)
        defaults.set(ttsSpeed, forKey: ttsSpeedKey)
        defaults.set(model, forKey: modelKey)
        defaults.set(avatarPath, forKey: avatarPathKey)
        defaults.set(silenceTimeout, forKey: silenceTimeoutKey)
        defaults.set(autoFadeDelay, forKey: autoFadeDelayKey)
        defaults.set(launchAtLogin, forKey: launchAtLoginKey)
        defaults.set(overlayOriginX, forKey: overlayOriginXKey)
        defaults.set(overlayOriginY, forKey: overlayOriginYKey)
        
        updateLaunchAtLogin()
    }
    
    private func updateLaunchAtLogin() {
        if launchAtLogin {
            try? SMAppService.mainApp.register()
        } else {
            try? SMAppService.mainApp.unregister()
        }
    }

    func updateHotkey(display: String, keyCode: UInt32, modifiers: UInt32) {
        hotkeyString = display
        hotkeyKeyCode = keyCode
        hotkeyModifiers = modifiers
        saveSettings()
    }

    func saveOverlayOrigin(x: Double, y: Double) {
        overlayOriginX = x
        overlayOriginY = y
        saveSettings()
    }
}
