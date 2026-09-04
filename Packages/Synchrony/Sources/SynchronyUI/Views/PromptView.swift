import SwiftUI
import SynchronyCore

struct PromptView: View {
    let coordinator: GameCoordinator

    var body: some View {
        VStack(spacing: 24) {
            header

            if let prompt = coordinator.currentPrompt {
                Text(prompt.text)
                    .font(.title2.bold())
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                Spacer()

                if coordinator.myAnswer == nil {
                    AnswerInputView(kind: prompt.kind) { answer in
                        coordinator.submitAnswer(answer)
                    }
                } else {
                    WaitingForOpponentView()
                }
            }

            Spacer()
        }
        .padding()
        .animation(.default, value: coordinator.myAnswer)
    }

    private var header: some View {
        VStack(spacing: 4) {
            Text("Ronda \(coordinator.roundNumber) de \(coordinator.totalRounds)")
                .font(.caption)
                .foregroundStyle(.secondary)
            if coordinator.connectionQuality == .degraded {
                Label("Conexión inestable", systemImage: "wifi.exclamationmark")
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }
        }
        .padding(.top)
    }
}

private struct WaitingForOpponentView: View {
    var body: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Ya respondiste. Esperando al otro jugador…")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 32)
    }
}

/// Renders the right input control for a prompt's kind, and reports the
/// chosen `AnswerValue` once the player confirms it.
private struct AnswerInputView: View {
    let kind: PromptKind
    let onAnswer: (AnswerValue) -> Void

    var body: some View {
        switch kind {
        case .numeric(let range, _):
            NumericAnswerInput(range: range, onAnswer: onAnswer)
        case .multipleChoice(let options):
            MultipleChoiceAnswerInput(options: options, onAnswer: onAnswer)
        case .freeText:
            FreeTextAnswerInput(onAnswer: onAnswer)
        case .direction:
            DirectionAnswerInput(onAnswer: onAnswer)
        }
    }
}

private struct NumericAnswerInput: View {
    let range: ClosedRange<Int>
    let onAnswer: (AnswerValue) -> Void

    @State private var value: Int

    init(range: ClosedRange<Int>, onAnswer: @escaping (AnswerValue) -> Void) {
        self.range = range
        self.onAnswer = onAnswer
        self._value = State(initialValue: (range.lowerBound + range.upperBound) / 2)
    }

    var body: some View {
        VStack(spacing: 20) {
            Text("\(value)")
                .font(.system(size: 56, weight: .bold, design: .rounded))
            Stepper("", value: $value, in: range)
                .labelsHidden()
            Button("Confirmar") { onAnswer(.number(value)) }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
        }
    }
}

private struct MultipleChoiceAnswerInput: View {
    let options: [String]
    let onAnswer: (AnswerValue) -> Void

    var body: some View {
        VStack(spacing: 12) {
            ForEach(options, id: \.self) { option in
                Button(option) { onAnswer(.choice(option)) }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 32)
    }
}

private struct FreeTextAnswerInput: View {
    let onAnswer: (AnswerValue) -> Void

    @State private var text = ""

    var body: some View {
        VStack(spacing: 16) {
            TextField("Tu respuesta", text: $text)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal, 32)
            Button("Confirmar") { onAnswer(.text(text)) }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(text.trimmingCharacters(in: .whitespaces).isEmpty)
        }
    }
}

private struct DirectionAnswerInput: View {
    let onAnswer: (AnswerValue) -> Void

    @State private var heading: Double = 0

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "location.north.fill")
                .font(.system(size: 48))
                .rotationEffect(.degrees(heading))
            Slider(value: $heading, in: 0...359)
                .padding(.horizontal, 32)
            Button("Confirmar") { onAnswer(.heading(heading)) }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
        }
    }
}

#Preview("Numérica") {
    PromptView(
        coordinator: .previewFixture(
            screen: .playing,
            prompt: Prompt(id: "p", text: "Elegí un número del 1 al 10", kind: .numeric(range: 1...10, tolerance: 1))
        )
    )
}

#Preview("Opción múltiple") {
    PromptView(coordinator: .previewFixture(screen: .playing))
}

#Preview("Esperando al otro") {
    PromptView(coordinator: .previewFixture(screen: .playing, myAnswer: .choice("Playa")))
}
