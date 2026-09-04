import SwiftUI

#if canImport(UIKit)
    import UIKit
#endif

struct HomeView: View {
    let coordinator: GameCoordinator

    @State private var displayName = ""

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            VStack(spacing: 8) {
                Text("Synchrony")
                    .font(.largeTitle.bold())
                Text("¿Qué tan sincronizados están?")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }

            if let errorMessage = coordinator.errorMessage {
                Text(errorMessage)
                    .font(.callout)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            VStack(spacing: 16) {
                Button {
                    coordinator.hostGame(displayName: displayName)
                } label: {
                    Label("Crear partida", systemImage: "antenna.radiowaves.left.and.right")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button {
                    coordinator.joinGame(displayName: displayName)
                } label: {
                    Label("Unirse a una partida", systemImage: "person.2")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
            .padding(.horizontal, 32)

            Button("Ver historial") {
                coordinator.showHistory()
            }
            .font(.callout)

            Spacer()
        }
        .padding()
        .task {
            displayName = PlayerDisplayName.fromCurrentDevice
        }
    }
}

/// A minimal display-name source that avoids pulling in a whole profile
/// screen for Phase 8 — the device's own name is a reasonable default a
/// player can already recognize.
enum PlayerDisplayName {
    @MainActor
    static var fromCurrentDevice: String {
        #if canImport(UIKit)
            return UIDevice.current.name
        #else
            return "Jugador"
        #endif
    }
}

#Preview {
    HomeView(coordinator: GameCoordinator.previewInstance())
}
