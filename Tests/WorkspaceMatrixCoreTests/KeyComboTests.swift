import Carbon.HIToolbox
import Foundation
import Testing
import WorkspaceMatrixCore

@Test func parsesCombos() throws {
    let combo = try #require(KeyCombo("ctrl+cmd+up"))
    #expect(combo.key == .up)
    #expect(combo.modifiers == [.control, .command])
    #expect(KeyCombo(" Shift + Option + Q ")?.description == "alt+shift+q")
    #expect(KeyCombo("control+command+7")?.description == "ctrl+cmd+7")
}

@Test func rejectsWhatCantBeBound() {
    #expect(KeyCombo("hyper+q") == nil)  // unknown modifier
    #expect(KeyCombo("cmd+space") == nil)  // key not in the table
    #expect(KeyCombo("cmd+") == nil)
    #expect(KeyCombo("q") == nil)  // would stop q from typing anywhere
    #expect(KeyCombo("shift+q") == nil)
}

@Test func spellsCombosOneWay() throws {
    for text in ["cmd+ctrl+left", "ctrl+cmd+left", "CMD + CTRL + LEFT"] {
        #expect(KeyCombo(text)?.description == "ctrl+cmd+left")
    }
    let combo = try #require(KeyCombo("ctrl+alt+shift+cmd+k"))
    #expect(KeyCombo(combo.description) == combo)
}

@Test func readsKeyPresses() {
    #expect(KeyCombo(virtualKeyCode: UInt16(kVK_UpArrow), modifiers: [.control, .command])?.description == "ctrl+cmd+up")
    #expect(KeyCombo(virtualKeyCode: UInt16(kVK_ANSI_K), modifiers: [.shift]) == nil)
    #expect(KeyCombo(virtualKeyCode: UInt16(kVK_Space), modifiers: [.command]) == nil)
}

/// The key table is typed in by hand; Carbon's constants are the reference.
@Test func virtualKeyCodesMatchCarbon() {
    let carbon: [KeyCombo.Key: Int] = [
        .a: kVK_ANSI_A, .b: kVK_ANSI_B, .c: kVK_ANSI_C, .d: kVK_ANSI_D, .e: kVK_ANSI_E, .f: kVK_ANSI_F,
        .g: kVK_ANSI_G, .h: kVK_ANSI_H, .i: kVK_ANSI_I, .j: kVK_ANSI_J, .k: kVK_ANSI_K, .l: kVK_ANSI_L,
        .m: kVK_ANSI_M, .n: kVK_ANSI_N, .o: kVK_ANSI_O, .p: kVK_ANSI_P, .q: kVK_ANSI_Q, .r: kVK_ANSI_R,
        .s: kVK_ANSI_S, .t: kVK_ANSI_T, .u: kVK_ANSI_U, .v: kVK_ANSI_V, .w: kVK_ANSI_W, .x: kVK_ANSI_X,
        .y: kVK_ANSI_Y, .z: kVK_ANSI_Z,
        .zero: kVK_ANSI_0, .one: kVK_ANSI_1, .two: kVK_ANSI_2, .three: kVK_ANSI_3, .four: kVK_ANSI_4,
        .five: kVK_ANSI_5, .six: kVK_ANSI_6, .seven: kVK_ANSI_7, .eight: kVK_ANSI_8, .nine: kVK_ANSI_9,
        .up: kVK_UpArrow, .down: kVK_DownArrow, .left: kVK_LeftArrow, .right: kVK_RightArrow,
    ]
    #expect(Set(carbon.keys) == Set(KeyCombo.Key.allCases))
    for (key, code) in carbon {
        #expect(key.virtualKeyCode == UInt16(code), "\(key)")
    }
}

@Test func combosAreStoredAsText() throws {
    let combo = try #require(KeyCombo("alt+k"))
    let json = try JSONEncoder().encode(combo)
    #expect(String(decoding: json, as: UTF8.self) == #""alt+k""#)
    #expect(try JSONDecoder().decode(KeyCombo.self, from: json) == combo)
    #expect(throws: DecodingError.self) { try JSONDecoder().decode(KeyCombo.self, from: Data(#""q""#.utf8)) }
}
