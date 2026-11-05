import CoreGraphics
import Foundation

/// One of the two games whose touch pad is its own design (the fork's DmGamepad skin and Hades pads), with the key table the
/// engine draws from. The shell's settings carry an editor for this layout (GamePadLayoutEditorView), the counterpart of the
/// generic touch layout editor: the same screen pattern, but the controls are the game's own keys at the game's own places,
/// and what it stores is the very dictionary the in-game layout editor (the eye key's long press in Silksong, the − key's in
/// Hades II) keeps in the app's defaults under `DmPadCustom` / `DmPadCustomHades`, so the two editors always agree. Per key
/// only the centre's offset from the table (as fractions of the screen) and a size multiplier are kept; "stick" is the left
/// stick's entry, and Silksong's invisible Up key rides on it, as in the engine.
/// The centres are the engine's own arithmetic (DmGamepad.m's skinCenterRaw / hadesCenterRaw / stickHome), restated so the
/// preview sits exactly where the game will draw the key: Silksong's action rows stack up from the bottom row in width
/// fractions (the top row stays a height fraction), Hades II's fan keys hang off the Y key's centre in width fractions.
public enum GamePadLayoutGame: String, CaseIterable, Sendable {
    case silksong = "010013C00E930000"
    case hades2 = "0100A00019DE0000"

    public static func forGame(_ id: String) -> GamePadLayoutGame? { GamePadLayoutGame(rawValue: id) }

    /// The defaults key the engine's editor for this game reads and writes.
    public var storeKey: String { self == .silksong ? "DmPadCustom" : "DmPadCustomHades" }
    /// The launcher setting whose choice skins this game's pad; the editor's preview follows it.
    public var skinRowID: String { self == .silksong ? "DM_SILK_SKIN" : "DM_HADES_SKIN" }
    /// The size steps and limits of the in-game editor.
    public static let sizeStep: CGFloat = 0.05
    public static let sizeRange: ClosedRange<CGFloat> = 0.6...1.6

    public struct Key: Equatable, Sendable, Identifiable {
        /// The art file's name, which is also the entry's name in the stored dictionary ("stick" for the stick).
        public var id: String { name }
        public let name: String
        /// The name shown for the key in the editor's panel (a source string for ShellStrings).
        public let label: String
        /// The glyph a drawn (glass) key carries; nil for the keys drawn as a symbol (eye, bag, pause) or an arrow.
        public let glyph: String?
        /// Table position: x as a fraction of the width; y as a height fraction, except a Hades fan key, whose y is an
        /// offset from the Y key's centre in width fractions, exactly as the engine's table keeps it.
        public let x: CGFloat
        public let y: CGFloat
        /// The key's radius as a fraction of the width, before the player's size multiplier.
        public let r: CGFloat
        public enum Shape: Sendable { case action, top, fan, plain }
        public let shape: Shape
        /// The badge sets draw the disc centred in a larger canvas (a letter medallion below it), so the layer grows.
        public let badged: Bool
    }

    /// The stick's table centre and disc radius (a fraction of the width), the engine's stickHome / stickR.
    public var stickCentre: CGPoint { self == .silksong ? CGPoint(x: 0.162, y: 0.742) : CGPoint(x: 0.168, y: 0.664) }
    public var stickRadius: CGFloat { self == .silksong ? 0.074 : 0.061 }

    /// The game's keys in the engine's table order (the stick is separate, always last in the editor).
    public var keys: [Key] {
        switch self {
        case .silksong: return [
            Key(name: "attack", label: "Attack", glyph: "Y", x: 0.7859, y: 0.770, r: 0.0374, shape: .action, badged: true),
            Key(name: "jump", label: "Jump", glyph: "B", x: 0.898, y: 0.770, r: 0.0480, shape: .action, badged: true),
            Key(name: "dash", label: "Dash", glyph: "ZR", x: 0.8188, y: 0.5983, r: 0.0374, shape: .action, badged: true),
            Key(name: "tool", label: "Tool", glyph: "R", x: 0.7103, y: 0.770, r: 0.0254, shape: .action, badged: true),
            Key(name: "needolin", label: "Needolin", glyph: "X", x: 0.6468, y: 0.770, r: 0.0254, shape: .action, badged: true),
            Key(name: "bind", label: "Bind", glyph: "A", x: 0.898, y: 0.5271, r: 0.0374, shape: .action, badged: true),
            Key(name: "clawline", label: "Clawline", glyph: "ZL", x: 0.898, y: 0.3631, r: 0.0254, shape: .action, badged: true),
            Key(name: "eye", label: "Eye", glyph: nil, x: 0.670, y: 0.082, r: 0.0224, shape: .top, badged: true),
            Key(name: "map", label: "Map", glyph: "L", x: 0.746, y: 0.082, r: 0.0224, shape: .top, badged: true),
            Key(name: "bag", label: "Bag", glyph: nil, x: 0.822, y: 0.082, r: 0.0224, shape: .top, badged: true),
            Key(name: "pause", label: "Pause", glyph: nil, x: 0.898, y: 0.082, r: 0.0224, shape: .top, badged: true),
        ]
        case .hades2: return [
            Key(name: "minus", label: "Minus", glyph: "−", x: 0.691, y: 0.086, r: 0.020, shape: .top, badged: true),
            Key(name: "plus", label: "Plus", glyph: "+", x: 0.754, y: 0.086, r: 0.020, shape: .top, badged: true),
            Key(name: "l", label: "L", glyph: "L", x: 0.817, y: 0.086, r: 0.020, shape: .top, badged: true),
            Key(name: "zl", label: "ZL", glyph: "ZL", x: 0.880, y: 0.086, r: 0.020, shape: .top, badged: true),
            Key(name: "zr", label: "ZR", glyph: "ZR", x: 0.943, y: 0.086, r: 0.020, shape: .top, badged: true),
            Key(name: "r", label: "R", glyph: "R", x: 0.903, y: -0.1451, r: 0.031, shape: .fan, badged: true),
            Key(name: "a", label: "A", glyph: "A", x: 0.8305, y: -0.1257, r: 0.031, shape: .fan, badged: true),
            Key(name: "x", label: "X", glyph: "X", x: 0.7773, y: -0.0726, r: 0.031, shape: .fan, badged: true),
            Key(name: "b", label: "B", glyph: "B", x: 0.758, y: 0.0, r: 0.031, shape: .fan, badged: true),
            Key(name: "y", label: "Y", glyph: "Y", x: 0.903, y: 0.715, r: 0.038, shape: .plain, badged: true),
            Key(name: "left", label: "D-pad left", glyph: nil, x: 0.645, y: 0.896, r: 0.019, shape: .plain, badged: false),
            Key(name: "up", label: "D-pad up", glyph: nil, x: 0.701, y: 0.896, r: 0.019, shape: .plain, badged: false),
            Key(name: "down", label: "D-pad down", glyph: nil, x: 0.753, y: 0.896, r: 0.019, shape: .plain, badged: false),
            Key(name: "right", label: "D-pad right", glyph: nil, x: 0.807, y: 0.896, r: 0.019, shape: .plain, badged: false),
        ]
        }
    }

    /// A key's built-in centre in a canvas of the given size, before the player's offset: the engine's raw centre.
    public func rawCentre(_ key: Key, in size: CGSize) -> CGPoint {
        switch key.shape {
        case .action:
            // Silksong's rows stack up from the bottom row (y 0.822) in width fractions (SKIN_REF_HW 0.4615).
            let y = 0.822 + (key.y - 0.822) * 0.4615 * size.width / size.height
            return CGPoint(x: key.x * size.width, y: y * size.height)
        case .fan:
            // A Hades fan key: its y is an offset from the Y key's centre (0.715), in width fractions.
            return CGPoint(x: key.x * size.width, y: (0.715 + key.y * size.width / size.height) * size.height)
        case .top, .plain:
            return CGPoint(x: key.x * size.width, y: key.y * size.height)
        }
    }

    /// The stick's built-in centre in a canvas of the given size.
    public func rawStickCentre(in size: CGSize) -> CGPoint {
        CGPoint(x: stickCentre.x * size.width, y: stickCentre.y * size.height)
    }

    /// The folder of this game's pad art for a skin choice, nil for the drawn (glass) keys. The choice is the launcher
    /// setting's value: Silksong 0 glass, 1 thorn, 2 thorn badges, 3 black iron; Hades II 0 glass, 1 moon, 2 moon badges.
    public func artFolder(skin: Int) -> String? {
        switch (self, skin) {
        case (.silksong, 1): return "padskin"
        case (.silksong, 2): return "padskin-badge"
        case (.silksong, 3): return "padskin-metal"
        case (.hades2, 1): return "hadesskin"
        case (.hades2, 2): return "hadesskin-badge"
        default: return nil
        }
    }

    /// How much larger than the key's disc the art layer is drawn: the badge sets bake the disc into a bigger canvas
    /// (Silksong 1020 over 880, Hades II 594 over 448, badged keys only), and the Hades art's disc is 0.875 of its canvas.
    public func artScale(_ key: Key, skin: Int) -> CGFloat {
        if skin == 2 && key.badged { return self == .silksong ? 1020.0 / 880.0 : 594.0 / 448.0 }
        return self == .hades2 ? 1.0 / 0.875 : 1.0
    }
}

/// The player's arrangement of one game's pad, in the engine editor's own form: per key (and the stick, under "stick")
/// the centre's offset from the table as fractions of the screen, and a size multiplier. Read from and written to the
/// app's defaults, where DmGamepad reads it at the pad's creation — the settings editor and the in-game editor are two
/// doors to the same room, and an edit here is what the next game start draws.
public struct GamePadCustom: Equatable, Sendable {
    public struct Entry: Equatable, Sendable {
        public var dx: CGFloat = 0
        public var dy: CGFloat = 0
        public var s: CGFloat = 1
        public var isDefault: Bool { dx == 0 && dy == 0 && s == 1 }
    }

    public private(set) var entries: [String: Entry] = [:]
    public init() {}

    public func entry(_ name: String) -> Entry { entries[name] ?? Entry() }
    public var isEmpty: Bool { entries.isEmpty }

    public mutating func set(_ name: String, _ entry: Entry) {
        entries[name] = entry.isDefault ? nil : entry
    }
    public mutating func reset(_ name: String) { entries[name] = nil }
    public mutating func resetAll() { entries.removeAll() }

    /// The dictionary as the engine keeps it: only the moved or resized keys, each with dx, dy and s.
    public var dictionary: [String: [String: Double]] {
        entries.mapValues { ["dx": Double($0.dx), "dy": Double($0.dy), "s": Double($0.s)] }
    }

    public init(dictionary: [String: Any]) {
        for (name, value) in dictionary {
            guard let e = value as? [String: Any] else { continue }
            var entry = Entry()
            entry.dx = (e["dx"] as? Double) ?? 0
            entry.dy = (e["dy"] as? Double) ?? 0
            let s = (e["s"] as? Double) ?? 1
            entry.s = GamePadLayoutGame.sizeRange.contains(CGFloat(s)) ? CGFloat(s) : 1
            if !entry.isDefault { entries[name] = entry }
        }
    }

    public static func load(_ game: GamePadLayoutGame, defaults: UserDefaults = .standard) -> GamePadCustom {
        GamePadCustom(dictionary: defaults.dictionary(forKey: game.storeKey) ?? [:])
    }

    public func save(_ game: GamePadLayoutGame, defaults: UserDefaults = .standard) {
        if entries.isEmpty { defaults.removeObject(forKey: game.storeKey) }
        else { defaults.set(dictionary, forKey: game.storeKey) }
    }

    /// A centre clamped as the engine clamps it (clampCentre): the centre may pass the edge by a fifth of the radius.
    public static func clamp(_ centre: CGPoint, radius: CGFloat, in size: CGSize) -> CGPoint {
        let m = 0.2 * radius
        return CGPoint(x: min(max(centre.x, -m), size.width + m), y: min(max(centre.y, -m), size.height + m))
    }

    /// A key's drawn centre in a canvas: the table centre plus the player's offset, clamped as the game clamps it.
    public func centre(of key: GamePadLayoutGame.Key, game: GamePadLayoutGame, in size: CGSize) -> CGPoint {
        let e = entry(key.name)
        let raw = game.rawCentre(key, in: size)
        let c = CGPoint(x: raw.x + e.dx * size.width, y: raw.y + e.dy * size.height)
        return Self.clamp(c, radius: key.r * e.s * size.width, in: size)
    }

    /// The stick's drawn centre in a canvas, as above.
    public func stickCentre(game: GamePadLayoutGame, in size: CGSize) -> CGPoint {
        let e = entry("stick")
        let raw = game.rawStickCentre(in: size)
        let c = CGPoint(x: raw.x + e.dx * size.width, y: raw.y + e.dy * size.height)
        return Self.clamp(c, radius: game.stickRadius * e.s * size.width, in: size)
    }
}
