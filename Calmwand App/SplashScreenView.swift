import SwiftUI

struct SplashScreenView: View {
    @State private var isSpinning = false

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            Image("Image")
                .resizable()
                .scaledToFit()
                .frame(width: 160, height: 160)                // adjust size
                .rotationEffect(.degrees(isSpinning ? 360 : 0))
                .animation(
                    .linear(duration: 1)                       // one full spin per second
                    .repeatForever(autoreverses: false),
                    value: isSpinning
                )
        }
        .onAppear {
            isSpinning = true
        }
    }
}
