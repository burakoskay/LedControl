import Cocoa
import Combine
import SwiftUI

final class LEDStatusPanel: NSPanel {
    private static let panelCornerRadius: CGFloat = 16

    override var canBecomeKey: Bool { true }

    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        isFloatingPanel = true
        isReleasedWhenClosed = false
        level = .statusBar
        hasShadow = true
        isOpaque = false
        backgroundColor = .clear
        animationBehavior = .utilityWindow
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        applyCornerMask()
    }

    override var contentViewController: NSViewController? {
        didSet {
            applyCornerMask()
        }
    }

    private func applyCornerMask() {
        guard let contentView else { return }
        contentView.wantsLayer = true
        contentView.layer?.cornerRadius = Self.panelCornerRadius
        contentView.layer?.cornerCurve = .continuous
        contentView.layer?.masksToBounds = true
    }
}

final class StatusBarController: NSObject {
    private static let panelWidth: CGFloat = 300
    private static let maximumPanelHeight: CGFloat = 520
    private static let minimumPanelHeight: CGFloat = 280
    private static let panelSpacing: CGFloat = 4
    private static let screenInset: CGFloat = 8

    private var statusBarItem: NSStatusItem?
    private var panel: LEDStatusPanel?
    private var eventMonitor: Any?
    private var preferredPanelHeight = maximumPanelHeight
    private let manager = LEDManager.shared
    private var cancellables = Set<AnyCancellable>()

    override init() {
        super.init()
        setupStatusBarItem()
        setupPanel()
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
            button.action = #selector(togglePanel)
            button.target = self
        }
    }

    private func setupPanel() {
        let panel = LEDStatusPanel(
            contentRect: NSRect(
                x: 0,
                y: 0,
                width: Self.panelWidth,
                height: Self.maximumPanelHeight
            )
        )
        panel.contentViewController = NSHostingController(
            rootView: LEDPopoverView(manager: manager) { [weak self] height in
                self?.updatePanelHeight(height)
            }
        )
        self.panel = panel
    }

    private func setupEventMonitor() {
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.closePanel()
        }
    }

    private func observeState() {
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

    // MARK: - Panel

    @objc private func togglePanel() {
        guard let panel else { return }
        if panel.isVisible {
            closePanel()
        } else {
            showPanel()
        }
    }

    private func showPanel() {
        guard let panel,
              let button = statusBarItem?.button,
              let buttonWindow = button.window else { return }

        let buttonRect = button.convert(button.bounds, to: nil)
        let screenRect = buttonWindow.convertToScreen(buttonRect)
        let panelSize = NSSize(width: Self.panelWidth, height: preferredPanelHeight)
        var origin = NSPoint(
            x: screenRect.midX - panelSize.width / 2,
            y: screenRect.minY - panelSize.height - Self.panelSpacing
        )

        if let screen = buttonWindow.screen ?? NSScreen.main {
            let visibleFrame = screen.visibleFrame
            origin.x = max(
                visibleFrame.minX + Self.screenInset,
                min(origin.x, visibleFrame.maxX - panelSize.width - Self.screenInset)
            )
            origin.y = max(visibleFrame.minY + Self.screenInset, origin.y)
        }

        panel.setFrame(NSRect(origin: origin, size: panelSize), display: true)
        panel.makeKeyAndOrderFront(nil)
        button.isHighlighted = true
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    private func closePanel() {
        statusBarItem?.button?.isHighlighted = false
        guard let panel, panel.isVisible else { return }
        panel.orderOut(nil)
    }

    private func updatePanelHeight(_ measuredHeight: CGFloat) {
        let height = min(
            max(measuredHeight, Self.minimumPanelHeight),
            Self.maximumPanelHeight
        )
        guard abs(height - preferredPanelHeight) > 0.5 else { return }
        preferredPanelHeight = height

        guard let panel else { return }
        let topEdge = panel.frame.maxY
        let resizedFrame = NSRect(
            x: panel.frame.minX,
            y: topEdge - height,
            width: Self.panelWidth,
            height: height
        )
        panel.setFrame(resizedFrame, display: true)
    }

    deinit {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }
}
