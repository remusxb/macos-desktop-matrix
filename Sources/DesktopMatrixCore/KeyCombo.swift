/// A global shortcut such as ctrl+cmd+up, parsed once where it enters the app (a config file, a text field,
/// a recorded key press) so nothing past that point handles raw strings.
public struct KeyCombo: Hashable, Sendable {
    /// A key that can be bound, named as in config files.
    public enum Key: String, CaseIterable, Sendable {
        case a, b, c, d, e, f, g, h, i, j, k, l, m, n, o, p, q, r, s, t, u, v, w, x, y, z
        case zero = "0", one = "1", two = "2", three = "3", four = "4"
        case five = "5", six = "6", seven = "7", eight = "8", nine = "9"
        case up, down, left, right

        /// The macOS virtual key code: the key's physical position on an ANSI keyboard.
        public var virtualKeyCode: UInt16 {
            switch self {
            case .a: 0x00
            case .s: 0x01
            case .d: 0x02
            case .f: 0x03
            case .h: 0x04
            case .g: 0x05
            case .z: 0x06
            case .x: 0x07
            case .c: 0x08
            case .v: 0x09
            case .b: 0x0B
            case .q: 0x0C
            case .w: 0x0D
            case .e: 0x0E
            case .r: 0x0F
            case .y: 0x10
            case .t: 0x11
            case .one: 0x12
            case .two: 0x13
            case .three: 0x14
            case .four: 0x15
            case .six: 0x16
            case .five: 0x17
            case .nine: 0x19
            case .seven: 0x1A
            case .eight: 0x1C
            case .zero: 0x1D
            case .o: 0x1F
            case .u: 0x20
            case .i: 0x22
            case .p: 0x23
            case .l: 0x25
            case .j: 0x26
            case .k: 0x28
            case .n: 0x2D
            case .m: 0x2E
            case .left: 0x7B
            case .right: 0x7C
            case .down: 0x7D
            case .up: 0x7E
            }
        }

        /// The key at a virtual key code, if it's one that can be bound.
        public init?(virtualKeyCode: UInt16) {
            guard let key = Self.allCases.first(where: { $0.virtualKeyCode == virtualKeyCode }) else { return nil }
            self = key
        }
    }

    /// The modifier keys held with the key.
    public struct Modifiers: OptionSet, Hashable, Sendable {
        /// The bits, private to this type.
        public let rawValue: UInt8

        /// Modifiers from their bits.
        public init(rawValue: UInt8) { self.rawValue = rawValue }

        /// ctrl, ⌃.
        public static let control = Modifiers(rawValue: 1 << 0)
        /// alt, ⌥.
        public static let option = Modifiers(rawValue: 1 << 1)
        /// shift, ⇧.
        public static let shift = Modifiers(rawValue: 1 << 2)
        /// cmd, ⌘.
        public static let command = Modifiers(rawValue: 1 << 3)

        /// At least one of these must be held: a bare or shift-only key would stop it from typing anywhere.
        public static let required: Modifiers = [.control, .option, .command]

        /// Spelled in combos in this order: ctrl+alt+shift+cmd.
        static let names: [(Modifiers, [String])] = [
            (.control, ["ctrl", "control"]), (.option, ["alt", "option"]),
            (.shift, ["shift"]), (.command, ["cmd", "command"]),
        ]
    }

    /// The key.
    public let key: Key
    /// The modifiers held with it; always includes one of `Modifiers.required`.
    public let modifiers: Modifiers

    /// Nil without ctrl, alt or cmd.
    public init?(key: Key, modifiers: Modifiers) {
        guard !modifiers.isDisjoint(with: .required) else { return nil }
        self.key = key
        self.modifiers = modifiers
    }

    /// Parses "ctrl+cmd+up": modifiers, then one key, joined by "+", in any case and with any spacing.
    public init?(_ text: String) {
        var parts = text.lowercased().split(separator: "+").map { $0.trimmingCharacters(in: .whitespaces) }
        guard let keyName = parts.popLast(), let key = Key(rawValue: keyName) else { return nil }
        var modifiers: Modifiers = []
        for part in parts {
            guard let (modifier, _) = Modifiers.names.first(where: { $0.1.contains(part) }) else { return nil }
            modifiers.insert(modifier)
        }
        self.init(key: key, modifiers: modifiers)
    }

    /// The combo of a key press, if its key can be bound and its modifiers allow it.
    public init?(virtualKeyCode: UInt16, modifiers: Modifiers) {
        guard let key = Key(virtualKeyCode: virtualKeyCode) else { return nil }
        self.init(key: key, modifiers: modifiers)
    }
}

extension KeyCombo: CustomStringConvertible {
    /// The canonical spelling, modifiers in ctrl, alt, shift, cmd order: "ctrl+cmd+up".
    public var description: String {
        let modifiers = Modifiers.names.filter { self.modifiers.contains($0.0) }.map { $0.1[0] }
        return (modifiers + [key.rawValue]).joined(separator: "+")
    }
}

extension KeyCombo: Codable {
    /// Reads the text form; a combo that doesn't parse is a decoding error.
    public init(from decoder: any Decoder) throws {
        let text = try decoder.singleValueContainer().decode(String.self)
        guard let combo = KeyCombo(text) else {
            throw DecodingError.dataCorrupted(
                .init(codingPath: decoder.codingPath, debugDescription: "bad key combo \(text)"))
        }
        self = combo
    }

    /// Writes the canonical text form.
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(description)
    }
}
