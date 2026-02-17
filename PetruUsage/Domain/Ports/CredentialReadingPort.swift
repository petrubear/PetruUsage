import Foundation

protocol CredentialReadingPort {
    func readCredential(for provider: Provider) throws -> OAuthCredential
}
