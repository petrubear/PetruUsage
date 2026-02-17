import Foundation

enum MetricFormat {
    case percent
    case dollars
    case count(suffix: String)
}

enum MetricLine: Identifiable {
    case progress(ProgressMetric)
    case text(TextMetric)
    case badge(BadgeMetric)

    var id: String {
        switch self {
        case .progress(let m): "progress-\(m.label)"
        case .text(let m): "text-\(m.label)"
        case .badge(let m): "badge-\(m.label)"
        }
    }
}

struct ProgressMetric {
    let label: String
    let used: Double
    let limit: Double
    let format: MetricFormat
    let resetsAt: Date?
    let periodDuration: TimeInterval?

    var fraction: Double {
        guard limit > 0 else { return 0 }
        return min(1.0, max(0.0, used / limit))
    }

    var formattedUsed: String {
        formatValue(used)
    }

    var formattedLimit: String {
        formatValue(limit)
    }

    var formattedPercentage: String {
        switch format {
        case .percent:
            return "\(Int(used))%"
        default:
            return "\(Int(fraction * 100))%"
        }
    }

    private func formatValue(_ value: Double) -> String {
        switch format {
        case .percent:
            return "\(Int(value))%"
        case .dollars:
            return String(format: "$%.2f", value)
        case .count(let suffix):
            return "\(Int(value)) \(suffix)"
        }
    }
}

struct TextMetric {
    let label: String
    let value: String
}

struct BadgeMetric {
    let label: String
    let text: String
    let color: String
}
