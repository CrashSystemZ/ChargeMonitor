import SwiftUI
import AppKit

@main
struct ChargeMonitorApp: App {
    @StateObject private var monitor = BatteryMonitor()

    init() {
        NSApplication.shared.setActivationPolicy(.accessory)
    }
    
    var body: some Scene {
        MenuBarExtra {
            BatteryPopoverView(monitor: monitor)
        } label: {
            let percentText = monitor.snapshot.stateOfChargePercent.map { "\($0)%" } ?? "—%"
            Text(percentText)
        }
        .menuBarExtraStyle(.window)
    }
}
