import SwiftUI
import SpriteKit

struct GameView: View {
    @StateObject private var gameState = GameState()
    @State private var showRecordSheet = false
    @State private var showRules = false
    @State private var hudCollapsed = false

    let onExit: () -> Void

    var body: some View {
        ZStack {
            SpriteKitContainerView(scene: gameState.scene)
                .ignoresSafeArea()

            VStack {
                if hudCollapsed {
                    HStack {
                        Button("Show HUD") { hudCollapsed = false }
                            .buttonStyle(CompactButtonStyle())
                        Spacer()
                        Button("Exit") { onExit() }
                            .buttonStyle(CompactButtonStyle())
                    }
                    .padding(10)
                    .background(Color.black.opacity(0.35))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                } else {
                    GameHUDView(gameState: gameState, onExit: onExit, onCollapse: { hudCollapsed = true })
                }
                Spacer()
                HStack {
                    Button("Record Sheet") { showRecordSheet = true }
                        .buttonStyle(CompactButtonStyle())
                    Button("Rules") { showRules = true }
                        .buttonStyle(CompactButtonStyle())
                }
            }
            .padding(12)
        }
        .sheet(isPresented: $showRecordSheet) {
            RecordSheetView(gameState: gameState)
        }
        .sheet(isPresented: $showRules) {
            RulesView()
        }
    }
}

struct GameHUDView: View {
    @ObservedObject var gameState: GameState
    let onExit: () -> Void
    let onCollapse: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(gameState.turnNumber == 0 ? "Setup" : "Turn \(gameState.turnNumber)")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text(gameState.phase.title)
                        .foregroundStyle(.white.opacity(0.8))
                }
                Spacer()
                HStack(spacing: 8) {
                    Button("Hide") { onCollapse() }
                        .buttonStyle(CompactButtonStyle())
                    Button("Exit") { onExit() }
                        .buttonStyle(CompactButtonStyle())
                }
            }

            if let hint = gameState.phaseHint {
                Text(hint)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.9))
                    .padding(.horizontal, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if let log = gameState.lastCombatLog {
                Text(log)
                    .font(.caption)
                    .foregroundStyle(.white)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.black.opacity(0.4))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }

            HStack(spacing: 8) {
                Button("End Phase") {
                    gameState.advancePhase()
                }
                .buttonStyle(PrimaryButtonStyle())

                Button("Clear") {
                    gameState.clearSelection()
                }
                .buttonStyle(SecondaryButtonStyle())
            }
            .frame(maxWidth: .infinity)

            if gameState.phase.isFirePhase, let target = gameState.pendingOgreTarget {
                OgreTargetPicker(gameState: gameState, target: target)
            }

            if gameState.phase.isFirePhase, let ogre = gameState.ogreSelection {
                OgreWeaponPicker(gameState: gameState, ogre: ogre)
            }
        }
        .padding(12)
        .background(Color.black.opacity(0.35))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

struct OgreWeaponPicker: View {
    @ObservedObject var gameState: GameState
    let ogre: OgreUnit

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Select Ogre weapons")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.8))
            ForEach(ogre.weapons) { weapon in
                Button {
                    gameState.toggleOgreWeapon(weaponID: weapon.id)
                } label: {
                    HStack {
                        Text(weapon.displayName)
                        Spacer()
                        Text(weapon.status == .destroyed ? "X" : (weapon.isSelected ? "•" : ""))
                    }
                }
                .buttonStyle(SecondaryButtonStyle())
                .disabled(weapon.status == .destroyed || weapon.hasFired)
            }
        }
    }
}

struct OgreTargetPicker: View {
    @ObservedObject var gameState: GameState
    let target: OgreUnit

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Target Ogre system")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.8))
            ForEach(target.targetableSystems) { system in
                Button(system.displayName) {
                    gameState.selectOgreTarget(system)
                }
                .buttonStyle(SecondaryButtonStyle())
            }
            Button("Cancel") { gameState.pendingOgreTarget = nil }
                .buttonStyle(SecondaryButtonStyle())
        }
    }
}

struct CompactButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.caption)
            .foregroundStyle(.white)
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(Color.black.opacity(0.45))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
    }
}
