//
//  SynchronyApp.swift
//  Synchrony
//
//  Created by Joaquin Chifteian on 3/9/26.
//

import SwiftData
import SwiftUI

import SynchronyPersistence
import SynchronyUI

@main
struct SynchronyApp: App {
    private let modelContainer: ModelContainer
    private let coordinator: GameCoordinator

    init() {
        // A local, on-device store crashing at launch means something is
        // seriously wrong with the schema — there's no sensible fallback
        // to run the app in that state.
        // swiftlint:disable:next force_try
        let modelContainer = try! ModelContainer.makeSynchronyContainer()
        self.modelContainer = modelContainer
        self.coordinator = GameCoordinator(
            repository: MatchHistoryRepository(container: modelContainer)
        )
    }

    var body: some Scene {
        WindowGroup {
            GameRootView(coordinator: coordinator)
        }
    }
}
