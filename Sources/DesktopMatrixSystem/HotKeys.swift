import Carbon.HIToolbox
import DesktopMatrixCore

/// Global hotkeys through Carbon. macOS tells the app only when one of its own combos is pressed, so it never
/// sees any other keystroke, and this needs neither Input Monitoring nor Accessibility.
@MainActor
public final class HotKeys {
    private var actions: [UInt32: @MainActor () -> Void] = [:]
    private var refs: [EventHotKeyRef] = []
    /// "DMTX": tags our hotkeys among the app's Carbon events.
    private static let signature: OSType = 0x444D_5458

    /// Starts listening for presses of the combos registered later.
    public init() {
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, context in
                var id = EventHotKeyID()
                GetEventParameter(
                    event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                    nil, MemoryLayout<EventHotKeyID>.size, nil, &id)
                guard let context else { return OSStatus(eventNotHandledErr) }
                let hotKeys = Unmanaged<HotKeys>.fromOpaque(context).takeUnretainedValue()
                // Carbon delivers hotkey events on the main thread.
                MainActor.assumeIsolated { hotKeys.actions[id.id]?() }
                return noErr
            }, 1, &spec, Unmanaged.passUnretained(self).toOpaque(), nil)
    }

    /// Calls `action` whenever `combo` is pressed; false when another app already holds the combo.
    @discardableResult
    public func register(_ combo: KeyCombo, _ action: @escaping @MainActor () -> Void) -> Bool {
        let id = UInt32(actions.count + 1)
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(
            UInt32(combo.key.virtualKeyCode), Self.carbonModifiers(combo.modifiers),
            EventHotKeyID(signature: Self.signature, id: id), GetApplicationEventTarget(), 0, &ref)
        guard status == noErr, let ref else {
            Log.app.error("can't register \(combo, privacy: .public) (status \(status)): is it taken?")
            return false
        }
        actions[id] = action
        refs.append(ref)
        return true
    }

    /// Releases every combo.
    public func unregisterAll() {
        refs.forEach { UnregisterEventHotKey($0) }
        refs.removeAll()
        actions.removeAll()
    }

    private static func carbonModifiers(_ modifiers: KeyCombo.Modifiers) -> UInt32 {
        let flags: [(KeyCombo.Modifiers, Int)] = [
            (.control, controlKey), (.option, optionKey), (.shift, shiftKey), (.command, cmdKey),
        ]
        return UInt32(flags.filter { modifiers.contains($0.0) }.reduce(0) { $0 | $1.1 })
    }
}
