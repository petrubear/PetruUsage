import SwiftUI

struct ResetTimerView: View {
    let resetsAt: Date
    let periodDuration: TimeInterval?

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "clock")
                .font(.system(size: 8))
                .foregroundStyle(.tertiary)

            Text(formatResetTime())
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
        }
    }

    private func formatResetTime() -> String {
        let remaining = resetsAt.timeIntervalSince(Date())

        if remaining <= 0 {
            return "Reset pending"
        }

        let hours = Int(remaining) / 3600
        let minutes = (Int(remaining) % 3600) / 60

        if hours > 24 {
            let days = hours / 24
            return "Resets in \(days)d \(hours % 24)h"
        }

        if hours > 0 {
            return "Resets in \(hours)h \(minutes)m"
        }

        return "Resets in \(minutes)m"
    }
}
