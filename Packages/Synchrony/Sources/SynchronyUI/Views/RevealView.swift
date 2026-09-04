import SwiftUI
import SynchronyCore

struct RevealView: View {
    let coordinator: GameCoordinator

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

            if let synced = coordinator.lastRoundSynced {
                Label(
                    synced ? "¡Sincronizados!" : "No coincidieron",
                    systemImage: synced ? "checkmark.circle.fill" : "xmark.circle"
                )
                .font(.title2.bold())
                .foregroundStyle(synced ? .green : .red)
            }

            Spacer()
        }
        .padding()
    }
}

private struct AnswerBubble: View {
    let title: String
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
