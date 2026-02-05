import AppKit
import SwiftUI

struct BatteryPopoverView: View {
	@ObservedObject var monitor: BatteryMonitor
	@ObservedObject var configurationManager: ConfigurationManager
	
	var body: some View {
		VStack(alignment: .leading, spacing: PopoverLayout.sectionSpacing) {
			header
			
			VStack(spacing: 0) {
				let lines = BatteryInfoFormatter(
					snapshot: monitor.snapshot,
					configuration: configurationManager.configuration
				).makeLines()
				
				ForEach(Array(lines.enumerated()), id: \.offset) { _, text in
					PopoverInfoLine(text)
				}
			}
			.padding(.horizontal, PopoverLayout.horizontalPadding)
			
			Divider().padding(.horizontal, PopoverLayout.horizontalPadding)
			
			if configurationManager.configuration.enabledOptions.contains(.significantEnergyApps) {
				SignificantEnergySection(
					apps: monitor.significantEnergyApps,
					onRevealInFinder: revealInFinder(url:)
				)
				
				Divider().padding(.horizontal, PopoverLayout.horizontalPadding)
			}
			
			Text("Controls")
				.font(.system(size: 12, weight: .semibold))
				.foregroundStyle(.secondary)
				.padding(.top, 2)
				.padding(.horizontal, PopoverLayout.horizontalPadding)
			
			PopoverMenuRow("Preferences", systemImageName: "gear") {
				ForEach(DisplayOption.allCases) { option in
					Toggle(option.title, isOn: displayOptionBinding(option))
				}
			}
			.padding(.horizontal, 6)
			
			Divider().padding(.horizontal, PopoverLayout.horizontalPadding)
			
			VStack(spacing: 0) {
				PopoverActionRow("GitHub Page") {
					UpdateChecker.shared.openGitHub()
				}
				
				PopoverActionRow("Check for Updates\(appVersionSuffix)") {
					UpdateChecker.shared.check()
				}
				
				PopoverActionRow("Battery Settings") {
					openBatterySettings()
				}
				
				PopoverActionRow("Quit") {
					NSApplication.shared.terminate(nil)
				}
				.keyboardShortcut("q")
			}
			.padding(.horizontal, 6)
			.padding(.bottom, 6)
		}
		.frame(minWidth: 240, maxWidth: 300, alignment: .leading)
		.onAppear { monitor.startPolling() }
		.onDisappear { monitor.stopPolling() }
	}
	
	private var header: some View {
		Text("Battery Monitor")
			.font(.headline)
			.padding(.top, 12)
			.padding(.horizontal, PopoverLayout.horizontalPadding)
	}
	
    private var appVersionSuffix: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        guard let version, !version.isEmpty else { return "" }
        return " (\(version))"
    }
	
	private func displayOptionBinding(_ option: DisplayOption) -> Binding<Bool> {
		Binding(
			get: { configurationManager.configuration.enabledOptions.contains(option) },
			set: { configurationManager.setOption(option, isEnabled: $0) }
		)
	}
	
	private func openBatterySettings() {
		guard let url = URL(string: "x-apple.systempreferences:com.apple.Battery") else { return }
		NSWorkspace.shared.open(url)
	}
	
	private func revealInFinder(url: URL?) {
		guard let url else { return }
		NSWorkspace.shared.activateFileViewerSelecting([url])
	}
}

private struct SignificantEnergySection: View {
	let apps: [SignificantEnergyApp]
	let onRevealInFinder: (URL?) -> Void
	
	var body: some View {
		let isEmpty = apps.isEmpty
		
		if !isEmpty {
			Text("Using Significant Energy")
				.font(.system(size: 12, weight: .semibold))
				.foregroundStyle(.secondary)
				.padding(.top, 2)
				.padding(.horizontal, PopoverLayout.horizontalPadding)
		}
		
		VStack(spacing: 0) {
			if isEmpty {
				HStack(spacing: 6) {
					ProgressView().controlSize(.small)
					Text("No Apps Using Significant Energy")
						.font(.system(size: PopoverLayout.bodyFontSize, weight: .regular))
						.foregroundStyle(.secondary)
						.lineLimit(1)
				}
				.frame(maxWidth: .infinity, alignment: .leading)
				.padding(.vertical, PopoverLayout.rowVerticalPadding)
				.padding(.horizontal, PopoverLayout.horizontalPadding)
			} else {
				ForEach(apps) { app in
					PopoverActionRow(app.name, icon: app.icon) {
						onRevealInFinder(app.bundleURL)
					}
					.padding(.horizontal, 6)
				}
			}
		}
	}
}

struct BatteryInfoFormatter {
	let snapshot: BatterySnapshot
	let configuration: AppConfiguration
	
	func makeLines() -> [String] {
		var lines: [String] = []
		
		lines.append(powerSourceLine)
		
		if showsNotChargingWarning {
			lines.append("Battery is not charging")
		} else if let line = timeToFullLine {
			lines.append(line)
		}
		
		lines.append(chargingStatusLine)
		
		appendIfPresent(chargingPowerLine, to: &lines)
		appendIfPresent(currentPowerLine, to: &lines)
		appendIfPresent(cycleCountLine, to: &lines)
		appendIfPresent(maximumCapacityLine, to: &lines)
		appendIfPresent(uptimeLine, to: &lines)
		
		if snapshot.powerSource == .powerAdapter {
			appendIfPresent(adapterNameLine, to: &lines)
			appendIfPresent(adapterManufacturerLine, to: &lines)
		}
		
		return lines
	}
	
	private var enabledOptions: Set<DisplayOption> {
		configuration.enabledOptions
	}
	
	private var powerSourceLine: String {
		switch snapshot.powerSource {
		case .powerAdapter: return "Power Source: Power Adapter"
		case .battery: return "Power Source: Battery"
		}
	}
	
	private var showsNotChargingWarning: Bool {
		snapshot.powerSource == .powerAdapter && !snapshot.isCharging && !snapshot.isFull
	}
	
	private var timeToFullLine: String? {
		guard let minutes = snapshot.timeToFullChargeMinutes, minutes > 0, !snapshot.isFull else { return nil }
		let hours = minutes / 60
		let mins = minutes % 60
		
		let value: String
		if hours > 0, mins > 0 { value = "\(hours)h \(mins)m" }
		else if hours > 0 { value = "\(hours)h" }
		else { value = "\(mins)m" }
		
		return "Time to Full: \(value)"
	}
	
	private var chargingStatusLine: String {
		if snapshot.isFull { return "Charging: Fully Charged" }
		
		let label = snapshot.isCharging && snapshot.isFastCharging ? "Charging (Fast)" : "Charging"
		let value: String = {
			guard snapshot.isCharging else { return "No" }
			return snapshot.stateOfChargePercent.map { "\($0)%" } ?? "Yes"
		}()
		
		return "\(label): \(value)"
	}
	
	private var chargingPowerLine: String? {
		guard enabledOptions.contains(.chargingWatts) else { return nil }
		guard snapshot.isCharging, let watts = visibleWatts(snapshot.chargingPowerW) else { return nil }
		return "Charging Power: \(formatWatts(watts))"
	}
	
	private var currentPowerLine: String? {
		guard enabledOptions.contains(.currentWatts) else { return nil }
		guard let watts = visibleWatts(snapshot.currentPowerW) else { return nil }
		return "Current Power: \(formatWatts(watts))"
	}
	
	private var cycleCountLine: String? {
		guard enabledOptions.contains(.cycleCount) else { return nil }
		return "Cycle Count: \(snapshot.cycleCount.map(String.init) ?? "—")"
	}
	
	private var maximumCapacityLine: String? {
		guard let cap = snapshot.maximumCapacityPercent, (0...100).contains(cap), cap < 100 else { return nil }
		return "Maximum Capacity: \(cap)%"
	}
	
	private var uptimeLine: String? {
		guard enabledOptions.contains(.uptime) else { return nil }
		return "Uptime: \(formatUptime(snapshot.systemUptimeSeconds) ?? "—")"
	}

	private var adapterNameLine: String? {
		guard enabledOptions.contains(.adapterName) else { return nil }
		guard let name = snapshot.adapterName, !name.isEmpty else { return nil }
		return "Name: \(name)"
	}
	
	private var adapterManufacturerLine: String? {
		guard enabledOptions.contains(.adapterManufacturer) else { return nil }
		guard let value = snapshot.adapterManufacturer, !value.isEmpty else { return nil }
		return "Manufacturer: \(value)"
	}
	
	private func visibleWatts(_ value: Double?) -> Double? {
		guard let value, value >= IOKitBatteryReader.minimumVisibleWatts else { return nil }
		return value
	}
	
	private func formatWatts(_ value: Double) -> String {
		String(format: "%.2f W", value)
	}
	
	private func formatUptime(_ seconds: TimeInterval) -> String? {
		Self.uptimeFormatter.string(from: seconds)
	}
	
	private func appendIfPresent(_ value: String?, to lines: inout [String]) {
		guard let value else { return }
		lines.append(value)
	}
	
	private static let uptimeFormatter: DateComponentsFormatter = {
		let dcf = DateComponentsFormatter()
		dcf.allowedUnits = [.day, .hour, .minute]
		dcf.unitsStyle = .abbreviated
		dcf.zeroFormattingBehavior = .dropAll
		return dcf
	}()
}
