import SwiftUI

struct AvatarView: View {
    let state: ConversationState
    
    @State private var glowProgress: CGFloat = 0
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            // Glow ring
            Circle()
                .stroke(
                    ringColor.opacity(0.8),
                    lineWidth: 3
                )
                .frame(width: 52, height: 52)
                .overlay(
                    Circle()
                        .trim(from: 0, to: glowProgress)
                        .stroke(
                            ringColor,
                            lineWidth: 3
                        )
                        .frame(width: 52, height: 52)
                )
            
            // Avatar image or placeholder
            avatarImage
                .frame(width: 48, height: 48)
                .clipShape(Circle())
        }
        .onAppear {
            isAnimating = true
            startAnimation()
        }
        .onDisappear {
            isAnimating = false
        }
        .onChange(of: state) {
            startAnimation()
        }
    }
    
    @ViewBuilder
    private var avatarImage: some View {
        if let image = loadAvatarImage() {
            Image(nsImage: image)
                .resizable()
                .scaledToFill()
        } else {
            ZStack {
                Circle()
                    .fill(Color.gray.opacity(0.3))
                Image(systemName: "person.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.white.opacity(0.7))
            }
        }
    }
    
    private var ringColor: Color {
        switch state {
        case .idle:
            return Color.gray.opacity(0.5)
        case .listening:
            return Color(red: 14/255, green: 165/255, blue: 163/255) // Nebula Teal
        case .thinking:
            return Color(red: 212/255, green: 168/255, blue: 83/255) // Stellar Gold
        case .speaking:
            return Color(red: 56/255, green: 189/255, blue: 248/255) // Aurora Cyan
        case .error:
            return Color.red.opacity(0.8)
        }
    }
    
    private func loadAvatarImage() -> NSImage? {
        let path = NSString(string: ConfigManager.shared.avatarPath).expandingTildeInPath
        return NSImage(contentsOfFile: path)
    }
    
    private func startAnimation() {
        guard state != .idle else {
            glowProgress = 0
            return
        }
        
        withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
            glowProgress = 1.0
        }
    }
}
