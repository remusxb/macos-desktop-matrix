import Foundation
import WorkspaceMatrixCore

/// The settings file. Editing it by hand works too; the app reads it at launch.
public struct ConfigFile: Sendable {
    /// ~/.config/workspace-matrix/config.json.
    public static let standard = ConfigFile(
        url: FileManager.default.homeDirectoryForCurrentUser.appending(path: ".config/workspace-matrix/config.json"))

    /// Where the file is.
    public let url: URL

    /// The settings at `url`.
    public init(url: URL) {
        self.url = url
    }

    /// The saved settings; the defaults when there's no file, or when it can't be read (logged).
    public func load() -> Config {
        guard FileManager.default.fileExists(atPath: url.path) else { return Config() }
        do {
            return try JSONDecoder().decode(Config.self, from: Data(contentsOf: url))
        } catch {
            Log.app.error("can't read \(url.path, privacy: .public), using defaults: \(error, privacy: .public)")
            return Config()
        }
    }

    /// Saves `config`, keeping the file readable: pretty-printed, keys sorted.
    public func save(_ config: Config) {
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(config).write(to: url, options: .atomic)
        } catch {
            Log.app.error("can't save \(url.path, privacy: .public): \(error, privacy: .public)")
        }
    }
}
