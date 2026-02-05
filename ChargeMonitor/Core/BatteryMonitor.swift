import Combine
import Foundation

@MainActor
final class BatteryMonitor: ObservableObject {
	@Published private(set) var snapshot = BatterySnapshot()
	@Published private(set) var significantEnergyApps: [SignificantEnergyApp] = []
	
	private let batteryReader: IOKitBatteryReader
	private let energyReader: SignificantEnergyReader
	
	private var pollingTask: Task<Void, Never>?
	private var isPopoverOpen = false
	
	private let activeInterval: TimeInterval = 2
	private let backgroundInterval: TimeInterval = 5
	
	init(
		batteryReader: IOKitBatteryReader? = nil,
		energyReader: SignificantEnergyReader? = nil
	) {
		self.batteryReader = batteryReader ?? IOKitBatteryReader()
		self.energyReader = energyReader ?? SignificantEnergyReader()
		startPollingLoopIfNeeded()
	}
	
	func startPolling() {
		isPopoverOpen = true
		startPollingLoopIfNeeded()
	}
	
	func stopPolling() {
		isPopoverOpen = false
		startPollingLoopIfNeeded()
	}
	
	private func startPollingLoopIfNeeded() {
		guard pollingTask == nil else { return }
		
		pollingTask = Task { [weak self] in
			while let self, !Task.isCancelled {
				await self.refresh()
				let interval = self.isPopoverOpen ? self.activeInterval : self.backgroundInterval
				try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
			}
		}
	}
	
	private func refresh() async {
		let nextSnapshot = await batteryReader.readSnapshot()
		if nextSnapshot != snapshot {
			snapshot = nextSnapshot
		}
		
		let nextApps = energyReader.computeSignificantApps()
		if nextApps.map(\.id) != significantEnergyApps.map(\.id) {
			significantEnergyApps = nextApps
		}
	}
	
	deinit {
		pollingTask?.cancel()
	}
}
