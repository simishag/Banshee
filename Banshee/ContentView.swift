import SwiftUI

struct RootView: View {
    @State private var showingSplash = true
    @State private var showingGame = false
    @State private var showingRules = false
    @State private var showingRecordSheet = false

    var body: some View {
        ZStack {
            if showingSplash {
                SplashView()
                    .transition(.opacity)
            } else if showingGame {
                GameView(onExit: {
                    showingGame = false
                })
                .transition(.opacity)
            } else {
                MainMenuView(
                    onStart: { showingGame = true },
                    onRules: { showingRules = true },
                    onRecordSheet: { showingRecordSheet = true }
                )
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.4), value: showingSplash)
        .animation(.easeInOut(duration: 0.4), value: showingGame)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                showingSplash = false
            }
        }
        .sheet(isPresented: $showingRules) {
            RulesView()
        }
        .sheet(isPresented: $showingRecordSheet) {
            RecordSheetView(gameState: GameState.preview)
        }
    }
}

struct MainMenuView: View {
    let onStart: () -> Void
    let onRules: () -> Void
    let onRecordSheet: () -> Void

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.08, green: 0.12, blue: 0.16), Color(red: 0.2, green: 0.22, blue: 0.24)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 20) {
                Text("Banshee")
                    .font(.system(size: 48, weight: .heavy, design: .serif))
                    .foregroundStyle(.white)
                Text("Ogre (1977) • Hot Seat")
                    .foregroundStyle(.white.opacity(0.7))

                VStack(spacing: 12) {
                    Button("Start Classic Scenario") { onStart() }
                        .buttonStyle(PrimaryButtonStyle())
                    Button("Rules Summary") { onRules() }
                        .buttonStyle(SecondaryButtonStyle())
                    Button("Record Sheet") { onRecordSheet() }
                        .buttonStyle(SecondaryButtonStyle())
                }
                .padding(.top, 12)
            }
            .padding(.horizontal, 24)
        }
    }
}

struct SplashView: View {
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 12) {
                Text("Banshee")
                    .font(.system(size: 56, weight: .black, design: .serif))
                    .foregroundStyle(.white)
                Text("Tactical Ogre Combat")
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color(red: 0.9, green: 0.3, blue: 0.2))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color.white.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
    }
}
