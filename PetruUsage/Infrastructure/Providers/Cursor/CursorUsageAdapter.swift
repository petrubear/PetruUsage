import Foundation
import os

final class CursorUsageAdapter: UsageFetchingPort {
    let provider: Provider = .cursor

    private let httpClient: HTTPClientPort
    private let sqlite: SQLitePort
    private let logger = Logger(subsystem: "com.petru.PetruUsage", category: "Cursor")

    private let stateDB = "~/Library/Application Support/Cursor/User/globalStorage/state.vscdb"
    private let baseURL = "https://api2.cursor.sh"
    private let refreshURL = "https://api2.cursor.sh/oauth/token"
    private let restUsageURL = "https://cursor.com/api/usage"
    private let clientID = "KbZUR41cY7W6zRSdpSUJ7I7mLYBKOCmB"
    private let refreshBufferSeconds: TimeInterval = 5 * 60

    private var usageURL: String { "\(baseURL)/aiserver.v1.DashboardService/GetCurrentPeriodUsage" }
    private var planURL: String { "\(baseURL)/aiserver.v1.DashboardService/GetPlanInfo" }
    private var creditsURL: String { "\(baseURL)/aiserver.v1.DashboardService/GetCreditGrantsBalance" }

    init(httpClient: HTTPClientPort, sqlite: SQLitePort) {
        self.httpClient = httpClient
        self.sqlite = sqlite
    }

    func fetchUsage() async throws -> ProviderUsageResult {
        var accessToken = readStateValue(key: "cursorAuth/accessToken")
        let refreshTokenValue = readStateValue(key: "cursorAuth/refreshToken")

        logger.info("Credentials: accessToken=\(accessToken != nil ? "present" : "nil"), refreshToken=\(refreshTokenValue != nil ? "present" : "nil")")

        guard accessToken != nil || refreshTokenValue != nil else {
            throw ProviderError.notLoggedIn("Not logged in. Sign in via Cursor app.")
        }

        // Proactively refresh if token is expired or about to expire
        if needsRefresh(accessToken: accessToken) {
            logger.info("Token needs refresh")
            if let rt = refreshTokenValue {
                do {
                    let refreshed = try await refreshAccessToken(refreshToken: rt)
                    accessToken = refreshed
                    logger.info("Token refresh succeeded")
                } catch {
                    logger.error("Token refresh failed: \(error.localizedDescription)")
                    // If refresh fails but we have an access token, try it anyway
                    if accessToken == nil { throw error }
                }
            } else if accessToken == nil {
                throw ProviderError.notLoggedIn("Not logged in. Sign in via Cursor app.")
            }
        }

        guard let token = accessToken else {
            throw ProviderError.notLoggedIn("Not logged in. Sign in via Cursor app.")
        }

        // Fetch usage (Connect protocol) with retry on auth error
        var currentToken = token
        var response = try await connectPost(url: usageURL, token: currentToken)
        logger.info("Usage API response: status=\(response.statusCode)")

        if response.isAuthError {
            if let rt = refreshTokenValue {
                let refreshed = try await refreshAccessToken(refreshToken: rt)
                currentToken = refreshed
                response = try await connectPost(url: usageURL, token: currentToken)
                logger.info("Usage API retry response: status=\(response.statusCode)")
            }
        }

        if response.isAuthError {
            throw ProviderError.authExpired("Token expired. Sign in via Cursor app.")
        }

        guard response.isSuccess else {
            throw ProviderError.httpError(response.statusCode)
        }

        guard let usage = try? JSONSerialization.jsonObject(with: response.data) as? [String: Any] else {
            logger.error("Failed to parse usage response as JSON")
            throw ProviderError.invalidResponse
        }

        // Dump raw response to temp file for debugging (bypasses os_log privacy redaction)
        if let debugData = try? JSONSerialization.data(withJSONObject: usage, options: .prettyPrinted),
           let debugString = String(data: debugData, encoding: .utf8) {
            let debugPath = NSTemporaryDirectory() + "petru_cursor_usage.json"
            try? debugString.write(toFile: debugPath, atomically: true, encoding: .utf8)
            logger.info("Wrote raw usage response to \(debugPath)")
        }

        // Fetch plan info (needed for Enterprise detection)
        var planName: String?
        if let planResponse = try? await connectPost(url: planURL, token: currentToken),
           planResponse.isSuccess,
           let planData = try? JSONSerialization.jsonObject(with: planResponse.data) as? [String: Any],
           let planInfo = planData["planInfo"] as? [String: Any] {
            planName = planInfo["planName"] as? String
            logger.debug("Plan name: \(planName ?? "nil")")
        }

        // Enterprise accounts return no planUsage from the Connect API.
        // Detect Enterprise and use the REST usage API instead.
        let planUsage = usage["planUsage"] as? [String: Any]
        let isEnterprise = planUsage == nil && planName?.lowercased() == "enterprise"
        if isEnterprise {
            logger.info("Enterprise account detected, using REST API")
            return try await buildEnterpriseResult(
                accessToken: currentToken,
                planName: planName,
                usage: usage
            )
        }

        guard usage["enabled"] as? Bool != false, planUsage != nil else {
            logger.error("No active subscription: enabled=\(usage["enabled"].map { String(describing: $0) } ?? "nil"), planUsage=\(planUsage != nil ? "present" : "nil")")
            throw ProviderError.noData("No active Cursor subscription.")
        }

        // Fetch credit grants
        var creditGrants: [String: Any]?
        if let creditsResponse = try? await connectPost(url: creditsURL, token: currentToken),
           creditsResponse.isSuccess {
            creditGrants = try? JSONSerialization.jsonObject(with: creditsResponse.data) as? [String: Any]
        }

        return try parseUsageResponse(usage: usage, planName: planName, creditGrants: creditGrants)
    }

    // MARK: - SQLite

    private func readStateValue(key: String) -> String? {
        guard let rows = try? sqlite.query(
            dbPath: stateDB,
            sql: "SELECT value FROM ItemTable WHERE key = '\(key)' LIMIT 1;"
        ),
              let value = rows.first?["value"], !value.isEmpty else {
            logger.debug("SQLite key '\(key)' not found or empty")
            return nil
        }
        return value
    }

    // MARK: - Token Refresh Check

    private func needsRefresh(accessToken: String?) -> Bool {
        guard let accessToken else { return true }
        guard let payload = JWTDecoder.decodePayload(accessToken),
              let exp = payload.expirationDate else {
            return true
        }
        return Date().addingTimeInterval(refreshBufferSeconds) >= exp
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
                "User-Agent": "PetruUsage",
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
            headers: [
                "Content-Type": "application/json",
                "User-Agent": "PetruUsage",
            ],
            body: bodyData,
            timeoutInterval: 15
        )

        let response = try await httpClient.execute(request)
        logger.debug("Refresh response: status=\(response.statusCode)")

        if response.statusCode == 400 || response.statusCode == 401 {
            // Check for shouldLogout in error response
            if let json = try? JSONSerialization.jsonObject(with: response.data) as? [String: Any],
               json["shouldLogout"] as? Bool == true {
                throw ProviderError.authExpired("Session expired. Sign in via Cursor app.")
            }
            throw ProviderError.authExpired("Token expired. Sign in via Cursor app.")
        }

        guard response.isSuccess,
              let json = try? JSONSerialization.jsonObject(with: response.data) as? [String: Any] else {
            throw ProviderError.refreshFailed
        }

        // Check if server wants us to logout
        if json["shouldLogout"] as? Bool == true {
            throw ProviderError.authExpired("Session expired. Sign in via Cursor app.")
        }

        guard let newToken = json["access_token"] as? String else {
            throw ProviderError.refreshFailed
        }

        return newToken
    }

    // MARK: - Enterprise Support

    private func buildSessionToken(accessToken: String) -> (userId: String, sessionToken: String)? {
        guard let payload = JWTDecoder.decodePayload(accessToken),
              let userId = payload.userId, !userId.isEmpty else {
            return nil
        }
        let sessionToken = "\(userId)%3A%3A\(accessToken)"
        return (userId: userId, sessionToken: sessionToken)
    }

    private func fetchEnterpriseUsage(accessToken: String) async -> [String: Any]? {
        guard let session = buildSessionToken(accessToken: accessToken) else {
            return nil
        }

        let encodedUserId = session.userId.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? session.userId
        let request = HTTPRequest(
            method: "GET",
            url: "\(restUsageURL)?user=\(encodedUserId)",
            headers: [
                "Cookie": "WorkosCursorSessionToken=\(session.sessionToken)",
                "User-Agent": "PetruUsage",
            ],
            timeoutInterval: 10
        )

        guard let response = try? await httpClient.execute(request),
              response.isSuccess else {
            return nil
        }

        return try? JSONSerialization.jsonObject(with: response.data) as? [String: Any]
    }

    private func buildEnterpriseResult(
        accessToken: String,
        planName: String?,
        usage: [String: Any]
    ) async throws -> ProviderUsageResult {
        let requestUsage = await fetchEnterpriseUsage(accessToken: accessToken)
        var lines: [MetricLine] = []

        if let requestUsage,
           let gpt4 = requestUsage["gpt-4"] as? [String: Any],
           let maxRequestUsage = gpt4["maxRequestUsage"] as? Int,
           maxRequestUsage > 0 {
            let used = gpt4["numRequests"] as? Int ?? 0
            let limit = maxRequestUsage

            let billingPeriodSeconds: TimeInterval = 30 * 24 * 60 * 60
            var cycleEndDate: Date?

            if let startOfMonth = requestUsage["startOfMonth"] as? String {
                let formatter = ISO8601DateFormatter()
                formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                if let cycleStart = formatter.date(from: startOfMonth) {
                    cycleEndDate = cycleStart.addingTimeInterval(billingPeriodSeconds)
                }
            }

            lines.append(.progress(ProgressMetric(
                label: "Included requests",
                used: Double(used),
                limit: Double(limit),
                format: .count(suffix: "requests"),
                resetsAt: cycleEndDate,
                periodDuration: billingPeriodSeconds
            )))
        }

        if lines.isEmpty {
            throw ProviderError.noData("Enterprise usage data unavailable. Try again later.")
        }

        let plan = planName.flatMap { formatPlanLabel($0) }
        return ProviderUsageResult(provider: .cursor, plan: plan, lines: lines)
    }

    // MARK: - Flexible JSON Numeric Extraction

    /// Extracts a Double from a JSON value that may be a String, Int, or Double.
    /// Connect protocol (protobuf-over-HTTP) serializes int64/uint64 as strings.
    private func flexDouble(_ value: Any?) -> Double? {
        if let d = value as? Double { return d }
        if let i = value as? Int { return Double(i) }
        if let s = value as? String { return Double(s) }
        return nil
    }

    /// Extracts an Int from a JSON value that may be a String, Int, or Double.
    private func flexInt(_ value: Any?) -> Int? {
        if let i = value as? Int { return i }
        if let s = value as? String { return Int(s) }
        if let d = value as? Double { return Int(d) }
        return nil
    }

    // MARK: - Parse Response

    private func parseUsageResponse(
        usage: [String: Any],
        planName: String?,
        creditGrants: [String: Any]?
    ) throws -> ProviderUsageResult {
        var lines: [MetricLine] = []

        // Credit grants (values are in cents)
        if let grants = creditGrants,
           grants["hasCreditGrants"] as? Bool == true,
           let totalCents = flexInt(grants["totalCents"]),
           let usedCents = flexInt(grants["usedCents"]),
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

        // Plan usage (values are in cents)
        if let planUsage = usage["planUsage"] as? [String: Any] {
            guard let limit = flexDouble(planUsage["limit"]) else {
                logger.error("planUsage exists but 'limit' extraction failed. Raw planUsage: \(planUsage)")
                throw ProviderError.invalidResponse
            }

            let totalSpend = flexDouble(planUsage["totalSpend"])
            let remaining = flexDouble(planUsage["remaining"]) ?? 0
            let planUsed = totalSpend ?? (limit - remaining)

            logger.debug("planUsage parsed: limit=\(limit), totalSpend=\(totalSpend.map { String($0) } ?? "nil"), remaining=\(remaining), computed used=\(planUsed)")

            // Calculate billing cycle from actual dates
            var billingPeriod: TimeInterval = 30 * 24 * 60 * 60
            var cycleEndDate: Date?

            let cycleStart = flexDouble(usage["billingCycleStart"])
            let cycleEnd = flexDouble(usage["billingCycleEnd"])

            if let cycleEnd {
                cycleEndDate = Date(timeIntervalSince1970: cycleEnd / 1000.0)
            }

            if let cycleStart, let cycleEnd, cycleEnd > cycleStart {
                billingPeriod = (cycleEnd - cycleStart) / 1000.0
            }

            lines.append(.progress(ProgressMetric(
                label: "Plan usage",
                used: planUsed / 100,
                limit: limit / 100,
                format: .dollars,
                resetsAt: cycleEndDate,
                periodDuration: billingPeriod
            )))

            if let bonusSpend = flexDouble(planUsage["bonusSpend"]), bonusSpend > 0 {
                lines.append(.text(TextMetric(
                    label: "Bonus spend",
                    value: String(format: "$%.2f", bonusSpend / 100)
                )))
            }
        }

        // On-demand spend limit (values are in cents)
        if let spendLimit = usage["spendLimitUsage"] as? [String: Any] {
            let limit = flexDouble(spendLimit["individualLimit"]) ?? flexDouble(spendLimit["pooledLimit"]) ?? 0
            let remaining = flexDouble(spendLimit["individualRemaining"]) ?? flexDouble(spendLimit["pooledRemaining"]) ?? 0
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
            logger.error("No usage lines produced. Usage keys: \(Array(usage.keys).joined(separator: ", "))")
            throw ProviderError.noData("No usage data available.")
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
