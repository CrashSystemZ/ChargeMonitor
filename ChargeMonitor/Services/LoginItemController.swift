import Foundation
import ServiceManagement

final class LoginItemController {
	func setEnabled(_ enabled: Bool) throws {
		if enabled {
			try SMAppService.mainApp.register()
		} else {
			try SMAppService.mainApp.unregister()
		}
	}
}
