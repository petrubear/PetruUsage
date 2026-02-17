import SwiftUI

struct MenuBarView: View {
    @Bindable var viewModel: UsageViewModel
    let onOpenSettings: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("PetruUsage")
                    .font(.headline)
                    .foregroundStyle(.primary)

                Spacer()

                if viewModel.isRefreshing {
                    ProgressView()
                        .controlSize(.small)
                        .padding(.trailing, 4)
                }

                Button(action: viewModel.refreshAll) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12))
                }
                .buttonStyle(.borderless)
                .disabled(viewModel.isRefreshing)

                Button(action: onOpenSettings) {
                    Image(systemName: "gear")
                        .font(.system(size: 12))
                }
                .buttonStyle(.borderless)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            Divider()

            // Provider cards
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
            .frame(maxHeight: 500)

            // Footer
            if let lastRefreshed = viewModel.lastRefreshed {
                Divider()
                HStack {
                    Text("Updated \(lastRefreshed, style: .relative) ago")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
            }

            Divider()

            // Quit button
            Button("Quit PetruUsage") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.borderless)
            .padding(.vertical, 8)
        }
        .frame(width: 320)
        .onAppear {
            if viewModel.lastRefreshed == nil {
                viewModel.refreshAll()
            }
        }
    }
}
