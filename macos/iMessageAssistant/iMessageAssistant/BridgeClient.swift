import Foundation

// MARK: - Models

struct PendingThread: Identifiable, Decodable {
    let chat_guid: String
    let kind: String          // "dm" or "group"
    let display_name: String? // named group chats
    let participants: [String]
    let last_ts: String
    let last_preview: String? // server field name
    let unreplied: Bool

    var id: String { chat_guid }
    var preview: String? { last_preview } // UI shim

    var displayName: String {
        if let d = display_name, !d.isEmpty { return d }
        return participants.first ?? chat_guid
    }

    var relativeTime: String {
        guard let date = ISO8601DateFormatter().date(from: last_ts) else { return last_ts }
        let diff = Date().timeIntervalSince(date)
        switch diff {
        case ..<60: return "just now"
        case ..<3600: return "\(Int(diff / 60))m ago"
        case ..<86400: return "\(Int(diff / 3600))h ago"
        default: return "\(Int(diff / 86400))d ago"
        }
    }
}

struct DraftContext: Decodable {
    let chat_guid: String
    let kind: String
    let participants: [String]
    let primary_contact: String?   // server field name
    let recent_thread: String      // pre-formatted by server's renderConversation()
    let drafting_context: DraftingContext?

    struct DraftingContext: Decodable {
        let tone: String?
        let contact_style_notes: String?
        let custom_instructions: String?
        let contact_custom_instructions: String?
        let global_style_profile: String?
    }

    // Shims for DraftService / UI compatibility
    var formattedThread: String { recent_thread }
    var contact_handle: String? { primary_contact }
    var style_notes: String? { drafting_context?.contact_style_notes }
}

struct DraftOption: Identifiable, Equatable {
    let id = UUID()
    let label: String
    let text: String
}

// MARK: - BridgeClient

actor BridgeClient {
    static let shared = BridgeClient()

    private var config: PreferencesReader.BridgeConfig?

    private func baseURL() throws -> URL {
        let cfg = try loadConfig()
        guard let url = URL(string: "http://localhost:\(cfg.port)") else {
            throw BridgeError.invalidURL
        }
        return url
    }

    private func authHeader() throws -> String {
        let cfg = try loadConfig()
        return "Bearer \(cfg.token)"
    }

    private func loadConfig() throws -> PreferencesReader.BridgeConfig {
        if let c = config { return c }
        let c = try PreferencesReader.readBridgeConfig()
        config = c
        return c
    }

    func invalidateConfig() {
        config = nil
    }

    // MARK: Public API

    func fetchPending(lookbackHours: Int = 2) async throws -> [PendingThread] {
        var url = try baseURL().appendingPathComponent("v1/pending")
        url.append(queryItems: [
            URLQueryItem(name: "lookback_hours", value: "\(lookbackHours)"),
            URLQueryItem(name: "max", value: "20"),
        ])
        var req = URLRequest(url: url, timeoutInterval: 5)
        req.setValue(try authHeader(), forHTTPHeaderField: "Authorization")
        let (data, resp) = try await URLSession.shared.data(for: req)
        try validate(resp)
        let decoded = try JSONDecoder().decode(PendingResponse.self, from: data)
        return decoded.threads
    }

    func fetchDraftContext(chatGuid: String) async throws -> DraftContext {
        var url = try baseURL().appendingPathComponent("v1/draft")
        url.append(queryItems: [URLQueryItem(name: "chat_guid", value: chatGuid)])
        var req = URLRequest(url: url, timeoutInterval: 5)
        req.setValue(try authHeader(), forHTTPHeaderField: "Authorization")
        let (data, resp) = try await URLSession.shared.data(for: req)
        try validate(resp)
        return try JSONDecoder().decode(DraftContext.self, from: data)
    }

    func sendReply(chatGuid: String, text: String, signature: String?) async throws {
        let url = try baseURL().appendingPathComponent("v1/reply")
        var req = URLRequest(url: url, timeoutInterval: 10)
        req.httpMethod = "POST"
        req.setValue(try authHeader(), forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        var body: [String: String] = ["chat_guid": chatGuid, "text": text]
        if let sig = signature { body["signature"] = sig }
        req.httpBody = try JSONEncoder().encode(body)
        let (_, resp) = try await URLSession.shared.data(for: req)
        try validate(resp)
    }

    func healthCheck() async -> Bool {
        guard let url = try? baseURL().appendingPathComponent("v1/health"),
              let auth = try? authHeader() else { return false }
        var req = URLRequest(url: url, timeoutInterval: 3)
        req.setValue(auth, forHTTPHeaderField: "Authorization")
        guard let (_, resp) = try? await URLSession.shared.data(for: req),
              let http = resp as? HTTPURLResponse else { return false }
        return http.statusCode == 200
    }

    // MARK: Helpers

    private func validate(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else { throw BridgeError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else { throw BridgeError.httpError(http.statusCode) }
    }

    enum BridgeError: LocalizedError {
        case invalidURL
        case invalidResponse
        case httpError(Int)

        var errorDescription: String? {
            switch self {
            case .invalidURL: return "Invalid bridge URL"
            case .invalidResponse: return "Invalid response from bridge"
            case .httpError(let code): return "Bridge returned HTTP \(code)"
            }
        }
    }
}

private struct PendingResponse: Decodable {
    let threads: [PendingThread]
}
