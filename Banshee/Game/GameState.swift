import Foundation
import SpriteKit

final class GameState: ObservableObject {
    @Published var units: [Unit] = []
    @Published var ogre: OgreUnit?
    @Published var phase: Phase = .defenderSetup
    @Published var turnNumber: Int = 0
    @Published var lastCombatLog: String?
    @Published var selectedUnitID: UUID?
    @Published var selectedAttackers: Set<UUID> = []
    @Published var pendingOgreTarget: OgreUnit?

    let map: MapData = .classic

    let scene: GameScene

    init() {
        self.scene = GameScene()
        setupScenario()
        scene.bind(to: self)
    }

    static var preview: GameState {
        GameState()
    }

    var ogreSelection: OgreUnit? {
        guard let ogre, selectedUnitID == ogre.id else { return nil }
        return ogre
    }

    func setupScenario() {
        units = [
            Unit(type: .commandPost, side: .defender, position: Hex(q: 7, r: 19)),
            Unit(type: .howitzer, side: .defender, position: Hex(q: 5, r: 18)),
            Unit(type: .howitzer, side: .defender, position: Hex(q: 9, r: 18)),
            Unit(type: .missileTank, side: .defender, position: Hex(q: 6, r: 16)),
            Unit(type: .missileTank, side: .defender, position: Hex(q: 8, r: 16)),
            Unit(type: .heavyTank, side: .defender, position: Hex(q: 4, r: 17)),
            Unit(type: .heavyTank, side: .defender, position: Hex(q: 10, r: 17)),
            Unit(type: .gev, side: .defender, position: Hex(q: 3, r: 15)),
            Unit(type: .gev, side: .defender, position: Hex(q: 11, r: 15)),
            Unit(type: .infantry, side: .defender, position: Hex(q: 7, r: 17), strength: 3),
            Unit(type: .infantry, side: .defender, position: Hex(q: 6, r: 19), strength: 3),
            Unit(type: .infantry, side: .defender, position: Hex(q: 8, r: 19), strength: 3)
        ]
        ogre = OgreUnit(position: Hex(q: 7, r: 0))
    }

    func advancePhase() {
        clearSelection()
        lastCombatLog = nil

        switch phase {
        case .defenderSetup:
            phase = .ogreSetup
        case .ogreSetup:
            turnNumber = 1
            phase = .ogreMove
            resetFireFlags(for: .ogre)
            resetFireFlags(for: .defender)
        case .ogreMove:
            phase = .ogreFire
            resetFireFlags(for: .ogre)
        case .ogreFire:
            recoverDisabledDefenders()
            phase = .defenderMove
        case .defenderMove:
            phase = .defenderFire
            resetFireFlags(for: .defender)
        case .defenderFire:
            phase = .gevSecondMove
        case .gevSecondMove:
            endTurn()
        }
        scene.syncUnits()
        scene.updateHighlightHexes(validHexesForSelection())
    }

    func endTurn() {
        turnNumber += 1
        phase = .ogreMove
        resetSelectionsForNewTurn()
        resetFireFlags(for: .ogre)
        resetFireFlags(for: .defender)
        scene.syncUnits()
        scene.updateHighlightHexes(validHexesForSelection())
    }

    func resetSelectionsForNewTurn() {
        clearSelection()
        ogre?.weapons = ogre?.weapons.map { weapon in
            var updated = weapon
            updated.hasFired = false
            updated.isSelected = false
            return updated
        } ?? []
        units = units.map { unit in
            var updated = unit
            updated.hasFired = false
            return updated
        }
        scene.syncUnits()
    }

    func clearSelection() {
        selectedUnitID = nil
        selectedAttackers.removeAll()
        pendingOgreTarget = nil
        ogre?.weapons = ogre?.weapons.map { weapon in
            var updated = weapon
            updated.isSelected = false
            return updated
        } ?? []
        scene.updateSelection()
        scene.updateHighlightHexes([])
    }

    func resetFireFlags(for side: Side) {
        if side == .ogre {
            ogre?.weapons = ogre?.weapons.map { weapon in
                var updated = weapon
                updated.hasFired = false
                updated.isSelected = false
                return updated
            } ?? []
        } else {
            units = units.map { unit in
                var updated = unit
                if unit.side == .defender {
                    updated.hasFired = false
                }
                return updated
            }
        }
        scene.syncUnits()
    }

    func recoverDisabledDefenders() {
        units = units.map { unit in
            guard unit.side == .defender else { return unit }
            var updated = unit
            if unit.status == .disabled {
                updated.status = .active
            }
            return updated
        }
        scene.syncUnits()
    }

    func toggleOgreWeapon(weaponID: UUID) {
        guard phase.isFirePhase, var ogre else { return }
        ogre.weapons = ogre.weapons.map { weapon in
            var updated = weapon
            if weapon.id == weaponID {
                updated.isSelected.toggle()
            }
            return updated
        }
        self.ogre = ogre
        scene.syncUnits()
    }

    func selectOgreTarget(_ system: OgreTargetSystem) {
        guard let target = pendingOgreTarget else { return }
        resolveAttack(targetingOgre: target, system: system)
        pendingOgreTarget = nil
    }

    func handleHexTap(_ hex: Hex) {
        print("tap: \(hex.q) \(hex.r)")
        
        if let ogre, ogre.position == hex {
            selectedUnitID = ogre.id
            scene.updateSelection()
            scene.updateHighlightHexes(validHexesForSelection())
            return
        }

        if let unit = units.first(where: { $0.position == hex && $0.status != .destroyed }) {
            selectUnit(unit)
            return
        }

        if phase.isSetupPhase {
            attemptPlacement(to: hex)
            return
        }

        if phase.isMovePhase {
            attemptMove(to: hex)
        } else if phase.isFirePhase {
            attemptAttack(on: hex)
        }
    }

    func selectUnit(_ unit: Unit) {
        if phase.isFirePhase {
            if unit.hasFired || unit.status != .active {
                return
            }
            if selectedAttackers.contains(unit.id) {
                selectedAttackers.remove(unit.id)
            } else {
                selectedAttackers.insert(unit.id)
            }
        }
        selectedUnitID = unit.id
        scene.updateSelection()
        scene.updateHighlightHexes(validHexesForSelection())
    }

    func attemptMove(to hex: Hex) {
        guard let selected = selectedUnitID else { return }
        if let ogre, ogre.id == selected {
            moveOgre(to: hex)
        } else if let index = units.firstIndex(where: { $0.id == selected }) {
            moveUnit(at: index, to: hex)
        }
    }

    func attemptPlacement(to hex: Hex) {
        guard let selected = selectedUnitID else { return }
        if phase == .defenderSetup {
            if let index = units.firstIndex(where: { $0.id == selected }) {
                placeDefenderUnit(at: index, to: hex)
            }
        } else if phase == .ogreSetup {
            placeOgre(to: hex)
        }
    }

    func attemptAttack(on hex: Hex) {
        if let ogre = ogre, ogre.position == hex {
            if phase == .defenderFire {
                pendingOgreTarget = ogre
                return
            }
        }

        guard let target = units.first(where: { $0.position == hex && $0.status != .destroyed }) else { return }
        resolveAttack(against: target)
    }

    func moveOgre(to hex: Hex) {
        guard phase == .ogreMove, var ogre else { return }
        guard map.isInside(hex), !map.isBlocked(hex) else { return }
        guard canReach(start: ogre.position, end: hex, maxMove: ogre.movement) else { return }
        let occupied = units.filter { $0.position == hex && $0.status != .destroyed }
        if occupied.contains(where: { $0.type != .infantry }) {
            return
        }
        ogre.position = hex
        self.ogre = ogre
        scene.animateOgreMove()
        if !occupied.isEmpty, ogreHasAP() {
            applyOgreAP(to: hex)
        }
        scene.syncUnits()
    }

    func placeOgre(to hex: Hex) {
        guard phase == .ogreSetup, var ogre else { return }
        guard isOgrePlacementValid(hex) else { return }
        ogre.position = hex
        self.ogre = ogre
        scene.animateOgreMove()
        scene.syncUnits()
        scene.updateHighlightHexes(validHexesForSelection())
    }

    func moveUnit(at index: Int, to hex: Hex) {
        let unit = units[index]
        guard unit.side == .defender else { return }
        guard phase == .defenderMove || (phase == .gevSecondMove && unit.type == .gev) else { return }
        guard unit.status == .active else { return }
        guard map.isInside(hex), !map.isBlocked(hex) else { return }
        let maxMove = phase == .gevSecondMove ? 3 : unit.type.movement
        guard canReach(start: unit.position, end: hex, maxMove: maxMove) else { return }

        if let ogre = ogre, ogre.position == hex {
            ramOgre(with: unit)
            return
        }

        if unit.type == .infantry {
            mergeInfantry(into: hex, movingUnitIndex: index)
        } else {
            if units.contains(where: { $0.position == hex && $0.status != .destroyed }) {
                return
            }
            units[index].position = hex
            scene.animateUnitMove(unitID: unit.id)
        }
        scene.syncUnits()
    }

    func placeDefenderUnit(at index: Int, to hex: Hex) {
        let unit = units[index]
        guard unit.side == .defender else { return }
        guard phase == .defenderSetup else { return }
        guard isDefenderPlacementValid(hex, movingUnit: unit) else { return }
        units[index].position = hex
        scene.animateUnitMove(unitID: unit.id)
        scene.syncUnits()
        scene.updateHighlightHexes(validHexesForSelection())
    }

    func ramOgre(with unit: Unit) {
        guard var ogre else { return }
        ogre.treadsRemaining = max(0, ogre.treadsRemaining - 1)
        if let index = units.firstIndex(where: { $0.id == unit.id }) {
            units[index].status = .destroyed
        }
        self.ogre = ogre
        lastCombatLog = "Ramming attack: Ogre loses 1 tread, rammer destroyed."
        scene.animateRamming(from: unit.position, to: ogre.position)
        scene.syncUnits()
    }

    func resolveAttack(against target: Unit) {
        guard phase.isFirePhase else { return }
        var attackers: [Unit] = []
        var ogreWeapons: [OgreWeapon] = []

        if phase == .ogreFire {
            guard let ogre else { return }
            ogreWeapons = ogre.weapons.filter { $0.isSelected && !$0.hasFired && $0.status == .active }
            if ogreWeapons.isEmpty {
                return
            }
        } else {
            attackers = units.filter { selectedAttackers.contains($0.id) && $0.status == .active && !$0.hasFired }
            if attackers.isEmpty {
                return
            }
        }

        let distance = currentAttackDistance(to: target.position)
        if phase == .ogreFire {
            guard ogreWeapons.allSatisfy({ $0.type.range >= distance }) else { return }
            if ogreWeapons.contains(where: { $0.type == .antipersonnel }) && target.type != .infantry && target.type != .commandPost {
                return
            }
        } else {
            guard attackers.allSatisfy({ $0.type.range >= distance }) else { return }
        }

        let attackStrength: Int
        if phase == .ogreFire {
            attackStrength = ogreWeapons.reduce(0) { $0 + $1.type.attack }
        } else {
            attackStrength = attackers.reduce(0) { $0 + $1.type.attack * ($1.type == .infantry ? $1.strength : 1) }
        }

        let defenseStrength = target.type.defense
        let roll = Int.random(in: 1...6)
        let result = CombatTable.resolve(attack: attackStrength, defense: defenseStrength, roll: roll)
        apply(result: result, to: target, attackStrength: attackStrength)

        if phase == .ogreFire {
            markOgreWeaponsFired(ids: ogreWeapons.map { $0.id })
        } else {
            markUnitsFired(ids: attackers.map { $0.id })
        }

        scene.animateAttack(from: currentAttackOrigin(), to: target.position, result: result)
        clearSelection()
        lastCombatLog = "Attack \(attackStrength)-\(defenseStrength) rolled \(roll): \(result.rawValue)"
        scene.syncUnits()
    }

    func resolveAttack(targetingOgre target: OgreUnit, system: OgreTargetSystem) {
        guard phase == .defenderFire else { return }
        let attackers = units.filter { selectedAttackers.contains($0.id) && $0.status == .active && !$0.hasFired }
        guard !attackers.isEmpty else { return }

        let distance = currentAttackDistance(to: target.position)
        guard attackers.allSatisfy({ $0.type.range >= distance }) else { return }

        let attackStrength = attackers.reduce(0) { $0 + $1.type.attack * ($1.type == .infantry ? $1.strength : 1) }
        let roll = Int.random(in: 1...6)

        switch system {
        case .treads:
            if attackers.count > 1 {
                lastCombatLog = "Tread attacks must be made by a single unit."
                return
            }
            let result = CombatTable.resolve(attack: 1, defense: 1, roll: roll)
            if result == .destroyed {
                var ogre = target
                ogre.treadsRemaining = max(0, ogre.treadsRemaining - attackStrength)
                self.ogre = ogre
                lastCombatLog = "Treads hit: \(attackStrength) treads destroyed."
            } else {
                lastCombatLog = "Treads attack rolled \(roll): no effect."
            }
        case .weapon(let weapon):
            let defense = weapon.type.defense
            let result = CombatTable.resolve(attack: attackStrength, defense: defense, roll: roll)
            apply(result: result, to: weapon)
            lastCombatLog = "Weapon attack \(attackStrength)-\(defense) rolled \(roll): \(result.rawValue)"
        }

        markUnitsFired(ids: attackers.map { $0.id })
        scene.animateAttack(from: currentAttackOrigin(), to: target.position, result: .destroyed)
        clearSelection()
        scene.syncUnits()
    }

    func apply(result: CombatResult, to target: Unit, attackStrength: Int) {
        guard let index = units.firstIndex(where: { $0.id == target.id }) else { return }
        var unit = units[index]
        switch result {
        case .noEffect:
            break
        case .disabled:
            if unit.type == .infantry {
                unit.strength = max(0, unit.strength - 1)
                if unit.strength == 0 {
                    unit.status = .destroyed
                }
            } else if unit.status == .disabled {
                unit.status = .destroyed
            } else {
                unit.status = .disabled
            }
        case .destroyed:
            unit.status = .destroyed
        }
        units[index] = unit
        scene.syncUnits()
    }

    func apply(result: CombatResult, to weapon: OgreWeapon) {
        guard var ogre else { return }
        ogre.weapons = ogre.weapons.map { item in
            guard item.id == weapon.id else { return item }
            var updated = item
            if result == .destroyed {
                updated.status = .destroyed
            } else if result == .disabled {
                if updated.status == .disabled {
                    updated.status = .destroyed
                } else {
                    updated.status = .disabled
                }
            }
            return updated
        }
        self.ogre = ogre
        scene.syncUnits()
    }

    func currentAttackOrigin() -> Hex {
        if phase == .ogreFire {
            return ogre?.position ?? Hex(q: 0, r: 0)
        }
        if let attacker = units.first(where: { selectedAttackers.contains($0.id) }) {
            return attacker.position
        }
        return Hex(q: 0, r: 0)
    }

    func currentAttackDistance(to target: Hex) -> Int {
        if phase == .ogreFire {
            return ogre?.position.distance(to: target) ?? 0
        }
        if let attacker = units.first(where: { selectedAttackers.contains($0.id) }) {
            return attacker.position.distance(to: target)
        }
        return 0
    }

    func markUnitsFired(ids: [UUID]) {
        units = units.map { unit in
            var updated = unit
            if ids.contains(unit.id) {
                updated.hasFired = true
            }
            return updated
        }
        scene.syncUnits()
    }

    func markOgreWeaponsFired(ids: [UUID]) {
        guard var ogre else { return }
        ogre.weapons = ogre.weapons.map { weapon in
            var updated = weapon
            if ids.contains(weapon.id) {
                updated.hasFired = true
                updated.isSelected = false
                if weapon.type == .missile {
                    updated.status = .destroyed
                }
            }
            return updated
        }
        self.ogre = ogre
        scene.syncUnits()
    }

    func validHexesForSelection() -> [Hex] {
        guard let selectedID = selectedUnitID else { return [] }
        if phase == .defenderSetup, let unit = units.first(where: { $0.id == selectedID }) {
            return validDefenderPlacementHexes(for: unit)
        }
        if phase == .ogreSetup, ogre?.id == selectedID {
            return validOgrePlacementHexes()
        }
        if phase.isMovePhase {
            if let ogre, ogre.id == selectedID {
                return validMoveHexesForOgre(ogre)
            }
            if let unit = units.first(where: { $0.id == selectedID }) {
                return validMoveHexesForUnit(unit)
            }
        }
        return []
    }

    func validDefenderPlacementHexes(for unit: Unit) -> [Hex] {
        guard unit.side == .defender else { return [] }
        var hexes: [Hex] = []
        for r in 0..<map.height {
            for q in 0..<map.width {
                let hex = Hex(q: q, r: r)
                if isDefenderPlacementValid(hex, movingUnit: unit) {
                    hexes.append(hex)
                }
            }
        }
        return hexes
    }

    func validOgrePlacementHexes() -> [Hex] {
        (0..<map.width).map { Hex(q: $0, r: map.height - 1) }.filter { isOgrePlacementValid($0) }
    }

    func validMoveHexesForUnit(_ unit: Unit) -> [Hex] {
        guard unit.side == .defender else { return [] }
        let maxMove = phase == .gevSecondMove ? 3 : unit.type.movement
        var hexes: [Hex] = []
        for r in 0..<map.height {
            for q in 0..<map.width {
                let hex = Hex(q: q, r: r)
                if canReach(start: unit.position, end: hex, maxMove: maxMove) && isMoveDestinationValid(hex, movingUnit: unit) {
                    hexes.append(hex)
                }
            }
        }
        return hexes
    }

    func validMoveHexesForOgre(_ ogre: OgreUnit) -> [Hex] {
        var hexes: [Hex] = []
        for r in 0..<map.height {
            for q in 0..<map.width {
                let hex = Hex(q: q, r: r)
                if canReach(start: ogre.position, end: hex, maxMove: ogre.movement) && isOgreMoveDestinationValid(hex) {
                    hexes.append(hex)
                }
            }
        }
        return hexes
    }

    func isDefenderPlacementValid(_ hex: Hex, movingUnit: Unit) -> Bool {
        guard map.isInside(hex), !map.isBlocked(hex) else { return false }
        guard (hex.q + hex.r) >= 8 else { return false }
        let occupants = units.filter { $0.position == hex && $0.status != .destroyed && $0.id != movingUnit.id }
        if movingUnit.type == .infantry {
            let nonInfantry = occupants.contains(where: { $0.type != .infantry })
            let strength = occupants.filter { $0.type == .infantry }.reduce(0) { $0 + $1.strength }
            return !nonInfantry && (strength + movingUnit.strength) <= 3
        }
        return occupants.isEmpty
    }

    func isOgrePlacementValid(_ hex: Hex) -> Bool {
        guard map.isInside(hex), !map.isBlocked(hex) else { return false }
        guard hex.r == map.height - 1 else { return false }
        let occupants = units.filter { $0.position == hex && $0.status != .destroyed }
        return !occupants.contains(where: { $0.type != .infantry })
    }

    func isMoveDestinationValid(_ hex: Hex, movingUnit: Unit) -> Bool {
        guard map.isInside(hex), !map.isBlocked(hex) else { return false }
        if movingUnit.type != .infantry {
            return !units.contains(where: { $0.position == hex && $0.status != .destroyed })
        }
        let occupants = units.filter { $0.position == hex && $0.status != .destroyed && $0.id != movingUnit.id }
        let nonInfantry = occupants.contains(where: { $0.type != .infantry })
        let strength = occupants.filter { $0.type == .infantry }.reduce(0) { $0 + $1.strength }
        return !nonInfantry && (strength + movingUnit.strength) <= 3
    }

    func isOgreMoveDestinationValid(_ hex: Hex) -> Bool {
        guard map.isInside(hex), !map.isBlocked(hex) else { return false }
        let occupants = units.filter { $0.position == hex && $0.status != .destroyed }
        return !occupants.contains(where: { $0.type != .infantry })
    }

    func canReach(start: Hex, end: Hex, maxMove: Int) -> Bool {
        if start == end { return true }
        var frontier: [(Hex, Int)] = [(start, 0)]
        var visited: Set<Hex> = [start]

        while !frontier.isEmpty {
            let (current, cost) = frontier.removeFirst()
            if cost >= maxMove { continue }
            for next in current.neighbors() {
                if visited.contains(next) { continue }
                guard map.isInside(next), !map.isBlocked(next) else { continue }
                guard !map.isEdgeBlocked(from: current, to: next) else { continue }
                if next == end { return true }
                visited.insert(next)
                frontier.append((next, cost + 1))
            }
        }
        return false
    }

    func mergeInfantry(into hex: Hex, movingUnitIndex: Int) {
        let moving = units[movingUnitIndex]
        let infantryIndices = units.enumerated().compactMap { index, unit in
            unit.type == .infantry && unit.status != .destroyed && unit.position == hex ? index : nil
        }
        let currentStrength = infantryIndices.reduce(0) { $0 + units[$1].strength }
        guard currentStrength + moving.strength <= 3 else { return }

        if let targetIndex = infantryIndices.first {
            units[targetIndex].strength = currentStrength + moving.strength
            units[movingUnitIndex].status = .destroyed
        } else {
            units[movingUnitIndex].position = hex
            scene.animateUnitMove(unitID: moving.id)
        }
    }

    func ogreHasAP() -> Bool {
        ogre?.weapons.contains(where: { $0.type == .antipersonnel && $0.status != .destroyed }) ?? false
    }

    func applyOgreAP(to hex: Hex) {
        let infantryIndices = units.enumerated().compactMap { index, unit in
            unit.type == .infantry && unit.status != .destroyed && unit.position == hex ? index : nil
        }
        guard let targetIndex = infantryIndices.first else { return }
        var unit = units[targetIndex]
        unit.strength = max(0, unit.strength - 1)
        if unit.strength == 0 {
            unit.status = .destroyed
        }
        units[targetIndex] = unit
        lastCombatLog = "Ogre AP reduces infantry by 1."
    }
}

enum Phase: CaseIterable {
    case defenderSetup
    case ogreSetup
    case ogreMove
    case ogreFire
    case defenderMove
    case defenderFire
    case gevSecondMove

    var title: String {
        switch self {
        case .defenderSetup: return "Defender Setup"
        case .ogreSetup: return "Ogre Setup"
        case .ogreMove: return "Ogre Movement"
        case .ogreFire: return "Ogre Fire"
        case .defenderMove: return "Defender Movement"
        case .defenderFire: return "Defender Fire"
        case .gevSecondMove: return "GEV Second Move"
        }
    }

    var isMovePhase: Bool {
        self == .ogreMove || self == .defenderMove || self == .gevSecondMove
    }

    var isFirePhase: Bool {
        self == .ogreFire || self == .defenderFire
    }

    var isSetupPhase: Bool {
        self == .defenderSetup || self == .ogreSetup
    }
}

extension GameState {
    var phaseHint: String? {
        switch phase {
        case .defenderSetup:
            return "Defender: tap a unit, then tap any hex with q+r ≥ 8 to place."
        case .ogreSetup:
            return "Ogre: tap the Ogre, then tap any bottom-row hex."
        case .ogreMove:
            return "Ogre movement: tap the Ogre, then tap a highlighted hex."
        case .defenderMove:
            return "Defender movement: tap a unit, then tap a highlighted hex."
        case .gevSecondMove:
            return "GEV second move: select a GEV and move up to 3 hexes."
        default:
            return nil
        }
    }
}
