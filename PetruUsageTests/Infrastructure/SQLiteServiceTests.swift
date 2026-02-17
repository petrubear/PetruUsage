import XCTest
@testable import PetruUsage

final class SQLiteServiceTests: XCTestCase {
    func testQueryNonExistentDatabase() {
        let service = SQLiteService()
        XCTAssertThrowsError(try service.query(dbPath: "/nonexistent/db.sqlite", sql: "SELECT 1")) { error in
            XCTAssertTrue(error is SQLiteError)
        }
    }

    func testSQLiteErrorDescription() {
        let openError = SQLiteError.openFailed(path: "/test/db", message: "file not found")
        XCTAssertTrue(openError.localizedDescription.contains("/test/db"))

        let prepareError = SQLiteError.prepareFailed(sql: "SELECT 1", message: "syntax error")
        XCTAssertTrue(prepareError.localizedDescription.contains("SELECT 1"))
    }
}
