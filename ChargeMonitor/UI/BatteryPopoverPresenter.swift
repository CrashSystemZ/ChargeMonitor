import Foundation

struct BatteryPopoverPresenter {
    let snapshot: BatterySnapshot
    
    private var powerSourceText: String {
        switch snapshot.powerSource {
        case .powerAdapter:
            return "Power Source: Power Adapter"
        case .battery:
            return "Power Source: Battery"
        case .ups:
            return "Power Source: UPS"
        }
    }
    
    private var shouldShowNotChargingWarning: Bool {
        (snapshot.powerSource == .powerAdapter || snapshot.powerSource == .ups) &&
        !snapshot.isCharging &&
        !snapshot.isFull
    }
    
    private var timeToFullText: String? {
        formatTimeToFull(snapshot.timeToFullChargeMinutes, isFull: snapshot.isFull)
    }
    
    private var chargingStatusText: String {
        if snapshot.isFull {
            return "Charging: Fully Charged"
        }
        let key = (snapshot.isCharging && snapshot.isFastCharging) ? "Charging (Fast)" : "Charging"
        var value = "No"
        if snapshot.isCharging {
            if let soc = snapshot.stateOfChargePercent {
                value = "\(soc)%"
            } else {
                value = "Yes"
            }
        }
        return "\(key): \(value)"
    }
    
    private var cycleCountText: String {
        "Cycle Count: \(snapshot.cycleCount.map(String.init) ?? "—")"
    }
    
    private var maximumCapacityText: String? {
        guard let cap = snapshot.maximumCapacityPercent, (0...100).contains(cap), cap < 100 else { return nil }
        return "Maximum Capacity: \(cap)%"
    }
    
    private var adapterNameText: String? {
        guard let name = snapshot.adapterName, !name.isEmpty else { return nil }
        return "Name: \(name)"
    }
    
    private var adapterManufacturerText: String? {
        guard let m = snapshot.adapterManufacturer, !m.isEmpty else { return nil }
        return "Manufacturer: \(m)"
    }
    
    private func formatTimeToFull(_ minutes: Int?, isFull: Bool) -> String? {
        guard let minutes, minutes > 0, !isFull else { return nil }
        let hours = minutes / 60
        let mins = minutes % 60
        
        let timeStr: String
        if hours > 0 && mins > 0 { timeStr = "\(hours)h \(mins)m" }
        else if hours > 0 { timeStr = "\(hours)h" }
        else { timeStr = "\(mins)m" }
        
        return "Time to Full: \(timeStr)"
    }
    
    func buildInfoLines() -> [String] {
        var out: [String] = []
        
        out.append(powerSourceText)
        
        if shouldShowNotChargingWarning {
            out.append("Battery is not charging")
        } else if let t = timeToFullText {
            out.append(t)
        }
        
        out.append(chargingStatusText)
        out.append(cycleCountText)
        
        if let mc = maximumCapacityText { out.append(mc) }
        
        if snapshot.powerSource == .powerAdapter {
            if let n = adapterNameText { out.append(n) }
            if let m = adapterManufacturerText { out.append(m) }
        }
        
        return out
    }
}

