import Foundation
import IOKit
import IOKit.ps

struct BatteryMetrics {
    var cycleCount: Int?
    var maximumCapacityPercent: Int?
    var stateOfChargePercent: Int?
    var chargePowerW: Double?
}

struct AdapterInfo {
    var name: String?
    var manufacturer: String?
}

struct IOKitBatteryReader: BatteryReaderProtocol {
    private let fastChargePowerThresholdW = 50.0
    
    private let acPowerValue = kIOPSACPowerValue as String
    private let batteryPowerValue = kIOPSBatteryPowerValue as String
    private let upsPowerValue = "UPS Power"
    
    func readSnapshot() async -> BatterySnapshot {
        let adapter = readAdapterInfo()
        let powerSource = readProvidingPowerSourceType() ?? .battery
        let chargeState = readChargeState()
        let metrics = readBatteryMetrics()
        let timeToFull = readTimeToFullCharge()
        
        let chargingByWire = (powerSource == .powerAdapter) && (adapter != nil)
        
        var snapshot = BatterySnapshot()
        snapshot.powerSource = powerSource
        snapshot.isCharging = chargeState.isCharging ?? false
        
        if chargingByWire, let adapter {
            snapshot.adapterName = adapter.name
            snapshot.adapterManufacturer = adapter.manufacturer
        }
        
        snapshot.cycleCount = metrics.cycleCount
        snapshot.maximumCapacityPercent = metrics.maximumCapacityPercent
        snapshot.stateOfChargePercent = metrics.stateOfChargePercent
        snapshot.timeToFullChargeMinutes = timeToFull
        snapshot.batteryChargePowerW = metrics.chargePowerW
        snapshot.isFastCharging = chargingByWire && (metrics.chargePowerW ?? 0) >= fastChargePowerThresholdW
        
        snapshot.isFull = {
            guard let soc = metrics.stateOfChargePercent, (0...100).contains(soc) else { return false }
            return soc >= 100
        }()
        
        return snapshot
    }
    
    private func readProvidingPowerSourceType() -> PowerSourceType? {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue() else { return nil }
        
        let type = IOPSGetProvidingPowerSourceType(info)?.takeUnretainedValue() as String?
        
        switch type {
        case acPowerValue:
            return .powerAdapter
        case batteryPowerValue:
            return .battery
        case upsPowerValue:
            return .ups
        default:
            return nil
        }
    }
    
    private func readAdapterInfo() -> AdapterInfo? {
        guard let cf = IOPSCopyExternalPowerAdapterDetails()?.takeRetainedValue() else { return nil }
        let dict = cf as NSDictionary
        
        return AdapterInfo(
            name: IOUtils.stringValue(dict["Name"]),
            manufacturer: IOUtils.stringValue(dict["Manufacturer"])
        )
    }
    
    private func getInternalBattery() -> [String: Any]? {
        guard
            let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
            let list = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef]
        else { return nil }
        
        for ps in list {
            guard let desc = IOPSGetPowerSourceDescription(info, ps)?.takeUnretainedValue() as? [String: Any] else {
                continue
            }
            
            if let transport = IOUtils.stringValue(desc[kIOPSTransportTypeKey]), transport == kIOPSInternalType {
                return desc
            }
            if let psType = IOUtils.stringValue(desc[kIOPSTypeKey]), psType == kIOPSInternalBatteryType {
                return desc
            }
        }
        return nil
    }
    
    private func readChargeState() -> (isCharging: Bool?, isCharged: Bool?) {
        guard let desc = getInternalBattery() else { return (nil, nil) }
        return (
            IOUtils.boolValue(desc[kIOPSIsChargingKey]),
            IOUtils.boolValue(desc[kIOPSIsChargedKey])
        )
    }
    
    private func readTimeToFullCharge() -> Int? {
        guard
            let desc = getInternalBattery(),
            let minutes = IOUtils.intValue(desc[kIOPSTimeToFullChargeKey]),
            minutes >= 0
        else { return nil }
        
        return minutes
    }
    
    private func readBatteryMetrics() -> BatteryMetrics {
        guard let props = readSmartBatteryProps() else {
            return BatteryMetrics(stateOfChargePercent: readStateOfCharge())
        }
        
        let designCap = IOUtils.intValue(props["DesignCapacity"])
        let rawMax = IOUtils.intValue(props["AppleRawMaxCapacity"])
        ?? IOUtils.intValue(props["NominalChargeCapacity"])
        ?? IOUtils.intValue(props["MaxCapacity"])
        
        let maxCapacityPercent: Int? = {
            if let v = IOUtils.intValue(props["MaximumCapacityPercent"]), (0...100).contains(v) { return v }
            guard let d = designCap, d > 0, let m = rawMax, m > 0 else { return nil }
            return Int((Double(m) / Double(d) * 100.0).rounded())
        }()
        
        let chargePowerW: Double? = {
            guard let amperage = props["InstantAmperage"] as? Int64,
                  let voltage = props["Voltage"] as? Int64
            else { return nil }
            
            let mA = max(0, amperage)
            let watts = Double(mA) * Double(voltage) / 1_000_000.0
            return (watts * 100).rounded() / 100
        }()
        
        return BatteryMetrics(
            cycleCount: IOUtils.intValue(props["CycleCount"]),
            maximumCapacityPercent: maxCapacityPercent,
            stateOfChargePercent: readStateOfCharge() ?? IOUtils.intValue(props["StateOfCharge"]),
            chargePowerW: chargePowerW
        )
    }
    
    private func readStateOfCharge() -> Int? {
        guard let desc = getInternalBattery() else { return nil }
        return IOUtils.intValue(desc[kIOPSCurrentCapacityKey])
    }
    
    private func readSmartBatteryProps() -> [String: Any]? {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSmartBattery"))
        guard service != 0 else { return nil }
        defer { IOObjectRelease(service) }
        
        var unmanaged: Unmanaged<CFMutableDictionary>?
        let kr = IORegistryEntryCreateCFProperties(service, &unmanaged, kCFAllocatorDefault, 0)
        guard kr == KERN_SUCCESS, let dict = unmanaged?.takeRetainedValue() as? [String: Any] else {
            return nil
        }
        return dict
    }
}
