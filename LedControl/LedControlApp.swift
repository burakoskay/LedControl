//
//  LedControlApp.swift
//  LedControl
//
//  Created by Burak Oskay on 26/05/2025.
//

import SwiftUI
import Cocoa

@main
struct LedControlApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView() // Prevents any main window from being created
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusBarController: StatusBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Set app to menu bar only (no Dock icon)
        NSApplication.shared.setActivationPolicy(.accessory)
        statusBarController = StatusBarController()
    }
}
