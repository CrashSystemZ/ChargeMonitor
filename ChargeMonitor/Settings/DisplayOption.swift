import Foundation

enum DisplayOption: String, CaseIterable, Identifiable, Codable {
	case adapterManufacturer
	case adapterName
	case chargingWatts
	case currentWatts
	case significantEnergyApps
	case cycleCount
	case uptime
	case startAtLogin
	case preventSleeping
	
	var id: String { rawValue }
	
	var title: String {
		switch self {
		case .adapterManufacturer: return "Manufacturer"
		case .adapterName: return "Adapter Name"
		case .chargingWatts: return "Charging Power"
		case .currentWatts: return "Current Power"
		case .significantEnergyApps: return "Significant Energy Apps"
		case .cycleCount: return "Cycle Count"
		case .uptime: return "Uptime"
		case .startAtLogin: return "Start at Login"
		case .preventSleeping: return "Prevent Sleeping"
		}
	}
}
