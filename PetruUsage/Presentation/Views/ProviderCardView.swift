import SwiftUI

struct ProviderCardView: View {
    let provider: Provider
    let status: ProviderStatus

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Provider header
            HStack(spacing: 8) {
                Image(systemName: provider.iconName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(provider.brandColor)

                Text(provider.displayName)
                    .font(.system(size: 13, weight: .semibold))

                if let result = status.result, let plan = result.plan {
                    Text(plan)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(provider.brandColor.opacity(0.1))
                        )
                }

                Spacer()

                if status.isLoading {
                    ProgressView()
                        .controlSize(.mini)
                }
            }

            // Content based on status
            switch status {
            case .idle:
                Text("Waiting...")
                    .font(.caption)
                    .foregroundStyle(.tertiary)

            case .loading:
                EmptyView()

            case .loaded(let result):
                VStack(spacing: 6) {
                    ForEach(result.lines) { line in
                        MetricLineView(line: line, brandColor: provider.brandColor)
                    }
                }

            case .error(let message):
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption2)
                        .foregroundStyle(.yellow)
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

            case .disabled:
                EmptyView()
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(.background)
                .shadow(color: .black.opacity(0.06), radius: 2, y: 1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(provider.brandColor.opacity(0.15), lineWidth: 1)
        )
    }
}

struct MetricLineView: View {
    let line: MetricLine
    let brandColor: Color

    var body: some View {
        switch line {
        case .progress(let metric):
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(metric.label)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(metric.formattedPercentage)
                        .font(.system(size: 11, weight: .medium))
                        .monospacedDigit()
                        .foregroundStyle(metric.fraction >= 0.9 ? .red : .primary)
                }

                ProgressBarView(fraction: metric.fraction, color: brandColor)

                if let resetsAt = metric.resetsAt {
                    ResetTimerView(resetsAt: resetsAt, periodDuration: metric.periodDuration)
                }
            }

        case .text(let metric):
            HStack {
                Text(metric.label)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(metric.value)
                    .font(.system(size: 11, weight: .medium))
                    .monospacedDigit()
            }

        case .badge(let metric):
            HStack {
                Text(metric.label)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(metric.text)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color(hex: metric.color))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(Color(hex: metric.color).opacity(0.15))
                    )
            }
        }
    }
}
