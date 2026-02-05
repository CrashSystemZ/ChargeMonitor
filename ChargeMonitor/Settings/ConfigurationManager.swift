import Combine
import Foundation

@MainActor
final class ConfigurationManager: ObservableObject {
    static let shared = ConfigurationManager()
    @Published private(set) var configuration: AppConfiguration
    private let store: ConfigurationStoring

    init(store: ConfigurationStoring) {
        self.store = store

        let initial = (store.load() ?? .default).normalized()
        self.configuration = initial
        store.save(initial)
    }

    convenience init() {
        self.init(store: UserDefaultsConfigurationStore())
    }

    func setOption(_ option: DisplayOption, isEnabled: Bool) {
        update { config in
            if isEnabled {
                config.enabledOptions.insert(option)
            } else {
                config.enabledOptions.remove(option)
            }
        }
    }

    private func update(_ mutation: (inout AppConfiguration) -> Void) {
        var next = configuration
        mutation(&next)
        next = next.normalized()
        configuration = next
        store.save(next)
    }
}
