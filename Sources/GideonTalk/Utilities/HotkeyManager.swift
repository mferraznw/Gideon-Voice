import Foundation
import Carbon

@MainActor
class HotkeyManager {
    var onToggle: (() -> Void)?
    private var hotKeyRef: EventHotKeyRef?
    private var handler: EventHandlerRef?
    
    func start() {
        registerHotkey(
            keyCode: ConfigManager.shared.hotkeyKeyCode,
            modifiers: ConfigManager.shared.hotkeyModifiers
        )
    }

    func updateHotkey(keyCode: UInt32, modifiers: UInt32) {
        stop()
        registerHotkey(keyCode: keyCode, modifiers: modifiers)
    }
    
    func stop() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
        }
        if let handler = handler {
            RemoveEventHandler(handler)
        }
    }
    
    private func registerHotkey(keyCode: UInt32, modifiers: UInt32) {
        let hotkeyId = EventHotKeyID(signature: OSType("GTaL".fourCharCode), id: 0)
        
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        
        // Install handler
        let handlerCallback: EventHandlerUPP = { _, _, userData -> OSStatus in
            guard let userData = userData else { return OSStatus(eventNotHandledErr) }
            let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()
            Task { @MainActor in
                manager.onToggle?()
            }
            return noErr
        }
        
        InstallEventHandler(
            GetEventDispatcherTarget(),
            handlerCallback,
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &handler
        )
        
        // Register hotkey
        RegisterEventHotKey(
            keyCode,
            modifiers,
            hotkeyId,
            GetEventDispatcherTarget(),
            0,
            &hotKeyRef
        )
    }
}

extension String {
    var fourCharCode: FourCharCode {
        var result: FourCharCode = 0
        for char in self.utf8 {
            result = result << 8 + FourCharCode(char)
        }
        return result
    }
}
