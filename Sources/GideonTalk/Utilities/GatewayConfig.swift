import Foundation

struct GatewayConfig {
    static func readToken() -> String? {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let configURL = home.appendingPathComponent(".openclaw/openclaw.json")
        
        guard let data = try? Data(contentsOf: configURL) else {
            return nil
        }
        
        // Try to parse as JSON
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            return extractToken(from: json)
        }
        
        // Try to parse as JSON5 (relaxed parsing)
        return parseJSON5(data: data)
    }
    
    private static func extractToken(from json: [String: Any]) -> String? {
        if let gateway = json["gateway"] as? [String: Any],
           let auth = gateway["auth"] as? [String: Any],
           let token = auth["token"] as? String {
            return token
        }
        return nil
    }
    
    private static func parseJSON5(data: Data) -> String? {
        // Basic JSON5 parsing - remove comments and trailing commas
        guard var string = String(data: data, encoding: .utf8) else {
            return nil
        }
        
        // Remove single-line comments
        string = string.replacingOccurrences(
            of: "//[^\n]*",
            with: "",
            options: .regularExpression
        )
        
        // Remove multi-line comments
        string = string.replacingOccurrences(
            of: "/\\*[^*]*\\*+(?:[^/*][^*]*\\*+)*/",
            with: "",
            options: .regularExpression
        )
        
        // Remove trailing commas before } or ]
        string = string.replacingOccurrences(
            of: ",\\s*([}\\]])",
            with: "$1",
            options: .regularExpression
        )
        
        guard let cleanedData = string.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: cleanedData) as? [String: Any] else {
            return nil
        }
        
        return extractToken(from: json)
    }
}
