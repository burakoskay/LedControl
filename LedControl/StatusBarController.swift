import Cocoa
import SwiftUI
import Combine

class StatusBarController: NSObject {
    private var statusBarItem: NSStatusItem?
    private var popover: NSPopover?
    private var eventMonitor: Any?
    private let manager = LEDManager.shared
    private var cancellables = Set<AnyCancellable>()

    override init() {
        super.init()
        setupStatusBarItem()
        setupPopover()
        setupEventMonitor()
        observeState()
    }

    // MARK: - Setup

    private func setupStatusBarItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusBarItem = item

        if let button = item.button {
            button.image = NSImage(systemSymbolName: "lightbulb", accessibilityDescription: "LED Control")
            button.image?.isTemplate = true
            button.action = #selector(togglePopover)
            button.target = self
        }
    }

    private func setupPopover() {
        let controller = NSPopover()
        controller.contentSize = NSSize(width: 300, height: 520)
        controller.behavior = .transient
        controller.animates = true
        controller.contentViewController = NSHostingController(
            rootView: LEDPopoverView(manager: manager)
        )
        popover = controller
    }

    private func setupEventMonitor() {
        // Close popover when clicking outside
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.closePopover()
        }
    }

    private func observeState() {
        // Update icon based on connection + on/off state
        Publishers.CombineLatest(manager.$isConnected, manager.$isOn)
            .receive(on: RunLoop.main)
            .sink { [weak self] isConnected, isOn in
                self?.updateIcon(connected: isConnected, on: isOn)
            }
            .store(in: &cancellables)
    }

    private func updateIcon(connected: Bool, on isOn: Bool) {
        guard let button = statusBarItem?.button else { return }

        let symbolName: String
        if !connected {
            symbolName = "lightbulb.slash"
        } else if isOn {
            symbolName = "lightbulb.max.fill"
        } else {
            symbolName = "lightbulb"
        }

        button.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: "LED Control")
        button.image?.isTemplate = true
    }

    // MARK: - Popover

    @objc private func togglePopover() {
        guard let popover else { return }
        if popover.isShown {
            closePopover()
        } else {
            showPopover()
        }
    }

    private func showPopover() {
        guard let popover, let button = statusBarItem?.button else { return }
        if !popover.isShown {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            // Bring popover to front
            NSApplication.shared.activate(ignoringOtherApps: true)
        }
    }

    private func closePopover() {
        if let popover, popover.isShown {
            popover.performClose(nil)
        }
    }

    deinit {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }
}
