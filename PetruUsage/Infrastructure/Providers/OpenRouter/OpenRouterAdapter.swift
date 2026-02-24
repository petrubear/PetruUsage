import Foundation

final class OpenRouterAdapter: UsageFetchingPort {
    let provider: Provider = .openrouter

    private let httpClient: HTTPClientPort
    private let keychain: KeychainPort

    private let singleKeyChainService = "OPENROUTER_API_KEY"
    private let managementKeychainService = "OPENROUTER_MANAGEMENT_KEY"
    private let singleKeyURL = "https://openrouter.ai/api/v1/auth/key"
    private let allKeysURL = "https://openrouter.ai/api/v1/keys"

    init(httpClient: HTTPClientPort, keychain: KeychainPort) {
        self.httpClient = httpClient
        self.keychain = keychain
    }

    func fetchUsage() async throws -> ProviderUsageResult {
        if let managementKey = try? keychain.readGenericPassword(service: managementKeychainService),
           !managementKey.isEmpty {
            return try await fetchAllKeysUsage(managementKey: managementKey)
        }

        guard let apiKey = try keychain.readGenericPassword(service: singleKeyChainService),
              !apiKey.isEmpty else {
            throw ProviderError.notLoggedIn("OpenRouter API key not found in Keychain.")
        }

        return try await fetchSingleKeyUsage(apiKey: apiKey)
    }

    // MARK: - Management Key Flow

    private func fetchAllKeysUsage(managementKey: String) async throws -> ProviderUsageResult {
        let request = HTTPRequest(
            method: "GET",
            url: allKeysURL,
            headers: [
                "Authorization": "Bearer \(managementKey)",
                "Accept": "application/json",
                "User-Agent": "PetruUsage",
            ],
            timeoutInterval: 10
        )

        let response = try await httpClient.execute(request)

        guard response.isSuccess else {
            if response.statusCode == 401 {
                throw ProviderError.authExpired("Management API key invalid or expired.")
            }
            throw ProviderError.httpError(response.statusCode)
        }

        return try parseAllKeysResponse(data: response.data)
    }

    private func parseAllKeysResponse(data: Data) throws -> ProviderUsageResult {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let keys = json["data"] as? [[String: Any]] else {
            throw ProviderError.invalidResponse
        }

        let activeKeys = keys.filter { ($0["disabled"] as? Bool) != true }

        let daily   = activeKeys.reduce(0.0) { $0 + ($1["usage_daily"]   as? Double ?? 0) }
        let weekly  = activeKeys.reduce(0.0) { $0 + ($1["usage_weekly"]  as? Double ?? 0) }
        let monthly = activeKeys.reduce(0.0) { $0 + ($1["usage_monthly"] as? Double ?? 0) }

        var lines: [MetricLine] = [
            .text(TextMetric(label: "Today",   value: String(format: "$%.4f", daily))),
            .text(TextMetric(label: "Week",    value: String(format: "$%.4f", weekly))),
            .text(TextMetric(label: "Month",   value: String(format: "$%.4f", monthly))),
        ]

        let keyCount = activeKeys.count
        lines.append(.badge(BadgeMetric(
            label: "Keys",
            text: "\(keyCount) active",
            color: "#8BE9FD"
        )))

        return ProviderUsageResult(provider: .openrouter, plan: "All Keys", lines: lines)
    }

    // MARK: - Single Key Flow

    private func fetchSingleKeyUsage(apiKey: String) async throws -> ProviderUsageResult {
        let request = HTTPRequest(
            method: "GET",
            url: singleKeyURL,
            headers: [
                "Authorization": "Bearer \(apiKey)",
                "Accept": "application/json",
                "User-Agent": "PetruUsage",
            ],
            timeoutInterval: 10
        )

        let response = try await httpClient.execute(request)

        guard response.isSuccess else {
            if response.statusCode == 401 {
                throw ProviderError.authExpired("API key invalid or expired.")
            }
            throw ProviderError.httpError(response.statusCode)
        }

        return try parseSingleKeyResponse(data: response.data)
    }

    private func parseSingleKeyResponse(data: Data) throws -> ProviderUsageResult {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let keyData = json["data"] as? [String: Any] else {
            throw ProviderError.invalidResponse
        }

        var lines: [MetricLine] = []

        let usage = keyData["usage"] as? Double ?? 0
        let limit = keyData["limit"] as? Double
        let label = keyData["label"] as? String
        let isFreeTier = keyData["is_free_tier"] as? Bool ?? false

        if let limit {
            lines.append(.progress(ProgressMetric(
                label: "Credits",
                used: usage,
                limit: limit,
                format: .dollars,
                resetsAt: nil,
                periodDuration: nil
            )))
        } else {
            lines.append(.text(TextMetric(label: "Spent", value: String(format: "$%.4f", usage))))
        }

        if isFreeTier {
            lines.append(.badge(BadgeMetric(label: "Tier", text: "Free", color: "#50FA7B")))
        }

        if lines.isEmpty {
            lines.append(.badge(BadgeMetric(label: "Status", text: "No data", color: "#a3a3a3")))
        }

        let plan = label.flatMap { $0.isEmpty ? nil : $0 }
        return ProviderUsageResult(provider: .openrouter, plan: plan, lines: lines)
    }
}
