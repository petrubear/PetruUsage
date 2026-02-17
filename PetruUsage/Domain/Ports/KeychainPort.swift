import Foundation

protocol KeychainPort {
    func readGenericPassword(service: String) throws -> String?
    func writeGenericPassword(service: String, data: String) throws
}
