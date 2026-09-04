import SwiftUI
import SynchronyPersistence

struct HistoryView: View {
    let coordinator: GameCoordinator

    var body: some View {
        NavigationStack {
            Group {
                if coordinator.history.isEmpty {
                    ContentUnavailableView(
                        "Todavía no jugaste ninguna partida",
                        systemImage: "clock",
                        description: Text("Cuando termines una partida, va a aparecer acá.")
                    )
                } else {
                    List {
                        Section {
                            StatisticsSummary(statistics: coordinator.historyStatistics)
                        }
                        Section("Partidas") {
                            ForEach(coordinator.history) { record in
                                MatchRow(record: record)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Historial")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { coordinator.returnHome() }
                }
            }
        }
    }
}

private struct StatisticsSummary: View {
    let statistics: MatchHistoryStatistics

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Partidas jugadas")
                Spacer()
                Text("\(statistics.matchCount)")
                    .foregroundStyle(.secondary)
            }
            HStack {
                Text("Sincronía promedio")
                Spacer()
                Text("\(Int(statistics.averageSyncPercentage))%")
                    .foregroundStyle(.secondary)
            }
            if let best = statistics.bestSyncPercentage {
                HStack {
                    Text("Mejor partida")
                    Spacer()
                    Text("\(Int(best))%")
                        .foregroundStyle(.secondary)
                }
            }
            HStack {
                Text("Tendencia")
                Spacer()
                Text(trendText)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var trendText: LocalizedStringKey {
        switch statistics.recentTrend {
        case .improving: "Mejorando ↗︎"
        case .declining: "Bajando ↘︎"
        case .steady: "Estable →"
        case .notEnoughData: "Necesitás más partidas"
        }
    }
}

private struct MatchRow: View {
    let record: MatchRecord

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(record.playedAt, style: .date)
                Text("\(record.roundCount) rondas")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text("\(Int(record.syncPercentage))%")
                .font(.headline)
        }
    }
}

#Preview("Con historial") {
    HistoryView(coordinator: .previewInstanceWithHistory())
}

#Preview("Vacío") {
    HistoryView(coordinator: .previewInstance())
}
