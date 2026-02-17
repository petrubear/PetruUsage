import Foundation

final class ClaudeUsageAdapter: UsageFetchingPort {
    let provider: Provider = .claude

    private let httpClient: HTTPClientPort
    private let keychain: KeychainPort

    private let credentialFilePath = "~/.claude/.credentials.json"
    private let keychainService = "Claude Code-credentials"
    private let usageURL = "https://api.anthropic.com/api/oauth/usage"
    private let refreshURL = "https://platform.claude.com/v1/oauth/token"
    private let clientID = "9d1c250a-e61b-44d9-88ed-5944d1962f5e"
    private let scopes = "user:profile user:inference user:sessions:claude_code user:mcp_servers"

    init(httpClient: HTTPClientPort, keychain: KeychainPort) {
        self.httpClient = httpClient
        self.keychain = keychain
    }

    func fetchUsage() async throws -> ProviderUsageResult {
        var credential = try loadCredentials()

        if credential.needsRefresh {
            if let refreshed = try? await refreshToken(credential: credential) {
                credential = refreshed
            }
        }

        var response = try await fetchUsageData(accessToken: credential.accessToken)

        if response.isAuthError {
            if let refreshed = try? await refreshToken(credential: credential) {
                credential = refreshed
                response = try await fetchUsageData(accessToken: credential.accessToken)
            }
        }

        guard response.isSuccess else {
            if response.isAuthError {
                throw ProviderError.authExpired("Token expired. Run `claude` to log in again.")
            }
            throw ProviderError.httpError(response.statusCode)
        }

        return try parseUsageResponse(response.data, subscriptionType: credential.subscriptionType)
    }

    // MARK: - Credentials

    private func loadCredentials() throws -> OAuthCredential {
        // Try file first
        let expandedPath = NSString(string: credentialFilePath).expandingTildeInPath
        if FileManager.default.fileExists(atPath: expandedPath),
           let data = FileManager.default.contents(atPath: expandedPath),
           let credential = parseCredentialData(data, source: .file(path: expandedPath)) {
            return credential
        }

        // Try keychain fallback
        if let keychainValue = try keychain.readGenericPassword(service: keychainService),
           let data = keychainValue.data(using: .utf8) ?? hexDecode(keychainValue),
           let credential = parseCredentialData(data, source: .keychain(service: keychainService)) {
            return credential
        }

        throw ProviderError.notLoggedIn("Not logged in. Run `claude` to authenticate.")
    }

    private func parseCredentialData(_ data: Data, source: CredentialSource) -> OAuthCredential? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let oauth = json["claudeAiOauth"] as? [String: Any],
              let accessToken = oauth["accessToken"] as? String, !accessToken.isEmpty else {
            return nil
        }

        let refreshToken = oauth["refreshToken"] as? String
        let expiresAt: Date? = (oauth["expiresAt"] as? Double).map {
            Date(timeIntervalSince1970: $0 / 1000)
        }
        let subscriptionType = oauth["subscriptionType"] as? String

        return OAuthCredential(
            accessToken: accessToken,
            refreshToken: refreshToken,
            expiresAt: expiresAt,
            source: source,
            subscriptionType: subscriptionType
        )
    }

    // MARK: - Token Refresh

    private func refreshToken(credential: OAuthCredential) async throws -> OAuthCredential {
        guard let refreshToken = credential.refreshToken else {
            throw ProviderError.noRefreshToken
        }

        let body: [String: String] = [
            "grant_type": "refresh_token",
            "refresh_token": refreshToken,
            "client_id": clientID,
            "scope": scopes,
        ]

        let bodyData = try JSONSerialization.data(withJSONObject: body)
        let request = HTTPRequest(
            method: "POST",
            url: refreshURL,
            headers: [
                "Content-Type": "application/json",
                "User-Agent": "PetruUsage",
            ],
            body: bodyData,
            timeoutInterval: 15
        )

        let response = try await httpClient.execute(request)

        if response.statusCode == 400 || response.statusCode == 401 {
            throw ProviderError.authExpired("Session expired. Run `claude` to log in again.")
        }

        guard response.isSuccess else {
            throw ProviderError.refreshFailed
        }

        guard let json = try? JSONSerialization.jsonObject(with: response.data) as? [String: Any],
              let newAccessToken = json["access_token"] as? String else {
            throw ProviderError.refreshFailed
        }

        let newRefreshToken = json["refresh_token"] as? String ?? refreshToken
        let expiresIn = json["expires_in"] as? Double
        let expiresAt = expiresIn.map { Date().addingTimeInterval($0) }

        return OAuthCredential(
            accessToken: newAccessToken,
            refreshToken: newRefreshToken,
            expiresAt: expiresAt,
            source: credential.source
        )
    }

    // MARK: - Usage API

    private func fetchUsageData(accessToken: String) async throws -> HTTPResponse {
        let request = HTTPRequest(
            method: "GET",
            url: usageURL,
            headers: [
                "Authorization": "Bearer \(accessToken.trimmingCharacters(in: .whitespaces))",
                "Accept": "application/json",
                "Content-Type": "application/json",
                "anthropic-beta": "oauth-2025-04-20",
                "User-Agent": "PetruUsage",
            ],
            timeoutInterval: 10
        )

        return try await httpClient.execute(request)
    }

    private func parseUsageResponse(_ data: Data, subscriptionType: String?) throws -> ProviderUsageResult {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ProviderError.invalidResponse
        }

        var lines: [MetricLine] = []

        // Session (5h window)
        if let fiveHour = json["five_hour"] as? [String: Any],
           let utilization = fiveHour["utilization"] as? Double {
            let resetsAt = (fiveHour["resets_at"] as? Double).map { Date(timeIntervalSince1970: $0) }
            lines.append(.progress(ProgressMetric(
                label: "Session",
                used: utilization,
                limit: 100,
                format: .percent,
                resetsAt: resetsAt,
                periodDuration: 5 * 60 * 60
            )))
        }

        // Weekly (7d window)
        if let sevenDay = json["seven_day"] as? [String: Any],
           let utilization = sevenDay["utilization"] as? Double {
            let resetsAt = (sevenDay["resets_at"] as? Double).map { Date(timeIntervalSince1970: $0) }
            lines.append(.progress(ProgressMetric(
                label: "Weekly",
                used: utilization,
                limit: 100,
                format: .percent,
                resetsAt: resetsAt,
                periodDuration: 7 * 24 * 60 * 60
            )))
        }

        // Sonnet (7d window)
        if let sonnet = json["seven_day_sonnet"] as? [String: Any],
           let utilization = sonnet["utilization"] as? Double {
            let resetsAt = (sonnet["resets_at"] as? Double).map { Date(timeIntervalSince1970: $0) }
            lines.append(.progress(ProgressMetric(
                label: "Sonnet",
                used: utilization,
                limit: 100,
                format: .percent,
                resetsAt: resetsAt,
                periodDuration: 7 * 24 * 60 * 60
            )))
        }

        // Extra usage
        if let extraUsage = json["extra_usage"] as? [String: Any],
           let isEnabled = extraUsage["is_enabled"] as? Bool, isEnabled {
            let usedCredits = extraUsage["used_credits"] as? Double ?? 0
            let monthlyLimit = extraUsage["monthly_limit"] as? Double ?? 0

            if monthlyLimit > 0 {
                lines.append(.progress(ProgressMetric(
                    label: "Extra usage",
                    used: usedCredits,
                    limit: monthlyLimit,
                    format: .dollars,
                    resetsAt: nil,
                    periodDuration: nil
                )))
            } else if usedCredits > 0 {
                lines.append(.text(TextMetric(
                    label: "Extra usage",
                    value: String(format: "$%.2f", usedCredits)
                )))
            }
        }

        if lines.isEmpty {
            lines.append(.badge(BadgeMetric(label: "Status", text: "No usage data", color: "#a3a3a3")))
        }

        let plan = subscriptionType.flatMap { formatPlanLabel($0) }
        return ProviderUsageResult(provider: .claude, plan: plan, lines: lines)
    }

    private func formatPlanLabel(_ name: String) -> String? {
        guard !name.isEmpty else { return nil }
        let lowered = name.lowercased()
        if lowered.contains("pro") { return "Pro" }
        if lowered.contains("max") { return "Max" }
        if lowered.contains("team") { return "Team" }
        if lowered.contains("enterprise") { return "Enterprise" }
        if lowered.contains("free") { return "Free" }
        return name.prefix(1).uppercased() + name.dropFirst()
    }

    // MARK: - Hex Decode

    private func hexDecode(_ string: String) -> Data? {
        var hex = string.trimmingCharacters(in: .whitespacesAndNewlines)
        if hex.hasPrefix("0x") || hex.hasPrefix("0X") {
            hex = String(hex.dropFirst(2))
        }
        guard hex.count % 2 == 0, hex.allSatisfy({ $0.isHexDigit }) else { return nil }

        var bytes: [UInt8] = []
        var index = hex.startIndex
        while index < hex.endIndex {
            let nextIndex = hex.index(index, offsetBy: 2)
            guard let byte = UInt8(hex[index..<nextIndex], radix: 16) else { return nil }
            bytes.append(byte)
            index = nextIndex
        }
        return Data(bytes)
    }
}

enum ProviderError: LocalizedError {
    case notLoggedIn(String)
    case authExpired(String)
    case noRefreshToken
    case refreshFailed
    case httpError(Int)
    case invalidResponse
    case noData(String)

    var errorDescription: String? {
        switch self {
        case .notLoggedIn(let msg): msg
        case .authExpired(let msg): msg
        case .noRefreshToken: "No refresh token available"
        case .refreshFailed: "Token refresh failed"
        case .httpError(let code): "HTTP error \(code)"
        case .invalidResponse: "Invalid response from server"
        case .noData(let msg): msg
        }
    }
}
