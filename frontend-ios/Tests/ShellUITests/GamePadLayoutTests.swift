import CoreGraphics
import Foundation
import Testing
@testable import ShellUI

/// A game's own pad arrangement: the store the in-game layout editor keeps, and the centres the engine's tables give.
@Suite struct GamePadLayoutTests {
    private let size = CGSize(width: 2344, height: 1080)

    // MARK: The store

    @Test func theStoreKeepsTheEnginesForm() {
        var c = GamePadCustom(dictionary: [
            "attack": ["dx": 0.05, "dy": -0.02, "s": 1.2],
            "jump": ["dx": 0.0, "dy": 0.0, "s": 1.0],      // a default entry is no entry
            "dash": ["dx": 0.01, "dy": 0.0, "s": 9.0],     // a size outside the editor's range reads as 1
            "stick": ["dx": -0.03, "dy": 0.0, "s": 0.8],
            "junk": "not a dictionary",
        ])
        #expect(c.entry("attack") == GamePadCustom.Entry(dx: 0.05, dy: -0.02, s: 1.2))
        #expect(c.entry("jump").isDefault)
        #expect(c.entry("dash").s == 1 && c.entry("dash").dx == 0.01)
        #expect(c.entry("stick").dx == -0.03)
        #expect(c.dictionary == ["attack": ["dx": 0.05, "dy": -0.02, "s": 1.2],
                                 "dash": ["dx": 0.01, "dy": 0.0, "s": 1.0],
                                 "stick": ["dx": -0.03, "dy": 0.0, "s": 0.8]])
        c.set("attack", GamePadCustom.Entry())
        #expect(c.entry("attack").isDefault && c.dictionary["attack"] == nil, "back at the default is not written")
        c.resetAll()
        #expect(c.isEmpty)
    }

    @Test func theStoreRoundTripsThroughTheDefaults() {
        let defaults = UserDefaults(suiteName: "GamePadLayoutTests")!
        defaults.removeObject(forKey: GamePadLayoutGame.silksong.storeKey)
        var c = GamePadCustom()
        c.set("bind", GamePadCustom.Entry(dx: 0.02, dy: 0.01, s: 0.9))
        c.save(.silksong, defaults: defaults)
        #expect(GamePadCustom.load(.silksong, defaults: defaults) == c)
        #expect(GamePadCustom.load(.hades2, defaults: defaults).isEmpty, "the two games' stores stay apart")
        c.resetAll()
        c.save(.silksong, defaults: defaults)
        #expect(defaults.dictionary(forKey: GamePadLayoutGame.silksong.storeKey) == nil, "an empty arrangement clears the key")
    }

    // MARK: The tables

    @Test func silksongCentresFollowTheEnginesStacking() {
        let game = GamePadLayoutGame.silksong
        let attack = game.keys.first { $0.name == "attack" }!
        // The action rows stack up from the bottom row in width fractions; at 2344x1080 attack sits at the table's row.
        let c = game.rawCentre(attack, in: size)
        #expect(abs(c.x - 0.7859 * 2344) < 0.5)
        #expect(abs(c.y - 831.5) < 0.5)
        let eye = game.keys.first { $0.name == "eye" }!
        #expect(game.rawCentre(eye, in: size) == CGPoint(x: 0.670 * 2344, y: 0.082 * 1080), "the top row is a height fraction")
        #expect(game.rawStickCentre(in: size) == CGPoint(x: 0.162 * 2344, y: 0.742 * 1080))
    }

    @Test func hadesFanKeysHangOffTheYKey() {
        let game = GamePadLayoutGame.hades2
        let r = game.keys.first { $0.name == "r" }!
        let c = game.rawCentre(r, in: size)
        #expect(abs(c.x - 0.903 * 2344) < 0.5)
        #expect(abs(c.y - 432.1) < 0.5, "the fan key's y is its offset from Y's centre, in width fractions")
        let y = game.keys.first { $0.name == "y" }!
        #expect(game.rawCentre(y, in: size) == CGPoint(x: 0.903 * 2344, y: 0.715 * 1080))
        #expect(game.rawStickCentre(in: size) == CGPoint(x: 0.168 * 2344, y: 0.664 * 1080))
    }

    @Test func offsetsAndTheClampApplyAsTheGameAppliesThem() {
        let game = GamePadLayoutGame.silksong
        let jump = game.keys.first { $0.name == "jump" }!
        var c = GamePadCustom()
        #expect(c.centre(of: jump, game: game, in: size) == game.rawCentre(jump, in: size))
        c.set("jump", GamePadCustom.Entry(dx: 0.1, dy: 0, s: 1))
        #expect(abs(c.centre(of: jump, game: game, in: size).x - (game.rawCentre(jump, in: size).x + 234.4)) < 0.5)
        // A centre pushed far off the canvas stops at a fifth of the radius past the edge, as clampCentre keeps it.
        let clamped = GamePadCustom.clamp(CGPoint(x: -500, y: 9999), radius: 100, in: size)
        #expect(clamped == CGPoint(x: -20, y: 1080 + 20))
    }

    @Test func theSkinChoosesTheArtFolder() {
        #expect(GamePadLayoutGame.silksong.artFolder(skin: 0) == nil)
        #expect(GamePadLayoutGame.silksong.artFolder(skin: 2) == "padskin-badge")
        #expect(GamePadLayoutGame.silksong.artFolder(skin: 3) == "padskin-metal")
        #expect(GamePadLayoutGame.hades2.artFolder(skin: 1) == "hadesskin")
        #expect(GamePadLayoutGame.hades2.artFolder(skin: 2) == "hadesskin-badge")
        #expect(GamePadLayoutGame.hades2.artFolder(skin: 3) == nil)
        let bag = GamePadLayoutGame.silksong.keys.first { $0.name == "bag" }!
        #expect(abs(GamePadLayoutGame.silksong.artScale(bag, skin: 2) - 1020.0 / 880.0) < 0.001)
        #expect(GamePadLayoutGame.silksong.artScale(bag, skin: 1) == 1)
    }
}
