import SwiftUI

struct ArduinoFileListView: View {
    @EnvironmentObject var bluetoothManager: BluetoothManager
    @Binding var isPresented: Bool
    @ObservedObject var sessionViewModel: SessionViewModel

    @State private var isImporting = false
    @State private var totalSeconds: Int = 0    // total expected seconds of session

    var body: some View {
        NavigationView {
            VStack {
                if bluetoothManager.arduinoFileList.isEmpty {
                    Text("Fetching sessions…")
                        .foregroundColor(.secondary)
                        .padding()
                }

                List {
                    ForEach(
                        bluetoothManager.arduinoFileList
                            .filter { $0.lowercased().hasPrefix("data") },
                        id: \.self
                    ) { entry in
                        let parts = entry.split(separator: ":")
                        let name = String(parts[0])
                        let mins = parts.count > 1 ? Int(parts[1]) ?? 0 : 0

                        Button {
                            guard !isImporting else { return }
                            isImporting = true
                            totalSeconds = mins * 60
                            bluetoothManager.arduinoFileContentLines.removeAll()
                            bluetoothManager.fileContentTransferCompleted = false
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                bluetoothManager.requestArduinoFile(fileName: name)
                            }
                        } label: {
                            HStack {
                                Text(name)
                                Spacer()
                                Text("(\(mins) min)")
                                    .foregroundColor(.secondary)
                            }
                            .contentShape(Rectangle())
                        }
                    }
                }

                if isImporting {
                    // real‐time progress bar
                    let linesSoFar = bluetoothManager.arduinoFileContentLines.count
                    ProgressView("Importing…", value: Double(linesSoFar), total: Double(totalSeconds))
                        .padding()
                    // optional text indicator
                    Text("\(min(linesSoFar / 60, totalSeconds/60)) of \(totalSeconds/60) min")
                        .font(.caption)
                        .foregroundColor(.secondary)
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
            .onReceive(bluetoothManager.$fileContentTransferCompleted) { done in
                if done && isImporting {
                    importSessionFromLines()
                    isPresented = false
                    isImporting = false
                }
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    bluetoothManager.requestArduinoFileList()
                }
            }
        }
    }

    func importSessionFromLines() {
        let rawLines = bluetoothManager.arduinoFileContentLines
            print("🔍 importSessionFromLines(): got \(rawLines.count) total lines")

            var rawTimestamps: [Double] = []
            var rawTemps:      [Double] = []

            for line in rawLines {
                // 1) Trim *all* whitespace/newlines
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)

                // 2) Split on ANY whitespace and filter out empties
                let parts = trimmed
                    .components(separatedBy: .whitespacesAndNewlines)
                    .filter { !$0.isEmpty }

                // 3) Debug-print what we actually got
                print("🔍 tokens = \(parts)")

                // 4) Must have at least two tokens
                guard parts.count >= 2 else {
                    print("⚠️ Not enough tokens to parse: \(parts)")
                    continue
                }

                // 5) Parse timestamp
                guard let t = Double(parts[0]) else {
                    print("⚠️ Could not parse timestamp: '\(parts[0])'")
                    continue
                }

                // 6) Parse raw hundredths-of-°F
                guard let rawHundredths = Double(parts[1]) else {
                    print("⚠️ Could not parse temp value: '\(parts[1])'")
                    continue
                }

                rawTimestamps.append(t)
                rawTemps.append(rawHundredths / 100.0)
            }

            print("⚙️ Successfully parsed \(rawTemps.count) points")

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

