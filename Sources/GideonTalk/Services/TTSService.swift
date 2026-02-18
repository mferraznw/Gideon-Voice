import Foundation

actor TTSService {
    static let shared = TTSService()
    
    private init() {}
    
    func synthesize(text: String, url: String, speed: Double) async throws -> Data {
        guard let baseURL = URL(string: url) else {
            throw TTSError.invalidURL
        }
        
        var components = URLComponents(url: baseURL.appendingPathComponent("synthesize"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "speed", value: String(speed))
        ]
        
        guard let finalURL = components.url else {
            throw TTSError.invalidURL
        }
        
        var request = URLRequest(url: finalURL)
        request.httpMethod = "POST"
        request.setValue("text/plain", forHTTPHeaderField: "Content-Type")
        request.httpBody = text.data(using: .utf8)
        
        let (responseData, _) = try await URLSession.shared.data(for: request)
        return responseData
    }
}

enum TTSError: Error {
    case invalidURL
}
