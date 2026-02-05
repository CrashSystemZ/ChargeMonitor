import Foundation
import IOKit.pwr_mgt

final class SleepController {
	private var systemSleepAssertionID: IOPMAssertionID?
	private var displaySleepAssertionID: IOPMAssertionID?
	
	func setPreventSleepEnabled(_ enabled: Bool) {
		if enabled {
			enableSleepPrevention()
			return
		}
		
		disableSleepPrevention()
	}
	
	private func enableSleepPrevention() {
		disableSleepPrevention()
		systemSleepAssertionID = createAssertion(
			type: kIOPMAssertionTypePreventUserIdleSystemSleep as CFString,
			name: "ChargeMonitor preventing idle system sleep" as CFString
		)
		displaySleepAssertionID = createAssertion(
			type: kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
			name: "ChargeMonitor preventing idle display sleep" as CFString
		)
	}
	
	private func disableSleepPrevention() {
		releaseAssertion(&systemSleepAssertionID)
		releaseAssertion(&displaySleepAssertionID)
	}
	
	private func createAssertion(type: CFString, name: CFString) -> IOPMAssertionID? {
		var id: IOPMAssertionID = 0
		let result = IOPMAssertionCreateWithName(
			type,
			IOPMAssertionLevel(kIOPMAssertionLevelOn),
			name,
			&id
		)
		guard result == kIOReturnSuccess else { return nil }
		return id
	}
	
	private func releaseAssertion(_ assertionID: inout IOPMAssertionID?) {
		guard let id = assertionID else { return }
		IOPMAssertionRelease(id)
		assertionID = nil
	}
	
	deinit {
		disableSleepPrevention()
	}
}
