//
//  Calmwand_AppApp.swift
//  Calmwand App
//
//  Created by Paraparamid on 2024/9/3.
//

import SwiftUI
import SwiftData

@main
struct Calmwand_App: App {
    init() {
            // Disable the idle timer so the screen doesn't auto-lock
            UIApplication.shared.isIdleTimerDisabled = true
        }
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()
    
    var body: some Scene {
        WindowGroup {
            HomeView()
                .preferredColorScheme(.light)
        }
        .modelContainer(sharedModelContainer)
    }
}
