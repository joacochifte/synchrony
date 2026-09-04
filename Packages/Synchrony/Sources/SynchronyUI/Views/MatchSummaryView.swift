import SwiftUI

struct MatchSummaryView: View {
    let coordinator: GameCoordinator

    @State private var hasAppeared = false

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            Text("Partida terminada")
                .font(.title.bold())

            VStack(spacing: 4) {
                Text("\(Int(coordinator.finalSyncPercentage))%")
                    .font(.system(.largeTitle, design: .rounded).weight(.bold))
                    .foregroundStyle(.tint)
                Text("de sincronía")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)
            .scaleEffect(hasAppeared ? 1 : 0.7)
            .opacity(hasAppeared ? 1 : 0)
            .onAppear {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.65)) {
                    hasAppeared = true
                }
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
