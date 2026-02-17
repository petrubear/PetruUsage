import Foundation

protocol UsageFetchingPort {
    var provider: Provider { get }
    func fetchUsage() async throws -> ProviderUsageResult
}
