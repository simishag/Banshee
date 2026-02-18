# CLAUDE.md — Banshee

Banshee is an iOS hot-seat implementation of the classic 1977 Steve Jackson board wargame **Ogre**. It is a pure Swift project using **SwiftUI** for UI and **SpriteKit** for the interactive hex-grid battlefield. There are no external dependencies.

---

## Repository layout

```
Banshee/
├── Banshee.xcodeproj/          # Xcode project (pbxproj only, no workspace)
└── Banshee/                    # Single app target – all source here
    ├── BansheeApp.swift         # @main entry point → RootView
    ├── ContentView.swift        # Navigation root: RootView, MainMenuView, SplashView + button styles
    ├── GameView.swift           # In-game SwiftUI layer: GameHUDView, OgreWeaponPicker, OgreTargetPicker
    ├── RecordSheetView.swift    # Modal sheet: live Ogre status + defender unit roster
    ├── RulesView.swift          # Modal sheet: static quick-reference rules text
    ├── Info.plist
    ├── Assets.xcassets/
    └── Game/
        ├── GameModels.swift     # Pure value types: Hex, Unit, OgreUnit, weapons, CombatTable
        ├── GameState.swift      # ObservableObject game-logic controller + Phase enum
        ├── GameScene.swift      # SKScene: rendering, animation, touch → hex dispatch
        └── MapData.swift        # MapData struct (dimensions, craters, ridge edges) + MapEdge
```

No test targets, no CI configuration, and no Swift Package / CocoaPods / Carthage dependencies exist.

---

## Build requirements

| Requirement | Version |
|---|---|
| Xcode | 15 or later |
| Deployment target | iOS 16+ |
| Swift | 5.9+ (bundled with Xcode 15) |
| External dependencies | None |

**To build:**
1. Open `Banshee.xcodeproj` in Xcode (the `.xcodeproj`, not a workspace).
2. Set a signing team in *Signing & Capabilities*.
3. Choose a simulator or device running iOS 16+.
4. `⌘R` to build and run. There is no Makefile or command-line build script.

---

## Architecture

### Layered design

```
SwiftUI layer (ContentView, GameView, RecordSheetView, RulesView)
        │  @ObservedObject / @StateObject
        ▼
GameState  ──bind()──▶  GameScene (SKScene)
        ◀──handleHexTap()──  touch events
```

- **GameState** (`ObservableObject`) is the single source of truth. It owns all `@Published` state, enforces game rules, and mutates models.
- **GameScene** (`SKScene`) is a *view*: it renders what GameState describes and forwards touch events back as `handleHexTap(_:)`. It holds only a `weak` reference to GameState.
- SwiftUI views observe GameState via `@StateObject` / `@ObservedObject` and render the HUD, sheets, and menus.

### Data model conventions

- **Value types everywhere** (`struct`, `enum`) for game data: `Hex`, `Unit`, `OgreUnit`, `OgreWeapon`, `MapData`, `CombatTableEntry`.
- Value types are mutated by copying and reassigning (`var updated = unit; updated.hasFired = true; units[i] = updated`). Never mutate inside a collection directly unless the property is marked `var` at the array level.
- **Reference types** only for long-lived, identity-bearing objects: `GameState` and `GameScene`.
- `UUID` is used for stable identifiers on `Unit`, `OgreUnit`, and `OgreWeapon`. IDs are generated once in `init`, never recycled.

---

## Key source files — what lives where

### `GameModels.swift`

All pure data structures and static game rules. Nothing in here imports SpriteKit or SwiftUI.

| Type | Role |
|---|---|
| `Hex` | Axial coordinate `(q, r)`. Provides `distance(to:)` (cube-distance) and `neighbors()`. |
| `Side` | `.ogre` / `.defender` |
| `UnitStatus` | `.active` / `.disabled` / `.destroyed` |
| `UnitType` | All six defender unit types with stats (`attack`, `defense`, `range`, `movement`). |
| `Unit` | A single defender piece. Contains `strength` (infantry squads), `hasFired`, `status`. |
| `OgreWeaponType` | Four weapon categories with their stats. |
| `OgreWeapon` | One weapon on the Ogre, including `hasFired`, `isSelected`, `status`. |
| `OgreUnit` | The Ogre: `treadsRemaining`, computed `movement` (≤3), `weapons` array (fixed loadout of 15 weapons). |
| `OgreTargetSystem` | Enum used by the UI picker to choose between `.treads` and `.weapon(OgreWeapon)`. |
| `CombatResult` | `.noEffect` / `.disabled` / `.destroyed` |
| `CombatTable` | Static 5-column CRT; `resolve(attack:defense:roll:)` returns a `CombatResult`. |

### `GameState.swift`

The game-logic brain. Owns all mutable state and phase transitions.

Key responsibilities:
- `setupScenario()` — places defender units and the Ogre at their starting positions.
- `advancePhase()` — steps through `Phase` cases; calls `recoverDisabledDefenders()` at the right transition.
- `handleHexTap(_:)` — dispatches a tap to setup, move, or attack logic based on the current phase.
- `resolveAttack(against:)` / `resolveAttack(targetingOgre:system:)` — combat resolution via `CombatTable`.
- `validHexesForSelection()` — returns highlighted hexes for movement or placement (BFS via `canReach`).
- After every mutation that changes visual state, calls `scene.syncUnits()` (and sometimes `scene.updateHighlightHexes` / `scene.updateSelection`).

The `Phase` enum (also in this file) drives the entire turn flow:

```
defenderSetup → ogreSetup → ogreMove → ogreFire → defenderMove → defenderFire → gevSecondMove → (next turn ogreMove)
```

`phaseHint` (extension at bottom of file) returns a user-facing instruction string for setup and move phases.

### `GameScene.swift`

SpriteKit rendering only — no game rules.

Key methods:
- `bind(to:)` — called once from `GameState.init`; stores weak ref, builds map, syncs units.
- `buildMap()` — draws hex grid + crater overlays; clears and rebuilds on size change (`didChangeSize`).
- `syncUnits()` — adds/removes/updates `SKNode` nodes to match current `GameState.units` and `GameState.ogre`.
- `updateSelection()` — draws yellow ring around the selected unit node.
- `updateHighlightHexes(_:)` — draws green hex outlines for valid moves/placements.
- `animateUnitMove`, `animateOgreMove`, `animateAttack`, `animateRamming` — short `SKAction` animations.
- `touchesEnded(_:with:)` — converts screen point → axial hex via `pixelToHex` (uses cube-rounding), then calls `gameState.handleHexTap`.

**Hex geometry** uses a **flat-top** axial layout:
- `axialToPixel`: `x = size * 1.5 * q`, `y = size * √3 * (r + q/2)`
- `pixelToHex`: inverse of above, then cube-round.

`showHexCoords = true` is a debug flag that draws `(q,r)` labels on every hex. Flip to `false` to remove them for production.

### `MapData.swift`

Defines `MapData` (width, height, `craters: Set<Hex>`, `ridgeEdges: Set<MapEdge>`) and the canonical `MapData.classic` instance (15×22, currently no craters or ridges).

`MapEdge` is a canonical, order-independent edge between two adjacent hexes (lower-coordinate hex is always `a`).

### `ContentView.swift`

Navigation shell. `RootView` owns splash/menu/game state with opacity transitions.

Defines three reusable `ButtonStyle` conformances used throughout the app:
- `PrimaryButtonStyle` — red fill, full width
- `SecondaryButtonStyle` — white-on-dark, full width
- `CompactButtonStyle` — defined in `GameView.swift`, small, used in the HUD

### `GameView.swift`

Hosts `SpriteView(scene: gameState.scene)` full-screen with SwiftUI overlaid on top. `GameHUDView` renders turn/phase info, combat log, the End Phase / Clear buttons, and conditionally shows `OgreWeaponPicker` and `OgreTargetPicker`.

---

## Game rules encoded in the app

### Unit stats (from `UnitType`)

| Type | ATK | DEF | RNG | MOV |
|---|---|---|---|---|
| Heavy Tank | 4 | 3 | 2 | 2 |
| Missile Tank | 3 | 2 | 4 | 2 |
| GEV | 2 | 2 | 2 | 4 |
| Howitzer | 6 | 1 | 8 | 0 |
| Infantry | 1/sq | 1 | 1 | 2 |
| Command Post | 0 | 0 | — | 0 |

### Ogre weapon loadout (Ogre Mark III default)

| Weapon | Count | ATK | DEF | RNG |
|---|---|---|---|---|
| Main Battery | 1 | 4 | 4 | 3 |
| Secondary Battery | 4 | 3 | 3 | 2 |
| Missile | 2 | 6 | 3 | 5 |
| Anti-Personnel (AP) | 8 | 1 | 1 | 1 |

Missiles are **one-shot**: `status` is set to `.destroyed` after firing.

### Ogre movement

`movement = max(0, min(3, ceil(treadsRemaining / 15.0)))`

### Combat Resolution Table (CRT)

| Column | 1 | 2 | 3 | 4 | 5 | 6 |
|---|---|---|---|---|---|---|
| 1-2 | NE | NE | D | D | X | X |
| 1-1 | NE | D | D | X | X | X |
| 2-1 | D | D | X | X | X | X |
| 3-1 | D | X | X | X | X | X |
| 4-1 | X | X | X | X | X | X |

Ratios below 0.5 are always NE; 5+ are always X.

### Placement rules

- **Defender setup**: any hex where `q + r >= 8` (roughly the back two-thirds of the 15×22 board).
- **Ogre setup**: any hex in the bottom row (`r == height - 1`).
- Infantry stacks up to 3 strength in one hex; armor never stacks.

---

## Common development tasks

### Adding terrain to the classic map

Edit `MapData.classic` in `MapData.swift`:

```swift
static let classic = MapData(
    width: 15,
    height: 22,
    craters: [Hex(q: 5, r: 8), Hex(q: 9, r: 12)],   // blocks movement and placement
    ridgeEdges: [MapEdge(Hex(q: 3, r: 5), Hex(q: 4, r: 5))]  // blocks crossing that hexside
)
```

`isBlocked` checks crater membership; `isEdgeBlocked(from:to:)` checks ridge membership. `canReach` in GameState honours both.

### Changing the starting scenario

Edit `GameState.setupScenario()`. Defender units start at half of the 15×22 map (rows 11+). The Ogre always starts at the top row.

### Adding a new unit type

1. Add a case to `UnitType` in `GameModels.swift` with `attack`, `defense`, `range`, `movement`, `isArmor`, `sortOrder`, `displayName`.
2. Add a color case in `GameScene.color(for:)`.
3. Place instances in `GameState.setupScenario()`.

### Adding a new Ogre weapon type

1. Add to `OgreWeaponType` in `GameModels.swift`.
2. Add the weapon to `OgreUnit.init` in the `weapons` array.
3. Handle any new single-shot logic in `GameState.markOgreWeaponsFired`.

### Toggling hex-coordinate debug overlay

In `GameScene.swift`:

```swift
private let showHexCoords = false   // was true
```

### Adjusting the CRT

Edit the `CombatTable.entries` array in `GameModels.swift`. Add more `CombatTableEntry` rows for additional odds columns and update the ratio thresholds in `CombatTable.resolve`.

---

## Architecture decisions and constraints

- **No ViewModel layer**: `GameState` acts as the ViewModel directly. SwiftUI views `@ObservedObject` it. Do not introduce a separate ViewModel struct unless the views become significantly more complex.
- **Scene is a pure renderer**: All rule enforcement lives in GameState. `GameScene` must never modify `GameState.units` or `GameState.ogre` directly — it only calls the public methods `GameState` exposes (`handleHexTap`, etc.).
- **Value-type mutation pattern**: Because `Unit` and `OgreUnit` are structs inside a `@Published` array/optional, mutation always follows the copy-modify-reassign pattern. This triggers `@Published` change notifications correctly.
- **Single scenario**: Only the classic Ogre scenario is implemented. There is no save/load, no networking, and no AI opponent.
- **No Swift Package dependencies**: Keep it that way unless a compelling need arises. The project intentionally uses only first-party Apple frameworks.
- **iOS only**: SpriteKit's `UITouch` API is used directly. AppKit equivalents are not present.

---

## Known gaps / future work notes

- `MapData.classic` has empty `craters` and `ridgeEdges` — terrain data needs to be added to match the actual Ogre board.
- No win condition check is implemented: the game does not detect when the Ogre destroys the Command Post or when its treads reach 0.
- No save/restore of game state between app launches.
- `showHexCoords = true` is a debug artifact that should be set to `false` before release.
- Only the Ogre Mark III loadout is hard-coded; other Ogre variants (Mark I, II, V) are not supported.
- No unit tests exist.
