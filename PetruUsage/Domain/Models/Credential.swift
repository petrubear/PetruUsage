import Foundation

struct OAuthCredential {
    let accessToken: String
    var refreshToken: String?
    var expiresAt: Date?
    let source: CredentialSource
    var subscriptionType: String? = nil

    var isExpired: Bool {
        guard let expiresAt else { return false }
        return Date() >= expiresAt
    }

    var needsRefresh: Bool {
        guard let expiresAt else { return false }
        let buffer: TimeInterval = 5 * 60
        return Date().addingTimeInterval(buffer) >= expiresAt
    }
}

enum CredentialSource {
    case file(path: String)
    case keychain(service: String)
    case sqlite(dbPath: String, key: String)
}

struct TokenRefreshResult {
    let accessToken: String
    let refreshToken: String?
    let expiresIn: Int?
}
