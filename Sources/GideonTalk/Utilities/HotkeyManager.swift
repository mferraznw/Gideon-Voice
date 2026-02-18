import Foundation
import Carbon

class HotkeyManager {
    var onToggle: (() -> Void)?
    private var hotKeyRef: EventHotKeyRef?
    private var handler: EventHandlerRef?
    
    func start() {
        registerHotkey()
    }
    
    func stop() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
        }
        if let handler = handler {
            RemoveEventHandler(handler)
        }
    }
    
    private func registerHotkey() {
        let hotkeyId = EventHotKeyID(signature: OSType("GTaL".fourCharCode), id: 0)
        
        // Cmd+Shift+G
        let keyCode: UInt32 = 5 // G key
        let modifiers: UInt32 = UInt32(cmdKey | shiftKey)
        
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        
        // Install handler
        let handlerCallback: EventHandlerUPP = { _, event, userData -> OSStatus in
            guard let userData = userData else { return OSStatus(eventNotHandledErr) }
            let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()
            DispatchQueue.main.async {
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
