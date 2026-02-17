import Foundation

struct ProviderUsageResult {
    let provider: Provider
    let plan: String?
    let lines: [MetricLine]
    let fetchedAt: Date

    init(provider: Provider, plan: String? = nil, lines: [MetricLine], fetchedAt: Date = Date()) {
        self.provider = provider
        self.plan = plan
        self.lines = lines
        self.fetchedAt = fetchedAt
    }
}
