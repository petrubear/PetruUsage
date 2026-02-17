import Foundation

final class ToggleProviderUseCase {
    private let settings: SettingsPort

    init(settings: SettingsPort) {
        self.settings = settings
    }

    func execute(provider: Provider, enabled: Bool) {
        settings.setProviderEnabled(provider, enabled: enabled)
    }
}
