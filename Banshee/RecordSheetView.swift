import SwiftUI

struct RecordSheetView: View {
    @ObservedObject var gameState: GameState

    var body: some View {
        NavigationStack {
            List {
                Section("Ogre Status") {
                    if let ogre = gameState.ogre {
                        HStack {
                            Text("Treads")
                            Spacer()
                            Text("\(ogre.treadsRemaining)/\(ogre.maxTreads)")
                        }
                        ForEach(ogre.weapons) { weapon in
                            HStack {
                                Text(weapon.displayName)
                                Spacer()
                                Text(weapon.status.rawValue.capitalized)
                            }
                        }
                    }
                }

                Section("Defender Units") {
                    ForEach(gameState.units.sorted(by: { $0.type.sortOrder < $1.type.sortOrder })) { unit in
                        HStack {
                            Text(unit.displayName)
                            Spacer()
                            Text(unit.statusDisplay)
                        }
                    }
                }
            }
            .navigationTitle("Record Sheet")
        }
    }
}
