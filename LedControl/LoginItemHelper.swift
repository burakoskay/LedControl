import Foundation
import ServiceManagement

enum LoginItemHelper {
    static func setEnabled(_ isEnabled: Bool) throws {
        if #available(macOS 13.0, *) {
            let service = SMAppService.mainApp
            if isEnabled {
                if service.status == .enabled {
                    return
                }
                try service.register()
            } else {
                if service.status == .notRegistered {
                    return
                }
                try service.unregister()
            }
        }
    }

    static func isEnabled() -> Bool {
        if #available(macOS 13.0, *) {
            return SMAppService.mainApp.status == .enabled
        }
        return false
    }
}
