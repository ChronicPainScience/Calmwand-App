// SplashScreenView.swift
import SwiftUI

struct SplashScreenView: View {
    @State private var progress = 0.0          // 0 → 1
    
    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()
            
            ProgressView(value: progress)
                .progressViewStyle(.linear)                    // slim bar
                .tint(.blue)                                   // optional colour
                .frame(width: 220)
                .environment(\.layoutDirection, .leftToRight)  // ← key line
        }
        .onAppear {
            withAnimation(.linear(duration: 1.0)) {
                progress = 1.0                                 // fills in ~1 s
            }
        }
    }
}

