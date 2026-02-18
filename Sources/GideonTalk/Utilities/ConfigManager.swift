import Foundation
import ServiceManagement

@MainActor
class ConfigManager: ObservableObject {
    static let shared = ConfigManager()
    
    // Keys
    private let hotkeyKey = "hotkey"
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
    
    // Values with defaults
    @Published var hotkeyString: String = "Cmd+Shift+G"
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
    }
    
    func saveSettings() {
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
        
        updateLaunchAtLogin()
    }
    
    private func updateLaunchAtLogin() {
        if launchAtLogin {
            try? SMAppService.mainApp.register()
        } else {
            try? SMAppService.mainApp.unregister()
        }
    }
}
