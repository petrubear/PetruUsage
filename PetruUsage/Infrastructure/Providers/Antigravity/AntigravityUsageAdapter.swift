import Foundation
import os

final class AntigravityUsageAdapter: UsageFetchingPort {
    let provider: Provider = .antigravity

    private let httpClient: HTTPClientPort
    private let sqlite: SQLitePort
    private let logger = Logger(subsystem: "com.petru.PetruUsage", category: "Antigravity")

    // Antigravity app's own state DB
    private let stateDBPath = "~/Library/Application Support/Antigravity/User/globalStorage/state.vscdb"
    private let protoTokenKey = "jetskiStateSync.agentManagerInitState"
    private let authStatusKey = "antigravityAuthStatus"

    private let cloudCodeURLs = [
        "https://daily-cloudcode-pa.googleapis.com",
        "https://cloudcode-pa.googleapis.com",
    ]
    private let fetchModelsPath = "/v1internal:fetchAvailableModels"
    private let googleOAuthURL = "https://oauth2.googleapis.com/token"
    private let googleClientID = "1071006060591-tmhssin2h21lcre235vtolojh4g403ep.apps.googleusercontent.com"
    private let googleClientSecret = "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"

    private let modelBlacklist: Set<String> = [
        "MODEL_CHAT_20706", "MODEL_CHAT_23310",
        "MODEL_GOOGLE_GEMINI_2_5_FLASH", "MODEL_GOOGLE_GEMINI_2_5_FLASH_THINKING",
        "MODEL_GOOGLE_GEMINI_2_5_FLASH_LITE", "MODEL_GOOGLE_GEMINI_2_5_PRO",
        "MODEL_PLACEHOLDER_M19", "MODEL_PLACEHOLDER_M9", "MODEL_PLACEHOLDER_M12",
    ]

    private var tokenCachePath: String {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("PetruUsage/antigravity-auth.json").path
    }

    init(httpClient: HTTPClientPort, sqlite: SQLitePort) {
        self.httpClient = httpClient
        self.sqlite = sqlite
    }

    func fetchUsage() async throws -> ProviderUsageResult {
        // Matching reference plugin token priority:
        // 1. Proto tokens from Antigravity state.vscdb (field 6 → accessToken, refreshToken)
        // 2. Cached refreshed token
        // 3. API key from antigravityAuthStatus (used as Bearer token)
        // 4. Refresh using refresh token from proto

        let apiKey = loadApiKey()
        let proto = loadProtoTokens()

        var tokens: [String] = []
        var refreshToken: String?

        // 1. Proto access token (if not expired)
        if let proto {
            logger.info("Loaded proto tokens from Antigravity state DB")
            if proto.expiresAt == nil || proto.expiresAt! > Date() {
                tokens.append(proto.accessToken)
            } else {
                logger.debug("Proto access token expired")
            }
            refreshToken = proto.refreshToken
        }

        // 2. Cached token
        if let cached = loadCachedToken() {
            if cached != proto?.accessToken {
                tokens.append(cached)
                logger.debug("Added cached token")
            }
        }

        // 3. API key (used as Bearer token, same as reference plugin)
        if let apiKey, apiKey != proto?.accessToken, !tokens.contains(apiKey) {
            tokens.append(apiKey)
            logger.info("Added API key as Bearer token")
        }

        guard !tokens.isEmpty || refreshToken != nil else {
            logger.warning("No credentials found from any source")
            throw ProviderError.notLoggedIn("Start Antigravity and try again.")
        }

        // Try Cloud Code API with each token
        var ccData: [String: Any]?

        for token in tokens {
            logger.debug("Trying Cloud Code API with token")
            let result = try await probeCloudCode(token: token)
            if let data = result.data {
                ccData = data
                logger.info("Cloud Code API succeeded")
                break
            }
            if result.authFailed {
                logger.debug("Token auth failed, trying next")
            }
        }

        // Refresh if nothing succeeded and we have a refresh token
        if ccData == nil, let refreshToken {
            logger.info("All tokens failed, attempting OAuth refresh")
            if let refreshed = try? await refreshAccessToken(refreshToken: refreshToken) {
                logger.info("OAuth refresh succeeded, retrying Cloud Code API")
                let result = try await probeCloudCode(token: refreshed)
                ccData = result.data
            } else {
                logger.error("OAuth refresh failed")
            }
        }

        guard let data = ccData else {
            logger.error("All credential sources exhausted, Cloud Code API unreachable")
            throw ProviderError.noData("Start Antigravity and try again.")
        }

        let configs = parseCloudCodeModels(data: data)
        let lines = buildModelLines(configs: configs)

        guard !lines.isEmpty else {
            throw ProviderError.noData("No model usage data available.")
        }

        return ProviderUsageResult(provider: .antigravity, plan: nil, lines: lines)
    }

    // MARK: - Proto Token Loading (from editor state.vscdb)

    private struct ProtoTokens {
        let accessToken: String
        let refreshToken: String?
        let expiresAt: Date?
    }

    private func loadProtoTokens() -> ProtoTokens? {
        let expanded = NSString(string: stateDBPath).expandingTildeInPath
        guard FileManager.default.fileExists(atPath: expanded) else {
            logger.debug("Antigravity state DB not found at \(expanded)")
            return nil
        }

        guard let rows = try? sqlite.query(
            dbPath: stateDBPath,
            sql: "SELECT value FROM ItemTable WHERE key = '\(protoTokenKey)' LIMIT 1;"
        ),
              let base64Value = rows.first?["value"], !base64Value.isEmpty else {
            logger.debug("Proto token key not found in Antigravity state DB")
            return nil
        }

        guard let protoData = Data(base64Encoded: base64Value) else {
            logger.debug("Failed to base64-decode proto data")
            return nil
        }

        if let tokens = decodeProtoTokens(protoData) {
            logger.info("Decoded proto tokens from Antigravity state DB")
            return tokens
        }

        return nil
    }

    /// Minimal protobuf wire-format decoder for the agentManagerInitState message.
    /// Reference plugin structure:
    ///   outer field 6 (message) → inner:
    ///     field 1 (string): accessToken
    ///     field 3 (string): refreshToken
    ///     field 4 (message): { field 1 (varint): expiryEpochSeconds }
    private func decodeProtoTokens(_ data: Data) -> ProtoTokens? {
        // Parse outer message to find field 6
        let outerFields = readFields(data)

        guard let field6 = outerFields[6], field6.wireType == 2 else {
            logger.debug("Proto decode: outer field 6 not found")
            return nil
        }

        // Parse inner message from field 6's data
        let innerFields = readFields(field6.data)

        let accessToken = innerFields[1].flatMap { $0.wireType == 2 ? String(data: $0.data, encoding: .utf8) : nil }
        let refreshToken = innerFields[3].flatMap { $0.wireType == 2 ? String(data: $0.data, encoding: .utf8) : nil }

        var expirySeconds: UInt64?
        if let field4 = innerFields[4], field4.wireType == 2 {
            let tsFields = readFields(field4.data)
            if let ts1 = tsFields[1], ts1.wireType == 0 {
                expirySeconds = ts1.varint
            }
        }

        guard let accessToken, !accessToken.isEmpty else {
            logger.debug("Proto decode: no accessToken in inner message")
            return nil
        }

        var expiresAt: Date?
        if let seconds = expirySeconds, seconds > 0 {
            expiresAt = Date(timeIntervalSince1970: Double(seconds))
        }

        return ProtoTokens(
            accessToken: accessToken,
            refreshToken: refreshToken,
            expiresAt: expiresAt
        )
    }

    /// Parsed protobuf field — either a varint or length-delimited bytes.
    private struct ProtoField {
        let wireType: UInt64
        let varint: UInt64     // valid when wireType == 0
        let data: Data         // valid when wireType == 2
    }

    /// Reads all fields from a protobuf message, returning a dictionary keyed by field number.
    /// Supports wire type 0 (varint) and 2 (length-delimited) only.
    /// Works on contiguous bytes — callers must pass `Data(slice)` for sub-ranges.
    private func readFields(_ data: Data) -> [UInt64: ProtoField] {
        var fields: [UInt64: ProtoField] = [:]
        var pos = 0

        while pos < data.count {
            guard let (tag, p1) = readVarint(data, pos: pos) else { break }
            pos = p1
            let fieldNumber = tag >> 3
            let wireType = tag & 0x07

            if wireType == 0 {
                guard let (value, p2) = readVarint(data, pos: pos) else { break }
                pos = p2
                fields[fieldNumber] = ProtoField(wireType: 0, varint: value, data: Data())
            } else if wireType == 2 {
                guard let (length, p2) = readVarint(data, pos: pos) else { break }
                pos = p2
                let len = Int(length)
                guard pos + len <= data.count else { break }
                fields[fieldNumber] = ProtoField(wireType: 2, varint: 0, data: Data(data[pos..<(pos + len)]))
                pos += len
            } else {
                break
            }
        }

        return fields
    }

    /// Reads a varint from contiguous Data at the given byte position.
    private func readVarint(_ data: Data, pos: Int) -> (UInt64, Int)? {
        var result: UInt64 = 0
        var shift: UInt64 = 0
        var i = pos
        while i < data.count {
            let byte = data[data.startIndex + i]
            result |= UInt64(byte & 0x7F) << shift
            i += 1
            if byte & 0x80 == 0 {
                return (result, i)
            }
            shift += 7
            if shift >= 64 { return nil }
        }
        return nil
    }

    // MARK: - API Key Loading (from antigravityAuthStatus)

    private func loadApiKey() -> String? {
        let expanded = NSString(string: stateDBPath).expandingTildeInPath
        guard FileManager.default.fileExists(atPath: expanded) else { return nil }

        guard let rows = try? sqlite.query(
            dbPath: stateDBPath,
            sql: "SELECT value FROM ItemTable WHERE key = '\(authStatusKey)' LIMIT 1;"
        ),
              let jsonString = rows.first?["value"], !jsonString.isEmpty,
              let data = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let apiKey = json["apiKey"] as? String, !apiKey.isEmpty else {
            return nil
        }

        return apiKey
    }

    // MARK: - Cloud Code API

    private struct CloudCodeResult {
        let data: [String: Any]?
        let authFailed: Bool
    }

    private func probeCloudCode(token: String) async throws -> CloudCodeResult {
        for baseURL in cloudCodeURLs {
            do {
                let request = HTTPRequest(
                    method: "POST",
                    url: baseURL + fetchModelsPath,
                    headers: [
                        "Content-Type": "application/json",
                        "Authorization": "Bearer \(token)",
                        "User-Agent": "antigravity",
                    ],
                    body: "{}".data(using: .utf8),
                    timeoutInterval: 15
                )

                let response = try await httpClient.execute(request)
                logger.debug("Cloud Code \(baseURL) responded with status \(response.statusCode)")

                if response.isAuthError {
                    return CloudCodeResult(data: nil, authFailed: true)
                }

                if response.isSuccess,
                   let json = try? JSONSerialization.jsonObject(with: response.data) as? [String: Any] {
                    return CloudCodeResult(data: json, authFailed: false)
                }
            } catch {
                logger.debug("Cloud Code \(baseURL) error: \(error.localizedDescription)")
                continue
            }
        }

        return CloudCodeResult(data: nil, authFailed: false)
    }

    // MARK: - Token Cache

    private func loadCachedToken() -> String? {
        guard FileManager.default.fileExists(atPath: tokenCachePath),
              let data = FileManager.default.contents(atPath: tokenCachePath),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let accessToken = json["accessToken"] as? String,
              let expiresAtMs = json["expiresAtMs"] as? Double else {
            return nil
        }
        guard expiresAtMs > Date().timeIntervalSince1970 * 1000 else { return nil }
        return accessToken
    }

    private func cacheToken(_ accessToken: String, expiresInSeconds: Int = 3600) {
        let payload: [String: Any] = [
            "accessToken": accessToken,
            "expiresAtMs": Date().timeIntervalSince1970 * 1000 + Double(expiresInSeconds) * 1000,
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: payload) else { return }
        let dir = (tokenCachePath as NSString).deletingLastPathComponent
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: tokenCachePath, contents: data)
    }

    // MARK: - Google OAuth Refresh

    private func refreshAccessToken(refreshToken: String) async throws -> String {
        let bodyString = [
            "client_id=\(googleClientID.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? googleClientID)",
            "client_secret=\(googleClientSecret.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? googleClientSecret)",
            "refresh_token=\(refreshToken.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? refreshToken)",
            "grant_type=refresh_token",
        ].joined(separator: "&")

        let request = HTTPRequest(
            method: "POST",
            url: googleOAuthURL,
            headers: [
                "Content-Type": "application/x-www-form-urlencoded",
                "User-Agent": "PetruUsage",
            ],
            body: bodyString.data(using: .utf8),
            timeoutInterval: 15
        )

        let response = try await httpClient.execute(request)
        logger.debug("OAuth refresh responded with status \(response.statusCode)")

        guard response.isSuccess,
              let json = try? JSONSerialization.jsonObject(with: response.data) as? [String: Any],
              let accessToken = json["access_token"] as? String else {
            logger.error("OAuth refresh failed: status \(response.statusCode)")
            throw ProviderError.refreshFailed
        }

        let expiresIn = json["expires_in"] as? Int ?? 3600
        cacheToken(accessToken, expiresInSeconds: expiresIn)
        logger.info("OAuth refresh succeeded, token cached for \(expiresIn)s")

        return accessToken
    }

    // MARK: - Parse Models

    private func parseCloudCodeModels(data: [String: Any]) -> [ModelConfig] {
        guard let models = data["models"] as? [String: Any] else { return [] }

        var configs: [ModelConfig] = []
        for (key, value) in models {
            guard let model = value as? [String: Any] else { continue }
            if model["isInternal"] as? Bool == true { continue }

            let modelId = model["model"] as? String ?? key
            if modelBlacklist.contains(modelId) { continue }

            guard let displayName = model["displayName"] as? String, !displayName.isEmpty else { continue }
            guard let quotaInfo = model["quotaInfo"] as? [String: Any],
                  let remainingFraction = quotaInfo["remainingFraction"] as? Double else { continue }

            let resetTime = quotaInfo["resetTime"] as? String

            configs.append(ModelConfig(
                label: normalizeLabel(displayName),
                remainingFraction: remainingFraction,
                resetTime: resetTime
            ))
        }

        return configs
    }

    private struct ModelConfig {
        let label: String
        let remainingFraction: Double
        let resetTime: String?
    }

    private func normalizeLabel(_ label: String) -> String {
        label.replacingOccurrences(of: #"\s*\([^)]*\)\s*$"#, with: "", options: .regularExpression).trimmingCharacters(in: .whitespaces)
    }

    private func buildModelLines(configs: [ModelConfig]) -> [MetricLine] {
        // Deduplicate by label, keeping lowest remaining fraction
        var deduped: [String: ModelConfig] = [:]
        for config in configs {
            if let existing = deduped[config.label] {
                if config.remainingFraction < existing.remainingFraction {
                    deduped[config.label] = config
                }
            } else {
                deduped[config.label] = config
            }
        }

        // Sort: Gemini Pro > other Gemini > Claude Opus > other Claude > rest
        let sorted = deduped.values.sorted { a, b in
            modelSortKey(a.label) < modelSortKey(b.label)
        }

        return sorted.map { config in
            let used = (1 - max(0, min(1, config.remainingFraction))) * 100
            let resetsAt = config.resetTime.flatMap { ISO8601DateFormatter().date(from: $0) }

            return .progress(ProgressMetric(
                label: config.label,
                used: used.rounded(),
                limit: 100,
                format: .percent,
                resetsAt: resetsAt,
                periodDuration: 5 * 60 * 60
            ))
        }
    }

    private func modelSortKey(_ label: String) -> String {
        let lower = label.lowercased()
        if lower.contains("gemini") && lower.contains("pro") { return "0a_\(label)" }
        if lower.contains("gemini") { return "0b_\(label)" }
        if lower.contains("claude") && lower.contains("opus") { return "1a_\(label)" }
        if lower.contains("claude") { return "1b_\(label)" }
        return "2_\(label)"
    }
}
