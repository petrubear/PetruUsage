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
        case .claude:       Color(red: 1.00, green: 0.72, blue: 0.42) // Dracula Orange  #FFB86C
        case .cursor:       Color(red: 1.00, green: 0.47, blue: 0.78) // Dracula Pink    #FF79C6
        case .codex:        Color(red: 0.31, green: 0.98, blue: 0.48) // Dracula Green   #50FA7B
        case .antigravity:  Color(red: 0.55, green: 0.91, blue: 0.99) // Dracula Cyan    #8BE9FD
        case .kiro:         Color(red: 0.74, green: 0.58, blue: 0.98) // Dracula Purple  #BD93F9
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
