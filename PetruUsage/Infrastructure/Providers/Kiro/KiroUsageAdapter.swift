import Foundation

final class KiroUsageAdapter: UsageFetchingPort {
    let provider: Provider = .kiro

    private let sqlite: SQLitePort

    private let stateDB = "~/Library/Application Support/Kiro/User/globalStorage/state.vscdb"
    private let stateKey = "kiro.kiroAgent"
    private let usageStateField = "kiro.resourceNotifications.usageState"
    private let tokenLogPath = "~/Library/Application Support/Kiro/User/globalStorage/kiro.kiroagent/dev_data/tokens_generated.jsonl"

    init(sqlite: SQLitePort) {
        self.sqlite = sqlite
    }

    func fetchUsage() async throws -> ProviderUsageResult {
        // Try cached usage state first
        if let cachedResult = try? loadCachedUsage() {
            return cachedResult
        }

        // Fallback: token counting from local log
        if let tokenResult = try? loadTokenCounts() {
            return tokenResult
        }

        throw ProviderError.noData("Install Kiro and try again.")
    }

    // MARK: - Cached Usage

    private func loadCachedUsage() throws -> ProviderUsageResult {
        let rows = try sqlite.query(
            dbPath: stateDB,
            sql: "SELECT value FROM ItemTable WHERE key = '\(stateKey)' LIMIT 1;"
        )

        guard let value = rows.first?["value"],
              let data = value.data(using: .utf8),
              let rootJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let usageState = rootJson[usageStateField] as? [String: Any],
              let breakdowns = usageState["usageBreakdowns"] as? [[String: Any]],
              !breakdowns.isEmpty else {
            throw ProviderError.invalidResponse
        }

        var lines: [MetricLine] = []

        for breakdown in breakdowns {
            guard let displayName = breakdown["displayName"] as? String,
                  let percentageUsed = breakdown["percentageUsed"] as? Double else { continue }

            let usageLimit = breakdown["usageLimit"] as? Int
            let currentUsage = breakdown["currentUsage"] as? Double
            let resetDate = (breakdown["resetDate"] as? String).flatMap { ISO8601DateFormatter().date(from: $0) }

            if let limit = usageLimit, limit > 0 {
                let used = currentUsage ?? (percentageUsed / 100 * Double(limit))
                lines.append(.progress(ProgressMetric(
                    label: displayName,
                    used: used,
                    limit: Double(limit),
                    format: .count(suffix: "invocations"),
                    resetsAt: resetDate,
                    periodDuration: nil
                )))
            } else {
                lines.append(.progress(ProgressMetric(
                    label: displayName,
                    used: percentageUsed,
                    limit: 100,
                    format: .percent,
                    resetsAt: resetDate,
                    periodDuration: nil
                )))
            }
        }

        guard !lines.isEmpty else {
            throw ProviderError.invalidResponse
        }

        return ProviderUsageResult(provider: .kiro, plan: nil, lines: lines)
    }

    // MARK: - Token Counting Fallback

    private func loadTokenCounts() throws -> ProviderUsageResult {
        let expandedPath = NSString(string: tokenLogPath).expandingTildeInPath

        guard FileManager.default.fileExists(atPath: expandedPath),
              let content = try? String(contentsOfFile: expandedPath, encoding: .utf8) else {
            throw ProviderError.noData("No Kiro token log found.")
        }

        let jsonLines = content.components(separatedBy: .newlines).filter { !$0.isEmpty }
        var totalTokens = 0

        for line in jsonLines {
            guard let data = line.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { continue }
            let prompt = json["promptTokens"] as? Int ?? 0
            let generated = json["generatedTokens"] as? Int ?? 0
            totalTokens += prompt + generated
        }

        let lines: [MetricLine] = [
            .text(TextMetric(
                label: "Tokens generated",
                value: formatTokenCount(totalTokens)
            ))
        ]

        return ProviderUsageResult(provider: .kiro, plan: nil, lines: lines)
    }

    private func formatTokenCount(_ count: Int) -> String {
        if count >= 1_000_000 {
            return String(format: "%.1fM", Double(count) / 1_000_000)
        }
        if count >= 1_000 {
            return String(format: "%.1fK", Double(count) / 1_000)
        }
        return "\(count)"
    }
}
