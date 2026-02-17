import Foundation

final class TokenRefreshService {
    private let httpClient: HTTPClientPort

    init(httpClient: HTTPClientPort) {
        self.httpClient = httpClient
    }

    func executeWithRetry<T>(
        accessToken: String,
        action: (String) async throws -> (HTTPResponse, T),
        refresh: (String) async throws -> String
    ) async throws -> T {
        let (response, result) = try await action(accessToken)

        if response.isAuthError {
            let newToken = try await refresh(accessToken)
            let (retryResponse, retryResult) = try await action(newToken)

            guard retryResponse.isSuccess else {
                throw ProviderError.authExpired("Authentication failed after refresh.")
            }

            return retryResult
        }

        return result
    }
}
