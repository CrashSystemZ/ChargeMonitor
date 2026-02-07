import Combine
import Foundation

@MainActor
final class AppBehaviorCoordinator: ObservableObject {
	private let settingEffects: [any SettingEffect]
	private var cancellables: Set<AnyCancellable> = []
	
	convenience init(configurationManager: ConfigurationManager) {
		self.init(
			configurationManager: configurationManager,
			settingEffects: SettingEffectFactory.makeDefault()
		)
	}
	
	init(configurationManager: ConfigurationManager, settingEffects: [any SettingEffect]) {
		self.settingEffects = settingEffects
		bind(to: configurationManager)
	}
	
	private func bind(to configurationManager: ConfigurationManager) {
		applyConfiguration(configurationManager.configuration)
		
		configurationManager.$configuration
			.sink { [weak self] config in
				self?.applyConfiguration(config)
			}
			.store(in: &cancellables)
	}
	
	private func applyConfiguration(_ configuration: AppConfiguration) {
		for effect in settingEffects {
			effect.apply(isEnabled: configuration.enabledOptions.contains(effect.option))
		}
	}
}
