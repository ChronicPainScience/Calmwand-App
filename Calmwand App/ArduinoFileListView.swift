import SwiftUI

struct ArduinoFileListView: View {
    @EnvironmentObject var bluetoothManager: BluetoothManager
    @Binding var isPresented: Bool
    @ObservedObject var sessionViewModel: SessionViewModel

    @State private var isImporting = false

    var body: some View {
        NavigationView {
            VStack {
                if bluetoothManager.arduinoFileList.isEmpty {
                    Text("Fetching sessions from Arduino…")
                        .foregroundColor(.secondary)
                        .padding()
                }

                List {
                    ForEach(
                        bluetoothManager.arduinoFileList
                            .filter { $0.lowercased().hasPrefix("data") },
                        id: \.self
                    ) { filename in
                        Button(action: {
                            guard !isImporting else { return }
                            isImporting = true

                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                print("Requesting file '\(filename)' from Arduino…")
                                bluetoothManager.requestArduinoFile(fileName: filename)
                            }
                        }) {
                            Text(filename)
                                .foregroundColor(.primary)
                        }
                    }
                }

                if isImporting {
                    Text("Importing… \(bluetoothManager.arduinoFileContentLines.count) lines received")
                        .padding()
                }
            }
            .navigationTitle("Arduino SD Sessions")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
            }
            .onReceive(bluetoothManager.$fileContentTransferCompleted) { finished in
                if finished && isImporting {
                    importSessionFromLines()
                    isPresented = false
                }
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    print("Requesting file list from Arduino…")
                    bluetoothManager.requestArduinoFileList()
                }
            }
        }
    }

    func importSessionFromLines() {
        let lines = bluetoothManager.arduinoFileContentLines
        print("importSessionFromLines(): \(lines.count) total lines")

        // We need at least two data points
        guard lines.count >= 2 else {
            print("Not enough lines to form a session (need ≥2). Aborting import.")
            isImporting = false
            return
        }

        // Parse each line into (timestamp, temp), then down‐sample 1/10
        var rawTimestamps: [Double] = []
        var rawTemps: [Double] = []
        for (i, line) in lines.enumerated() {
            // Only import 1 out of 10 lines
            guard i % 10 == 0 else { continue }

            let parts = line.split(separator: " ")
            if parts.count >= 2,
               let t = Double(parts[0]),
               let temp = Double(parts[1])
            {
                rawTimestamps.append(t)
                rawTemps.append(temp)
            } else {
                print("Could not parse line: '\(line)'")
            }
        }
        print("⚙️ After down‐sampling: \(rawTimestamps.count) timestamps, \(rawTemps.count) temps")

        // Must still have ≥2 points after down‐sampling
        guard rawTimestamps.count >= 2 else {
            print("Too few points after down‐sampling. Aborting.")
            isImporting = false
            return
        }

        // Build “timeSinceStart” in seconds
        let firstRaw = rawTimestamps.first!
        let times: [Double] = rawTimestamps.map { ($0 - firstRaw) / 1000.0 }

        // Duration in seconds (last timeSinceStart)
        let durationSec = Int(times.last!.rounded(.down))
        let tempChange = rawTemps.last! - rawTemps.first!

        // Regression parameters (A, B, k) using (times, rawTemps)
        let epsilon = 0.1
        let A = (rawTemps.max() ?? 0) + epsilon
        let n = Double(rawTemps.count)
        var sumX = 0.0, sumLnAminusY = 0.0, sumX_LnAminusY = 0.0, sumXSquare = 0.0
        for i in 0..<rawTemps.count {
            let x = times[i]
            let y = rawTemps[i]
            let AminusY = A - y
            guard AminusY > 0 else { continue }
            let lnAminusY = log(AminusY)
            sumX += x
            sumLnAminusY += lnAminusY
            sumX_LnAminusY += x * lnAminusY
            sumXSquare += x * x
        }
        let denominator = n * sumXSquare - sumX * sumX
        guard denominator != 0 else {
            print("Denominator zero; regression failed.")
            isImporting = false
            return
        }
        let k = -(n * sumX_LnAminusY - sumX * sumLnAminusY) / denominator
        let lnB = (sumLnAminusY + k * sumX) / n
        let B = exp(lnB)

        print("Regression: A=\(A), B=\(B), k=\(k)")

        // Compute score
        let t = Double(durationSec)
        let predictedIncrease = B * (1 - exp(-k * t))
        let relaxFactor = min(pow(predictedIncrease / 5.0, 0.15), 1.0)
        let speedFactor = min(pow(k / 0.0050, 0.15), 1.0)
        let sessionMinutes = t / 60.0
        let maxScore = min(sessionMinutes * 10, 100)
        let score = maxScore * relaxFactor * speedFactor

        print("Score = \(score)")

        // Inhale/exhale (ms → s)
        let inhaleSeconds = (Double(bluetoothManager.inhaleData) ?? 0) / 1000.0
        let exhaleSeconds = (Double(bluetoothManager.exhaleData) ?? 0) / 1000.0

        // Create and append session
        let newSession = SessionModel(
            duration: durationSec,
            temperatureChange: tempChange,
            tempSetData: rawTemps,
            inhaleTime: inhaleSeconds,
            exhaleTime: exhaleSeconds,
            regressionA: A,
            regressionB: B,
            regressionk: k,
            score: score
        )
        sessionViewModel.sessionArray.append(newSession)
        print("sessionViewModel.sessionArray now \(sessionViewModel.sessionArray.count) items")

        isImporting = false
    }
}

