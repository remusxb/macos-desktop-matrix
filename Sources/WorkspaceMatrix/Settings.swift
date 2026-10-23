import AppKit
import Carbon.HIToolbox
import SwiftUI

/// What the settings window edits; every change is saved to the config file and applied right away.
final class SettingsModel: ObservableObject {
    @Published var config: Config {
        didSet {
            config.save()
            onChange(config)
        }
    }
    /// Key combos as typed; each one reaches `config` once it parses.
    @Published var keyDrafts: [String: String]
    /// The direction whose combo is being recorded from the keyboard.
    @Published private(set) var recording: Direction?
    private var monitor: Any?
    private let onChange: (Config) -> Void
    private let pauseHotKeys: (Bool) -> Void

    init(_ config: Config, onChange: @escaping (Config) -> Void, pauseHotKeys: @escaping (Bool) -> Void) {
        self.config = config
        keyDrafts = config.keys
        self.onChange = onChange
        self.pauseHotKeys = pauseHotKeys
    }

    func record(_ direction: Direction) {
        stopRecording()
        recording = direction
        // Our own hotkeys would swallow the combo (and switch desktops) before we could see it.
        pauseHotKeys(true)
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            if event.keyCode == UInt16(kVK_Escape) {
                self.stopRecording()
            } else if let combo = comboString(keyCode: event.keyCode, modifiers: event.modifierFlags) {
                self.keyDrafts[direction.rawValue] = combo
                self.config.keys[direction.rawValue] = combo
                self.stopRecording()
            }
            return nil  // keep waiting on keys that can't be bound
        }
    }

    func stopRecording() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        guard recording != nil else { return }
        recording = nil
        pauseHotKeys(false)
    }
}

struct SettingsView: View {
    @ObservedObject var model: SettingsModel

    var body: some View {
        Form {
            Section("Grid") {
                Stepper("Rows: \(model.config.rows)", value: $model.config.rows, in: 1...16)
                Stepper("Columns: \(model.config.cols)", value: $model.config.cols, in: 1...16)
                Toggle("Wrap around at the edges", isOn: $model.config.wrap)
                if model.config.rows * model.config.cols > 16 {
                    Text("macOS has at most 16 desktops, so some tiles can't be reached.")
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
                    Text(String(format: "%.1f s", model.config.hideAfter)).monospacedDigit().frame(width: 52, alignment: .trailing)
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
                Text("Press Record and the combo, or type one like ctrl+cmd+up. It needs ctrl, cmd or alt; keys a–z, 0–9 and arrows.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        // A grouped Form scrolls, so it has no height of its own and the window would collapse to its title bar.
        .frame(width: 460, height: 690)
    }
}

/// A combo is applied as soon as it parses; until then it shows red and the old one stays active.
// No @State: it's a macro on the macOS 27 SDK, and Command Line Tools don't ship SwiftUI's macro plugin.
struct KeyField: View {
    let direction: Direction
    @ObservedObject var model: SettingsModel

    var body: some View {
        let key = direction.rawValue
        let text = Binding(get: { model.keyDrafts[key] ?? "" }, set: { combo in
            model.keyDrafts[key] = combo
            if parseCombo(combo) != nil, model.config.keys[key] != combo { model.config.keys[key] = combo }
        })
        let recording = model.recording == direction
        HStack {
            TextField(key.capitalized, text: recording ? .constant("Press the combo… (esc cancels)") : text)
                .foregroundStyle(recording ? Color.secondary : parseCombo(text.wrappedValue) == nil ? Color.red : Color.primary)
                .disabled(recording)
            Button(recording ? "Cancel" : "Record") {
                recording ? model.stopRecording() : model.record(direction)
            }
        }
    }
}

/// Menu bar icon with Settings… and Quit.
final class StatusMenu: NSObject, NSWindowDelegate {
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let model: SettingsModel
    private var window: NSWindow?

    init(model: SettingsModel) {
        self.model = model
        super.init()
        item.button?.image = NSImage(systemSymbolName: "square.grid.3x3.fill", accessibilityDescription: "Workspace Matrix")
        let menu = NSMenu()
        menu.addItem(withTitle: "Settings…", action: #selector(openSettings), keyEquivalent: ",").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Workspace Matrix", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        item.menu = menu
    }

    @objc private func openSettings() {
        if window == nil {
            let window = NSWindow(contentViewController: NSHostingController(rootView: SettingsView(model: model)))
            window.title = "Workspace Matrix"
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            window.delegate = self
            window.center()
            self.window = window
        }
        NSApp.activate()
        window?.makeKeyAndOrderFront(nil)
    }

    // Closing mid-recording must not leave the hotkeys paused.
    func windowWillClose(_ notification: Notification) {
        model.stopRecording()
    }
}
