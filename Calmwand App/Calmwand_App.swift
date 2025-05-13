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
    
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
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
    
    @State private var showSplash = true
    
    var body: some Scene {
            WindowGroup {
                ZStack {                                 // ← 1. single stacking context
                    HomeView()                           // always in background

                    if showSplash {                      // ← 2. conditional splash
                        SplashScreenView()
                            .transition(.opacity)
                            .zIndex(1)                   // keep on top
                    }
                }
                .preferredColorScheme(.light)
                .onAppear {                              // hide after ~1 s
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.05) {
                        withAnimation(.easeOut) { showSplash = false }
                    }
                }
            }
            .modelContainer(sharedModelContainer)
        }
}
