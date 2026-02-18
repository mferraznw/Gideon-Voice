# GideonTalk — Bug Fix & Completion Prompt

## Context
This is a macOS menu bar voice assistant app (Swift 5.9, SwiftUI, macOS 14+). It was scaffolded from SPEC.md but has several issues preventing it from working. The app should: show a menu bar icon, respond to Cmd+Shift+G hotkey, record mic audio, send to local STT/TTS endpoints, and chat via an OpenAI-compatible API.

## Critical Bugs to Fix

### 1. Menu bar icon doesn't appear
**File**: `Sources/GideonTalk/Views/MenuBarView.swift`
- `MenuBarManager` has `@objc` selectors but doesn't inherit from `NSObject` — add `: NSObject`
- Menu item targets aren't set — each `NSMenuItem` with an action needs `target = self`
- Verify `NSStatusItem` is being retained (it may get garbage collected if not stored strongly)

### 2. Global hotkey doesn't work
**File**: `Sources/GideonTalk/Utilities/HotkeyManager.swift`  
- Carbon `RegisterEventHotKey` requires the app to have Accessibility permissions
- The `EventHandlerUPP` callback closure may not work correctly as a C function pointer in Swift — consider using `installEventHandler` with a proper C function, or switch to `CGEvent.tapCreate` approach which is more modern
- Alternative: Use `NSEvent.addGlobalMonitorForEvents(matching: .keyDown)` for a simpler approach (still needs Accessibility permissions but more Swift-native)
- Add a prompt to the user if Accessibility isn't granted: `AXIsProcessTrustedWithOptions`

### 3. App crashes on launch (SIGKILL)
- The app may be getting killed because it's a command-line executable trying to be a GUI app
- Ensure `Info.plist` has `LSUIElement = true` and is properly embedded
- May need to build as a proper `.app` bundle instead of a bare executable
- Consider adding `NSApp.run()` or ensuring the SwiftUI lifecycle is properly initialized

### 4. Missing types/classes referenced but not defined
Check that these exist and are properly implemented:
- `StateManager.shared` — singleton managing `ConversationState`
- `ConversationManager.shared` — manages chat history
- `ThinkingView` — animation view for thinking state
- `SpeakingBarsView` — animation view for speaking state
- `OverlayWindow` — `NSPanel` subclass for the floating overlay

### 5. AudioRecorder issues
**File**: `Sources/GideonTalk/Services/AudioRecorder.swift`
- `getCurrentLevel()` installs a duplicate tap — will crash. Remove or fix.
- The recording format requests 16kHz but the hardware input may not support it — need to use the input node's native format and convert, or use `AVAudioConverter`
- Actor isolation: `startRecording`/`stopRecording` are async but the tap callback writes to `audioFile` — potential race condition

## Improvements Needed

### Build as .app bundle
The app should be a proper macOS .app bundle, not just a binary. Update `Package.swift` or add a build script:
```bash
# After swift build, create bundle:
mkdir -p GideonTalk.app/Contents/MacOS
mkdir -p GideonTalk.app/Contents/Resources
cp .build/release/GideonTalk GideonTalk.app/Contents/MacOS/
cp Sources/GideonTalk/Info.plist GideonTalk.app/Contents/
```

### Accessibility permission request
On first launch, prompt for Accessibility:
```swift
let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue(): true] as CFDictionary
let trusted = AXIsProcessTrustedWithOptions(options)
if !trusted {
    // Show alert explaining why permission is needed
}
```

### Gateway token reading
**File**: `Sources/GideonTalk/Utilities/GatewayConfig.swift`
- Must parse `~/.openclaw/openclaw.json` and extract `gateway.auth.token`
- The file may use JSON5 syntax (trailing commas, comments) — use a lenient parser or strip comments first

## Local Service Endpoints (for testing)
- **STT**: `POST http://127.0.0.1:18790/transcribe` (Content-Type: audio/wav, returns `{"text": "..."}`)
- **TTS**: `POST http://127.0.0.1:18790/synthesize` (Content-Type: text/plain, returns WAV audio)
- **Chat**: `POST http://127.0.0.1:18789/v1/chat/completions` (OpenAI-compatible, needs Bearer token)

## Definition of Done
- [ ] App launches and shows icon in menu bar
- [ ] Clicking icon shows dropdown menu with status, Toggle Listening, New Conversation, Settings, Quit
- [ ] Cmd+Shift+G toggles listening (with Accessibility permission prompt on first use)
- [ ] Recording captures mic audio as WAV
- [ ] STT endpoint receives audio and returns transcript
- [ ] Chat endpoint receives transcript and returns response
- [ ] TTS endpoint receives response text and returns audio
- [ ] Audio plays through speakers
- [ ] Floating overlay appears during conversation with transcript text
- [ ] `swift build -c release` compiles with no errors or warnings
- [ ] App can be packaged as a .app bundle
