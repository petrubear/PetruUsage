import Foundation
@testable import PetruUsage

final class MockHTTPClient: HTTPClientPort {
    var responses: [String: HTTPResponse] = [:]
    var requestLog: [HTTPRequest] = []

    func execute(_ request: HTTPRequest) async throws -> HTTPResponse {
        requestLog.append(request)

        if let response = responses[request.url] {
            return response
        }

        return HTTPResponse(
            statusCode: 404,
            data: Data(),
            headers: [:]
        )
    }

    func setResponse(for url: String, statusCode: Int, body: [String: Any]) {
        let data = (try? JSONSerialization.data(withJSONObject: body)) ?? Data()
        responses[url] = HTTPResponse(statusCode: statusCode, data: data, headers: [:])
    }

    func setResponse(for url: String, response: HTTPResponse) {
        responses[url] = response
    }
}

final class MockSQLiteService: SQLitePort {
    var queryResults: [String: [[String: String]]] = [:]

    func query(dbPath: String, sql: String) throws -> [[String: String]] {
        let key = "\(dbPath)|\(sql)"
        if let result = queryResults[key] {
            return result
        }
        // Try matching just by SQL
        for (k, v) in queryResults {
            if k.contains(sql) || sql.contains(k) {
                return v
            }
        }
        return []
    }

    func setResult(dbPath: String, sql: String, rows: [[String: String]]) {
        queryResults["\(dbPath)|\(sql)"] = rows
    }
}

final class MockKeychainService: KeychainPort {
    var passwords: [String: String] = [:]

    func readGenericPassword(service: String) throws -> String? {
        passwords[service]
    }

    func writeGenericPassword(service: String, data: String) throws {
        passwords[service] = data
    }
}
