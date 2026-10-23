import Foundation

/// Everything the user can set. Every field is optional in the file; a missing one keeps its default here.
public struct Config: Equatable, Sendable {
    /// Grid rows; at least 1.
    public var rows = 3
    /// Grid columns; at least 1.
    public var cols = 3
    /// Whether a step off an edge wraps around to the other side.
    public var wrap = false
    /// The combo for each direction.
    public var keys = Config.defaultKeys
    /// Tile width in points, before shrinking to fit the screen.
    public var tileWidth = 160.0
    /// Seconds the grid stays up after the last move.
    public var hideAfter = 0.6
    /// Switch with no slide animation.
    public var instant = false

    /// The defaults.
    public init() {}

    /// The grid these settings describe.
    public var grid: Grid { Grid(rows: rows, cols: cols, wrap: wrap) }

    /// ctrl+cmd+arrows.
    public static let defaultKeys: [Direction: KeyCombo] = Dictionary(
        uniqueKeysWithValues: Direction.allCases.map { direction in
            (direction, KeyCombo("ctrl+cmd+\(direction.rawValue)")!)
        })
}

extension Config: Codable {
    private enum CodingKeys: String, CodingKey {
        case rows, cols, wrap, keys, tileWidth, hideAfter, instant
    }

    /// Missing fields keep their defaults; a combo that doesn't parse keeps the default for its direction.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        func field<T: Decodable>(_ key: CodingKeys, _ fallback: T) throws -> T {
            try container.decodeIfPresent(T.self, forKey: key) ?? fallback
        }
        let defaults = Config()
        rows = try max(1, field(.rows, defaults.rows))
        cols = try max(1, field(.cols, defaults.cols))
        wrap = try field(.wrap, defaults.wrap)
        tileWidth = try field(.tileWidth, defaults.tileWidth)
        hideAfter = try field(.hideAfter, defaults.hideAfter)
        instant = try field(.instant, defaults.instant)
        for (name, text) in try field(.keys, [String: String]()) {
            guard let direction = Direction(rawValue: name) else { continue }
            guard let combo = KeyCombo(text) else {
                Log.app.error("config: ignoring key combo \(text, privacy: .public) for \(name, privacy: .public)")
                continue
            }
            keys[direction] = combo
        }
    }

    /// Writes every field, combos as text keyed by direction.
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(rows, forKey: .rows)
        try container.encode(cols, forKey: .cols)
        try container.encode(wrap, forKey: .wrap)
        try container.encode(tileWidth, forKey: .tileWidth)
        try container.encode(hideAfter, forKey: .hideAfter)
        try container.encode(instant, forKey: .instant)
        let keyTexts = Dictionary(uniqueKeysWithValues: keys.map { ($0.key.rawValue, $0.value.description) })
        try container.encode(keyTexts, forKey: .keys)
    }
}
