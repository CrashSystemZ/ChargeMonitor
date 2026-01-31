import Foundation

struct BatterySnapshot: Equatable {
    var powerSource: PowerSourceType = .battery
    var isCharging: Bool = false
    var isFull: Bool = false

    var adapterName: String? = nil
    var adapterManufacturer: String? = nil

    var cycleCount: Int? = nil
    var maximumCapacityPercent: Int? = nil
    var stateOfChargePercent: Int? = nil
    var timeToFullChargeMinutes: Int? = nil

    var batteryChargePowerW: Double? = nil
    var isFastCharging: Bool = false
}

enum PowerSourceType: Equatable {
    case battery
    case powerAdapter
    case ups
}
