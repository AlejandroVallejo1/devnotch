import AppKit
import Combine
import SwiftUI

final class NotchPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

@MainActor
final class NotchWindowController: NSWindowController {
    private let viewModel: NotchViewModel
    private let screen: NSScreen
    private let hoverController: NotchHoverController
    private var cancellables = Set<AnyCancellable>()

    init(screen: NSScreen, viewModel: NotchViewModel) {
        self.screen = screen
        self.viewModel = viewModel
        self.hoverController = NotchHoverController(screen: screen)

        let size = NotchLayout.expandedSize
        let origin = NotchLayout.windowOrigin(for: screen, size: size)
        let frame = NSRect(origin: origin, size: size)

        let panel = NotchPanel(
            contentRect: frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        // Start collapsed: let the cursor click through the window.
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.hidesOnDeactivate = false

        let collapsedSize = NotchLayout.collapsedSize(for: screen)
        let rootView = NotchRootView(collapsedSize: collapsedSize)
            .environmentObject(viewModel)
            .frame(width: size.width, height: size.height, alignment: .top)

        panel.contentView = NSHostingView(rootView: rootView)
        super.init(window: panel)

        hoverController.viewModel = viewModel
        hoverController.start()

        // Toggle mouse transparency based on expanded state so tabs and pin
        // receive clicks when open but the whole region is click-through when closed.
        viewModel.$isHovered.combineLatest(viewModel.$isPinned)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] hovered, pinned in
                let expanded = hovered || pinned
                self?.window?.ignoresMouseEvents = !expanded
            }
            .store(in: &cancellables)
    }

    required init?(coder: NSCoder) { fatalError() }

    deinit {
        // hoverController owns its own teardown in deinit; we don't need to
        // call stop() here (and can't, cross-actor).
    }
}

enum NotchLayout {
    /// The window size. SwiftUI animates the visible pill between collapsed and
    /// expanded bounds inside this frame.
    static let expandedSize = CGSize(width: 520, height: 280)

    /// Collapsed size is computed per-screen to hug the physical notch.
    /// Fallback used when notch metrics aren't available (e.g. external display).
    static let collapsedFallback = CGSize(width: 190, height: 34)

    static func collapsedSize(for screen: NSScreen) -> CGSize {
        let notchW = notchWidth(for: screen)
        let notchH = notchHeight(for: screen)
        guard notchW > 0, notchH > 0 else { return collapsedFallback }
        // Slightly narrower than the physical notch so we're guaranteed to sit
        // inside it (subpixel rounding + shadow bleed push us out otherwise).
        return CGSize(width: notchW - 6, height: notchH)
    }

    static func windowOrigin(for screen: NSScreen, size: CGSize) -> CGPoint {
        let screenFrame = screen.frame
        let x = screenFrame.midX - size.width / 2
        let y = screenFrame.maxY - size.height
        return CGPoint(x: x, y: y)
    }

    /// Notch bar height reported by the system (iOS 15+ MBP). Falls back to 32pt.
    static func notchHeight(for screen: NSScreen) -> CGFloat {
        if let topInset = screen.safeAreaInsets.top as CGFloat?, topInset > 0 {
            return topInset
        }
        return 32
    }

    /// Approximate notch width. macOS doesn't expose this directly, so we
    /// estimate from the auxiliaryTopLeft/Right areas. Let the hardware report
    /// the real value — MacBook Airs have narrower notches (~175pt) than MBPs
    /// (~230pt).
    static func notchWidth(for screen: NSScreen) -> CGFloat {
        let screenWidth = screen.frame.width
        let leftArea = screen.auxiliaryTopLeftArea?.width ?? (screenWidth / 2 - 110)
        let rightArea = screen.auxiliaryTopRightArea?.width ?? (screenWidth / 2 - 110)
        let notchWidth = screenWidth - leftArea - rightArea
        return max(140, min(notchWidth, 280))
    }
}
