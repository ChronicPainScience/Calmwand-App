import SwiftUI

struct TenMinuteTimerView: View {
    /// Time elapsed in seconds.
    let timeElapsed: Int
    
    /// Total duration for a full cycle: 10 minutes = 600 seconds.
    private let totalDuration: Double = 600
    
    /// Number of complete 10‑minute cycles.
    private var fullCycles: Int {
        timeElapsed / 600
    }
    
    /// Fraction (0.0–1.0) of the current cycle that has elapsed.
    private var fraction: Double {
        Double(timeElapsed % 600) / totalDuration
    }
    
    // Define two alternating gradients (or you can use different color shades)
    var gradientEven: AngularGradient {
            AngularGradient(
                gradient: Gradient(colors: [Color.blue, Color.purple]),
                center: .center,
                startAngle: .degrees(-90),
                endAngle: .degrees(270)
            )
        }
        
        var gradientOdd: AngularGradient {
            AngularGradient(
                gradient: Gradient(colors: [Color.green, Color.teal]),
                center: .center,
                startAngle: .degrees(-90),
                endAngle: .degrees(270)
            )
        }
    
    var body: some View {
        ZStack {
            // Background track.
            Circle()
                .stroke(Color.gray.opacity(0.3), lineWidth: 10)
                .frame(width: 200, height: 200)
            
            // Draw complete cycles.
            ForEach(0..<fullCycles, id: \.self) { cycle in
                Circle()
                    .stroke(
                        cycle % 2 == 0 ? gradientEven : gradientOdd,
                        lineWidth: 10
                    )
                    .frame(width: 200, height: 200)
            }
            
            // Draw the current (partial) cycle as an arc.
            // Use a Path to create an arc from -90° to (-90 + fraction * 360°).
            let startAngle = Angle.degrees(-90)
            let endAngle = Angle.degrees(-90 + fraction * 360)
            let currentGradient = fullCycles % 2 == 0 ? gradientEven : gradientOdd
            
            Path { path in
                path.addArc(center: CGPoint(x: 100, y: 100),
                            radius: 100,
                            startAngle: startAngle,
                            endAngle: endAngle,
                            clockwise: false)
            }
            .stroke(currentGradient, style: StrokeStyle(lineWidth: 10, lineCap: .round))
            .frame(width: 200, height: 200)
            .animation(.linear, value: fraction)
            
            // Center label: shows full minutes elapsed.
            Text("\(timeElapsed / 60) min")
                .font(.system(size: 40, weight: .bold, design: .monospaced))
                .foregroundColor(.primary)
        }
        .padding()
    }
}

struct TenMinuteTimerView_Previews: PreviewProvider {
    static var previews: some View {
        // Preview example: 750 seconds elapsed equals 12 minutes and 30 seconds.
        TenMinuteTimerView(timeElapsed: 620)
    }
}

