import AppKit
import Combine
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    let preferences = Preferences()
    let viewModel = NotchViewModel()

    private var windowController: NotchWindowController?
    private var preferencesWindow: PreferencesWindowController?
    private var statusItem: NSStatusItem?
    private var screenObserver: NSObjectProtocol?
    private var cancellables = Set<AnyCancellable>()

    // Services
    private var usageTracker: UsageTracker!
    private var sessionMonitor: SessionMonitor!
    private var limitNotifier: LimitNotifier!

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        usageTracker = UsageTracker()
        sessionMonitor = SessionMonitor()
        limitNotifier = LimitNotifier(preferences: preferences)

        viewModel.wire(
            usage: usageTracker,
            sessions: sessionMonitor,
            preferences: preferences
        )

        usageTracker.$snapshot
            .sink { [weak self] snapshot in
                self?.limitNotifier.check(snapshot: snapshot)
            }
            .store(in: &cancellables)

        usageTracker.start()
        sessionMonitor.start()

        installWindow()
        installStatusItem()
        observeScreenChanges()
    }

    private func installWindow() {
        guard let screen = ScreenInfo.notchedScreen() else { return }
        windowController = NotchWindowController(screen: screen, viewModel: viewModel)
        windowController?.showWindow(nil)
    }

    private func installStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        let image = NSImage(systemSymbolName: "chart.bar.fill", accessibilityDescription: "DevNotch")
        image?.isTemplate = true
        item.button?.image = image
        item.button?.imagePosition = .imageOnly
        item.button?.toolTip = "DevNotch"

        let menu = NSMenu()
        let toggleItem = NSMenuItem(title: "Toggle notch", action: #selector(toggleNotch), keyEquivalent: "t")
        toggleItem.target = self
        menu.addItem(toggleItem)
        menu.addItem(.separator())
        let connectItem = NSMenuItem(title: "Connect to claude.ai…", action: #selector(connectToClaude), keyEquivalent: "l")
        connectItem.target = self
        menu.addItem(connectItem)
        let refreshItem = NSMenuItem(title: "Refresh live now", action: #selector(refreshLiveNow), keyEquivalent: "r")
        refreshItem.target = self
        menu.addItem(refreshItem)
        #if DEBUG
        // Developer submenu: hidden unless Option is held (see `menuNeedsUpdate`).
        let debugMenu = NSMenu()
        let probeItem = NSMenuItem(title: "Probe claude.ai endpoints", action: #selector(probeEndpoints), keyEquivalent: "")
        probeItem.target = self
        debugMenu.addItem(probeItem)
        let debugHeader = NSMenuItem(title: "Developer", action: nil, keyEquivalent: "")
        debugHeader.submenu = debugMenu
        debugHeader.isHidden = true
        menu.addItem(debugHeader)
        #endif

        menu.delegate = self
        let prefsItem = NSMenuItem(title: "Preferences…", action: #selector(openPreferences), keyEquivalent: ",")
        prefsItem.target = self
        menu.addItem(prefsItem)
        menu.addItem(.separator())
        // No explicit target -> routed through the responder chain to NSApp
        menu.addItem(NSMenuItem(title: "Quit DevNotch", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        item.menu = menu
        statusItem = item
    }

    private func observeScreenChanges() {
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.windowController?.close()
                self?.windowController = nil
                self?.installWindow()
            }
        }
    }

    @objc private func toggleNotch() {
        viewModel.isPinned.toggle()
    }

    // MARK: - NSMenuDelegate

    func menuNeedsUpdate(_ menu: NSMenu) {
        #if DEBUG
        let optionDown = NSEvent.modifierFlags.contains(.option)
        for item in menu.items where item.title == "Developer" {
            item.isHidden = !optionDown
        }
        #endif
    }

    @objc private func openPreferences() {
        if preferencesWindow == nil {
            preferencesWindow = PreferencesWindowController(preferences: preferences)
        }
        preferencesWindow?.show()
    }

    @objc private func connectToClaude() {
        ClaudeLoginWindowController.shared.present()
    }

    #if DEBUG
    @objc private func probeEndpoints() {
        Task { @MainActor in
            await EndpointProbe.run()
        }
    }
    #endif

    @objc private func refreshLiveNow() {
        usageTracker.refreshLive()
        // Show result (or the error we just hit) in an alert after a short delay.
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            let snap = usageTracker.snapshot
            let alert = NSAlert()
            if snap.isLive {
                alert.messageText = "Live data"
                alert.informativeText = """
                Session: \(Int((snap.live?.sessionPercent ?? 0) * 100))%
                Weekly: \(snap.live?.weeklyPercent.map { "\(Int($0 * 100))%" } ?? "n/a")
                Resets in: \(FormatHelpers.relativeDuration(snap.live?.sessionResetsIn ?? 0))
                """
                alert.alertStyle = .informational
            } else if let err = snap.liveError {
                alert.messageText = "Live fetch failed"
                alert.informativeText = err
                alert.alertStyle = .warning
            } else {
                alert.messageText = "Not connected to claude.ai"
                alert.informativeText = "Use \"Connect to claude.ai…\" first."
                alert.alertStyle = .informational
            }
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }
}
