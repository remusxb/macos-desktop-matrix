import Foundation
import os

/// The app's one logger, in the unified log: `make logs`, or Console.app filtered by the subsystem.
/// Errors are logged once, where they're handled; values are public only when they hold nothing personal.
public enum Log {
    /// The subsystem every message is filed under.
    public static let subsystem = Bundle.main.bundleIdentifier ?? "io.github.remusxb.desktop-matrix"
    /// Everything the app logs.
    public static let app = Logger(subsystem: subsystem, category: "app")
}
