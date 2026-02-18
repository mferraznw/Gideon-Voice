import Foundation

actor STTService {
    static let shared = STTService()
    
    private init() {}
    
    func transcribe(audio data: Data, url: String) async throws -> String {
        guard let baseURL = URL(string: url) else {
            throw STTError.invalidURL
        }
        
        var request = URLRequest(url: baseURL.appendingPathComponent("transcribe"))
        request.httpMethod = "POST"
        request.setValue("audio/wav", forHTTPHeaderField: "Content-Type")
        request.httpBody = data
        
        let (responseData, _) = try await URLSession.shared.data(for: request)
        
        let response = try JSONDecoder().decode(STTResponse.self, from: responseData)
        return response.text
    }
}

enum STTError: Error {
    case invalidURL
}

struct STTResponse: Decodable {
    let text: String
}
