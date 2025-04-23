

import SwiftUI
import Charts

struct DataPoint: Identifiable {
    let id = UUID()
    let x: Double
    let y: Double
}
struct ScatterPlotView: View {
    let data: [DataPoint]
    let yMin: Double
    let yMax: Double

    private var regressionParameters: (A: Double, B: Double, k: Double) {
        // A = y + ε
        let epsilon = 0.1
        let A = (data.map { $0.y }.max() ?? 0) + epsilon

        // intialize some useful varaibles
        var sumX = 0.0
        var sumLnAminusY = 0.0
        var sumX_LnAminusY = 0.0
        var sumXSquare = 0.0
        let n = Double(data.count)

        for point in data {
            let AminusY = A - point.y
            // ensure A - y > 0
            guard AminusY > 0 else { continue }
            let lnAminusY = log(AminusY)            //calculate ln(A-y) >> y'
            sumX += point.x                         //calculate sum(x)
            sumLnAminusY += lnAminusY               //calculate sum(ln(A-y)) >> sum(y')
            sumX_LnAminusY += point.x * lnAminusY   //calculate sum(x·ln(A-y)) >> sum(x·y')
            sumXSquare += point.x * point.x         //calculate sum(x^2)
        }

        let denominator = n * sumXSquare - sumX * sumX //calculate denominator = n·sum(x^2)- (sumx)^2
        let k = -(n * sumX_LnAminusY - sumX * sumLnAminusY) / denominator
        let lnB = (sumLnAminusY + k * sumX) / n
        let B = exp(lnB)

        return (A, B, k)
    }
    
    private var regressionData: [DataPoint] {
        let xMin = data.map { $0.x }.min() ?? 0
        let xMax = data.map { $0.x }.max() ?? 0
        let xValues: [Double]
        if xMin == xMax {
            xValues = [xMin]
        } else {
            xValues = stride(from: xMin, through: xMax, by: (xMax - xMin) / 100).map { $0 }
        }
        //let xValues = stride(from: xMin, through: xMax, by: (xMax - xMin) / 100)
        
        return xValues.map { x in
            let y = regressionParameters.A - regressionParameters.B * exp(-regressionParameters.k * x)
            return DataPoint(x: x, y: y)
        }
    }
    

    var body: some View {
        VStack {
            Chart {
                // Plot the original data points
                ForEach(data) { point in
                    PointMark(
                        x: .value("Time (s)", point.x),
                        y: .value("Temperature (°F)", point.y)
                    )
                }
                
                // Plot the exponential regression curve
                ForEach(regressionData) { point in
                    LineMark(
                        x: .value("Time (s)", point.x),
                        y: .value("Temperature (°F)", point.y)
                    )
                    .foregroundStyle(.red)
                }
            }
            .chartXAxisLabel("Time (s)")
            .chartYAxisLabel("Temperature (°F)")
            .chartYScale(domain: yMin...yMax)
            .frame(height: 300)
            .padding(.horizontal, 20)
            
            // Text("y = \(String(format: "%.4f", regressionParameters.A)) - \(String(format: "%.4f", regressionParameters.B)) × exp(-\(String(format: "%.4f", regressionParameters.k)) x)")
                // .font(.subheadline)
                // .foregroundColor(.gray)
        }
    }
}


struct PlotView: View {
    let timepassed: Int
    var time: [Double]
    let temperature: [Double]
    let timeStride: Int

    init(timepassed: Int, temperature: [Double], timeStride: Int) {
        self.timepassed = timepassed
        self.time = stride(from: timeStride, through: timepassed, by: timeStride).map { Double($0) }
        self.temperature = temperature
        self.timeStride = timeStride
    }

    var body: some View {
        
        let dataPoints = zip(time, temperature).map { DataPoint(x: $0, y: $1) }
        ScatterPlotView(data: dataPoints, yMin: temperature.min() ?? 0, yMax: temperature.max() ?? 98.6)
    }
}



#Preview {
    PlotView(timepassed: 150, temperature: [
        93.8, 93.9, 94.2, 94.5, 94.7, 94.9, 95.1, 95.2, 95.3, 95.4,
        95.5, 95.6, 95.65, 95.7, 95.75, 95.8, 95.85, 95.9, 95.92, 95.95,
        95.97, 96.0, 96.02, 96.04, 96.05, 96.06, 96.07, 96.08, 96.09, 96.1
    ], timeStride: 5)
}

