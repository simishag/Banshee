import Foundation

struct Hex: Hashable, Codable {
    let q: Int
    let r: Int
    let s: Int
    
    init(q: Int, r: Int) {
        self.q = q
        self.r = r
        s = -q-r
    }

    func distance(to other: Hex) -> Int {
        let a = Hex.cubeFromOffset(self)
        let b = Hex.cubeFromOffset(other)
        let dx = a.x - b.x
        let dy = a.y - b.y
        let dz = a.z - b.z
        return max(abs(dx), abs(dy), abs(dz))
    }

    func neighbors() -> [Hex] {
        let odd = r & 1
        let deltasEven = [(1, 0), (0, -1), (-1, -1), (-1, 0), (-1, 1), (0, 1)]
        let deltasOdd = [(1, 0), (1, -1), (0, -1), (-1, 0), (0, 1), (1, 1)]
        let deltas = odd == 0 ? deltasEven : deltasOdd
        return deltas.map { Hex(q: q + $0.0, r: r + $0.1) }
    }

    struct Cube {
        let x: Int
        let y: Int
        let z: Int
    }

    static func cubeFromOffset(_ hex: Hex) -> Cube {
        let x = hex.q - (hex.r - (hex.r & 1)) / 2
        let z = hex.r
        let y = -x - z
        return Cube(x: x, y: y, z: z)
    }

    static func offsetFromCube(_ cube: Cube) -> Hex {
        let q = cube.x + (cube.z - (cube.z & 1)) / 2
        let r = cube.z
        return Hex(q: q, r: r)
    }
}

enum Side: String, Codable {
    case ogre
    case defender
}

enum UnitStatus: String, Codable {
    case active
    case disabled
    case destroyed
}

enum UnitType: String, Codable, CaseIterable {
    case heavyTank
    case missileTank
    case gev
    case howitzer
    case infantry
    case commandPost

    var displayName: String {
        switch self {
        case .heavyTank: return "Heavy Tank"
        case .missileTank: return "Missile Tank"
        case .gev: return "GEV"
        case .howitzer: return "Howitzer"
        case .infantry: return "Infantry"
        case .commandPost: return "Command Post"
        }
    }

    var attack: Int {
        switch self {
        case .heavyTank: return 4
        case .missileTank: return 3
        case .gev: return 2
        case .howitzer: return 6
        case .infantry: return 1
        case .commandPost: return 0
        }
    }

    var defense: Int {
        switch self {
        case .heavyTank: return 3
        case .missileTank: return 2
        case .gev: return 2
        case .howitzer: return 1
        case .infantry: return 1
        case .commandPost: return 0
        }
    }

    var range: Int {
        switch self {
        case .heavyTank: return 2
        case .missileTank: return 4
        case .gev: return 2
        case .howitzer: return 8
        case .infantry: return 1
        case .commandPost: return 0
        }
    }

    var movement: Int {
        switch self {
        case .heavyTank: return 2
        case .missileTank: return 2
        case .gev: return 4
        case .howitzer: return 0
        case .infantry: return 2
        case .commandPost: return 0
        }
    }

    var isArmor: Bool {
        switch self {
        case .heavyTank, .missileTank, .gev, .howitzer: return true
        case .infantry, .commandPost: return false
        }
    }

    var sortOrder: Int {
        switch self {
        case .commandPost: return 0
        case .howitzer: return 1
        case .missileTank: return 2
        case .heavyTank: return 3
        case .gev: return 4
        case .infantry: return 5
        }
    }
}

struct Unit: Identifiable, Codable {
    let id: UUID
    let type: UnitType
    let side: Side
    var position: Hex
    var status: UnitStatus
    var strength: Int
    var hasFired: Bool

    init(type: UnitType, side: Side, position: Hex, strength: Int = 1) {
        self.id = UUID()
        self.type = type
        self.side = side
        self.position = position
        self.status = .active
        self.strength = strength
        self.hasFired = false
    }

    var displayName: String {
        if type == .infantry {
            return "Infantry (\(strength))"
        }
        return type.displayName
    }

    var statusDisplay: String {
        if status == .destroyed {
            return "Destroyed"
        }
        if type == .infantry {
            return "\(strength) squads"
        }
        if status == .disabled {
            return "Disabled"
        }
        return "Active"
    }
}

enum OgreWeaponType: String, Codable {
    case mainBattery
    case secondaryBattery
    case missile
    case antipersonnel

    var displayName: String {
        switch self {
        case .mainBattery: return "Main Battery"
        case .secondaryBattery: return "Secondary Battery"
        case .missile: return "Missile"
        case .antipersonnel: return "AP"
        }
    }

    var attack: Int {
        switch self {
        case .mainBattery: return 4
        case .secondaryBattery: return 3
        case .missile: return 6
        case .antipersonnel: return 1
        }
    }

    var range: Int {
        switch self {
        case .mainBattery: return 3
        case .secondaryBattery: return 2
        case .missile: return 5
        case .antipersonnel: return 1
        }
    }

    var defense: Int {
        switch self {
        case .mainBattery: return 4
        case .secondaryBattery: return 3
        case .missile: return 3
        case .antipersonnel: return 1
        }
    }
}

struct OgreWeapon: Identifiable, Codable {
    let id: UUID
    let type: OgreWeaponType
    var status: UnitStatus
    var hasFired: Bool
    var isSelected: Bool

    init(type: OgreWeaponType) {
        self.id = UUID()
        self.type = type
        self.status = .active
        self.hasFired = false
        self.isSelected = false
    }

    var displayName: String {
        type.displayName
    }
}

struct OgreUnit: Identifiable, Codable {
    let id: UUID
    var position: Hex
    var treadsRemaining: Int
    let maxTreads: Int
    var weapons: [OgreWeapon]

    init(position: Hex) {
        self.id = UUID()
        self.position = position
        self.maxTreads = 45
        self.treadsRemaining = 45
        self.weapons = [
            OgreWeapon(type: .mainBattery),
            OgreWeapon(type: .secondaryBattery),
            OgreWeapon(type: .secondaryBattery),
            OgreWeapon(type: .secondaryBattery),
            OgreWeapon(type: .secondaryBattery),
            OgreWeapon(type: .missile),
            OgreWeapon(type: .missile),
            OgreWeapon(type: .antipersonnel),
            OgreWeapon(type: .antipersonnel),
            OgreWeapon(type: .antipersonnel),
            OgreWeapon(type: .antipersonnel),
            OgreWeapon(type: .antipersonnel),
            OgreWeapon(type: .antipersonnel),
            OgreWeapon(type: .antipersonnel),
            OgreWeapon(type: .antipersonnel)
        ]
    }

    var movement: Int {
        max(0, min(3, Int(ceil(Double(treadsRemaining) / 15.0))))
    }

    var isDestroyed: Bool {
        treadsRemaining <= 0
    }

    var targetableSystems: [OgreTargetSystem] {
        var systems: [OgreTargetSystem] = [.treads]
        for weapon in weapons where weapon.status != .destroyed {
            systems.append(.weapon(weapon))
        }
        return systems
    }
}

enum OgreTargetSystem: Identifiable {
    case treads
    case weapon(OgreWeapon)

    var id: String {
        switch self {
        case .treads: return "treads"
        case .weapon(let weapon): return weapon.id.uuidString
        }
    }

    var displayName: String {
        switch self {
        case .treads: return "Treads"
        case .weapon(let weapon): return weapon.displayName
        }
    }
}

enum CombatResult: String {
    case noEffect = "NE"
    case disabled = "D"
    case destroyed = "X"
}

struct CombatTableEntry {
    let odds: String
    let results: [Int: CombatResult]
}

struct CombatTable {
    static let entries: [CombatTableEntry] = [
        CombatTableEntry(odds: "1-2", results: [1: .noEffect, 2: .noEffect, 3: .disabled, 4: .disabled, 5: .destroyed, 6: .destroyed]),
        CombatTableEntry(odds: "1-1", results: [1: .noEffect, 2: .disabled, 3: .disabled, 4: .destroyed, 5: .destroyed, 6: .destroyed]),
        CombatTableEntry(odds: "2-1", results: [1: .disabled, 2: .disabled, 3: .destroyed, 4: .destroyed, 5: .destroyed, 6: .destroyed]),
        CombatTableEntry(odds: "3-1", results: [1: .disabled, 2: .destroyed, 3: .destroyed, 4: .destroyed, 5: .destroyed, 6: .destroyed]),
        CombatTableEntry(odds: "4-1", results: [1: .destroyed, 2: .destroyed, 3: .destroyed, 4: .destroyed, 5: .destroyed, 6: .destroyed])
    ]

    static func resolve(attack: Int, defense: Int, roll: Int) -> CombatResult {
        guard defense > 0 else { return .destroyed }
        let ratio = Double(attack) / Double(defense)
        if ratio < 0.5 {
            return .noEffect
        }
        if ratio >= 5.0 {
            return .destroyed
        }
        let column: CombatTableEntry
        if ratio >= 4.0 {
            column = entries[4]
        } else if ratio >= 3.0 {
            column = entries[3]
        } else if ratio >= 2.0 {
            column = entries[2]
        } else if ratio >= 1.0 {
            column = entries[1]
        } else {
            column = entries[0]
        }
        return column.results[roll] ?? .noEffect
    }
}
