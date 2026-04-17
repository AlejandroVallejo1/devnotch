import AppKit
import Combine
import WebKit

/// Presents claude.ai in a WKWebView for the user to sign in. When the
/// `sessionKey` cookie appears, captures it, fetches the user's organization UUID,
/// stores in Keychain, and closes.
///
/// Three capture paths for resilience:
///   1. Cookie-store change observer (live).
///   2. `webView(_:didFinish:)` navigation end (catches cookies set during redirects).
///   3. A manual "I'm signed in" toolbar button (bulletproof fallback).
@MainActor
final class ClaudeLoginWindowController: NSWindowController, WKNavigationDelegate, WKHTTPCookieStoreObserver, NSToolbarDelegate {
    static let shared = ClaudeLoginWindowController()

    private let webView: WKWebView
    private var captured: Bool = false

    private static let doneToolbarItemID = NSToolbarItem.Identifier("ClaudeNotch.Done")
    private static let reloadToolbarItemID = NSToolbarItem.Identifier("ClaudeNotch.Reload")

    private convenience init() {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = WKWebsiteDataStore.nonPersistent()
        let webView = WKWebView(frame: .zero, configuration: config)
        self.init(webView: webView)
    }

    private init(webView: WKWebView) {
        self.webView = webView

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 540, height: 760),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Sign in to Claude"
        window.contentView = webView
        window.center()
        window.isReleasedWhenClosed = false

        super.init(window: window)

        webView.navigationDelegate = self
        webView.configuration.websiteDataStore.httpCookieStore.add(self)
        installToolbar()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func installToolbar() {
        let toolbar = NSToolbar(identifier: "ClaudeNotch.LoginToolbar")
        toolbar.displayMode = .iconAndLabel
        toolbar.delegate = self
        window?.toolbar = toolbar
    }

    func present() {
        captured = false
        if let url = URL(string: "https://claude.ai/") {
            webView.load(URLRequest(url: url))
        }
        NSApp.activate(ignoringOtherApps: true)
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
    }

    // MARK: - Capture paths

    nonisolated func cookiesDidChange(in cookieStore: WKHTTPCookieStore) {
        Task { @MainActor [weak self] in
            cookieStore.getAllCookies { cookies in
                self?.evaluate(cookies: cookies, source: "observer")
            }
        }
    }

    nonisolated func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.webView.configuration.websiteDataStore.httpCookieStore.getAllCookies { cookies in
                self.evaluate(cookies: cookies, source: "didFinish")
            }
        }
    }

    @objc private func manualDone() {
        webView.configuration.websiteDataStore.httpCookieStore.getAllCookies { [weak self] cookies in
            self?.evaluate(cookies: cookies, source: "manual", force: true)
        }
    }

    @objc private func reload() {
        webView.reload()
    }

    // MARK: - Core capture

    private func evaluate(cookies: [HTTPCookie], source: String, force: Bool = false) {
        guard !captured else { return }
        let claudeCookies = cookies.filter { $0.domain.contains("claude.ai") }
        #if DEBUG
        NSLog("[DevNotch] cookie check (%@): %d claude.ai cookies", source, claudeCookies.count)
        #endif

        guard let session = claudeCookies.first(where: { $0.name == "sessionKey" }) else {
            if force {
                showManualError()
            }
            return
        }
        captured = true

        Task { [weak self] in
            let api = ClaudeWebAPI(sessionKey: session.value, organizationUUID: nil)
            let (orgUUID, email) = (try? await api.fetchAccountInfo()) ?? (nil, nil)

            await MainActor.run {
                ClaudeAuth.shared.store(
                    sessionKey: session.value,
                    organizationUUID: orgUUID,
                    email: email
                )
                self?.window?.close()
            }
        }
    }

    private func showManualError() {
        let alert = NSAlert()
        alert.messageText = "Couldn't find your Claude session cookie"
        alert.informativeText = """
        Make sure you signed in on the page above. If you're already signed in and this keeps failing:

        • Click Reload in the toolbar.
        • Or sign out and sign back in.

        The cookie we need is named `sessionKey`.
        """
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    // MARK: - NSToolbarDelegate

    nonisolated func toolbar(_ toolbar: NSToolbar,
                             itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier,
                             willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        switch itemIdentifier {
        case Self.doneToolbarItemID:
            let item = NSToolbarItem(itemIdentifier: itemIdentifier)
            item.label = "I'm signed in"
            item.paletteLabel = "I'm signed in"
            item.isBordered = true
            item.image = NSImage(systemSymbolName: "checkmark.circle.fill", accessibilityDescription: "Done")
            Task { @MainActor [weak self] in
                item.target = self
                item.action = #selector(ClaudeLoginWindowController.manualDone)
            }
            return item
        case Self.reloadToolbarItemID:
            let item = NSToolbarItem(itemIdentifier: itemIdentifier)
            item.label = "Reload"
            item.paletteLabel = "Reload"
            item.isBordered = true
            item.image = NSImage(systemSymbolName: "arrow.clockwise", accessibilityDescription: "Reload")
            Task { @MainActor [weak self] in
                item.target = self
                item.action = #selector(ClaudeLoginWindowController.reload)
            }
            return item
        default:
            return nil
        }
    }

    nonisolated func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [Self.reloadToolbarItemID, .flexibleSpace, Self.doneToolbarItemID]
    }

    nonisolated func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        toolbarDefaultItemIdentifiers(toolbar)
    }
}
