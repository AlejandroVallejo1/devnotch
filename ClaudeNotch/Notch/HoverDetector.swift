import AppKit

/// Watches global mouse position and signals the view model when the cursor enters
/// or leaves the "active" region around the notch.
///
/// Running this outside the SwiftUI view hierarchy lets us:
/// - Keep the NSWindow in `ignoresMouseEvents = true` state when collapsed, so
///   the cursor can click through transparent areas as if the app weren't there.
/// - Not block clicks on tabs/pin when expanded (no overlay in front of content).
@MainActor
final class NotchHoverController {
    weak var viewModel: NotchViewModel?
    private let screen: NSScreen
    private var monitor: Any?
    private var pollTimer: Timer?
    private var lastInside: Bool = false

    init(screen: NSScreen) {
        self.screen = screen
    }

    func start() {
        monitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved]) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.evaluate()
            }
        }
        // Also poll, because global monitors miss events while other apps are
        // "grabbing" the cursor (e.g. slow fullscreen app switches).
        pollTimer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.evaluate()
            }
        }
    }

    func stop() {
        if let m = monitor { NSEvent.removeMonitor(m) }
        monitor = nil
        pollTimer?.invalidate()
        pollTimer = nil
    }

    deinit {
        if let m = monitor { NSEvent.removeMonitor(m) }
        pollTimer?.invalidate()
    }

    private func evaluate() {
        guard let vm = viewModel else { return }
        let mouse = NSEvent.mouseLocation
        let rect = activeRect(expanded: vm.isExpanded)
        let inside = rect.contains(mouse)
        if inside != lastInside {
            lastInside = inside
            vm.setHovered(inside)
        }
    }

    /// The region that keeps the notch expanded while the cursor is inside it.
    /// When collapsed: small rectangle tight around the physical notch.
    /// When expanded: the full bounding box of the expanded pill.
    private func activeRect(expanded: Bool) -> CGRect {
        let screenFrame = screen.frame
        if expanded {
            let width = NotchLayout.expandedSize.width
            let height = NotchLayout.expandedSize.height
            return CGRect(
                x: screenFrame.midX - width / 2,
                y: screenFrame.maxY - height,
                width: width,
                height: height
            )
        } else {
            let notchWidth = NotchLayout.notchWidth(for: screen)
            let notchHeight = NotchLayout.notchHeight(for: screen)
            // A tight rectangle just below the notch. We keep it ~2pt wider on
            // each side to make hover trigger reliably without being triggered
            // by nearby mouse movement.
            let width = notchWidth + 8
            let height = notchHeight + 2
            return CGRect(
                x: screenFrame.midX - width / 2,
                y: screenFrame.maxY - height,
                width: width,
                height: height
            )
        }
    }
}
