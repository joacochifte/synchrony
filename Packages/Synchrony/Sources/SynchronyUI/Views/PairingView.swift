import SwiftUI
import SynchronyTransport

struct PairingView: View {
    let coordinator: GameCoordinator

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            ProgressView()
                .controlSize(.large)

            Text(statusText)
                .font(.title3)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            if coordinator.role == .host {
                Text("Esperando a que el otro jugador se una desde la misma red.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            Spacer()

            Button("Cancelar") {
                coordinator.returnHome()
            }
            .padding(.bottom)
        }
        .padding()
    }

    private var statusText: String {
        switch coordinator.connectionState {
        case .notConnected, .connecting:
            coordinator.role == .host ? "Creando partida…" : "Buscando partida…"
        case .connected:
            "¡Conectados! Arrancando…"
        case .disconnected:
            "Se perdió la conexión."
        }
    }
}

#Preview("Buscando") {
    PairingView(coordinator: .previewFixture(screen: .pairing, role: .peer))
}

#Preview("Sesión real sobre InMemoryTransport") {
    PairingView(coordinator: .previewLiveSession())
}
