import SwiftUI

struct MatchSummaryView: View {
    let coordinator: GameCoordinator

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            Text("Partida terminada")
                .font(.title.bold())

            VStack(spacing: 4) {
                Text("\(Int(coordinator.finalSyncPercentage))%")
                    .font(.system(size: 72, weight: .bold, design: .rounded))
                    .foregroundStyle(.tint)
                Text("de sincronía")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(spacing: 16) {
                Button("Jugar de nuevo") {
                    coordinator.returnHome()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button("Ver historial") {
                    coordinator.showHistory()
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
            .padding(.horizontal, 32)
            .padding(.bottom)
        }
        .padding()
    }
}

#Preview {
    MatchSummaryView(coordinator: .previewFixture(screen: .summary, finalSyncPercentage: 80))
}
