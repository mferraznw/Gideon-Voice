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
            "model": model,
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

    func chatStreaming(
        messages: [[String: String]],
        baseURL: String,
        token: String,
        model: String,
        onPartial: @MainActor @escaping (String) -> Void,
        onSentence: @MainActor @escaping (String) -> Void
    ) async throws -> String {
        guard let url = URL(string: baseURL) else {
            throw ChatError.invalidURL
        }

        var request = URLRequest(url: url.appendingPathComponent("v1/chat/completions"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("main", forHTTPHeaderField: "x-openclaw-agent-id")
        request.setValue("agent:main:main", forHTTPHeaderField: "x-openclaw-session-key")

        let body: [String: Any] = [
            "model": model,
            "messages": messages,
            "user": "voice",
            "stream": true
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 120

        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        if let http = response as? HTTPURLResponse, http.statusCode >= 400 {
            throw ChatError.invalidResponse
        }

        var fullText = ""
        var sentenceBuffer = ""

        for try await rawLine in bytes.lines {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty, line.hasPrefix("data:") else { continue }

            let payload = String(line.dropFirst(5)).trimmingCharacters(in: .whitespaces)
            if payload == "[DONE]" { break }

            guard let data = payload.data(using: .utf8),
                  let event = try? JSONDecoder().decode(ChatStreamEvent.self, from: data),
                  let chunk = event.choices.first?.delta.content,
                  !chunk.isEmpty else {
                continue
            }

            fullText += chunk
            sentenceBuffer += chunk
            await onPartial(fullText)

            while let sentence = nextSentence(from: &sentenceBuffer) {
                await onSentence(sentence)
            }
        }

        let trailing = sentenceBuffer.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trailing.isEmpty {
            await onSentence(trailing)
        }

        return fullText
    }

    private func nextSentence(from buffer: inout String) -> String? {
        let delimiters = [". ", "! ", "? ", "\n"]
        var earliestRange: Range<String.Index>?

        for delimiter in delimiters {
            if let range = buffer.range(of: delimiter) {
                if let earliestRange, range.lowerBound >= earliestRange.lowerBound {
                    continue
                }
                earliestRange = range
            }
        }

        guard let range = earliestRange else {
            return nil
        }

        let sentenceEnd: String.Index
        if buffer[range].hasSuffix("\n") {
            sentenceEnd = range.lowerBound
        } else {
            sentenceEnd = buffer.index(after: range.lowerBound)
        }

        let sentence = String(buffer[..<sentenceEnd]).trimmingCharacters(in: .whitespacesAndNewlines)
        buffer = String(buffer[range.upperBound...])
        return sentence.isEmpty ? nil : sentence
    }
}

enum ChatError: Error {
    case invalidURL
    case invalidResponse
}

private struct ChatStreamEvent: Decodable {
    let choices: [Choice]

    struct Choice: Decodable {
        let delta: Delta
    }

    struct Delta: Decodable {
        let content: String?
    }
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
