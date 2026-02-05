import Foundation

struct AppConfiguration: Codable, Equatable {
	var enabledOptions: Set<DisplayOption> = Self.defaultEnabledOptions
	
	static let `default` = AppConfiguration()
	
	private static var defaultEnabledOptions: Set<DisplayOption> {
		Set(DisplayOption.allCases).subtracting([.startAtLogin, .preventSleeping])
	}
	
	init() {}
	
	func normalized() -> AppConfiguration {
		var copy = self
		copy.enabledOptions = copy.enabledOptions.intersection(Set(DisplayOption.allCases))
		return copy
	}
	
	enum CodingKeys: String, CodingKey {
		case enabledOptions
	}

	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		self.enabledOptions = try container.decodeIfPresent(
			Set<DisplayOption>.self,
			forKey: .enabledOptions
		) ?? Self.defaultEnabledOptions
	}
}
