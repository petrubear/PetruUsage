import SwiftUI

struct SettingsView: View {
    @Bindable var viewModel: SettingsViewModel

    var body: some View {
        Form {
            Section("Providers") {
                ForEach(Provider.allCases) { provider in
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
                HStack {
                    Text("Auto-refresh every")
                    Picker("", selection: Binding(
                        get: { viewModel.refreshIntervalMinutes },
                        set: { viewModel.refreshIntervalMinutes = $0 }
                    )) {
                        Text("1 min").tag(1.0)
                        Text("2 min").tag(2.0)
                        Text("5 min").tag(5.0)
                        Text("10 min").tag(10.0)
                        Text("15 min").tag(15.0)
                        Text("30 min").tag(30.0)
                    }
                    .frame(width: 100)
                }
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
        }
        .formStyle(.grouped)
        .frame(width: 350, height: 400)
        .navigationTitle("Settings")
    }
}
