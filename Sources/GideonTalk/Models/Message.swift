import Foundation

struct Message: Equatable {
    let role: String
    let content: String
    let timestamp: Date
    
    init(role: String, content: String) {
        self.role = role
        self.content = content
        self.timestamp = Date()
    }
}

@MainActor
class ConversationManager: ObservableObject {
    static let shared = ConversationManager()
    
    private(set) var messages: [Message] = []
    private let maxMessages = 20 // 10 exchanges
    
    private init() {}
    
    func addMessage(role: String, content: String) {
        messages.append(Message(role: role, content: content))
        
        // Keep only last 20 messages
        if messages.count > maxMessages {
            messages.removeFirst(messages.count - maxMessages)
        }
    }
    
    func getMessages() -> [[String: String]] {
        messages.map { ["role": $0.role, "content": $0.content] }
    }
    
    func clearHistory() {
        messages.removeAll()
    }
}
