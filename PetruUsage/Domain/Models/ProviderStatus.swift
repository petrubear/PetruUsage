import Foundation

enum ProviderStatus {
    case idle
    case loading
    case loaded(ProviderUsageResult)
    case error(String)
    case disabled

    var isLoading: Bool {
        if case .loading = self { return true }
        return false
    }

    var result: ProviderUsageResult? {
        if case .loaded(let result) = self { return result }
        return nil
    }

    var errorMessage: String? {
        if case .error(let message) = self { return message }
        return nil
    }

    var isDisabled: Bool {
        if case .disabled = self { return true }
        return false
    }
}
