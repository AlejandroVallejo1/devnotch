import AppKit

enum ScreenInfo {
    /// Returns the screen that has a notch (non-zero top safe-area inset), or the main screen as fallback.
    static func notchedScreen() -> NSScreen? {
        if let notched = NSScreen.screens.first(where: { ($0.safeAreaInsets.top) > 0 }) {
            return notched
        }
        return NSScreen.main
    }
}
