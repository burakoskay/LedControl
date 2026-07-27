import AppKit
import SwiftUI

/// Compatibility background for systems that predate native SwiftUI Liquid Glass.
struct VisualEffectBlur: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        configure(view)
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        configure(nsView)
    }

    private func configure(_ view: NSVisualEffectView) {
        view.material = .underWindowBackground
        view.blendingMode = .behindWindow
        view.state = .active
    }
}
