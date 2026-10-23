@preconcurrency import ApplicationServices
import CoreGraphics
import WorkspaceMatrixCore

/// The two permissions the app asks for (README, Permissions): macOS shows its own prompt for each.
public enum Permissions {
    /// Accessibility, to switch desktops: asks for it if missing.
    public static func requestAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        if !AXIsProcessTrustedWithOptions(options) {
            Log.app.notice(
                "no Accessibility permission yet: desktops won't switch until it's granted and the app restarts")
        }
    }

    /// Screen Recording, for the previews: asks for it if missing.
    public static func requestScreenRecording() {
        guard !CGPreflightScreenCaptureAccess() else { return }
        Log.app.notice("no Screen Recording permission yet: previews are off until it's granted and the app restarts")
        CGRequestScreenCaptureAccess()
    }
}
