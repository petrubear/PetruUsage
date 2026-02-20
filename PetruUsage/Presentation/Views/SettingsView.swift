import SwiftUI

struct SettingsView: View {
    @Bindable var viewModel: SettingsViewModel

    var body: some View {
        Form {
            Section("Providers") {
                ForEach(Provider.visibleCases) { provider in
                    Toggle(isOn: Binding(
                        get: { viewModel.isProviderEnabled(provider) },
                        set: { viewModel.setProviderEnabled(provider, enabled: $0) }
                    )) {
                        HStack(spacing: 6) {
                            Image(systemName: provider.iconName)
                                .foregroundStyle(provider.brandColor)
                                .frame(width: 20)
                            Text(provider.displayName)
                        }
                    }
                }
            }

            Section("Refresh") {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Auto-refresh every")
                        .font(.subheadline)
                    Picker("", selection: Binding(
                        get: { viewModel.refreshIntervalMinutes },
                        set: { viewModel.refreshIntervalMinutes = $0 }
                    )) {
                        Text("1m").tag(1.0)
                        Text("5m").tag(5.0)
                        Text("15m").tag(15.0)
                        Text("30m").tag(30.0)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }
            }

            Section("Appearance") {
                Picker("Theme", selection: $viewModel.theme) {
                    ForEach(AppTheme.allCases, id: \.self) { theme in
                        Text(theme.displayName).tag(theme)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
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

                Button(role: .destructive) {
                    NSApplication.shared.terminate(nil)
                } label: {
                    Text("Quit PetruUsage")
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 350, height: 520)
        .navigationTitle("Settings")
    }
}
