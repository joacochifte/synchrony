import SwiftUI

/// Top-level screen switcher, driven entirely by `GameCoordinator.screen`.
/// This is the one piece of `SynchronyUI` the app target actually mounts.
public struct GameRootView: View {
    private let coordinator: GameCoordinator

    public init(coordinator: GameCoordinator) {
        self.coordinator = coordinator
    }

    public var body: some View {
        Group {
            switch coordinator.screen {
            case .home:
                HomeView(coordinator: coordinator)
            case .pairing:
                PairingView(coordinator: coordinator)
            case .playing:
                PromptView(coordinator: coordinator)
            case .revealing:
                RevealView(coordinator: coordinator)
            case .summary:
                MatchSummaryView(coordinator: coordinator)
            case .history:
                HistoryView(coordinator: coordinator)
            }
        }
        .animation(.default, value: coordinator.screen)
    }
}
