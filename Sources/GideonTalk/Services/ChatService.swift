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
        
        let body: [String: Any] = [
            "model": model,
            "messages": systemMessage() + messages,
            "stream": false
        ]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        let (responseData, _) = try await URLSession.shared.data(for: request)
        
        let response = try JSONDecoder().decode(ChatResponse.self, from: responseData)
        return response.choices.first?.message.content ?? ""
    }
    
    private func systemMessage() -> [[String: String]] {
        [
            [
                "role": "system",
                "content": "You are Gideon, a voice assistant. Keep responses concise and conversational. You're speaking out loud, so be natural — no markdown, no bullet points, no code blocks."
            ]
        ]
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
