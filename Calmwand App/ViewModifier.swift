//
//  ViewModifier.swift
//  Calmwand App
//
//  Created by Paraparamid on 2025/2/4.
//

import SwiftUI



struct BackgroundGradient: ViewModifier {
    func body(content: Content) -> some View {
        ZStack {
            LinearGradient(gradient: Gradient(colors: [Color.blue.opacity(0.25), Color.white]),
                           startPoint: .top,
                           endPoint: .bottom)
                .edgesIgnoringSafeArea(.all)
            
            content
        }
    }
}

extension View {
    
    func applyBackgroundGradient() -> some View {
        self.modifier(BackgroundGradient())
    }
    
    func cardStyle() -> some View {
        self
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(UIColor.systemBackground))
                    .shadow(color: Color.black.opacity(0.3), radius: 5, x: 0, y: 3)
            )
            .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 3)
            .padding(.horizontal)
    }
}
