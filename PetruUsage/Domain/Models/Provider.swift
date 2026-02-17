import SwiftUI

enum Provider: String, CaseIterable, Identifiable, Codable {
    case claude
    case cursor
    case codex
    case antigravity
    case kiro

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .claude: "Claude"
        case .cursor: "Cursor"
        case .codex: "Codex"
        case .antigravity: "Gemini"
        case .kiro: "Kiro"
        }
    }

    var brandColor: Color {
        switch self {
        case .claude: Color(red: 0.85, green: 0.45, blue: 0.27)
        case .cursor: Color(red: 0.0, green: 0.0, blue: 0.0)
        case .codex: Color(red: 0.0, green: 0.64, blue: 0.52)
        case .antigravity: Color(red: 0.26, green: 0.52, blue: 0.96)
        case .kiro: Color(red: 0.56, green: 0.27, blue: 0.96)
        }
    }

    var iconName: String {
        switch self {
        case .claude: "brain.head.profile"
        case .cursor: "cursorarrow.rays"
        case .codex: "terminal"
        case .antigravity: "arrow.up.circle"
        case .kiro: "wand.and.stars"
        }
    }

    /// Providers currently shown in the UI. Cursor is hidden until its API parsing is fixed.
    static var visibleCases: [Provider] {
        allCases.filter { $0 != .cursor }
    }
}
