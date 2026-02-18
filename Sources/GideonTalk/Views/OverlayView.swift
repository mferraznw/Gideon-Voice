import SwiftUI

struct OverlayView: View {
    @StateObject private var stateManager = StateManager.shared
    
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
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
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
                        .transition(.opacity)
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
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                }
            }
            .frame(maxWidth: .infinity)
            .animation(.easeInOut(duration: 0.2), value: stateManager.state)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
                .overlay(Color.black.opacity(0.28).clipShape(RoundedRectangle(cornerRadius: 12)))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
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
