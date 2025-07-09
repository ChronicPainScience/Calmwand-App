import SwiftUI

struct ArduinoFileListView: View {
    @EnvironmentObject var bluetoothManager: BluetoothManager
    @Binding var isPresented: Bool
    @ObservedObject var sessionViewModel: SessionViewModel

    @State private var isImporting = false
    @State private var totalSeconds: Int = 0    // total expected seconds of session
    @State private var showDeleteAllAlert = false
    
    @State private var pendingSessionNumber: Int? = nil
    
    @State private var importQueue: [(sessionNumber: Int,
                                      filename: String,
                                      minutes: Int)] = []
    @State private var currentImportIndex: Int = 0        // progress through the queue
    
    private var existingIds: Set<Int> {
        Set(sessionViewModel.sessionArray.map { $0.sessionNumber })
    }

    /// 1) Precompute the filtered list of “data…” entries
    private var sessionEntries: [(sessionNumber: Int, filename: String, minutes: Int)] {
      // parse and drop any malformed / too‐short:
        let tuples = bluetoothManager.arduinoFileList.compactMap { raw -> (Int, String, Int)? in
            let comps = raw.components(separatedBy: ":")          // "42:DATA42.TXT:12"
            guard
                comps.count >= 3,
                let sid  = Int(comps[0]),                         // numeric session id
                !existingIds.contains(sid),
                let mins = Int(comps[2]),
                mins >= 2,
                comps[1].lowercased().hasPrefix("data")
            else { return nil }

            return (sid, comps[1], mins)                          // (42, "DATA42.TXT", 12)
        }

      // dedupe by filename (last one wins):
      var dict = [Int:(String,Int)]()               // key = sid
        for (sid, name, mins) in tuples {
            dict[sid] = (name, mins)                  // last one wins if duplicate
        }

        return dict
            .sorted { $0.key < $1.key }               // sort by sessionNumber
            .map { (sessionNumber: $0.key,
                    filename:       $0.value.0,
                    minutes:        $0.value.1) }
    }

    var body: some View {
      NavigationView {
        VStack {
          if sessionEntries.isEmpty {
            Text("Fetching sessions…")
              .foregroundColor(.secondary)
              .padding()
          }

            List(sessionEntries, id: \.sessionNumber) { entry in
            HStack {
              // when you tap the filename row:
              Button {
                guard !isImporting else { return }
                isImporting = true
                totalSeconds = entry.minutes * 60
                bluetoothManager.arduinoFileContentLines.removeAll()
                bluetoothManager.fileContentTransferCompleted = false
                
                  pendingSessionNumber = Int(
                      entry.filename
                          .dropFirst(4)      // strip “data”
                          .dropLast(4)       // strip “.txt”
                  )
                  
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                  bluetoothManager.requestArduinoFile(fileName: entry.filename)
                }
              } label: {
                HStack {
                  Text(entry.filename)    // now “DATA48.TXT”
                  Spacer()
                  Text("(\(entry.minutes) min)")
                    .foregroundColor(.secondary)
                }
                .contentShape(Rectangle())
              }

              // swipe to delete
              .swipeActions(edge: .trailing) {
                Button(role: .destructive) {
                  bluetoothManager.deleteArduinoSession(named: entry.filename)
                  // remove locally any raw that began with that filename + “:”
                  bluetoothManager.arduinoFileList.removeAll {
                    $0.hasPrefix(entry.filename + ":")
                  }
                } label: {
                  Label("Delete", systemImage: "trash")
                }
              }
            }
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
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    // Build a queue of every *remaining* file
                    importQueue = sessionEntries                      // already filtered
                    currentImportIndex = 0
                    startNextQueuedImport()
                } label: {
                    Label("Import All", systemImage: "tray.and.arrow.down.fill")
                }
                .disabled(sessionEntries.isEmpty || isImporting)      // grey out if nothing to do
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
            guard done, isImporting else { return }

            if let num = pendingSessionNumber {
                importSessionFromLines(sessionNumber: num)
            }

            // move to next file in queue (if any)
            currentImportIndex += 1
            isImporting = false
            startNextQueuedImport()              // recurse to the next file
        }        .onAppear {
          bluetoothManager.requestArduinoFileList()
        }
      }
    }
    /// Parses the lines, removes outliers, does regression, creates a SessionModel
    private func importSessionFromLines(sessionNumber: Int) {
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
        
        let kAbs = abs(k)
        
        let newSession = SessionModel(
            sessionNumber: sessionNumber,
            duration:         durationSec,
            temperatureChange: tempChange,
            tempSetData:      filteredTemps,
            inhaleTime:       inh,
            exhaleTime:       exh,
            regressionA:      A,
            regressionB:      B,
            regressionk:      kAbs,
            score:            score
        )
        if !sessionViewModel.sessionArray.contains(where: { $0.sessionNumber == sessionNumber }) {
            sessionViewModel.sessionArray.append(newSession)
        }
        print("SessionViewModel now has \(sessionViewModel.sessionArray.count) sessions")

        isImporting = false
    }
    private func startNextQueuedImport() {
        guard currentImportIndex < importQueue.count else {
            importQueue.removeAll()                // finished
            return
        }

        let entry = importQueue[currentImportIndex]

        isImporting  = true
        totalSeconds = entry.minutes * 60
        pendingSessionNumber = entry.sessionNumber   // use sid directly

        bluetoothManager.arduinoFileContentLines.removeAll()
        bluetoothManager.fileContentTransferCompleted = false

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            bluetoothManager.requestArduinoFile(fileName: entry.filename)
        }
    }
}

// 1) Define a little helper type
struct ArduinoSessionEntry: Identifiable {
  let id: Int        // sessionId
  let filename: String
  let minutes: Int

  // Conform to Identifiable
  var identity: String { "\(id)-\(filename)" }
  var identifiableID: String { identity }
}


/// A tiny row‐view so that the main body stays small enough
struct ArduinoFileRow: View {
    let entry: String
    @Binding var isImporting: Bool
    @Binding var totalSeconds: Int
    let onDelete: (String) -> Void
    let onSelect: (String, Int) -> Void

    var body: some View {
        // Split "dataX:YY" into name and minutes
        let parts = entry.split(separator: ":")
        let name = String(parts[0])
        let mins = parts.count > 1 ? Int(parts[1]) ?? 0 : 0

        Button {
            guard !isImporting else { return }
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
        .disabled(isImporting)
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                onDelete(name)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}
