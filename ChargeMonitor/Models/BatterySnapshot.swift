import Foundation

struct BatterySnapshot: Equatable {
	var powerSource: PowerSourceType = .battery
	var isCharging: Bool = false
	var isFull: Bool = false
	
	var adapterName: String?
	var adapterManufacturer: String?
	
	var cycleCount: Int?
	var maximumCapacityPercent: Int?
	var stateOfChargePercent: Int?
	var timeToFullChargeMinutes: Int?
	
	var chargingPowerW: Double?
	var currentPowerW: Double?
	var isFastCharging: Bool = false
	
	var systemUptimeSeconds: TimeInterval = 0
}

enum PowerSourceType: Equatable {
	case battery
	case powerAdapter
}
