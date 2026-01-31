import Foundation
import Combine

@MainActor
final class BatteryMonitor: ObservableObject {
    @Published private(set) var snapshot = BatterySnapshot()
    @Published private(set) var significantEnergyApps: [SignificantEnergyApp] = []
    
    private let reader: BatteryReaderProtocol
    private let energyReader: SignificantEnergyReader
    private var pollingTask: Task<Void, Never>?
    private var isPopoverOpen: Bool = false
    
    private let defaultInterval: TimeInterval = 2.0
    private let backgroundInterval: TimeInterval = 5.0
    
    init(
        reader: BatteryReaderProtocol? = nil,
        energyReader: SignificantEnergyReader? = nil
    ) {
        self.reader = reader ?? IOKitBatteryReader()
        self.energyReader = energyReader ?? SignificantEnergyReader()
        schedulePolling()
    }
    
    func startPolling() {
        isPopoverOpen = true
        schedulePolling()
    }
    
    func stopPolling() {
        isPopoverOpen = false
        schedulePolling()
    }
    
    private func schedulePolling() {
        if pollingTask == nil {
            pollingTask = Task { [weak self] in
                while !Task.isCancelled {
                    guard let self else { return }
                    
                    await self.updateSnapshot()
                    
                    let interval = self.determineInterval()
                    try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
                }
            }
        }
    }
    
    private func determineInterval() -> TimeInterval {
        if isPopoverOpen {
            return defaultInterval
        }
        return backgroundInterval
    }
    
    private func updateSnapshot() async {
        let newSnapshot = await reader.readSnapshot()
        if newSnapshot != snapshot {
            self.snapshot = newSnapshot
        }
        
        let apps = energyReader.computeSignificantApps()
        if apps.map(\.id) != significantEnergyApps.map(\.id) {
            self.significantEnergyApps = apps
        }
    }
}

