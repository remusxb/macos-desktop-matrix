import DesktopMatrixCore
import Foundation
import Testing

@Test func aPartialFileKeepsTheDefaults() throws {
    let config = try JSONDecoder().decode(
        Config.self, from: Data(#"{"rows": 0, "cols": 5, "keys": {"up": "alt+k"}}"#.utf8))
    #expect(config.rows == 1)
    #expect(config.cols == 5)
    #expect(config.keys[.up]?.description == "alt+k")
    #expect(config.keys[.down] == Config.defaultKeys[.down])
    #expect(config.instant == false)
}

@Test func aComboThatDoesntParseKeepsItsDefault() throws {
    let config = try JSONDecoder().decode(
        Config.self, from: Data(#"{"keys": {"left": "q", "sideways": "cmd+s"}}"#.utf8))
    #expect(config.keys == Config.defaultKeys)
}

/// The file an earlier version saved still loads the same.
@Test func readsFilesFromEarlierVersions() throws {
    let saved = """
        {
          "cols" : 4, "hideAfter" : 0.6, "instant" : true,
          "keys" : { "down" : "ctrl+cmd+down", "left" : "ctrl+cmd+left", "right" : "ctrl+cmd+right", "up" : "ctrl+cmd+up" },
          "rows" : 4, "tileWidth" : 160, "wrap" : false
        }
        """
    let config = try JSONDecoder().decode(Config.self, from: Data(saved.utf8))
    var expected = Config()
    expected.rows = 4
    expected.cols = 4
    expected.instant = true
    #expect(config == expected)
}

@Test func savedSettingsComeBackTheSame() throws {
    var config = Config()
    config.rows = 2
    config.cols = 5
    config.wrap = true
    config.tileWidth = 200
    config.hideAfter = 1.2
    config.instant = true
    config.keys[.left] = KeyCombo("alt+h")
    #expect(try JSONDecoder().decode(Config.self, from: JSONEncoder().encode(config)) == config)
}
