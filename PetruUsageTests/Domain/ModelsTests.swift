import XCTest
@testable import PetruUsage

final class ModelsTests: XCTestCase {
    func testProviderCasesExist() {
        XCTAssertEqual(Provider.allCases.count, 5)
        XCTAssertEqual(Provider.claude.displayName, "Claude")
        XCTAssertEqual(Provider.cursor.displayName, "Cursor")
        XCTAssertEqual(Provider.codex.displayName, "Codex")
        XCTAssertEqual(Provider.antigravity.displayName, "Antigravity")
        XCTAssertEqual(Provider.kiro.displayName, "Kiro")
    }

    func testProviderIdentifiable() {
        XCTAssertEqual(Provider.claude.id, "claude")
        XCTAssertEqual(Provider.cursor.id, "cursor")
    }

    func testProgressMetricFraction() {
        let metric = ProgressMetric(
            label: "Test",
            used: 50,
            limit: 100,
            format: .percent,
            resetsAt: nil,
            periodDuration: nil
        )
        XCTAssertEqual(metric.fraction, 0.5, accuracy: 0.001)
    }

    func testProgressMetricFractionClamped() {
        let metric = ProgressMetric(
            label: "Test",
            used: 150,
            limit: 100,
            format: .percent,
            resetsAt: nil,
            periodDuration: nil
        )
        XCTAssertEqual(metric.fraction, 1.0, accuracy: 0.001)
    }

    func testProgressMetricZeroLimit() {
        let metric = ProgressMetric(
            label: "Test",
            used: 50,
            limit: 0,
            format: .percent,
            resetsAt: nil,
            periodDuration: nil
        )
        XCTAssertEqual(metric.fraction, 0.0)
    }

    func testProgressMetricDollarsFormat() {
        let metric = ProgressMetric(
            label: "Plan",
            used: 25.5,
            limit: 100,
            format: .dollars,
            resetsAt: nil,
            periodDuration: nil
        )
        XCTAssertEqual(metric.formattedUsed, "$25.50")
        XCTAssertEqual(metric.formattedLimit, "$100.00")
    }

    func testProgressMetricCountFormat() {
        let metric = ProgressMetric(
            label: "Credits",
            used: 750,
            limit: 1000,
            format: .count(suffix: "credits"),
            resetsAt: nil,
            periodDuration: nil
        )
        XCTAssertEqual(metric.formattedUsed, "750 credits")
        XCTAssertEqual(metric.formattedLimit, "1000 credits")
    }

    func testCredentialNeedsRefresh() {
        let expiringSoon = OAuthCredential(
            accessToken: "token",
            refreshToken: "refresh",
            expiresAt: Date().addingTimeInterval(60),
            source: .file(path: "/tmp/test")
        )
        XCTAssertTrue(expiringSoon.needsRefresh)

        let fresh = OAuthCredential(
            accessToken: "token",
            refreshToken: "refresh",
            expiresAt: Date().addingTimeInterval(3600),
            source: .file(path: "/tmp/test")
        )
        XCTAssertFalse(fresh.needsRefresh)
    }

    func testCredentialIsExpired() {
        let expired = OAuthCredential(
            accessToken: "token",
            refreshToken: nil,
            expiresAt: Date().addingTimeInterval(-60),
            source: .file(path: "/tmp/test")
        )
        XCTAssertTrue(expired.isExpired)

        let noExpiry = OAuthCredential(
            accessToken: "token",
            refreshToken: nil,
            expiresAt: nil,
            source: .file(path: "/tmp/test")
        )
        XCTAssertFalse(noExpiry.isExpired)
    }

    func testProviderStatusProperties() {
        let loading = ProviderStatus.loading
        XCTAssertTrue(loading.isLoading)
        XCTAssertNil(loading.result)
        XCTAssertNil(loading.errorMessage)

        let error = ProviderStatus.error("test error")
        XCTAssertFalse(error.isLoading)
        XCTAssertEqual(error.errorMessage, "test error")
        XCTAssertNil(error.result)

        let result = ProviderUsageResult(provider: .claude, lines: [])
        let loaded = ProviderStatus.loaded(result)
        XCTAssertFalse(loaded.isLoading)
        XCTAssertNotNil(loaded.result)
    }

    func testMetricLineIdentifiers() {
        let progress = MetricLine.progress(ProgressMetric(
            label: "Session", used: 50, limit: 100, format: .percent, resetsAt: nil, periodDuration: nil
        ))
        XCTAssertEqual(progress.id, "progress-Session")

        let text = MetricLine.text(TextMetric(label: "Extra", value: "$5.00"))
        XCTAssertEqual(text.id, "text-Extra")

        let badge = MetricLine.badge(BadgeMetric(label: "Status", text: "OK", color: "#00ff00"))
        XCTAssertEqual(badge.id, "badge-Status")
    }
}
