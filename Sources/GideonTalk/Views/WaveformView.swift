import SwiftUI

struct WaveformView: View {
    @State private var levels: [CGFloat] = Array(repeating: 0.3, count: 7)
    @State private var isAnimating = false
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<7, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color(red: 14/255, green: 165/255, blue: 163/255)) // Nebula Teal
                    .frame(width: 4, height: levels[index] * 40)
                    .animation(
                        .easeInOut(duration: 0.1)
                            .repeatForever(autoreverses: true),
                        value: levels[index]
                    )
            }
        }
        .onAppear {
            animate()
        }
        .onDisappear {
            isAnimating = false
        }
    }
    
    private func animate() {
        isAnimating = true
        
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
            guard isAnimating else {
                timer.invalidate()
                return
            }
            
            for i in 0..<7 {
                levels[i] = CGFloat.random(in: 0.2...1.0)
            }
        }
    }
}

struct ThinkingView: View {
    @State private var progress: CGFloat = 0
    
    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(Color(red: 212/255, green: 168/255, blue: 83/255)) // Stellar Gold
                    .frame(width: 8, height: 8)
                    .scaleEffect(progress > CGFloat(i) * 0.33 ? 1.2 : 0.8)
                    .opacity(progress > CGFloat(i) * 0.33 ? 1 : 0.5)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: false)) {
                progress = 1
            }
        }
    }
}

struct SpeakingBarsView: View {
    @State private var levels: [CGFloat] = Array(repeating: 0.5, count: 5)
    @State private var isAnimating = false
    
    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<5, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color(red: 56/255, green: 189/255, blue: 248/255)) // Aurora Cyan
                    .frame(width: 5, height: levels[index] * 30)
                    .animation(
                        .easeInOut(duration: 0.08)
                            .repeatForever(autoreverses: true),
                        value: levels[index]
                    )
            }
        }
        .onAppear {
            isAnimating = true
            animate()
        }
        .onDisappear {
            isAnimating = false
        }
    }
    
    private func animate() {
        Timer.scheduledTimer(withTimeInterval: 0.08, repeats: true) { timer in
            guard isAnimating else {
                timer.invalidate()
                return
            }
            
            for i in 0..<5 {
                levels[i] = CGFloat.random(in: 0.3...1.0)
            }
        }
    }
}
