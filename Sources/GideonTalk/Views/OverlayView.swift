import SwiftUI

struct OverlayView: View {
    @StateObject private var stateManager = StateManager.shared
    @State private var position: CGPoint = .zero
    @State private var isDragging = false
    
    var body: some View {
        VStack(spacing: 12) {
            // Header
            HStack {
                AvatarView(state: stateManager.state)
                    .frame(width: 48, height: 48)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Gideon")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.9))
                    
                    Text(stateManager.state.statusText)
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.6))
                }
                
                Spacer()
            }
            
            Divider()
                .background(Color.white.opacity(0.2))
            
            // Content
            VStack(spacing: 8) {
                // Waveform while listening
                if stateManager.state == .listening {
                    WaveformView()
                        .frame(height: 40)
                }
                
                // User transcript
                if !stateManager.currentTranscript.isEmpty {
                    Text(stateManager.currentTranscript)
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                }
                
                // Thinking indicator
                if stateManager.state == .thinking {
                    ThinkingView()
                }
                
                // Response
                if !stateManager.currentResponse.isEmpty {
                    Text(stateManager.currentResponse)
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                }
                
                // Speaking visualization
                if stateManager.state == .speaking {
                    SpeakingBarsView()
                        .frame(height: 30)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding(16)
        .background(
            VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                .cornerRadius(12)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
        .gesture(
            DragGesture()
                .onChanged { value in
                    if let window = NSApp.keyWindow as? NSPanel {
                        var newOrigin = window.frame.origin
                        newOrigin.x += value.translation.width
                        newOrigin.y -= value.translation.height
                        window.setFrameOrigin(newOrigin)
                    }
                }
        )
    }
}

struct VisualEffectView: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}
