import Foundation

actor TTSService {
    static let shared = TTSService()
    
    private init() {}
    
    func synthesize(text: String, url: String, speed: Double) async throws -> Data {
        // Try OpenAI TTS first, fall back to StellaVoice
        let openAIKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"] ?? ""
        
        if !openAIKey.isEmpty {
            return try await synthesizeOpenAI(text: text, apiKey: openAIKey, speed: speed)
        } else {
            return try await synthesizeStella(text: text, url: url, speed: speed)
        }
    }
    
    private func synthesizeOpenAI(text: String, apiKey: String, speed: Double) async throws -> Data {
        guard let url = URL(string: "https://api.openai.com/v1/audio/speech") else {
            throw TTSError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 30
        
        let body: [String: Any] = [
            "model": "tts-1",
            "input": text,
            "voice": "echo",
            "speed": speed,
            "response_format": "mp3"
        ]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        print("[TTSService] Using OpenAI TTS (echo), \(text.count) chars")
        let (responseData, httpResponse) = try await URLSession.shared.data(for: request)
        
        if let http = httpResponse as? HTTPURLResponse, http.statusCode != 200 {
            let errorText = String(data: responseData.prefix(200), encoding: .utf8) ?? "unknown"
            print("[TTSService] OpenAI TTS error \(http.statusCode): \(errorText)")
            throw TTSError.apiFailed
        }
        
        print("[TTSService] OpenAI TTS success: \(responseData.count) bytes")
        return responseData
    }
    
    private func synthesizeStella(text: String, url: String, speed: Double) async throws -> Data {
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
        
        print("[TTSService] Using StellaVoice TTS, \(text.count) chars")
        let (responseData, _) = try await URLSession.shared.data(for: request)
        return responseData
    }
}

enum TTSError: Error {
    case invalidURL
    case apiFailed
}
