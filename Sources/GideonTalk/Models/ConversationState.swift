import Foundation

enum ConversationState: Equatable {
    case idle
    case listening
    case thinking
    case speaking
    case error(String)
    
    var statusText: String {
        switch self {
        case .idle:
            return "Ready"
        case .listening:
            return "Listening..."
        case .thinking:
            return "Thinking..."
        case .speaking:
            return "Speaking..."
        case .error(let message):
            return "Error: \(message)"
        }
    }
    
    var statusIcon: String {
        switch self {
        case .idle:
            return "mic.slash"
        case .listening:
            return "mic"
        case .thinking:
            return "sparkles"
        case .speaking:
            return "speaker.wave.2"
        case .error:
            return "exclamationmark.triangle"
        }
    }
}

@MainActor
class StateManager: ObservableObject {
    static let shared = StateManager()
    
    @Published var state: ConversationState = .idle
    @Published var currentTranscript: String = ""
    @Published var currentResponse: String = ""
    @Published var error: String?
    
    private init() {}
}
