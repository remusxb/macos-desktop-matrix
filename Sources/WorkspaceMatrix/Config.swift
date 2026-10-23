import Foundation

struct Config {
    var rows = 3
    var cols = 3
    var wrap = false
    var keys = ["up": "ctrl+cmd+up", "down": "ctrl+cmd+down", "left": "ctrl+cmd+left", "right": "ctrl+cmd+right"]
    var tileWidth = 160.0
    var hideAfter = 0.6
    var instant = false

    static let path = FileManager.default.homeDirectoryForCurrentUser
        .appending(path: ".config/workspace-matrix/config.json").path

    static func load() -> Config {
        guard let data = FileManager.default.contents(atPath: path) else { return Config() }
        do {
            return try JSONDecoder().decode(Config.self, from: data)
        } catch {
            log("bad config \(path): \(error), using defaults")
            return Config()
        }
    }

    func save() {
        do {
            try FileManager.default.createDirectory(atPath: (Config.path as NSString).deletingLastPathComponent,
                                                    withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(self).write(to: URL(fileURLWithPath: Config.path))
        } catch {
            log("can't save config \(Config.path): \(error)")
        }
    }
}

extension Config: Codable {
    private enum CodingKeys: String, CodingKey {
        case rows, cols, wrap, keys, tileWidth, hideAfter, instant
    }

    // Every field is optional in the file; missing ones keep the defaults above.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        func get<T: Decodable>(_ key: CodingKeys, _ fallback: T) throws -> T {
            try c.decodeIfPresent(T.self, forKey: key) ?? fallback
        }
        let d = Config()
        rows = try max(1, get(.rows, d.rows))
        cols = try max(1, get(.cols, d.cols))
        wrap = try get(.wrap, d.wrap)
        keys = try d.keys.merging(get(.keys, [:])) { $1 }
        tileWidth = try get(.tileWidth, d.tileWidth)
        hideAfter = try get(.hideAfter, d.hideAfter)
        instant = try get(.instant, d.instant)
    }
}
