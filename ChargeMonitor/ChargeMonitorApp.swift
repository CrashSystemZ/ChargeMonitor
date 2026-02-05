import AppKit
import SwiftUI

@main
@MainActor
struct ChargeMonitorApp: App {
	@NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
	@StateObject private var monitor: BatteryMonitor
	@StateObject private var configurationManager: ConfigurationManager
	@StateObject private var behaviorCoordinator: AppBehaviorCoordinator
	
	init() {
		let monitor = BatteryMonitor()
		let configurationManager = ConfigurationManager.shared
		
		_monitor = StateObject(wrappedValue: monitor)
		_configurationManager = StateObject(wrappedValue: configurationManager)
		_behaviorCoordinator = StateObject(
			wrappedValue: AppBehaviorCoordinator(
				configurationManager: configurationManager
			)
		)
	}
	
	var body: some Scene {
		MenuBarExtra {
			BatteryPopoverView(
				monitor: monitor,
				configurationManager: configurationManager
			)
		} label: {
			Text(menuBarTitle)
		}
		.menuBarExtraStyle(.window)
	}
	
	private var menuBarTitle: String {
		monitor.snapshot.stateOfChargePercent.map { "\($0)%" } ?? "—%"
	}
}

final class AppDelegate: NSObject, NSApplicationDelegate {
	func applicationDidFinishLaunching(_ notification: Notification) {
		NSApplication.shared.setActivationPolicy(.accessory)
	}
}
