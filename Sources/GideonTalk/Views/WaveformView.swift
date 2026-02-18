import SwiftUI

struct WaveformView: View {
    @ObservedObject private var recorder = AudioRecorder.shared
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<7, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color(red: 14/255, green: 165/255, blue: 163/255)) // Nebula Teal
                    .frame(width: 4, height: max(4, recorder.micLevels[index] * 40))
                    .animation(.spring(response: 0.2, dampingFraction: 0.75), value: recorder.micLevels[index])
            }
        }
    }
}

struct ThinkingView: View {
    @State private var phase: CGFloat = 0
    
    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<3, id: \.self) { i in
                let pulse = max(0, CGFloat(Darwin.sin(Double(phase + CGFloat(i) * 0.5))))
                Circle()
                    .fill(Color(red: 212/255, green: 168/255, blue: 83/255)) // Stellar Gold
                    .frame(width: 8, height: 8)
                    .scaleEffect(0.75 + 0.35 * pulse)
                    .opacity(0.5 + 0.5 * pulse)
            }
        }
        .animation(.easeInOut(duration: 0.18), value: phase)
        .onAppear {
            withAnimation(.linear(duration: 1.0).repeatForever(autoreverses: false)) {
                phase = .pi * 2
            }
        }
    }
}

struct SpeakingBarsView: View {
    @ObservedObject private var player = AudioPlayer.shared
    
    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<5, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color(red: 56/255, green: 189/255, blue: 248/255)) // Aurora Cyan
                    .frame(width: 5, height: max(4, player.levels[index] * 30))
                    .animation(.spring(response: 0.15, dampingFraction: 0.7), value: player.levels[index])
            }
        }
    }
}
