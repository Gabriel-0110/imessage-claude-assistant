import Foundation

/// Reads the bridge token and port from the bun server's preferences file.
struct PreferencesReader {
    static let preferencesURL: URL = {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home
            .appendingPathComponent(".claude")
            .appendingPathComponent("channels")
            .appendingPathComponent("imessage")
            .appendingPathComponent("style")
            .appendingPathComponent("preferences.json")
    }()

    struct BridgeConfig {
        let token: String
        let port: Int
    }

    static func readBridgeConfig() throws -> BridgeConfig {
        let data = try Data(contentsOf: preferencesURL)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ConfigError.invalidFormat
        }
        guard let token = json["bridgeToken"] as? String, token.count >= 32 else {
            throw ConfigError.missingToken
        }
        let port = json["bridgePort"] as? Int ?? 7842
        return BridgeConfig(token: token, port: port)
    }

    enum ConfigError: LocalizedError {
        case invalidFormat
        case missingToken

        var errorDescription: String? {
            switch self {
            case .invalidFormat: return "preferences.json has unexpected format"
            case .missingToken: return "Bridge token not found. Start the bun server first to generate it."
            }
        }
    }
}
