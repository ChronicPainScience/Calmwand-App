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
                  ) { entry in
                    // entry == "data1.txt:10"
                    let parts = entry.split(separator: ":")
                    let name = String(parts[0])
                    let mins = parts.count > 1 ? Int(parts[1]) ?? 0 : 0

                    Button(action: {
                      guard !isImporting else { return }
                      isImporting = true
                      DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        bluetoothManager.requestArduinoFile(fileName: name)
                      }
                    }) {
                      HStack {
                        Text(name)
                        Spacer()
                        Text("(\(mins) min)")
                          .foregroundColor(.secondary)
                      }
                      .contentShape(Rectangle()) // makes whole row tappable
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
                        bluetoothManager.cancelFileImport()
                        isImporting = false
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

        guard lines.count >= 2 else {
            print("Not enough lines to form a session. Aborting.")
            isImporting = false
            return
        }

        // 1) Parse & down‐sample 1/10
        var rawTimestamps: [Double] = []
        var rawTemps:      [Double] = []

        for line in bluetoothManager.arduinoFileContentLines {
            // Trim out any leading/trailing whitespace or newlines
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Now split on one or more spaces
            let parts = trimmed.split(whereSeparator: { $0.isWhitespace })
            guard parts.count >= 2 else {
                print("⚠️ Could not split line into two parts: '\(trimmed)'")
                continue
            }
            
            // Parse timestamp
            guard let t = Double(parts[0]) else {
                print("⚠️ Could not parse timestamp: '\(parts[0])'")
                continue
            }
            
            // Parse raw hundredths (also trimmed now)
            guard let rawHundredths = Double(parts[1]) else {
                print("⚠️ Could not parse temperature: '\(parts[1])'")
                continue
            }
            
            rawTimestamps.append(t)
            rawTemps.append(rawHundredths / 100.0)  // convert to °F
        }

        print("⚙️ Parsed \(rawTemps.count) points (no down-sampling)")
        guard rawTimestamps.count >= 2 else {
            print("Too few points after down‐sampling. Aborting.")
            isImporting = false
            return
        }

        // 2) Remove outliers using IQR on temperatures
        let sortedTemps = rawTemps.sorted()
        let q1 = sortedTemps[Int(Double(sortedTemps.count) * 0.25)]
        let q3 = sortedTemps[Int(Double(sortedTemps.count) * 0.75)]
        let iqr = q3 - q1
        let lowerFence = q1 - 1.5 * iqr
        let upperFence = q3 + 1.5 * iqr

        var filteredTimes: [Double] = []
        var filteredTemps: [Double] = []
        for (time, temp) in zip(rawTimestamps, rawTemps) {
            if temp >= lowerFence && temp <= upperFence {
                filteredTimes.append(time)
                filteredTemps.append(temp)
            } else {
                print("Outlier removed: time=\(time)ms, temp=\(temp)°F")
            }
        }
        print("After outlier removal: \(filteredTemps.count) points")

        guard filteredTimes.count >= 2 else {
            print("Too few points after outlier removal. Aborting.")
            isImporting = false
            return
        }

        // 3) Convert timestamps to seconds since start
        let firstRaw = filteredTimes.first!
        let times = filteredTimes.map { ($0 - firstRaw) / 1000.0 }

        // 4) Compute duration and temp change
        let durationSec = Int(times.last!.rounded(.down))
        let tempChange = filteredTemps.last! - filteredTemps.first!

        // 5) Regression (A, B, k) on (times, filteredTemps)
        let epsilon = 0.1
        let A = (filteredTemps.max() ?? 0) + epsilon
        let n = Double(filteredTemps.count)
        var sumX = 0.0, sumLn = 0.0, sumXln = 0.0, sumX2 = 0.0

        for i in 0..<filteredTemps.count {
            let x = times[i]
            let y = filteredTemps[i]
            let d = A - y
            guard d > 0 else { continue }
            let lnD = log(d)
            sumX    += x
            sumLn   += lnD
            sumXln  += x * lnD
            sumX2   += x * x
        }

        let denom = n * sumX2 - sumX * sumX
        guard denom != 0 else {
            print("Regression denominator zero. Aborting.")
            isImporting = false
            return
        }
        let k = -(n * sumXln - sumX * sumLn) / denom
        let lnB = (sumLn + k * sumX) / n
        let B = exp(lnB)
        print("Regression: A=\(A), B=\(B), k=\(k)")

        // 6) Score
        let t = Double(durationSec)
        let predInc = B * (1 - exp(-k * t))
        let relax  = min(pow(predInc / 5.0, 0.15), 1.0)
        let speed  = min(pow(k / 0.0050, 0.15), 1.0)
        let maxScore = min((t/60)*10, 100)
        let score    = maxScore * relax * speed
        print("🎯 Score = \(score)")

        // 7) Inhale/exhale times (ms→s)
        let inh = (Double(bluetoothManager.inhaleData) ?? 0) / 1000.0
        let exh = (Double(bluetoothManager.exhaleData) ?? 0) / 1000.0

        // 8) Append SessionModel
        let newSession = SessionModel(
            duration: durationSec,
            temperatureChange: tempChange,
            tempSetData: filteredTemps,
            inhaleTime: inh,
            exhaleTime: exh,
            regressionA: A,
            regressionB: B,
            regressionk: k,
            score: score
        )
        sessionViewModel.sessionArray.append(newSession)
        print("sessionViewModel now has \(sessionViewModel.sessionArray.count) sessions")

        isImporting = false
    }
}

