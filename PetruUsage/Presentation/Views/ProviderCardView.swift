import SwiftUI

struct ProviderCardView: View {
    let provider: Provider
    let status: ProviderStatus

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Provider header
            HStack(spacing: 6) {
                Image(systemName: provider.iconName)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(provider.brandColor)

                Text(provider.displayName)
                    .font(.system(size: 13, weight: .semibold))

                if let result = status.result, let plan = result.plan {
                    Text(plan)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1)
                        .background(
                            Capsule()
                                .fill(.quaternary)
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
                    .foregroundStyle(.secondary)

            case .loading:
                EmptyView()

            case .loaded(let result):
                VStack(spacing: 4) {
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
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(.background)
                .shadow(color: .black.opacity(0.05), radius: 1, y: 1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(.quaternary, lineWidth: 0.5)
        )
    }
}

struct MetricLineView: View {
    let line: MetricLine
    let brandColor: Color

    var body: some View {
        switch line {
        case .progress(let metric):
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(metric.label)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(metric.formattedPercentage)
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(.primary)
                }

                ProgressBarView(fraction: metric.fraction, color: brandColor)

                if let resetsAt = metric.resetsAt {
                    ResetTimerView(resetsAt: resetsAt, periodDuration: metric.periodDuration)
                }
            }

        case .text(let metric):
            HStack {
                Text(metric.label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(metric.value)
                    .font(.caption)
                    .monospacedDigit()
            }

        case .badge(let metric):
            HStack {
                Text(metric.label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(metric.text)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(Color(hex: metric.color).opacity(0.2))
                    )
            }
        }
    }
}
