import Foundation

@MainActor
protocol SettingEffect {
	var option: DisplayOption { get }
	func apply(isEnabled: Bool)
}

@MainActor
final class StartAtLoginSettingEffect: SettingEffect {
	let option: DisplayOption = .startAtLogin
	
	private let loginItemController: LoginItemController
	private var appliedValue: Bool?

	init(loginItemController: LoginItemController) {
		self.loginItemController = loginItemController
	}

	@MainActor
	convenience init() {
		self.init(loginItemController: StartAtLoginSettingEffect.makeDefaultLoginItemController())
	}
	
	private static func makeDefaultLoginItemController() -> LoginItemController {
		LoginItemController()
	}
	
	func apply(isEnabled: Bool) {
		guard appliedValue != isEnabled else { return }
		appliedValue = isEnabled
		
		do {
			try loginItemController.setEnabled(isEnabled)
		} catch {
			NSLog("Failed to update Start at Login: \(error)")
		}
	}
}

@MainActor
final class PreventSleepingSettingEffect: SettingEffect {
	let option: DisplayOption = .preventSleeping
	
	private let sleepController: SleepController
	private var appliedValue: Bool?
	
	init(sleepController: SleepController) {
		self.sleepController = sleepController
	}
	
	@MainActor
	convenience init() {
		self.init(sleepController: PreventSleepingSettingEffect.makeDefaultSleepController())
	}
	
	private static func makeDefaultSleepController() -> SleepController {
		SleepController()
	}
	
	func apply(isEnabled: Bool) {
		guard appliedValue != isEnabled else { return }
		appliedValue = isEnabled
		sleepController.setPreventSleepEnabled(isEnabled)
	}
}

enum SettingEffectFactory {
	@MainActor
	static func makeDefault() -> [any SettingEffect] {
		[
			StartAtLoginSettingEffect(),
			PreventSleepingSettingEffect()
		]
	}
}

