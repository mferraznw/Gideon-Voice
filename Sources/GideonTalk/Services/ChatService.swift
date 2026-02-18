import Foundation

actor ChatService {
    static let shared = ChatService()
    
    private init() {}
    
    func chat(messages: [[String: String]], baseURL: String, token: String, model: String) async throws -> String {
        guard let url = URL(string: baseURL) else {
            throw ChatError.invalidURL
        }
        
        var request = URLRequest(url: url.appendingPathComponent("v1/chat/completions"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        // Route to the main Gideon agent session so voice has full context
        request.setValue("main", forHTTPHeaderField: "x-openclaw-agent-id")
        request.setValue("agent:main:main", forHTTPHeaderField: "x-openclaw-session-key")
        
        let body: [String: Any] = [
            "model": "openclaw:main",
            "messages": messages,
            "user": "voice",
            "stream": false
        ]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 60
        
        print("[ChatService] Sending to gateway: \(messages.last?["content"]?.prefix(80) ?? "empty")")
        
        let (responseData, httpResponse) = try await URLSession.shared.data(for: request)
        
        if let http = httpResponse as? HTTPURLResponse {
            print("[ChatService] Response status: \(http.statusCode)")
        }
        
        let response = try JSONDecoder().decode(ChatResponse.self, from: responseData)
        let reply = response.choices.first?.message.content ?? ""
        print("[ChatService] Got reply: \(reply.prefix(80))")
        return reply
    }
}

enum ChatError: Error {
    case invalidURL
}

struct ChatResponse: Decodable {
    let choices: [Choice]
    
    struct Choice: Decodable {
        let message: MessageContent
    }
    
    struct MessageContent: Decodable {
        let content: String
    }
}
