import Foundation

protocol SQLitePort {
    func query(dbPath: String, sql: String) throws -> [[String: String]]
}
