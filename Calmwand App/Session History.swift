
import SwiftUI

// MARK: - SessionHistoryView
struct SessionHistoryView: View {
    @StateObject var sessionViewModel: SessionViewModel
    @ObservedObject var userSettingsModel: UserSettingsModel
    
    // initialize weekly goal from UserDefaults
    @State private var goal: Int = UserDefaults.standard.integer(forKey: "goal")
    @State private var showClearConfirmation = false
    
    var body: some View {
        NavigationView {
            VStack{
                WeeklyGoalCard(goal: $goal, sessionCount: sessionViewModel.sessionArray.count)
                List {
                    // Recent Sessions section
                    Section(header:
                        Text("Recent Sessions")
                            .font(.title2)
                            .bold()
                            .padding(.vertical, 4)
                    ) {
                        ForEach($sessionViewModel.sessionArray) { $session in
                            NavigationLink(destination: DetailedView(session: $session, userSettingsModel: userSettingsModel)) {
                                SessionRowView(session: session)
                            }
                        }
                        .onDelete { indexSet in
                            sessionViewModel.sessionArray.remove(atOffsets: indexSet)
                        }
                        .listRowBackground(Color.clear)
                    }
                }
                .listStyle(.grouped)
                .scrollContentBackground(.hidden)
                .navigationTitle("Session History")
                .toolbar {
                    ToolbarItemGroup(placement: .navigationBarTrailing) {
                        Button("Add Session") {
                            sessionViewModel.addSession(dur: 151,
                                                        tempC: 5,
                                                        inhale: 4.5,
                                                        exhale: 9.0,
                                                        Set: [
                                                            93.8, 93.9, 94.2, 94.5, 94.7, 94.9, 95.1, 95.2, 95.3, 95.4,
                                                            95.5, 95.6, 95.65, 95.7, 95.75, 95.8, 95.85, 95.9, 95.92, 95.95,
                                                            95.97, 96.0, 96.02, 96.04, 96.05, 96.06, 96.07, 96.08, 96.09, 96.1
                                                        ])
                        }
                        
                        Button("Refresh") {
                            sessionViewModel.updateAllSessions()
                        }
                        
                        Button(action: {
                            showClearConfirmation = true
                        }, label: {
                            Image(systemName: "trash.fill")
                        })
                    }
                }
                .alert("Delete All Sessions?", isPresented: $showClearConfirmation) {
                    Button("Delete", role: .destructive) {
                        sessionViewModel.sessionArray.removeAll()
                    }
                    Button("Cancel", role: .cancel) { }
                } message: {
                    Text("This action cannot be undone.")
                }
            }
            .applyBackgroundGradient()
        }
    }
}

// MARK: - WeeklyGoalCard
struct WeeklyGoalCard: View {
    @Binding var goal: Int
    let sessionCount: Int
    
    /// current progress
    var progress: Double {
        Double(min(sessionCount, goal)) / Double(goal)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // title
            HStack {
                Text("Weekly Session Goal")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(Color(UIColor.systemBrown))
                Spacer()
                Text("\(goal) sessions")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            // slider
            Slider(value: Binding(
                get: { Double(goal) },
                set: { newValue in
                    goal = Int(newValue)
                    UserDefaults.standard.set(goal, forKey: "goal")
                }
            ), in: 1...21, step: 1)
            .accentColor(.blue)
            
            // Progress Bar
            CustomProgressBar(progress: progress)
                .frame(height: 12)
                .padding(.vertical, 8)
            
            // Reward Animation
            if sessionCount >= goal {
                RewardAnimationView()
                    .padding(.top, 8)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 25)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.4), radius: 5, x: 0, y: 3)
        )
        .padding(.horizontal)
    }
}

// MARK: - ProgressBar
struct CustomProgressBar: View {
    var progress: Double  // 0 ~ 1
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // background track
                Capsule()
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 12)
                
                // foreground track
                Capsule()
                    .fill(LinearGradient(gradient: Gradient(colors: [Color.blue, Color.green]),
                         startPoint: .leading,
                         endPoint: .trailing))
                    .frame(width: geometry.size.width * CGFloat(progress), height: 12)
                    .animation(.spring(duration: 0.8), value: progress)
            }
        }
        .frame(height: 12)
    }
}

// MARK: - Reward Animation
struct RewardAnimationView: View {
    @State private var scale: CGFloat = 0.5
    
    var body: some View {
        Text("🎉 Goal reached!")
            .font(.title2)
            .foregroundColor(Color(UIColor.systemMint))
            .fontWeight(.bold)
            .scaleEffect(scale)
            .onAppear {
                // spring
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8, blendDuration: 0)) {
                    scale = 1.2
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.5, blendDuration: 0)) {
                        scale = 1.0
                    }
                }
            }
    }
}

// MARK: - SessionRowView
struct SessionRowView: View {
    let session: SessionModel
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: "star.fill")
                        .foregroundColor(.yellow)
                    Text("Score: \(session.score.map { String(format: "%.0f", $0) } ?? "N/A")")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.red)
                }
                
                HStack {
                    Image(systemName: "clock.fill")
                        .foregroundColor(.blue)
                    Text("Duration: \(session.duration / 60) min")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, minHeight: 80)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(UIColor.systemBackground))
                .shadow(color: Color.black.opacity(0.3), radius: 5, x: 0, y: 3)
        )
    }
}


// MARK: - DetailedView



struct DetailedView: View {
    @Binding var session: SessionModel
    @ObservedObject var userSettingsModel: UserSettingsModel
    
    @State private var isExporting = false
    @State private var csvDocument: CSVDocument = CSVDocument(text: "")

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("Hand Temperature vs. Time")
                    .font(.title)
                    .fontWeight(.bold)
                    .padding(.top, 20)
                
                      PlotView(timepassed: session.duration,
                         temperature: session.tempSetData,
                         timeStride: userSettingsModel.interval)
                    .frame(height: 300)
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 4)
                    .padding(.horizontal)
                
                HStack(spacing: 40) {
                    VStack {
                        Text("Inhale Time")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(session.inhaleTime, specifier: "%.1f") s")
                            .font(.headline)
                    }
                    
                    VStack {
                        Text("Exhale Time")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(session.exhaleTime, specifier: "%.1f") s")
                            .font(.headline)
                    }
                }
                .padding(.horizontal)
                
                if let score = session.score {
                    VStack {
                        Text("Score")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(score, specifier: "%.0f")")
                            .font(.system(size: 36, weight: .bold))
                            .foregroundColor(.red)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.secondarySystemBackground))
                            .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 2)
                    )
                    .padding(.horizontal)
                } else {
                    Text("Regression parameters not available.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.secondarySystemBackground))
                        )
                        .padding(.horizontal)
                }
                
                // Comment Textfield
                VStack(alignment: .leading, spacing: 8) {
                    Text("Comments")
                        .font(.headline)
                    PlaceholderTextEditor(text: $session.comment, placeholder: "Enter your comments here...")
                }
                .padding(.horizontal)
                .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 2)
                
                Spacer()
            }
            .padding(.bottom, 20)
        }
        .scrollDismissesKeyboard(.interactively)
        .applyBackgroundGradient()
        .toolbar(content: {
            Button {
                let csvString = generateCSV()
                csvDocument = CSVDocument(text: csvString)
                isExporting = true
            } label: {
                Label("Export CSV", systemImage: "square.and.arrow.up")
            }
        })
        .fileExporter(isPresented: $isExporting,
                      document: csvDocument,
                      contentType: .commaSeparatedText,
                      defaultFilename: "TemperatureData") { result in
            switch result {
            case .success(let url):
                print("CSV exported to: \(url)")
            case .failure(let error):
                print("Export failed: \(error.localizedDescription)")
            }
        }
    }
    
    // generate csv file
    func generateCSV() -> String {
        var csv = "Time (s),Temperature (F)\n"
        let interval = Double(userSettingsModel.interval)
        for (index, temp) in session.tempSetData.enumerated() {
            // time starts from 5
            let time = interval * Double(index + 1)
            csv += "\(time),\(temp)\n"
        }
        return csv
    }

}


struct PlaceholderTextEditor: View {
    @Binding var text: String
    let placeholder: String

    var body: some View {
        TextEditor(text: $text)
            .font(.system(.body, design: .rounded))  // rounded font
            .padding(8)
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(10)
            .overlay(
                Group {
                    if text.isEmpty {
                        Text(placeholder)
                            .foregroundColor(.gray)
                            .padding(.top, 12)
                            .padding(.leading, 16)
                    }
                },
                alignment: .topLeading
            )
            .frame(height: 150)
    }
}


#Preview {
    SessionHistoryView(sessionViewModel: SessionViewModel(), userSettingsModel: UserSettingsModel())
}



