import SwiftUI

struct SettingsView: View {
    @Bindable var viewModel: SettingsViewModel

    var body: some View {
        Form {
            Section("Providers") {
                ForEach(viewModel.orderedVisibleProviders) { provider in
                    Toggle(isOn: Binding(
                        get: { viewModel.isProviderEnabled(provider) },
                        set: { viewModel.setProviderEnabled(provider, enabled: $0) }
                    )) {
                        HStack(spacing: 8) {
                            Image(systemName: provider.iconName)
                                .foregroundStyle(provider.brandColor)
                                .frame(width: 20)
                            Text(provider.displayName)
                        }
                    }
                    .toggleStyle(.switch)
                }
                .onMove { viewModel.moveProviders(from: $0, to: $1) }
            }

            Section("Refresh Interval") {
                Picker("Auto-refresh every", selection: Binding(
                    get: { viewModel.refreshIntervalMinutes },
                    set: { viewModel.refreshIntervalMinutes = $0 }
                )) {
                    Text("1 min").tag(1.0)
                    Text("5 min").tag(5.0)
                    Text("15 min").tag(15.0)
                    Text("30 min").tag(30.0)
                }
                .pickerStyle(.segmented)
            }

            Section("Appearance") {
                Picker("Theme", selection: $viewModel.theme) {
                    ForEach(AppTheme.allCases, id: \.self) { theme in
                        Text(theme.displayName).tag(theme)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section("System") {
                Toggle("Hide from Dock", isOn: Binding(
                    get: { viewModel.hideFromDock },
                    set: { viewModel.hideFromDock = $0 }
                ))

                Toggle("Start on login", isOn: Binding(
                    get: { viewModel.startOnLogin },
                    set: { viewModel.startOnLogin = $0 }
                ))
            }

            Section {
                Button(role: .destructive) {
                    NSApplication.shared.terminate(nil)
                } label: {
                    Label("Quit PetruUsage", systemImage: "power")
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 360, height: 520)
        .navigationTitle("Settings")
    }
}
