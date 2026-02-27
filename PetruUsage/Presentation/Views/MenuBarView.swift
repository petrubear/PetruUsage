import SwiftUI

struct MenuBarView: View {
    @Bindable var viewModel: UsageViewModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)

                Text("PetruUsage")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary)

                Spacer()

                if viewModel.isRefreshing {
                    ProgressView()
                        .controlSize(.small)
                        .padding(.trailing, 2)
                }

                Button(action: viewModel.refreshAll) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
                .disabled(viewModel.isRefreshing)
                .help("Refresh all providers")

                Button {
                    NSApp.activate(ignoringOtherApps: true)
                    openWindow(id: "settings")
                } label: {
                    Image(systemName: "gear")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
                .help("Settings")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            Divider()

            // Provider cards
            if viewModel.sortedProviders.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "tray")
                        .font(.system(size: 28))
                        .foregroundStyle(.tertiary)
                    Text("No providers enabled")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("Enable providers in Settings")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(viewModel.sortedProviders) { provider in
                            if let status = viewModel.providerStatuses[provider] {
                                ProviderCardView(provider: provider, status: status)
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }
                .frame(maxHeight: .infinity)
            }

            // Footer
            if let lastRefreshed = viewModel.lastRefreshed {
                Divider()
                HStack {
                    Image(systemName: "clock")
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                    Text("Updated \(lastRefreshed, style: .relative) ago")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
            }

            Divider()

            // Quit button
            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Text("Quit PetruUsage")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.borderless)
            .padding(.vertical, 8)
        }
        .frame(width: 340, height: 700)
        .onAppear {
            if viewModel.lastRefreshed == nil {
                viewModel.refreshAll()
            }
        }
    }
}
