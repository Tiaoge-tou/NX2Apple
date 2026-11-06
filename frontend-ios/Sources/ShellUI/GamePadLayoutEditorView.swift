import CoreGraphics
import ImageIO
import SwiftUI

/// Opens one game's own pad layout editor from its settings (set by the library, as with the button mapping).
private struct ShellOpenGamePadLayoutKey: EnvironmentKey {
    nonisolated(unsafe) static let defaultValue: ((String) -> Void)? = nil
}

extension EnvironmentValues {
    public var shellOpenGamePadLayout: ((String) -> Void)? {
        get { self[ShellOpenGamePadLayoutKey.self] }
        set { self[ShellOpenGamePadLayoutKey.self] = newValue }
    }
}

/// The entry row in a game's settings, under its button skin row: one row that opens the layout editor of the game's own
/// pad. Shown only for the games whose pad is its own design (GamePadLayoutGame); every other game uses the generic
/// touch controls and their editor in the shell settings.
struct GamePadLayoutEntryRow: View {
    let gameID: String
    let arranged: Bool
    @Environment(\.shellOpenGamePadLayout) private var openEditor

    var body: some View {
        let row = SettingRow(id: "padLayout", label: ShellStrings.text("Button layout"),
                             note: ShellStrings.text("Move this game's combat keys and change their size."),
                             kind: .choice([]), value: "")
        ChoiceValueRow(row: row, valueLabel: ShellStrings.text(arranged ? "Custom" : "Built-in"),
                       hint: ShellStrings.text("Opens the button layout editor")) {
            openEditor?(gameID)
        }
        .shellTarget("set.row.padLayout", radius: 11) { openEditor?(gameID) }
        .accessibilityIdentifier("padLayout.open")
    }
}

/// One game's own pad, arranged: the generic touch layout editor's screen pattern (a full-screen preview at the device's
/// proportions, a panel beside it) carrying this game's keys at this game's places, drawn with the skin the game's own
/// button skin setting chooses — picture art where the skin has it, drawn glass keys where it does not. Drag a key to
/// move it, choose it and step its size with − and +, put one key or all of them back. Only the combat layout is here:
/// the title and bag pages keep their own places, as they do for the in-game editor. Every change is stored at once in
/// the arrangement the in-game editor keeps (GamePadCustom), so the next game start and that editor both see it.
struct GamePadLayoutEditorView: View {
    let game: GamePadLayoutGame
    let title: String
    /// The game's button skin choice (its launcher setting's value) and its label, for the note that names it.
    let skin: Int
    let skinLabel: String
    var close: () -> Void

    @State private var custom: GamePadCustom
    @State private var selected: String?
    @State private var confirmingReset = false
    /// The drag in progress: the key, where its entry started, and its live centre in the canvas.
    @State private var drag: (name: String, start: GamePadCustom.Entry, centre: CGPoint)?

    init(game: GamePadLayoutGame, title: String, skin: Int, skinLabel: String, close: @escaping () -> Void) {
        self.game = game
        self.title = title
        self.skin = skin
        self.skinLabel = skinLabel
        self.close = close
        _custom = State(initialValue: GamePadCustom.load(game))
    }

    private var folder: String? { game.artFolder(skin: skin) }

    var body: some View {
        GeometryReader { proxy in
            // The preview always keeps the screen's own landscape proportions, as the generic editor's does: the games
            // are landscape, so the keys sit in the canvas exactly where the game draws them, in either orientation.
            let screenAspect = max(proxy.size.width, proxy.size.height) / max(1, min(proxy.size.width, proxy.size.height))
            let wide = proxy.size.width > proxy.size.height * 1.1 && proxy.size.width >= 600
            if wide {
                let column = min(340, max(250, (proxy.size.width * 0.34).rounded()))
                let w = max(200, min(proxy.size.width - column - 20 - 32, (proxy.size.height - 24) * screenAspect))
                HStack(alignment: .top, spacing: 20) {
                    canvas.frame(width: w, height: w / screenAspect)
                        .frame(maxHeight: .infinity)
                    ScrollView {
                        VStack(alignment: .leading, spacing: 14) { header; panel }.padding(.vertical, 12)
                    }
                    .scrollIndicators(.automatic)
                    .frame(width: column)
                }
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        header
                        canvas.aspectRatio(screenAspect, contentMode: .fit)
                        panel
                    }
                    .padding(.horizontal, 24).padding(.vertical, 20)
                    .frame(maxWidth: 640).frame(maxWidth: .infinity)
                }
                .scrollIndicators(.hidden)
            }
        }
        .foregroundStyle(.white).preferredColorScheme(.dark)
        .confirmationDialog(ShellStrings.text("Reset all keys?"), isPresented: $confirmingReset, titleVisibility: .visible) {
            Button(ShellStrings.text("Reset all keys"), role: .destructive) {
                custom.resetAll()
                selected = nil
                custom.save(game)
            }
            Button(ShellStrings.text("Cancel"), role: .cancel) {}
        } message: {
            Text(ShellStrings.text("Puts every key of this game back to its built-in place and size."))
        }
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).shellType(ShellType.pageTitle).lineLimit(1).minimumScaleFactor(0.7)
                    .accessibilityAddTraits(.isHeader)
                Text(ShellStrings.text("Button layout")).shellType(ShellType.note).foregroundStyle(.white.opacity(0.55))
            }
            Spacer(minLength: 8)
            Button(action: close) { Text(ShellStrings.text("Done")) }
                .buttonStyle(ChipButtonStyle())
                .accessibilityIdentifier("padLayout.done")
                .shellTarget("padlay.done", radius: 22, action: close)
        }
    }

    // MARK: The preview canvas

    private var canvas: some View {
        GeometryReader { geo in
            let size = geo.size
            ZStack {
                ZStack {
                    RoundedRectangle(cornerRadius: 18).fill(Color.white.opacity(0.05))
                    RoundedRectangle(cornerRadius: 18).strokeBorder(Color.white.opacity(0.14), lineWidth: 1)
                }
                .contentShape(Rectangle())
                .onTapGesture { selected = nil }
                stickView(in: size)
                ForEach(game.keys) { key in keyView(key, in: size) }
            }
        }
    }

    /// A key's centre as drawn right now: the drag's live centre while it is dragged, else the arrangement's.
    private func centre(of name: String, in size: CGSize) -> CGPoint {
        if let drag, drag.name == name { return drag.centre }
        if name == "stick" { return custom.stickCentre(game: game, in: size) }
        let key = game.keys.first { $0.name == name }!
        return custom.centre(of: key, game: game, in: size)
    }

    private func keyView(_ key: GamePadLayoutGame.Key, in size: CGSize) -> some View {
        let e = custom.entry(key.name)
        let d = 2 * key.r * e.s * size.width * game.artScale(key, skin: skin)
        let c = centre(of: key.name, in: size)
        return keyFace(key, diameter: d)
            .frame(width: d, height: d)
            .overlay { if selected == key.name { selectionRing(d) } }
            .position(c)
            .gesture(dragGesture(key.name, in: size))
            .onTapGesture { selected = key.name }
            .accessibilityLabel(ShellStrings.setting(key.label))
            .zIndex(selected == key.name || drag?.name == key.name ? 2 : 1)
    }

    private func stickView(in size: CGSize) -> some View {
        let e = custom.entry("stick")
        // The glass choice draws the stick at 0.9 of the picture skins', as the pad does.
        let glassFactor: CGFloat = folder == nil && game == .silksong ? 0.9 : 1
        let d = 2 * game.stickRadius * e.s * size.width * glassFactor * (game == .hades2 && folder != nil ? 1.0 / 0.875 : 1)
        let c = centre(of: "stick", in: size)
        return ZStack {
            if let folder, let img = padArt(folder, "stick") {
                Image(decorative: img, scale: 1).resizable().scaledToFit()
            } else {
                Circle().fill(Color.white.opacity(0.10))
                Circle().strokeBorder(Color.white.opacity(0.35), lineWidth: 1.5)
            }
            if let folder, let knob = padArt(folder, "knob") {
                Image(decorative: knob, scale: 1).resizable().scaledToFit().frame(width: d * 0.67, height: d * 0.67)
            } else {
                Circle().fill(Color.white.opacity(0.16)).frame(width: d * 0.67, height: d * 0.67)
            }
        }
        .frame(width: d, height: d)
        .overlay { if selected == "stick" { selectionRing(d) } }
        .position(c)
        .gesture(dragGesture("stick", in: size))
        .onTapGesture { selected = "stick" }
        .accessibilityLabel(ShellStrings.text("Left stick"))
        .zIndex(selected == "stick" || drag?.name == "stick" ? 2 : 1)
    }

    private func selectionRing(_ d: CGFloat) -> some View {
        Circle().strokeBorder(Color.accentColor, lineWidth: 3)
            .frame(width: d * 1.12 + 8, height: d * 1.12 + 8)
    }

    /// Dragging moves the key freely (the in-game editor's way, not the generic editor's steps): the stored offset is
    /// the centre's distance from the table centre as screen fractions, clamped as the game clamps the centre, and it
    /// is saved when the drag ends.
    private func dragGesture(_ name: String, in size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 2)
            .onChanged { value in
                if drag?.name != name {
                    selected = name
                    let start = custom.entry(name)
                    drag = (name, start, centre(of: name, in: size))
                }
                guard let d0 = drag else { return }
                let raw = game.keys.first { $0.name == name }
                let base = name == "stick" ? game.rawStickCentre(in: size) : game.rawCentre(raw!, in: size)
                let startCentre = CGPoint(x: base.x + d0.start.dx * size.width, y: base.y + d0.start.dy * size.height)
                let moved = CGPoint(x: startCentre.x + value.translation.width, y: startCentre.y + value.translation.height)
                let radius = (raw?.r ?? game.stickRadius) * d0.start.s * size.width
                drag = (name, d0.start, GamePadCustom.clamp(moved, radius: radius, in: size))
            }
            .onEnded { _ in
                guard let d0 = drag else { return }
                let raw = game.keys.first { $0.name == name }
                let base = name == "stick" ? game.rawStickCentre(in: size) : game.rawCentre(raw!, in: size)
                var entry = d0.start
                entry.dx = (d0.centre.x - base.x) / size.width
                entry.dy = (d0.centre.y - base.y) / size.height
                custom.set(name, entry)
                custom.save(game)
                drag = nil
            }
    }

    /// One key's face: its picture art in the chosen skin, or a drawn glass key (a translucent disc, the glyph or the
    /// symbol the pad draws for the eye, the bag and the pause key, arrows for the Hades D-pad).
    @ViewBuilder private func keyFace(_ key: GamePadLayoutGame.Key, diameter d: CGFloat) -> some View {
        if let folder, let img = padArt(folder, key.name) {
            Image(decorative: img, scale: 1).resizable().scaledToFit()
        } else {
            ZStack {
                Circle().fill(Color.white.opacity(0.10))
                Circle().strokeBorder(Color.white.opacity(0.35), lineWidth: 1.5)
                if let glyph = key.glyph {
                    Text(glyph).font(.system(size: d * (glyph.count > 1 ? 0.30 : 0.42), weight: .semibold))
                        .foregroundStyle(.white.opacity(0.9))
                } else {
                    symbol(for: key.name).font(.system(size: d * 0.42)).foregroundStyle(.white.opacity(0.9))
                }
            }
        }
    }

    @ViewBuilder private func symbol(for name: String) -> some View {
        switch name {
        case "eye": Image(systemName: "eye")
        case "bag": Image(systemName: "bag")
        case "pause": Image(systemName: "pause")
        case "left": Image(systemName: "arrowtriangle.left.fill")
        case "up": Image(systemName: "arrowtriangle.up.fill")
        case "down": Image(systemName: "arrowtriangle.down.fill")
        case "right": Image(systemName: "arrowtriangle.right.fill")
        default: Image(systemName: "circle")
        }
    }

    /// A pad art image from the app bundle, where the build stages the sets (dm/<folder>/<name>.png, as DmGamepad reads).
    /// A CGImage through ImageIO, as ShellArtwork decodes, so this file builds on macOS as well as iOS (no UIKit).
    private func padArt(_ folder: String, _ name: String) -> CGImage? {
        guard let path = Bundle.main.resourcePath,
              let data = try? Data(contentsOf: URL(fileURLWithPath: path + "/dm/\(folder)/\(name).png")),
              let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }

    // MARK: The panel

    private var panel: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Silksong's pad has pages of its own (title, bag) that this editor does not touch; Hades II's pad is
            // one layout whole, so the note would only puzzle there.
            if game == .silksong {
                Text(ShellStrings.text("Only the combat keys are arranged here. The title and bag pages keep their layout."))
                    .shellType(ShellType.note).foregroundStyle(.white.opacity(0.55))
                    .fixedSize(horizontal: false, vertical: true)
            }
            if !skinLabel.isEmpty {
                Text(ShellStrings.text("Preview skin: \(skinLabel)"))
                    .shellType(ShellType.note).foregroundStyle(.white.opacity(0.55))
            }
            if let name = selected {
                Divider().overlay(Color.white.opacity(0.12))
                let entry = custom.entry(name)
                HStack {
                    Text(ShellStrings.setting(name == "stick" ? "Left stick" : label(of: name))).shellType(ShellType.settingLabel)
                    Spacer()
                    Text(entry.dx == 0 && entry.dy == 0 ? ShellStrings.text("Built-in place") : ShellStrings.text("Moved"))
                        .shellType(ShellType.note).foregroundStyle(.white.opacity(0.55))
                }
                // The generic editor's arrows: one tap moves the chosen key a hundredth of the screen.
                HStack(spacing: 12) {
                    Spacer()
                    nudgeButton(name, systemImage: "chevron.left", label: "Move left", dx: -0.01, dy: 0)
                    nudgeButton(name, systemImage: "chevron.up", label: "Move up", dx: 0, dy: -0.01)
                    nudgeButton(name, systemImage: "chevron.down", label: "Move down", dx: 0, dy: 0.01)
                    nudgeButton(name, systemImage: "chevron.right", label: "Move right", dx: 0.01, dy: 0)
                    Spacer()
                }
                HStack(spacing: 12) {
                    Text(ShellStrings.text("Size")).shellType(ShellType.settingLabel)
                    Spacer()
                    Button { stepSize(name, by: -GamePadLayoutGame.sizeStep) } label: { Text("−") }
                        .buttonStyle(ChipButtonStyle())
                        .disabled(entry.s <= GamePadLayoutGame.sizeRange.lowerBound)
                    Text("\(Int((entry.s * 100).rounded()))%")
                        .shellType(ShellType.note).monospacedDigit().frame(minWidth: 52)
                    Button { stepSize(name, by: GamePadLayoutGame.sizeStep) } label: { Text("+") }
                        .buttonStyle(ChipButtonStyle())
                        .disabled(entry.s >= GamePadLayoutGame.sizeRange.upperBound)
                }
                Button(ShellStrings.text("Reset this key")) {
                    custom.reset(name)
                    custom.save(game)
                }
                .buttonStyle(ShellButtonStyle(fills: true))
                .disabled(entry.isDefault)
            } else {
                Text(ShellStrings.text("Choose a key to change its size, or drag it to a new place."))
                    .shellType(ShellType.note).foregroundStyle(.white.opacity(0.55))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Divider().overlay(Color.white.opacity(0.12))
            Button(ShellStrings.text("Reset all keys")) { confirmingReset = true }
                .buttonStyle(ShellButtonStyle(fills: true))
                .disabled(custom.isEmpty)
            Text(ShellStrings.text("The game keeps the same arrangement in its own layout editor."))
                .shellType(ShellType.note).foregroundStyle(.white.opacity(0.45))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func label(of name: String) -> String {
        game.keys.first { $0.name == name }?.label ?? name
    }

    private func nudgeButton(_ name: String, systemImage: String, label: String, dx: CGFloat, dy: CGFloat) -> some View {
        Button { nudge(name, dx: dx, dy: dy) } label: {
            Image(systemName: systemImage).frame(width: 40, height: 28)
        }
        .buttonStyle(ChipButtonStyle())
        .accessibilityLabel(ShellStrings.setting(label))
    }

    /// One arrow step: the key's stored offset moves with it, capped at a full screen either way (the drawing clamps
    /// the centre to the screen long before that, in the editor and in the game alike).
    private func nudge(_ name: String, dx: CGFloat, dy: CGFloat) {
        var entry = custom.entry(name)
        entry.dx = min(1, max(-1, entry.dx + dx))
        entry.dy = min(1, max(-1, entry.dy + dy))
        custom.set(name, entry)
        custom.save(game)
    }

    private func stepSize(_ name: String, by step: CGFloat) {
        var entry = custom.entry(name)
        entry.s = min(GamePadLayoutGame.sizeRange.upperBound,
                      max(GamePadLayoutGame.sizeRange.lowerBound, ((entry.s + step) * 20).rounded() / 20))
        custom.set(name, entry)
        custom.save(game)
    }
}
