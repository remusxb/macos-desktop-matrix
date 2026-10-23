import AppKit
import DesktopMatrixCore
import SwiftUI

/// What the settings window edits. Every change goes to `onChange`, which saves and applies it.
@MainActor
public final class SettingsModel: ObservableObject {
    @Published var config: Config {
        didSet { onChange(config) }
    }
    /// The combo fields' text as typed; a combo reaches `config` once it parses.
    @Published var keyDrafts: [Direction: String]
    /// The direction whose combo is being recorded from the keyboard.
    @Published private(set) var recording: Direction?

    private var monitor: Any?
    private let onChange: (Config) -> Void
    private let pauseHotKeys: (Bool) -> Void

    /// `pauseHotKeys` stops the app's own keys while a combo is recorded.
    public init(_ config: Config, onChange: @escaping (Config) -> Void, pauseHotKeys: @escaping (Bool) -> Void) {
        self.config = config
        keyDrafts = config.keys.mapValues(\.description)
        self.onChange = onChange
        self.pauseHotKeys = pauseHotKeys
    }

    /// Takes the next bindable key press as `direction`'s combo; esc cancels.
    func record(_ direction: Direction) {
        stopRecording()
        recording = direction
        // Our own hotkeys would swallow the combo (and switch desktops) before we could see it.
        pauseHotKeys(true)
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            MainActor.assumeIsolated {
                guard let self else { return }
                if event.keyCode == Self.escapeKeyCode {
                    self.stopRecording()
                } else if let combo = KeyCombo(virtualKeyCode: event.keyCode, modifiers: .init(event.modifierFlags)) {
                    self.keyDrafts[direction] = combo.description
                    self.config.keys[direction] = combo
                    self.stopRecording()
                }
            }
            return nil  // keep waiting on keys that can't be bound
        }
    }

    /// Ends recording, if one is going on, and gives the app its keys back.
    public func stopRecording() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        guard recording != nil else { return }
        recording = nil
        pauseHotKeys(false)
    }

    private static let escapeKeyCode: UInt16 = 0x35
}

extension KeyCombo.Modifiers {
    /// The modifiers held in an AppKit key event; others (fn, caps lock) don't take part in combos.
    init(_ flags: NSEvent.ModifierFlags) {
        let pairs: [(NSEvent.ModifierFlags, KeyCombo.Modifiers)] = [
            (.control, .control), (.option, .option), (.shift, .shift), (.command, .command),
        ]
        self = pairs.filter { flags.contains($0.0) }.reduce([]) { $0.union($1.1) }
    }
}

struct SettingsView: View {
    @ObservedObject var model: SettingsModel

    var body: some View {
        Form {
            Section("Grid") {
                Stepper("Rows: \(model.config.rows)", value: $model.config.rows, in: 1...Self.maxDesktops)
                Stepper("Columns: \(model.config.cols)", value: $model.config.cols, in: 1...Self.maxDesktops)
                Toggle("Wrap around at the edges", isOn: $model.config.wrap)
                if model.config.rows * model.config.cols > Self.maxDesktops {
                    Text("macOS has at most \(Self.maxDesktops) desktops, so some tiles can't be reached.")
                        .foregroundStyle(.secondary)
                }
            }
            Section("Overlay") {
                LabeledContent("Tile width") {
                    Slider(value: $model.config.tileWidth, in: 80...320, step: 10)
                    Text("\(Int(model.config.tileWidth)) pt").monospacedDigit().frame(width: 52, alignment: .trailing)
                }
                LabeledContent("Stays for") {
                    Slider(value: $model.config.hideAfter, in: 0.3...3, step: 0.1)
                    Text(String(format: "%.1f s", model.config.hideAfter)).monospacedDigit()
                        .frame(width: 52, alignment: .trailing)
                }
            }
            Section("Switching") {
                Picker("Desktop switch", selection: $model.config.instant) {
                    Text("Normal").tag(false)
                    Text("Instant").tag(true)
                }
                .pickerStyle(.segmented)
            }
            Section {
                ForEach(Direction.allCases, id: \.self) { KeyField(direction: $0, model: model) }
            } header: {
                Text("Keys")
            } footer: {
                Text(
                    "Press Record and the combo, or type one like ctrl+cmd+up. It needs ctrl, cmd or alt; keys a–z, 0–9 and arrows."
                )
                .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        // A grouped Form scrolls, so it has no height of its own and the window would collapse to its title bar.
        .frame(width: 460, height: 690)
    }

    /// macOS numbers at most this many desktops.
    private static let maxDesktops = 16
}

/// A combo applies as soon as it parses; until then it shows red and the old one stays active.
// No @State: on the macOS 27 SDK it's a macro, and the Command Line Tools don't ship SwiftUI's macro plugin.
struct KeyField: View {
    let direction: Direction
    @ObservedObject var model: SettingsModel

    var body: some View {
        let text = Binding(
            get: { model.keyDrafts[direction] ?? "" },
            set: { typed in
                model.keyDrafts[direction] = typed
                if let combo = KeyCombo(typed), model.config.keys[direction] != combo {
                    model.config.keys[direction] = combo
                }
            })
        let recording = model.recording == direction
        HStack {
            TextField(
                direction.rawValue.capitalized, text: recording ? .constant("Press the combo… (esc cancels)") : text
            )
            .foregroundStyle(
                recording ? Color.secondary : KeyCombo(text.wrappedValue) == nil ? Color.red : Color.primary
            )
            .disabled(recording)
            Button(recording ? "Cancel" : "Record") {
                recording ? model.stopRecording() : model.record(direction)
            }
        }
    }
}
