import Foundation

final class AntigravityUsageAdapter: UsageFetchingPort {
    let provider: Provider = .antigravity

    private let httpClient: HTTPClientPort
    private let sqlite: SQLitePort

    private let stateDB = "~/Library/Application Support/Antigravity/User/globalStorage/state.vscdb"
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

    init(httpClient: HTTPClientPort, sqlite: SQLitePort) {
        self.httpClient = httpClient
        self.sqlite = sqlite
    }

    func fetchUsage() async throws -> ProviderUsageResult {
        let apiKey = loadApiKey()
        let protoTokens = loadProtoTokens()

        // Collect available tokens
        var tokens: [String] = []
        if let proto = protoTokens, !proto.accessToken.isEmpty {
            if proto.expirySeconds == nil || proto.expirySeconds! > Date().timeIntervalSince1970 {
                tokens.append(proto.accessToken)
            }
        }
        if let key = apiKey, !key.isEmpty, key != protoTokens?.accessToken {
            tokens.append(key)
        }

        guard !tokens.isEmpty else {
            throw ProviderError.notLoggedIn("Start Antigravity and try again.")
        }

        // Try Cloud Code API with each token
        var ccData: [String: Any]?
        var authFailed = false

        for token in tokens {
            let result = try await probeCloudCode(token: token)
            if let data = result.data {
                ccData = data
                break
            }
            if result.authFailed { authFailed = true }
        }

        // Refresh if all tokens failed auth
        if ccData == nil && authFailed, let refreshToken = protoTokens?.refreshToken {
            if let refreshed = try? await refreshAccessToken(refreshToken: refreshToken) {
                let result = try await probeCloudCode(token: refreshed)
                ccData = result.data
            }
        }

        guard let data = ccData else {
            throw ProviderError.noData("Start Antigravity and try again.")
        }

        let configs = parseCloudCodeModels(data: data)
        let lines = buildModelLines(configs: configs)

        guard !lines.isEmpty else {
            throw ProviderError.noData("Start Antigravity and try again.")
        }

        return ProviderUsageResult(provider: .antigravity, plan: nil, lines: lines)
    }

    // MARK: - Credential Loading

    private func loadApiKey() -> String? {
        guard let rows = try? sqlite.query(
            dbPath: stateDB,
            sql: "SELECT value FROM ItemTable WHERE key = 'antigravityAuthStatus' LIMIT 1"
        ),
              let value = rows.first?["value"],
              let data = value.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let apiKey = json["apiKey"] as? String else {
            return nil
        }
        return apiKey
    }

    private struct ProtoTokens {
        let accessToken: String
        let refreshToken: String?
        let expirySeconds: TimeInterval?
    }

    private func loadProtoTokens() -> ProtoTokens? {
        guard let rows = try? sqlite.query(
            dbPath: stateDB,
            sql: "SELECT value FROM ItemTable WHERE key = 'jetskiStateSync.agentManagerInitState' LIMIT 1"
        ),
              let value = rows.first?["value"],
              let rawData = Data(base64Encoded: value) else {
            return nil
        }

        let raw = String(data: rawData, encoding: .isoLatin1) ?? ""
        let outer = ProtobufDecoder.readFields(raw)

        guard let field6 = outer[6], field6.type == .lengthDelimited else { return nil }
        let inner = ProtobufDecoder.readFields(field6.stringData)

        let accessToken = inner[1].flatMap { $0.type == .lengthDelimited ? $0.stringData : nil }
        let refreshToken = inner[3].flatMap { $0.type == .lengthDelimited ? $0.stringData : nil }

        var expirySeconds: TimeInterval?
        if let field4 = inner[4], field4.type == .lengthDelimited {
            let ts = ProtobufDecoder.readFields(field4.stringData)
            if let field1 = ts[1], field1.type == .varint {
                expirySeconds = TimeInterval(field1.varintValue)
            }
        }

        guard let token = accessToken, !token.isEmpty else { return nil }
        return ProtoTokens(accessToken: token, refreshToken: refreshToken, expirySeconds: expirySeconds)
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
                    ],
                    body: "{}".data(using: .utf8),
                    timeoutInterval: 15
                )

                let response = try await httpClient.execute(request)

                if response.isAuthError {
                    return CloudCodeResult(data: nil, authFailed: true)
                }

                if response.isSuccess,
                   let json = try? JSONSerialization.jsonObject(with: response.data) as? [String: Any] {
                    return CloudCodeResult(data: json, authFailed: false)
                }
            } catch {
                continue
            }
        }

        return CloudCodeResult(data: nil, authFailed: false)
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
            headers: ["Content-Type": "application/x-www-form-urlencoded"],
            body: bodyString.data(using: .utf8),
            timeoutInterval: 15
        )

        let response = try await httpClient.execute(request)

        guard response.isSuccess,
              let json = try? JSONSerialization.jsonObject(with: response.data) as? [String: Any],
              let accessToken = json["access_token"] as? String else {
            throw ProviderError.refreshFailed
        }

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

// MARK: - Minimal Protobuf Decoder

enum ProtobufDecoder {
    enum WireType {
        case varint
        case lengthDelimited
    }

    struct Field {
        let type: WireType
        let varintValue: UInt64
        let stringData: String

        init(varint value: UInt64) {
            self.type = .varint
            self.varintValue = value
            self.stringData = ""
        }

        init(string data: String) {
            self.type = .lengthDelimited
            self.varintValue = 0
            self.stringData = data
        }
    }

    static func readFields(_ s: String) -> [Int: Field] {
        var fields: [Int: Field] = [:]
        let chars = Array(s.unicodeScalars)
        var pos = 0

        while pos < chars.count {
            guard let tag = readVarint(chars, pos: &pos) else { break }
            let fieldNum = Int(tag / 8)
            let wireType = tag % 8

            if wireType == 0 {
                guard let value = readVarint(chars, pos: &pos) else { break }
                fields[fieldNum] = Field(varint: value)
            } else if wireType == 2 {
                guard let length = readVarint(chars, pos: &pos) else { break }
                let len = Int(length)
                guard pos + len <= chars.count else { break }
                let data = String(String.UnicodeScalarView(Array(chars[pos..<(pos + len)])))
                fields[fieldNum] = Field(string: data)
                pos += len
            } else {
                break
            }
        }

        return fields
    }

    private static func readVarint(_ chars: [Unicode.Scalar], pos: inout Int) -> UInt64? {
        var value: UInt64 = 0
        var shift: UInt64 = 0

        while pos < chars.count {
            let byte = UInt8(chars[pos].value & 0xFF)
            pos += 1
            value += UInt64(byte & 0x7F) << shift
            if (byte & 0x80) == 0 { return value }
            shift += 7
        }

        return nil
    }
}
