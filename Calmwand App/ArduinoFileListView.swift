import SwiftUI

struct ArduinoFileListView: View {
    @EnvironmentObject var bluetoothManager: BluetoothManager
    @Binding var isPresented: Bool
    @ObservedObject var sessionViewModel: SessionViewModel

    @State private var isImporting = false
    @State private var totalSeconds: Int = 0    // total expected seconds of session
    @State private var showDeleteAllAlert = false

    /// 1) Precompute the filtered list of “data…” entries
    private var sessionEntries: [String] {
        bluetoothManager.arduinoFileList
            .compactMap { entry in
                // 1a) Must start “data”
                guard entry.lowercased().hasPrefix("data") else { return nil }
                // 1b) Split off the “:XX” minutes piece
                let parts = entry.split(separator: ":")
                guard parts.count > 1,
                      let mins = Int(parts[1]),
                      mins >= 2                    // only 2+ minutes
                else { return nil }
                return entry
            }
    }

    var body: some View {
        NavigationView {
            VStack {
                if sessionEntries.isEmpty {
                    Text("Fetching sessions…")
                        .foregroundColor(.secondary)
                        .padding()
                }

                List(sessionEntries, id: \.self) { entry in
                    ArduinoFileRow(
                        entry: entry,
                        isImporting: $isImporting,
                        totalSeconds: $totalSeconds,
                        onDelete: { name in
                              // tell Arduino to delete
                              bluetoothManager.deleteArduinoSession(named: name)
                              // instantly remove it from *this* list:
                              bluetoothManager.arduinoFileList.removeAll { entry in
                                // drop anything whose “dataX:” prefix matches
                                entry.hasPrefix(name + ":")
                            }
                        },
                        onSelect: { name, mins in
                            guard !isImporting else { return }
                            isImporting = true
                            totalSeconds = mins * 60
                            bluetoothManager.arduinoFileContentLines.removeAll()
                            bluetoothManager.fileContentTransferCompleted = false
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                bluetoothManager.requestArduinoFile(fileName: name)
                            }
                        }
                    )
                }

                if isImporting {
                    let linesSoFar = bluetoothManager.arduinoFileContentLines.count
                    ProgressView("Importing…", value: Double(linesSoFar), total: Double(totalSeconds))
                        .padding()
                    Text("\(min(linesSoFar/60, totalSeconds/60)) of \(totalSeconds/60) min")
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
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(role: .destructive) {
                        showDeleteAllAlert = true
                    } label: {
                        Label("Delete All", systemImage: "trash")
                    }
                    .disabled(sessionEntries.isEmpty)
                }
            }
            .alert("Delete all sessions on device?", isPresented: $showDeleteAllAlert) {
                Button("Delete All", role: .destructive) {
                    bluetoothManager.deleteAllArduinoSessions()
                    bluetoothManager.arduinoFileList.removeAll()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This will permanently remove every session file from the Arduino's SD card.")
            }
            .onReceive(bluetoothManager.$fileContentTransferCompleted) { done in
                if done && isImporting {
                    importSessionFromLines()
                    isPresented = false
                    isImporting = false
                }
            }
            .onAppear {
                bluetoothManager.requestArduinoFileList()
            }
        }
    }

    /// Parses the lines, removes outliers, does regression, creates a SessionModel
    private func importSessionFromLines() {
        let rawLines = bluetoothManager.arduinoFileContentLines
        print("🔍 importSessionFromLines(): got \(rawLines.count) total lines")

        var rawTimestamps: [Double] = []
        var rawTemps:      [Double] = []

        for line in rawLines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            let parts = trimmed
                .components(separatedBy: .whitespacesAndNewlines)
                .filter { !$0.isEmpty }
            print("🔍 tokens = \(parts)")

            guard parts.count >= 2,
                  let t = Double(parts[0]),
                  let rawHundredths = Double(parts[1]) else
            {
                print("⚠️ Skipping unparseable line: '\(line)'")
                continue
            }

            rawTimestamps.append(t)
            rawTemps.append(rawHundredths / 100.0)
        }

        print("⚙️ Successfully parsed \(rawTemps.count) points")
        guard rawTimestamps.count >= 2 else {
            print("Too few points. Aborting.")
            isImporting = false
            return
        }

        // 2) Outlier removal (IQR)
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

        // 3) Convert to seconds
        let firstRaw = filteredTimes.first!
        let times = filteredTimes.map { ($0 - firstRaw) / 1000.0 }

        // 4) Duration & ΔT
        let durationSec = Int(times.last!.rounded(.down))
        let tempChange = filteredTemps.last! - filteredTemps.first!

        // 5) Exponential‐fit regression: y = A - B·e^(−k·x)
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
            sumX   += x
            sumLn  += lnD
            sumXln += x * lnD
            sumX2  += x * x
        }
        let denom = n * sumX2 - sumX * sumX
        guard denom != 0 else {
            print("Regression denom zero. Aborting.")
            isImporting = false
            return
        }
        let k   = -(n * sumXln - sumX * sumLn) / denom
        let lnB = (sumLn + k * sumX) / n
        let B   = exp(lnB)
        print("Regression: A=\(A), B=\(B), k=\(k)")

        // 6) Score
        let t = Double(durationSec)
        let predInc = B * (1 - exp(-k * t))
        let relax  = min(pow(predInc / 5.0, 0.15), 1.0)
        let speed  = min(pow(k / 0.0050, 0.15), 1.0)
        let maxScore = min((t/60)*10, 100)
        let score    = maxScore * relax * speed
        print("🎯 Score = \(score)")

        // 7) Inhale/exhale times from BLE strings
        let inh = (Double(bluetoothManager.inhaleData) ?? 0) / 1000.0
        let exh = (Double(bluetoothManager.exhaleData) ?? 0) / 1000.0

        // 8) Append
        let newSession = SessionModel(
            duration:         durationSec,
            temperatureChange: tempChange,
            tempSetData:      filteredTemps,
            inhaleTime:       inh,
            exhaleTime:       exh,
            regressionA:      A,
            regressionB:      B,
            regressionk:      k,
            score:            score
        )
        sessionViewModel.sessionArray.append(newSession)
        print("SessionViewModel now has \(sessionViewModel.sessionArray.count) sessions")

        isImporting = false
    }
}


/// A tiny row‐view so that the main body stays small enough
struct ArduinoFileRow: View {
    let entry: String
    @Binding var isImporting: Bool
    @Binding var totalSeconds: Int
    let onDelete: (String) -> Void
    let onSelect: (String, Int) -> Void

    var body: some View {
        let parts = entry.split(separator: ":")
        let name  = String(parts[0])
        let mins  = parts.count > 1 ? Int(parts[1]) ?? 0 : 0

        Button {
            onSelect(name, mins)
        } label: {
            HStack {
                Text(name)
                Spacer()
                Text("(\(mins) min)")
                    .foregroundColor(.secondary)
            }
            .contentShape(Rectangle())
        }
        .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        onDelete(name)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
    }
}

