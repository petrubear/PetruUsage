import Foundation

final class CodexUsageAdapter: UsageFetchingPort {
    let provider: Provider = .codex

    private let httpClient: HTTPClientPort
    private let keychain: KeychainPort

    private let authPaths = ["~/.config/codex/auth.json", "~/.codex/auth.json"]
    private let keychainService = "Codex Auth"
    private let clientID = "app_EMoamEEZ73f0CkXaXp7hrann"
    private let refreshURL = "https://auth.openai.com/oauth/token"
    private let usageURL = "https://chatgpt.com/backend-api/wham/usage"
    private let refreshAge: TimeInterval = 8 * 24 * 60 * 60

    init(httpClient: HTTPClientPort, keychain: KeychainPort) {
        self.httpClient = httpClient
        self.keychain = keychain
    }

    func fetchUsage() async throws -> ProviderUsageResult {
        var authState = try loadAuth()

        if shouldRefresh(authState.auth) {
            if let refreshed = try? await refreshToken(authState: &authState) {
                authState.auth["tokens"] = (authState.auth["tokens"] as? [String: Any] ?? [:]).merging(
                    ["access_token": refreshed], uniquingKeysWith: { _, new in new }
                )
            }
        }

        guard let tokens = authState.auth["tokens"] as? [String: Any],
              var accessToken = tokens["access_token"] as? String else {
            throw ProviderError.notLoggedIn("Not logged in. Run `codex` to authenticate.")
        }

        let accountId = tokens["account_id"] as? String

        var response = try await fetchUsageData(accessToken: accessToken, accountId: accountId)

        if response.isAuthError {
            if let refreshed = try? await refreshToken(authState: &authState) {
                accessToken = refreshed
                response = try await fetchUsageData(accessToken: accessToken, accountId: accountId)
            }
        }

        guard response.isSuccess else {
            if response.isAuthError {
                throw ProviderError.authExpired("Token expired. Run `codex` to log in again.")
            }
            throw ProviderError.httpError(response.statusCode)
        }

        return try parseUsageResponse(data: response.data, headers: response.headers)
    }

    // MARK: - Auth Loading

    private struct AuthState {
        var auth: [String: Any]
        let source: String
        let path: String?
    }

    private func loadAuth() throws -> AuthState {
        // Try file paths
        for authPath in authPaths {
            let expanded = NSString(string: authPath).expandingTildeInPath
            guard FileManager.default.fileExists(atPath: expanded),
                  let data = FileManager.default.contents(atPath: expanded),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  hasTokenAuth(json) else { continue }
            return AuthState(auth: json, source: "file", path: expanded)
        }

        // Try keychain
        if let keychainValue = try keychain.readGenericPassword(service: keychainService),
           let data = keychainValue.data(using: .utf8) ?? hexDecode(keychainValue),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           hasTokenAuth(json) {
            return AuthState(auth: json, source: "keychain", path: nil)
        }

        throw ProviderError.notLoggedIn("Not logged in. Run `codex` to authenticate.")
    }

    private func hasTokenAuth(_ auth: [String: Any]) -> Bool {
        if let tokens = auth["tokens"] as? [String: Any], tokens["access_token"] != nil {
            return true
        }
        return auth["OPENAI_API_KEY"] != nil
    }

    // MARK: - Token Refresh

    private func shouldRefresh(_ auth: [String: Any]) -> Bool {
        guard let lastRefresh = auth["last_refresh"] as? String else { return true }
        let formatter = ISO8601DateFormatter()
        guard let lastDate = formatter.date(from: lastRefresh) else { return true }
        return Date().timeIntervalSince(lastDate) > refreshAge
    }

    private func refreshToken(authState: inout AuthState) async throws -> String? {
        guard let tokens = authState.auth["tokens"] as? [String: Any],
              let refreshToken = tokens["refresh_token"] as? String else {
            return nil
        }

        let bodyString = [
            "grant_type=refresh_token",
            "client_id=\(clientID.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? clientID)",
            "refresh_token=\(refreshToken.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? refreshToken)",
        ].joined(separator: "&")

        let request = HTTPRequest(
            method: "POST",
            url: refreshURL,
            headers: [
                "Content-Type": "application/x-www-form-urlencoded",
                "User-Agent": "PetruUsage",
            ],
            body: bodyString.data(using: .utf8),
            timeoutInterval: 15
        )

        let response = try await httpClient.execute(request)

        if response.statusCode == 400 || response.statusCode == 401 {
            throw ProviderError.authExpired("Session expired. Run `codex` to log in again.")
        }

        guard response.isSuccess,
              let json = try? JSONSerialization.jsonObject(with: response.data) as? [String: Any],
              let newAccessToken = json["access_token"] as? String else {
            return nil
        }

        // Update auth state
        var updatedTokens = tokens
        updatedTokens["access_token"] = newAccessToken
        if let newRefresh = json["refresh_token"] as? String {
            updatedTokens["refresh_token"] = newRefresh
        }
        authState.auth["tokens"] = updatedTokens
        authState.auth["last_refresh"] = ISO8601DateFormatter().string(from: Date())

        return newAccessToken
    }

    // MARK: - Usage API

    private func fetchUsageData(accessToken: String, accountId: String?) async throws -> HTTPResponse {
        var headers: [String: String] = [
            "Authorization": "Bearer \(accessToken)",
            "Accept": "application/json",
            "User-Agent": "PetruUsage",
        ]
        if let accountId {
            headers["ChatGPT-Account-Id"] = accountId
        }

        let request = HTTPRequest(method: "GET", url: usageURL, headers: headers, timeoutInterval: 10)
        return try await httpClient.execute(request)
    }

    // MARK: - Parse Response

    private func parseUsageResponse(data: Data, headers: [String: String]) throws -> ProviderUsageResult {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ProviderError.invalidResponse
        }

        var lines: [MetricLine] = []
        let now = Date()

        let rateLimit = json["rate_limit"] as? [String: Any]
        let primaryWindow = rateLimit?["primary_window"] as? [String: Any]
        let secondaryWindow = rateLimit?["secondary_window"] as? [String: Any]

        // Try headers first, then body
        let headerPrimary = headers["x-codex-primary-used-percent"].flatMap(Double.init)
        let headerSecondary = headers["x-codex-secondary-used-percent"].flatMap(Double.init)

        let sessionUsed = headerPrimary ?? (primaryWindow?["used_percent"] as? Double)
        let weeklyUsed = headerSecondary ?? (secondaryWindow?["used_percent"] as? Double)

        if let used = sessionUsed {
            lines.append(.progress(ProgressMetric(
                label: "Session",
                used: used,
                limit: 100,
                format: .percent,
                resetsAt: resetsAtDate(now: now, window: primaryWindow),
                periodDuration: 5 * 60 * 60
            )))
        }

        if let used = weeklyUsed {
            lines.append(.progress(ProgressMetric(
                label: "Weekly",
                used: used,
                limit: 100,
                format: .percent,
                resetsAt: resetsAtDate(now: now, window: secondaryWindow),
                periodDuration: 7 * 24 * 60 * 60
            )))
        }

        // Additional rate limits (per-model)
        if let additional = json["additional_rate_limits"] as? [[String: Any]] {
            for entry in additional {
                guard let rl = entry["rate_limit"] as? [String: Any] else { continue }
                let name = entry["limit_name"] as? String ?? "Model"
                let shortName = name.replacingOccurrences(
                    of: #"^GPT-[\d.]+-Codex-"#, with: "", options: .regularExpression
                )

                if let pw = rl["primary_window"] as? [String: Any],
                   let used = pw["used_percent"] as? Double {
                    let windowSec = pw["limit_window_seconds"] as? Double
                    lines.append(.progress(ProgressMetric(
                        label: shortName,
                        used: used,
                        limit: 100,
                        format: .percent,
                        resetsAt: resetsAtDate(now: now, window: pw),
                        periodDuration: windowSec ?? 5 * 60 * 60
                    )))
                }
            }
        }

        // Code review rate limit
        if let reviewLimit = json["code_review_rate_limit"] as? [String: Any],
           let reviewWindow = reviewLimit["primary_window"] as? [String: Any],
           let used = reviewWindow["used_percent"] as? Double {
            lines.append(.progress(ProgressMetric(
                label: "Reviews",
                used: used,
                limit: 100,
                format: .percent,
                resetsAt: resetsAtDate(now: now, window: reviewWindow),
                periodDuration: 7 * 24 * 60 * 60
            )))
        }

        // Credits
        let creditsBalance = headers["x-codex-credits-balance"].flatMap(Double.init)
            ?? (json["credits"] as? [String: Any])?["balance"] as? Double
        if let remaining = creditsBalance {
            let limit: Double = 1000
            let used = max(0, min(limit, limit - remaining))
            lines.append(.progress(ProgressMetric(
                label: "Credits",
                used: used,
                limit: limit,
                format: .count(suffix: "credits"),
                resetsAt: nil,
                periodDuration: nil
            )))
        }

        let plan = (json["plan_type"] as? String).flatMap { formatPlanLabel($0) }

        if lines.isEmpty {
            lines.append(.badge(BadgeMetric(label: "Status", text: "No usage data", color: "#a3a3a3")))
        }

        return ProviderUsageResult(provider: .codex, plan: plan, lines: lines)
    }

    private func resetsAtDate(now: Date, window: [String: Any]?) -> Date? {
        guard let window else { return nil }
        if let resetAt = window["reset_at"] as? Double {
            return Date(timeIntervalSince1970: resetAt)
        }
        if let resetAfter = window["reset_after_seconds"] as? Double {
            return now.addingTimeInterval(resetAfter)
        }
        return nil
    }

    private func formatPlanLabel(_ name: String) -> String? {
        name.isEmpty ? nil : name.prefix(1).uppercased() + name.dropFirst().lowercased()
    }

    private func hexDecode(_ string: String) -> Data? {
        var hex = string.trimmingCharacters(in: .whitespacesAndNewlines)
        if hex.hasPrefix("0x") || hex.hasPrefix("0X") { hex = String(hex.dropFirst(2)) }
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
