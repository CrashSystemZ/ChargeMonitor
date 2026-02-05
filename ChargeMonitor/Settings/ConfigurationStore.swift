import Foundation

protocol ConfigurationStoring {
	func load() -> AppConfiguration?
	func save(_ configuration: AppConfiguration)
}

final class UserDefaultsConfigurationStore: ConfigurationStoring {
	private let defaults: UserDefaults
	private let key: String
	private let decoder = PropertyListDecoder()
	private let encoder = PropertyListEncoder()
	
	init(defaults: UserDefaults = .standard, key: String = "appConfiguration") {
		self.defaults = defaults
		self.key = key
	}
	
	func load() -> AppConfiguration? {
		guard let data = defaults.data(forKey: key) else { return nil }
		return try? decoder.decode(AppConfiguration.self, from: data)
	}
	
	func save(_ configuration: AppConfiguration) {
		guard let data = try? encoder.encode(configuration) else { return }
		defaults.set(data, forKey: key)
	}
}
