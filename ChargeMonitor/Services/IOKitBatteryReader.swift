import Foundation
import IOKit
import IOKit.ps

struct AdapterInfo {
	var name: String?
	var manufacturer: String?
}

struct BatteryMetrics {
	var cycleCount: Int?
	var maximumCapacityPercent: Int?
	var stateOfChargePercent: Int?
	var chargingPowerW: Double?
	var currentPowerW: Double?
	var isExternalPowerConnected: Bool?
}

struct IOKitBatteryReader {
	private static let fastChargePowerThresholdW = 50.0
	static let minimumVisibleWatts = 0.1
	
	private struct PowerReadingContext {
		let isCharging: Bool
		let isExternalPowerConnected: Bool
		let powerSource: PowerSourceType
	}
	
	private static let acPower = kIOPSACPowerValue as String
	private static let batteryPower = kIOPSBatteryPowerValue as String
	
	private static let keyTransportType = kIOPSTransportTypeKey as String
	private static let keyPSType = kIOPSTypeKey as String
	private static let keyIsCharging = kIOPSIsChargingKey as String
	private static let keyTimeToFull = kIOPSTimeToFullChargeKey as String
	private static let keyCurrentCapacity = kIOPSCurrentCapacityKey as String
	
	func readSnapshot() async -> BatterySnapshot {
		let context = readPowerSourcesContext()
		let powerSource = mapPowerSource(context?.providingPowerSourceType) ?? .battery
		let adapter = (powerSource == .powerAdapter) ? readAdapterInfo() : nil
		let internalBattery = context?.internalBattery
		
		let isCharging = internalBattery?.bool(Self.keyIsCharging) ?? false
		let metrics = readBatteryMetrics(internalBattery: internalBattery, powerSource: powerSource, isCharging: isCharging)
		let timeToFull = readTimeToFullChargeMinutes(internalBattery: internalBattery)
		let isExternalPowerConnected = metrics.isExternalPowerConnected ?? (adapter != nil) || (powerSource == .powerAdapter)
		
		let chargingByWire = isExternalPowerConnected
		let chargingPower = metrics.chargingPowerW ?? 0
		let isFastCharging = chargingByWire && chargingPower >= Self.fastChargePowerThresholdW
		
		var snapshot = BatterySnapshot()
		snapshot.systemUptimeSeconds = Self.readUptimeSeconds()
		snapshot.powerSource = powerSource
		snapshot.isCharging = isCharging
		snapshot.isFastCharging = isFastCharging
		snapshot.isFull = isFull(metrics.stateOfChargePercent)
		
		if chargingByWire, let adapter {
			snapshot.adapterName = adapter.name
			snapshot.adapterManufacturer = adapter.manufacturer
		}
		
		snapshot.cycleCount = metrics.cycleCount
		snapshot.maximumCapacityPercent = metrics.maximumCapacityPercent
		snapshot.stateOfChargePercent = metrics.stateOfChargePercent
		snapshot.timeToFullChargeMinutes = timeToFull
		snapshot.chargingPowerW = metrics.chargingPowerW
		snapshot.currentPowerW = metrics.currentPowerW
		
		return snapshot
	}
	
	private struct PowerSourcesContext {
		let providingPowerSourceType: String?
		let internalBattery: [String: Any]?
	}
	
	private func readPowerSourcesContext() -> PowerSourcesContext? {
		guard
			let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
			let list = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef]
		else { return nil }
		
		let providing = IOPSGetProvidingPowerSourceType(info)?.takeUnretainedValue() as String?
		
		let internalBattery = list
			.compactMap { IOPSGetPowerSourceDescription(info, $0)?.takeUnretainedValue() as? [String: Any] }
			.first(where: isInternalBattery)
		
		return PowerSourcesContext(providingPowerSourceType: providing, internalBattery: internalBattery)
	}
	
	private func mapPowerSource(_ raw: String?) -> PowerSourceType? {
		switch raw {
		case Self.acPower: return .powerAdapter
		case Self.batteryPower: return .battery
		default: return nil
		}
	}
	
	private func isInternalBattery(_ desc: [String: Any]) -> Bool {
		if desc.string(Self.keyTransportType) == kIOPSInternalType { return true }
		return desc.string(Self.keyPSType) == kIOPSInternalBatteryType
	}
	
	private func readAdapterInfo() -> AdapterInfo? {
		guard let details = IOPSCopyExternalPowerAdapterDetails()?.takeRetainedValue() else { return nil }
		let dict = details as NSDictionary
		
		return AdapterInfo(
			name: dict.string("Name"),
			manufacturer: dict.string("Manufacturer")
		)
	}
	
	private func readTimeToFullChargeMinutes(internalBattery: [String: Any]?) -> Int? {
		guard
			let internalBattery,
			let minutes = internalBattery.int(Self.keyTimeToFull),
			minutes >= 0
		else { return nil }
		return minutes
	}
	
	private func readBatteryMetrics(
		internalBattery: [String: Any]?,
		powerSource: PowerSourceType,
		isCharging: Bool
	) -> BatteryMetrics {
		guard let props = readSmartBatteryProperties() else {
			return BatteryMetrics(
				stateOfChargePercent: readStateOfCharge(internalBattery: internalBattery),
				isExternalPowerConnected: (powerSource == .powerAdapter)
			)
		}
		
		let stateOfCharge = readStateOfCharge(internalBattery: internalBattery) ?? props.int("StateOfCharge")
		let maximumCapacityPercent = readMaximumCapacityPercent(props: props)
		let externalPowerConnected = readExternalPowerConnected(props: props, powerSource: powerSource)
		let power = readPower(
			props: props,
			context: PowerReadingContext(
				isCharging: isCharging,
				isExternalPowerConnected: externalPowerConnected,
				powerSource: powerSource
			)
		)
		
		return BatteryMetrics(
			cycleCount: props.int("CycleCount"),
			maximumCapacityPercent: maximumCapacityPercent,
			stateOfChargePercent: stateOfCharge,
			chargingPowerW: power?.charging,
			currentPowerW: power?.current,
			isExternalPowerConnected: externalPowerConnected
		)
	}
	
	private func readStateOfCharge(internalBattery: [String: Any]?) -> Int? {
		internalBattery?.int(Self.keyCurrentCapacity)
	}
	
	private func readMaximumCapacityPercent(props: [String: Any]) -> Int? {
		if let value = props.int("MaximumCapacityPercent"), (0...100).contains(value) { return value }
		
		guard
			let design = props.int("DesignCapacity"),
			design > 0,
			let maxCapacity = readMaxCapacity(props: props),
			maxCapacity > 0
		else { return nil }
		
		return Int((Double(maxCapacity) / Double(design) * 100.0).rounded())
	}
	
	private func readMaxCapacity(props: [String: Any]) -> Int? {
		props.int("AppleRawMaxCapacity")
		?? props.int("NominalChargeCapacity")
		?? props.int("MaxCapacity")
	}
	
	private func readPower(
		props: [String: Any],
		context: PowerReadingContext
	) -> (charging: Double?, current: Double?)? {
		guard
			let amperageMA = props.int64("InstantAmperage"),
			let voltageMV = props.int64("Voltage")
		else { return nil }
		
		let batteryPowerW = Double(amperageMA) * Double(voltageMV) / 1_000_000.0
		
		let chargingPowerW: Double? = {
			guard context.isCharging else { return nil }
			let value = batteryPowerW
			return value >= Self.minimumVisibleWatts ? round2(value) : nil
		}()
		
		let currentPowerW: Double? = {
			if let systemPowerW = readSystemPowerW(
				props: props,
				isExternalPowerConnected: context.isExternalPowerConnected,
				chargingPowerW: chargingPowerW
			) {
				return systemPowerW >= Self.minimumVisibleWatts ? round2(systemPowerW) : nil
			}
			
			guard context.powerSource == .battery else { return nil }
			
			let value = -batteryPowerW
			return value >= Self.minimumVisibleWatts ? round2(value) : nil
		}()
		
		return (chargingPowerW, currentPowerW)
	}
	
	private func readSystemPowerW(
		props: [String: Any],
		isExternalPowerConnected: Bool,
		chargingPowerW: Double?
	) -> Double? {
		if let value = readPowerValueAbs(props: props, key: "SystemPower"),
			value >= Self.minimumVisibleWatts { return value }
		if let value = readPowerValueAbs(props: props, key: "AvgSystemPower"),
			value >= Self.minimumVisibleWatts { return value }
		if let value = readPowerValueAbs(props: props, key: "AverageSystemPower"),
		   value >= Self.minimumVisibleWatts { return value }
		
		guard let telemetry = props.dictionary("PowerTelemetryData") else { return nil }
		
		if let value = readPowerValueAbs(props: telemetry, key: "SystemPower"), value >= Self.minimumVisibleWatts { return value }
		
		if isExternalPowerConnected, let systemPowerIn = readPowerValueAbs(props: telemetry, key: "SystemPowerIn"), systemPowerIn >= Self.minimumVisibleWatts {
			let charging = chargingPowerW ?? 0
			let withoutCharge = systemPowerIn - charging
			return withoutCharge >= Self.minimumVisibleWatts ? withoutCharge : systemPowerIn
		}
		
		return nil
	}
	
	private func readExternalPowerConnected(props: [String: Any], powerSource: PowerSourceType) -> Bool {
		if let connected = props.bool("ExternalConnected") { return connected }
		if let connected = props.bool("AppleRawExternalConnected") { return connected }
		return powerSource == .powerAdapter
	}
	
	private func readPowerValueAbs(props: [String: Any], key: String) -> Double? {
		guard let mW = props.int64(key) else { return nil }
		return Double(abs(mW)) / 1000.0
	}
	
	private func round2(_ value: Double) -> Double {
		(value * 100).rounded() / 100
	}
	
	private static func readUptimeSeconds() -> TimeInterval {
		var mib = [CTL_KERN, KERN_BOOTTIME]
		var bootTime = timeval()
		var size = MemoryLayout<timeval>.size
		guard sysctl(&mib, 2, &bootTime, &size, nil, 0) == 0 else {
			return ProcessInfo.processInfo.systemUptime
		}
		let bootDate = Date(timeIntervalSince1970: TimeInterval(bootTime.tv_sec) + TimeInterval(bootTime.tv_usec) / 1_000_000)
		return Date().timeIntervalSince(bootDate)
	}

	private func isFull(_ soc: Int?) -> Bool {
		guard let soc, (0...100).contains(soc) else { return false }
		return soc >= 100
	}
	
	private func readSmartBatteryProperties() -> [String: Any]? {
		let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSmartBattery"))
		guard service != 0 else { return nil }
		defer { IOObjectRelease(service) }
		
		var unmanaged: Unmanaged<CFMutableDictionary>?
		let result = IORegistryEntryCreateCFProperties(service, &unmanaged, kCFAllocatorDefault, 0)
		
		guard
			result == KERN_SUCCESS,
			let dict = unmanaged?.takeRetainedValue() as? [String: Any]
		else { return nil }
		
		return dict
	}
}
