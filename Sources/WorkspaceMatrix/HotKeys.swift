import AppKit
import Carbon.HIToolbox

/// Global hotkeys through Carbon: unlike event taps, they need no Accessibility permission.
final class HotKeys {
    private var actions: [UInt32: () -> Void] = [:]
    private var refs: [EventHotKeyRef] = []

    init() {
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, event, context in
            var id = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                              nil, MemoryLayout<EventHotKeyID>.size, nil, &id)
            Unmanaged<HotKeys>.fromOpaque(context!).takeUnretainedValue().actions[id.id]?()
            return noErr
        }, 1, &spec, Unmanaged.passUnretained(self).toOpaque(), nil)
    }

    func register(_ combo: String, _ action: @escaping () -> Void) {
        guard let hotKey = parseCombo(combo) else { return log("unknown key combo '\(combo)'") }
        let id = UInt32(actions.count + 1)
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(hotKey.key, hotKey.modifiers, EventHotKeyID(signature: 0x574D_5458, id: id),
                                         GetApplicationEventTarget(), 0, &ref)
        guard status == noErr, let ref else { return log("can't register '\(combo)' (status \(status)), is it taken?") }
        actions[id] = action
        refs.append(ref)
    }

    func unregisterAll() {
        refs.forEach { UnregisterEventHotKey($0) }
        refs.removeAll()
        actions.removeAll()
    }
}

/// "ctrl+cmd+up" -> (key code, Carbon modifier mask). Keys are physical (ANSI) positions.
/// Needs ctrl, cmd or alt: a bare (or shift-only) key would stop that key from typing anywhere.
func parseCombo(_ combo: String) -> (key: UInt32, modifiers: UInt32)? {
    var parts = combo.lowercased().split(separator: "+").map { $0.trimmingCharacters(in: .whitespaces) }
    guard let key = parts.popLast().flatMap({ keyCodes[$0] }) else { return nil }
    var modifiers = 0
    for part in parts {
        guard let flag = modifierFlags[part] else { return nil }
        modifiers |= flag
    }
    guard modifiers & (cmdKey | controlKey | optionKey) != 0 else { return nil }
    return (UInt32(key), UInt32(modifiers))
}

/// The combo string for a pressed key, or nil when `parseCombo` wouldn't accept it.
func comboString(keyCode: UInt16, modifiers: NSEvent.ModifierFlags) -> String? {
    guard let key = keyNames[Int(keyCode)] else { return nil }
    let names: [(NSEvent.ModifierFlags, String)] = [(.control, "ctrl"), (.option, "alt"), (.shift, "shift"), (.command, "cmd")]
    let combo = (names.filter { modifiers.contains($0.0) }.map(\.1) + [key]).joined(separator: "+")
    return parseCombo(combo) == nil ? nil : combo
}

private let keyNames = Dictionary(keyCodes.map { ($1, $0) }, uniquingKeysWith: { first, _ in first })

private let modifierFlags = [
    "cmd": cmdKey, "command": cmdKey, "ctrl": controlKey, "control": controlKey,
    "alt": optionKey, "option": optionKey, "shift": shiftKey,
]

private let keyCodes = [
    "a": kVK_ANSI_A, "b": kVK_ANSI_B, "c": kVK_ANSI_C, "d": kVK_ANSI_D, "e": kVK_ANSI_E, "f": kVK_ANSI_F,
    "g": kVK_ANSI_G, "h": kVK_ANSI_H, "i": kVK_ANSI_I, "j": kVK_ANSI_J, "k": kVK_ANSI_K, "l": kVK_ANSI_L,
    "m": kVK_ANSI_M, "n": kVK_ANSI_N, "o": kVK_ANSI_O, "p": kVK_ANSI_P, "q": kVK_ANSI_Q, "r": kVK_ANSI_R,
    "s": kVK_ANSI_S, "t": kVK_ANSI_T, "u": kVK_ANSI_U, "v": kVK_ANSI_V, "w": kVK_ANSI_W, "x": kVK_ANSI_X,
    "y": kVK_ANSI_Y, "z": kVK_ANSI_Z,
    "0": kVK_ANSI_0, "1": kVK_ANSI_1, "2": kVK_ANSI_2, "3": kVK_ANSI_3, "4": kVK_ANSI_4,
    "5": kVK_ANSI_5, "6": kVK_ANSI_6, "7": kVK_ANSI_7, "8": kVK_ANSI_8, "9": kVK_ANSI_9,
    "up": kVK_UpArrow, "down": kVK_DownArrow, "left": kVK_LeftArrow, "right": kVK_RightArrow,
]
