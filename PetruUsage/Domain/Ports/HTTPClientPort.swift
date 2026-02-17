import Foundation

struct HTTPRequest {
    let method: String
    let url: String
    var headers: [String: String] = [:]
    var body: Data?
    var timeoutInterval: TimeInterval = 10

    static func get(_ url: String, headers: [String: String] = [:]) -> HTTPRequest {
        HTTPRequest(method: "GET", url: url, headers: headers)
    }

    static func post(_ url: String, headers: [String: String] = [:], body: Data? = nil) -> HTTPRequest {
        HTTPRequest(method: "POST", url: url, headers: headers, body: body)
    }
}

struct HTTPResponse {
    let statusCode: Int
    let data: Data
    let headers: [String: String]

    var isSuccess: Bool { (200..<300).contains(statusCode) }
    var isAuthError: Bool { statusCode == 401 || statusCode == 403 }

    func decoded<T: Decodable>(_ type: T.Type) throws -> T {
        try JSONDecoder().decode(type, from: data)
    }

    var bodyString: String? {
        String(data: data, encoding: .utf8)
    }
}

protocol HTTPClientPort {
    func execute(_ request: HTTPRequest) async throws -> HTTPResponse
}
