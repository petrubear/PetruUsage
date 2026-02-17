import Foundation
import SQLite3

final class SQLiteService: SQLitePort {
    func query(dbPath: String, sql: String) throws -> [[String: String]] {
        let expandedPath = NSString(string: dbPath).expandingTildeInPath

        var db: OpaquePointer?
        // Use READWRITE instead of READONLY to support WAL-mode databases
        // whose -shm file may be held by another process (e.g., Cursor, VS Code).
        // We never write — this just lets SQLite access the WAL correctly.
        let openFlags = SQLITE_OPEN_READWRITE | SQLITE_OPEN_NOMUTEX
        let rc = sqlite3_open_v2(expandedPath, &db, openFlags, nil)
        guard rc == SQLITE_OK, let db else {
            let msg = db.map { String(cString: sqlite3_errmsg($0)) } ?? "unknown error"
            sqlite3_close(db)
            throw SQLiteError.openFailed(path: expandedPath, message: msg)
        }
        defer { sqlite3_close(db) }

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK, let stmt else {
            let msg = String(cString: sqlite3_errmsg(db))
            throw SQLiteError.prepareFailed(sql: sql, message: msg)
        }
        defer { sqlite3_finalize(stmt) }

        var rows: [[String: String]] = []
        let columnCount = sqlite3_column_count(stmt)

        while sqlite3_step(stmt) == SQLITE_ROW {
            var row: [String: String] = [:]
            for i in 0..<columnCount {
                let name = String(cString: sqlite3_column_name(stmt, i))
                if let text = sqlite3_column_text(stmt, i) {
                    row[name] = String(cString: text)
                }
            }
            rows.append(row)
        }

        return rows
    }
}

enum SQLiteError: LocalizedError {
    case openFailed(path: String, message: String)
    case prepareFailed(sql: String, message: String)

    var errorDescription: String? {
        switch self {
        case .openFailed(let path, let message):
            "Failed to open database at \(path): \(message)"
        case .prepareFailed(let sql, let message):
            "Failed to prepare SQL '\(sql)': \(message)"
        }
    }
}
