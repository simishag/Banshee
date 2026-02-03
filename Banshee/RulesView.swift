import SwiftUI

struct RulesView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Ogre (1977) Quick Rules")
                    .font(.title2)

                Group {
                    Text("Turn Sequence")
                        .font(.headline)
                    Text("1. Ogre moves")
                    Text("2. Ogre fires")
                    Text("3. Defender repairs disabled armor")
                    Text("4. Defender moves")
                    Text("5. Defender fires")
                    Text("6. GEVs move their second (3-hex) move")
                }

                Group {
                    Text("Combat")
                        .font(.headline)
                    Text("Combine any number of attacks into one attack, except against Ogre treads. Odds round down in the defender’s favor.")
                    Text("CRT results: X destroys, D disables (infantry loses 1 strength; armor becomes disabled; disabled armor destroyed).")
                    Text("Attacks against Ogre treads are always 1-1; an X destroys treads equal to attack strength.")
                }

                Group {
                    Text("Movement")
                        .font(.headline)
                    Text("Units may not enter craters; ridges block movement across hexsides. Armor may ram an Ogre by moving into its hex, destroying the rammer and reducing Ogre treads by 1.")
                    Text("Infantry stacks 1-3 squads in one hex; other units may not stack.")
                }

                Group {
                    Text("Victory")
                        .font(.headline)
                    Text("Ogre wins by destroying the Command Post. Defender wins by stopping the Ogre (destroying its treads or overall unit).")
                }
            }
            .padding(20)
        }
    }
}
