import Foundation

final class CursorUsageAdapter: UsageFetchingPort {
    let provider: Provider = .cursor

    private let httpClient: HTTPClientPort
    private let sqlite: SQLitePort

    private let stateDB = "~/Library/Application Support/Cursor/User/globalStorage/state.vscdb"
    private let baseURL = "https://api2.cursor.sh"
    private let refreshURL = "https://api2.cursor.sh/oauth/token"
    private let clientID = "KbZUR41cY7W6zRSdpSUJ7I7mLYBKOCmB"

    private var usageURL: String { "\(baseURL)/aiserver.v1.DashboardService/GetCurrentPeriodUsage" }
    private var planURL: String { "\(baseURL)/aiserver.v1.DashboardService/GetPlanInfo" }
    private var creditsURL: String { "\(baseURL)/aiserver.v1.DashboardService/GetCreditGrantsBalance" }

    init(httpClient: HTTPClientPort, sqlite: SQLitePort) {
        self.httpClient = httpClient
        self.sqlite = sqlite
    }

    func fetchUsage() async throws -> ProviderUsageResult {
        var accessToken = try readStateValue(key: "cursorAuth/accessToken")
        let refreshToken = try? readStateValue(key: "cursorAuth/refreshToken")

        if accessToken.isEmpty {
            guard let rt = refreshToken, !rt.isEmpty else {
                throw ProviderError.notLoggedIn("Not logged in. Sign in via Cursor app.")
            }
            accessToken = try await refreshAccessToken(refreshToken: rt)
        }

        // Check if token needs refresh
        if let payload = JWTDecoder.decodePayload(accessToken),
           let exp = payload.expirationDate,
           Date().addingTimeInterval(5 * 60) >= exp {
            if let rt = refreshToken, !rt.isEmpty {
                if let refreshed = try? await refreshAccessToken(refreshToken: rt) {
                    accessToken = refreshed
                }
            }
        }

        // Fetch usage (Connect protocol)
        var response = try await connectPost(url: usageURL, token: accessToken)

        if response.isAuthError {
            if let rt = refreshToken, !rt.isEmpty {
                accessToken = try await refreshAccessToken(refreshToken: rt)
                response = try await connectPost(url: usageURL, token: accessToken)
            }
        }

        guard response.isSuccess else {
            if response.isAuthError {
                throw ProviderError.authExpired("Token expired. Sign in via Cursor app.")
            }
            throw ProviderError.httpError(response.statusCode)
        }

        guard let usage = try? JSONSerialization.jsonObject(with: response.data) as? [String: Any] else {
            throw ProviderError.invalidResponse
        }

        // Fetch plan info
        var planName: String?
        if let planResponse = try? await connectPost(url: planURL, token: accessToken),
           planResponse.isSuccess,
           let planData = try? JSONSerialization.jsonObject(with: planResponse.data) as? [String: Any],
           let planInfo = planData["planInfo"] as? [String: Any] {
            planName = planInfo["planName"] as? String
        }

        // Fetch credit grants
        var creditGrants: [String: Any]?
        if let creditsResponse = try? await connectPost(url: creditsURL, token: accessToken),
           creditsResponse.isSuccess {
            creditGrants = try? JSONSerialization.jsonObject(with: creditsResponse.data) as? [String: Any]
        }

        return parseUsageResponse(usage: usage, planName: planName, creditGrants: creditGrants)
    }

    // MARK: - SQLite

    private func readStateValue(key: String) throws -> String {
        let rows = try sqlite.query(
            dbPath: stateDB,
            sql: "SELECT value FROM ItemTable WHERE key = '\(key)' LIMIT 1;"
        )
        guard let value = rows.first?["value"], !value.isEmpty else {
            throw ProviderError.notLoggedIn("Not logged in. Sign in via Cursor app.")
        }
        return value
    }

    // MARK: - Connect Protocol

    private func connectPost(url: String, token: String) async throws -> HTTPResponse {
        let request = HTTPRequest(
            method: "POST",
            url: url,
            headers: [
                "Authorization": "Bearer \(token)",
                "Content-Type": "application/json",
                "Connect-Protocol-Version": "1",
            ],
            body: "{}".data(using: .utf8),
            timeoutInterval: 10
        )
        return try await httpClient.execute(request)
    }

    // MARK: - Token Refresh

    private func refreshAccessToken(refreshToken: String) async throws -> String {
        let body: [String: String] = [
            "grant_type": "refresh_token",
            "client_id": clientID,
            "refresh_token": refreshToken,
        ]

        let bodyData = try JSONSerialization.data(withJSONObject: body)
        let request = HTTPRequest(
            method: "POST",
            url: refreshURL,
            headers: ["Content-Type": "application/json"],
            body: bodyData,
            timeoutInterval: 15
        )

        let response = try await httpClient.execute(request)

        if response.statusCode == 400 || response.statusCode == 401 {
            throw ProviderError.authExpired("Session expired. Sign in via Cursor app.")
        }

        guard response.isSuccess,
              let json = try? JSONSerialization.jsonObject(with: response.data) as? [String: Any],
              let newToken = json["access_token"] as? String else {
            throw ProviderError.refreshFailed
        }

        return newToken
    }

    // MARK: - Parse Response

    private func parseUsageResponse(
        usage: [String: Any],
        planName: String?,
        creditGrants: [String: Any]?
    ) -> ProviderUsageResult {
        var lines: [MetricLine] = []

        // Credit grants
        if let grants = creditGrants,
           grants["hasCreditGrants"] as? Bool == true,
           let totalCents = (grants["totalCents"] as? String).flatMap(Int.init),
           let usedCents = (grants["usedCents"] as? String).flatMap(Int.init),
           totalCents > 0 {
            lines.append(.progress(ProgressMetric(
                label: "Credits",
                used: Double(usedCents) / 100,
                limit: Double(totalCents) / 100,
                format: .dollars,
                resetsAt: nil,
                periodDuration: nil
            )))
        }

        // Plan usage
        if let planUsage = usage["planUsage"] as? [String: Any],
           let limit = planUsage["limit"] as? Double {
            let totalSpend = planUsage["totalSpend"] as? Double
            let remaining = planUsage["remaining"] as? Double ?? 0
            let planUsed = totalSpend ?? (limit - remaining)

            // Billing cycle
            let billingPeriod: TimeInterval = 30 * 24 * 60 * 60
            var cycleEndDate: Date?
            if let cycleEnd = usage["billingCycleEnd"] as? String,
               let endMs = Double(cycleEnd) {
                cycleEndDate = Date(timeIntervalSince1970: endMs / 1000)
            }

            lines.append(.progress(ProgressMetric(
                label: "Plan usage",
                used: planUsed / 100,
                limit: limit / 100,
                format: .dollars,
                resetsAt: cycleEndDate,
                periodDuration: billingPeriod
            )))

            if let bonusSpend = planUsage["bonusSpend"] as? Double, bonusSpend > 0 {
                lines.append(.text(TextMetric(
                    label: "Bonus spend",
                    value: String(format: "$%.2f", bonusSpend / 100)
                )))
            }
        }

        // On-demand spend limit
        if let spendLimit = usage["spendLimitUsage"] as? [String: Any] {
            let limit = spendLimit["individualLimit"] as? Double ?? spendLimit["pooledLimit"] as? Double ?? 0
            let remaining = spendLimit["individualRemaining"] as? Double ?? spendLimit["pooledRemaining"] as? Double ?? 0
            if limit > 0 {
                let used = limit - remaining
                lines.append(.progress(ProgressMetric(
                    label: "On-demand",
                    used: used / 100,
                    limit: limit / 100,
                    format: .dollars,
                    resetsAt: nil,
                    periodDuration: nil
                )))
            }
        }

        if lines.isEmpty {
            lines.append(.badge(BadgeMetric(label: "Status", text: "No usage data", color: "#a3a3a3")))
        }

        let plan = planName.flatMap { formatPlanLabel($0) }
        return ProviderUsageResult(provider: .cursor, plan: plan, lines: lines)
    }

    private func formatPlanLabel(_ name: String) -> String? {
        let lowered = name.lowercased()
        if lowered == "free" { return "Free" }
        if lowered == "pro" { return "Pro" }
        if lowered == "business" { return "Business" }
        if lowered == "enterprise" { return "Enterprise" }
        return name.isEmpty ? nil : name
    }
}
