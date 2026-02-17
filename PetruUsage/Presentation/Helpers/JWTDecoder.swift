import Foundation

enum JWTDecoder {
    struct Payload: Decodable {
        let sub: String?
        let exp: Double?
        let iat: Double?

        var expirationDate: Date? {
            exp.map { Date(timeIntervalSince1970: $0) }
        }

        var userId: String? {
            guard let sub else { return nil }
            let parts = sub.split(separator: "|")
            return parts.count > 1 ? String(parts[1]) : String(parts[0])
        }
    }

    static func decodePayload(_ token: String) -> Payload? {
        let segments = token.split(separator: ".")
        guard segments.count >= 2 else { return nil }

        let payloadSegment = String(segments[1])
        guard let data = base64UrlDecode(payloadSegment) else { return nil }

        return try? JSONDecoder().decode(Payload.self, from: data)
    }

    private static func base64UrlDecode(_ string: String) -> Data? {
        var base64 = string
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")

        let remainder = base64.count % 4
        if remainder > 0 {
            base64 += String(repeating: "=", count: 4 - remainder)
        }

        return Data(base64Encoded: base64)
    }
}
