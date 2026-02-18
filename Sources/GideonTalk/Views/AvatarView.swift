import SwiftUI

struct AvatarView: View {
    let state: ConversationState

    @State private var ringScale: CGFloat = 1
    @State private var ringOpacity: Double = 0.8
    @State private var ringTrim: CGFloat = 1
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(ringColor.opacity(0.3), lineWidth: 2)
                .frame(width: 56, height: 56)

            Circle()
                .trim(from: 0, to: ringTrim)
                .stroke(ringColor.opacity(ringOpacity), lineWidth: 3)
                .frame(width: 56, height: 56)
                .scaleEffect(ringScale)
                .rotationEffect(state == .thinking ? .degrees(360) : .zero)
                .overlay(
                    Circle()
                        .stroke(ringColor.opacity(0.2), lineWidth: 10)
                        .blur(radius: state == .idle ? 0 : 5)
                        .opacity(state == .idle ? 0 : 1)
                )

            avatarImage
                .frame(width: 48, height: 48)
                .clipShape(Circle())
        }
        .onAppear {
            startAnimation()
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
        switch state {
        case .idle:
            ringTrim = 1
            ringScale = 1
            ringOpacity = 0.4
        case .listening:
            ringTrim = 1
            ringOpacity = 1
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                ringScale = 1.08
            }
        case .thinking:
            ringTrim = 0.72
            ringScale = 1
            ringOpacity = 1
            withAnimation(.linear(duration: 1.0).repeatForever(autoreverses: false)) {
                ringTrim = 1
            }
        case .speaking:
            ringTrim = 0.9
            ringOpacity = 1
            withAnimation(.interpolatingSpring(stiffness: 120, damping: 9).repeatForever(autoreverses: true)) {
                ringScale = 1.12
            }
        case .error:
            ringTrim = 1
            ringScale = 1
            ringOpacity = 1
        }
    }
}
