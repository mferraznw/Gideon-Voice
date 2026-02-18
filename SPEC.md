# GideonTalk.app — Voice Assistant for macOS

## Overview
A native Swift/SwiftUI macOS menu bar app that provides a tap-to-toggle voice conversation interface with an AI assistant (Gideon). Fully local STT and TTS via StellaVoice daemon, AI brain via OpenAI-compatible chatCompletions endpoint on the local gateway.

## Architecture

```
[Mic] → AVAudioEngine → WAV buffer
  → POST http://127.0.0.1:18790/transcribe (local STT)
  → POST http://127.0.0.1:18789/v1/chat/completions (gateway AI)
  → POST http://127.0.0.1:18790/synthesize (local TTS)
  → AVAudioPlayer → [Speakers]
```

All three services run locally. Zero cloud dependency for STT/TTS. The gateway handles AI routing (Anthropic, OpenRouter, etc).

## Requirements
- macOS 14.0+ (Sonoma), Apple Silicon
- Swift 5.9+, SwiftUI
- No external dependencies (no SPM packages if possible, or minimal)
- Permissions: Microphone, Accessibility (for global hotkey)

## User Experience

### Menu Bar
- **Icon**: Custom SF Symbol or small Gideon avatar (⚔️ as fallback)
- **States**:
  - Idle: Static icon
  - Listening: Icon pulses with accent color
  - Thinking: Icon rotates or shimmers
  - Speaking: Icon has audio wave indicator
- **Click**: Opens settings/status dropdown
- **Global Hotkey**: `Cmd+Shift+G` (configurable) — tap to toggle listening

### Floating Overlay (the "Orb")
When active, a floating translucent panel appears (like Spotlight but smaller):

```
┌─────────────────────────────────────┐
│  [Gideon Avatar]  ⚔️ Gideon         │
│                                      │
│  ≋≋≋≋≋≋≋≋ (waveform animation)     │  ← While user is speaking
│  "What's on my calendar today?"      │  ← Live transcript of user
│                                      │
│  ✨ Thinking...                      │  ← While waiting for AI
│                                      │
│  🔊 ▮▮▯▮▮▯▮ (audio visualization)  │  ← While Gideon speaks
│  "You have a meeting at 2 PM with…" │  ← Gideon's response text
│                                      │
└─────────────────────────────────────┘
```

**Overlay Behavior:**
- Appears on hotkey activation (slide down from menu bar or fade in center-top)
- Stays visible during entire conversation turn
- Auto-fades 3 seconds after Gideon finishes speaking
- Can be dismissed with Escape
- Translucent/vibrancy material background (NSVisualEffectView / .ultraThinMaterial)
- Always on top, non-activating (doesn't steal focus from current app)
- Draggable to reposition

### Gideon Avatar in Overlay
- Display the avatar image from `~/Pictures/MyGideon.png` (the suited android butler)
- Circular crop, ~48pt, top-left of the overlay
- Subtle glow/ring animation that matches current state:
  - Idle: Dim ring
  - Listening: Blue pulse
  - Thinking: Gold shimmer
  - Speaking: Teal/cyan wave

## Conversation Flow

### Tap-to-Toggle Mode
1. User presses `Cmd+Shift+G`
2. Overlay appears, mic starts recording
3. Menu bar icon pulses (listening state)
4. User speaks naturally
5. User presses `Cmd+Shift+G` again (or silence detection after 2s pause)
6. Recording stops
7. Audio sent to STT endpoint → transcript displayed
8. Transcript sent to chatCompletions → response streamed
9. Response text displayed + sent to TTS → audio plays
10. Overlay fades after playback completes

### Silence Detection (optional, Phase 2)
- Use `AVAudioEngine` input level monitoring
- After 2 seconds of silence below threshold, auto-stop recording
- Visual indicator showing silence countdown

## API Integration

### STT (Speech-to-Text)
```
POST http://127.0.0.1:18790/transcribe
Content-Type: audio/wav
Body: <raw WAV audio data>
Response: {"text": "transcribed text here"}
```

### AI (Chat Completions)
```
POST http://127.0.0.1:18789/v1/chat/completions
Content-Type: application/json
Authorization: Bearer <gateway-token>

{
  "model": "anthropic/claude-opus-4-6",
  "messages": [
    {"role": "system", "content": "You are Gideon, a voice assistant. Keep responses concise and conversational. You're speaking out loud, so be natural — no markdown, no bullet points, no code blocks."},
    {"role": "user", "content": "<transcribed text>"}
  ],
  "stream": false
}
```

**Gateway auth token**: Read from `~/.openclaw/openclaw.json` at path `gateway.auth.token`, or accept as a config field in the app.

### TTS (Text-to-Speech)
```
POST http://127.0.0.1:18790/synthesize
Content-Type: text/plain
Body: <response text>
Response: WAV audio data
```

Optional speed control: `POST http://127.0.0.1:18790/synthesize?speed=1.0`

## Configuration (Settings Panel)

Accessible from menu bar dropdown → Settings:

| Setting | Default | Description |
|---------|---------|-------------|
| Hotkey | Cmd+Shift+G | Global toggle hotkey |
| Gateway URL | http://127.0.0.1:18789 | OpenClaw gateway |
| Gateway Token | (from config) | Auth token |
| STT URL | http://127.0.0.1:18790 | StellaVoice endpoint |
| TTS URL | http://127.0.0.1:18790 | StellaVoice endpoint |
| TTS Speed | 1.0 | Speech speed (0.5-2.0) |
| Model | (default) | Model override for voice |
| Avatar Path | ~/Pictures/MyGideon.png | Avatar image |
| Silence Timeout | 2.0s | Auto-stop after silence |
| Auto-fade Delay | 3.0s | Overlay fade after response |
| Launch at Login | false | Auto-start |

Store in UserDefaults or a JSON config at `~/.config/gideon-talk/config.json`.

## Conversation History

- Maintain a rolling conversation history (last 10 exchanges) in memory
- Send as messages array to chatCompletions for context continuity
- Clear history on app restart or via menu option "New Conversation"
- Optionally: persist history to disk for session resume

## Visual Design

### Color Palette (matches SolutionsMark.com "Deep Space Professional")
- **Background**: Ultra-thin material with dark tint
- **Accent/Listening**: Nebula Teal `#0EA5A3`
- **Thinking**: Stellar Gold `#D4A853`  
- **Speaking**: Aurora Cyan `#38BDF8`
- **Text**: White with 90% opacity
- **Subtitle**: White with 60% opacity

### Typography
- Title: SF Pro Medium, 14pt
- Transcript: SF Pro Regular, 13pt
- Status text: SF Pro Regular, 11pt, 60% opacity

### Animations
- Waveform: Sinusoidal bars (5-7 bars) animating height based on mic input level
- Thinking: Three dots pulsing, or a subtle circular shimmer around avatar
- Speaking: Audio level visualization (bars or circular equalizer around avatar)
- Transitions: Spring animations for overlay appear/dismiss

## Project Structure

```
GideonTalk/
├── GideonTalkApp.swift          # App entry, menu bar setup
├── Models/
│   ├── ConversationState.swift  # State machine (idle/listening/thinking/speaking)
│   └── Message.swift            # Chat message model
├── Services/
│   ├── AudioRecorder.swift      # AVAudioEngine mic capture → WAV
│   ├── STTService.swift         # POST to StellaVoice /transcribe
│   ├── ChatService.swift        # POST to gateway /v1/chat/completions
│   ├── TTSService.swift         # POST to StellaVoice /synthesize
│   └── AudioPlayer.swift        # AVAudioPlayer for TTS playback
├── Views/
│   ├── MenuBarView.swift        # NSStatusItem + dropdown menu
│   ├── OverlayWindow.swift      # Floating panel (NSPanel)
│   ├── OverlayView.swift        # SwiftUI overlay content
│   ├── WaveformView.swift       # Animated waveform visualization
│   ├── AvatarView.swift         # Circular avatar with state ring
│   └── SettingsView.swift       # Settings panel
├── Utilities/
│   ├── HotkeyManager.swift      # Global hotkey registration
│   ├── ConfigManager.swift      # Settings persistence
│   └── GatewayConfig.swift      # Read token from openclaw.json
├── Assets.xcassets/
│   └── AppIcon.appiconset/
└── Info.plist
```

## Build & Run

```bash
# Clone and build
cd ~/repos/GideonTalk
swift build

# Or open in Xcode
open Package.swift

# Run
swift run GideonTalk
# OR
.build/debug/GideonTalk
```

## Phase 1 (MVP)
- [x] Menu bar icon with state indication
- [x] Global hotkey tap-to-toggle
- [x] Mic recording → WAV
- [x] STT via StellaVoice
- [x] Chat via gateway chatCompletions
- [x] TTS via StellaVoice
- [x] Audio playback
- [x] Basic floating overlay with transcript text
- [x] Avatar display

## Phase 2 (Polish)
- [ ] Waveform animation (real mic levels)
- [ ] Thinking/speaking animations
- [ ] Avatar glow states
- [ ] Silence detection auto-stop
- [ ] Settings panel
- [ ] Conversation history (rolling context)
- [ ] Launch at login
- [ ] Auto-read gateway token from openclaw.json
- [ ] Drag to reposition overlay
- [ ] Escape to dismiss

## Phase 3 (Advanced)
- [ ] Streaming chatCompletions (show text as it arrives)
- [ ] Streaming TTS (start speaking before full response)
- [ ] Wake word detection ("Hey Gideon")
- [ ] Interrupt support (talk while Gideon is speaking to cut in)
- [ ] Multi-turn conversation awareness
- [ ] Screen context (optional: capture screen for visual context)

## Key Implementation Notes

1. **Non-activating window**: The overlay must NOT steal focus. Use `NSPanel` with `.nonactivatingPanel` style and `level: .floating`.

2. **Audio format**: Record at 16kHz mono WAV for STT. StellaVoice expects standard WAV.

3. **Gateway auth**: The token is in `~/.openclaw/openclaw.json` at `gateway.auth.token`. Parse the JSON5/JSON to extract it.

4. **Hotkey registration**: Use `CGEvent.tapCreate` for global hotkey capture, or the `HotKey` SPM package for simplicity.

5. **Menu bar only**: Set `LSUIElement = true` in Info.plist so the app doesn't appear in the Dock.

6. **Thread safety**: Audio recording and network calls on background threads. UI updates on main thread via `@MainActor`.

7. **Error handling**: If StellaVoice isn't running, show a status indicator in the menu dropdown. Same for gateway connectivity.
