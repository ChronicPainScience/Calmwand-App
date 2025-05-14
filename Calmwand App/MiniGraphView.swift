import SwiftUI

/// Draws a simple polyline with X/Y axes, no grid or markers.
struct MiniGraphView: View {
    let data: [Double]
    
    var body: some View {
        GeometryReader { geo in
            let minY = data.min() ?? 0
            let maxY = data.max() ?? (minY + 1)
            let range = maxY - minY
            
            ZStack {
                // 1) AXES
                Path { p in
                    // X-axis
                    p.move(to: CGPoint(x: 0, y: geo.size.height))
                    p.addLine(to: CGPoint(x: geo.size.width, y: geo.size.height))
                    // Y-axis
                    p.move(to: CGPoint(x: 0, y: 0))
                    p.addLine(to: CGPoint(x: 0, y: geo.size.height))
                }
                .stroke(Color.gray, lineWidth: 1)
                
                // 2) POLYLINE
                Path { p in
                    guard data.count > 1 else { return }
                    for idx in data.indices {
                        let x = geo.size.width * CGFloat(idx) / CGFloat(data.count - 1)
                        let yNorm = (data[idx] - minY) / range
                        let y = geo.size.height * (1 - CGFloat(yNorm))
                        if idx == 0 {
                            p.move(to: CGPoint(x: x, y: y))
                        } else {
                            p.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                }
                .stroke(Color.gray, lineWidth: 2)
            }
        }
    }
}
