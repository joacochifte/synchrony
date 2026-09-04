import SwiftUI
import SynchronyCore

struct RevealView: View {
    let coordinator: GameCoordinator

    @State private var hasAppeared = false

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            if let prompt = coordinator.currentPrompt {
                Text(prompt.text)
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 32)
            }

            HStack(spacing: 24) {
                AnswerBubble(title: "Vos", answer: coordinator.myAnswer)
                AnswerBubble(title: "El otro", answer: coordinator.opponentAnswer)
            }
            .scaleEffect(hasAppeared ? 1 : 0.8)
            .opacity(hasAppeared ? 1 : 0)

            if let synced = coordinator.lastRoundSynced {
                Label(
                    synced ? "¡Sincronizados!" : "No coincidieron",
                    systemImage: synced ? "checkmark.circle.fill" : "xmark.circle"
                )
                .font(.title2.bold())
                .foregroundStyle(synced ? .green : .red)
                .scaleEffect(hasAppeared ? 1 : 0.5)
                .opacity(hasAppeared ? 1 : 0)
                .accessibilityLabel(synced ? Text("Sincronizados") : Text("No coincidieron"))
            }

            Spacer()
        }
        .padding()
        .onAppear {
            // The reveal is the emotional beat of the round, so it earns a
            // small spring rather than just appearing flat.
            withAnimation(.spring(response: 0.45, dampingFraction: 0.65)) {
                hasAppeared = true
            }
        }
    }
}

private struct AnswerBubble: View {
    let title: LocalizedStringKey
    let answer: AnswerValue?

    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(displayText)
                .font(.title3.bold())
                .multilineTextAlignment(.center)
                .padding()
                .frame(minWidth: 100, minHeight: 60)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
        }
        .accessibilityElement(children: .combine)
    }

    private var displayText: String {
        switch answer {
        case .number(let value): "\(value)"
        case .choice(let value): value
        case .text(let value): value
        case .heading(let value): "\(Int(value))°"
        case nil: "—"
        }
    }
}

#Preview("Sincronizados") {
    RevealView(
        coordinator: .previewFixture(
            screen: .revealing,
            myAnswer: .choice("Playa"),
            opponentAnswer: .choice("Playa"),
            lastRoundSynced: true
        )
    )
}

#Preview("No coincidieron") {
    RevealView(
        coordinator: .previewFixture(
            screen: .revealing,
            myAnswer: .choice("Playa"),
            opponentAnswer: .choice("Montaña"),
            lastRoundSynced: false
        )
    )
}
