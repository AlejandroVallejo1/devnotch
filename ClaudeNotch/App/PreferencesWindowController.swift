import AppKit
import SwiftUI

/// A plain window controller for the Preferences pane. We do not use SwiftUI's
/// `Settings` scene because in an `LSUIElement` / accessory-mode app the
/// `showSettingsWindow:` action is not wired through a main menu, so the
/// standard selector doesn't open anything.
@MainActor
final class PreferencesWindowController: NSWindowController {
    private let preferences: Preferences

    init(preferences: Preferences) {
        self.preferences = preferences
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 480),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "DevNotch — Preferences"
        window.isReleasedWhenClosed = false
        window.center()
        window.contentView = NSHostingView(
            rootView: PreferencesView().environmentObject(preferences)
        )
        super.init(window: window)
    }

    required init?(coder: NSCoder) { fatalError() }

    func show() {
        NSApp.activate(ignoringOtherApps: true)
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
        window?.orderFrontRegardless()
    }
}
