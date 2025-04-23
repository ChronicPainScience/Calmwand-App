import SwiftUI
import UIKit

struct SessionSummary: View {
    
    @ObservedObject var bluetoothManager: BluetoothManager
    @ObservedObject var sessionViewModel: SessionViewModel
    @StateObject var currentSessionModel = CurrentSessionModel()
    @ObservedObject var userSettingsModel: UserSettingsModel
    
    @State var popBthconnect: Bool = false
    @State private var isSessionActive = false
    @State private var timer: Timer? // timer
    
    @State var sessionStatus: String = "Start Session"
    @State var buttonImageName: String = "play.circle"
    
    @State private var sessionCompleted: Bool = false
    @State private var lastScore: Double? = nil
    
    
    // connect -> connected button
    var connectionLabel: String {
            if bluetoothManager.isConnected      { return "CONNECTED"  }
            if bluetoothManager.isConnecting     { return "CONNECTING" }
            return "CONNECT"
        }

    func startSession() {
        isSessionActive = true
        sessionCompleted = false
        lastScore = nil
        currentSessionModel.temperatureSet.removeAll()
        currentSessionModel.timeElapsed = 0
        
        let generator = UIImpactFeedbackGenerator(style: .soft)
                generator.impactOccurred()
        
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            currentSessionModel.timeElapsed += 1
            
            // every userSettingsModel.interval s, record temperature data
            if currentSessionModel.timeElapsed % userSettingsModel.interval == 0 {
                let currentTemperature = (Double(bluetoothManager.temperatureData) ?? 0) / 100
                currentSessionModel.temperatureSet.append(currentTemperature)
            }
        }
    }
    
    func endSession() {
        isSessionActive = false
        timer?.invalidate()
        timer = nil
        
        let generator = UIImpactFeedbackGenerator(style: .rigid)
                generator.impactOccurred()
    }
    
    func formattedTime() -> String {
        let minutes = currentSessionModel.timeElapsed / 60
        let seconds = currentSessionModel.timeElapsed % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    func calculateTemperatureChange(tempSet: [Double]) -> Double {
        guard let firstTemp = tempSet.first, let lastTemp = tempSet.last else { return 0 }
        return lastTemp - firstTemp
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                // bluetooth Connection button
                Button(action: {
                    popBthconnect.toggle()
                }) {
                    Text(connectionLabel)
                        .font(.headline)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.white.opacity(0.8))
                        )
                        .foregroundColor(.blue)
                        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
                        .padding(.horizontal)
                }
                .padding(.top, 50)
                .sheet(isPresented: $popBthconnect) {
                    BluetoothConnectionView(popBconnect: $popBthconnect,
                                              bluetoothManager: bluetoothManager)
                }
                
                Spacer()
                
                // Main Screen
                if isSessionActive {
                    TenMinuteTimerView(timeElapsed: currentSessionModel.timeElapsed)
                        .transition(.scale)
                } else if sessionCompleted {
                    SessionResultView(score: lastScore, sessionDuration: currentSessionModel.timeElapsed)
                        .transition(.opacity)
                } else {
                    Text("Press 'Start Session' to begin")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // start/end button
                Button(action: {
                    withAnimation(.spring()) {
                        if isSessionActive {

                            endSession()
                            
                            let tempChange = calculateTemperatureChange(tempSet: currentSessionModel.temperatureSet)
                            let currentInhaleTime = (Double(bluetoothManager.inhaleData) ?? 4000) / 1000
                            let currentExhaleTime = (Double(bluetoothManager.exhaleData) ?? 9500) / 1000
                            
                            sessionViewModel.addSession(
                                dur: currentSessionModel.timeElapsed,
                                tempC: tempChange,
                                inhale: currentInhaleTime,
                                exhale: currentExhaleTime,
                                Set: currentSessionModel.temperatureSet)
                            
                            // lastest session score
                            if let lastSession = sessionViewModel.sessionArray.last {
                                lastScore = lastSession.score
                            }
                            
                            sessionStatus = "Start Session"
                            buttonImageName = "play.circle"
                            sessionCompleted = true
                        } else {
                            startSession()
                            sessionStatus = "End Session"
                            buttonImageName = "pause.circle"
                        }
                    }
                }) {
                    HStack {
                        Image(systemName: buttonImageName)
                            .font(.system(size: 20))
                        Text(sessionStatus.uppercased())
                            .font(.headline)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white.opacity(0.8))
                    )
                    .foregroundColor(.blue)
                    .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
                    .padding(.horizontal)
                }
                
                // developer purposes
                // NavigationLink {
                   // SessionRecordView(currentSessionModel: currentSessionModel,
                                     // bluetoothManager: bluetoothManager,
                                     // userSettingsModel: userSettingsModel)
                //} label: {
                 //   HStack {
                    //    Image(systemName: "clock.arrow.trianglehead.counterclockwise.rotate.90")
                      //      .font(.system(size: 20))
                     //   Text("Session Progress".uppercased())
                     //       .font(.caption)
                  //  }
                  //  .bold()
                  //  .foregroundColor(.gray)
               // }
               // .padding(.bottom, 20)
            }
            .applyBackgroundGradient()
        }
    }
}


struct ElegantTimerView: View {
    let time: String
    
    var body: some View {
        ZStack {
            Circle()
                .trim(from: 0, to: 1)
                .stroke(
                    AngularGradient(gradient: Gradient(colors: [Color.blue, Color.purple, Color.blue]),
                                    center: .center),
                    style: StrokeStyle(lineWidth: 8, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .frame(width: 200, height: 200)
                .shadow(color: Color.purple.opacity(0.4), radius: 10, x: 0, y: 5)
            
            Text(time)
                .font(.system(size: 40, weight: .bold, design: .monospaced))
                .foregroundColor(.primary)
                .shadow(radius: 2)
        }
        .padding()
    }
}


struct AnimatedCircularProgressView: View {
    let score: Double   // score range 0 - 100
    @State private var animatedProgress: CGFloat = 0.0
    
    var body: some View {
        let progress = min(max(CGFloat(score / 100.0), 0.0), 1.0)
        
        return ZStack {
            // Grey circle ring (bottom)
            Circle()
                .stroke(Color.gray.opacity(0.2), lineWidth: 20)
                .shadow(radius: 5)
            
            // colourful circle ring (foreground)
            Circle()
                .trim(from: 0, to: animatedProgress)
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: gradientColors(for: score)),
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 20, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 1.2), value: animatedProgress)
            
            // Score in the middle
            VStack {
                Text(String(format: "%.0f", score))
                    .font(.system(size: 55, weight: .heavy, design: .rounded))
                    .foregroundColor(gradientColors(for: score).last ?? .primary)
                    .shadow(color: Color.black.opacity(0.2), radius: 3, x: 2, y: 2)
                
                Text("SCORE")
                    .font(.headline)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
            }
        }
        .frame(width: 200, height: 200)
        .onAppear {
            animatedProgress = progress
        }
    }
    
    // color changed according to the score
    private func gradientColors(for score: Double) -> [Color] {
        if score <= 50 {
            return [Color.red, Color.orange]
        } else if score <= 80 {
            return [Color.orange, Color.yellow]
        } else {
            return [Color.green, Color.blue]
        }
    }
}

struct SessionResultView: View {
    let score: Double?
    let sessionDuration: Int
    
    var body: some View {
        VStack(spacing: 25) {
            if let score = score {
                VStack(spacing: 8) {
                    Text(feedbackMessage(for: score))
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(feedbackColor(for: score))
                        .padding(.horizontal)
                    
                    RoundedRectangle(cornerRadius: 10)
                        .fill(feedbackColor(for: score).opacity(0.1))
                        .frame(width: 150, height: 5)
                }
                
                AnimatedCircularProgressView(score: score)
                    .padding()
                
                VStack(spacing: 6) {
                    Text("Your session score is \(String(format: "%.0f", score))")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text("Session Duration: \(sessionDuration / 60) min")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("Keep up the great work!")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 10)
            } else {
                Text("Session data unavailable")
                    .font(.headline)
                    .foregroundColor(.red)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(UIColor.systemBackground))
                .shadow(radius: 10)
        )
        .padding(.horizontal)
    }
    
    private func feedbackMessage(for score: Double) -> String {
        switch score {
        case ...50:
            return "Keep going!"
        case ...80:
            return "Nice job!"
        default:
            return "Congratulations!"
        }
    }
    
    private func feedbackColor(for score: Double) -> Color {
        switch score {
        case ...50:
            return .red
        case ...80:
            return .orange
        default:
            return .green
        }
    }
}

// developer purposes
struct SessionRecordView: View {
    @ObservedObject var currentSessionModel: CurrentSessionModel
    @ObservedObject var bluetoothManager: BluetoothManager
    @ObservedObject var userSettingsModel: UserSettingsModel
    
    var body: some View {
        List {
            NavigationLink("Real Time Temperature Data") {
                TemperatureView(temperatureData: bluetoothManager.temperatureData)
            }
            NavigationLink("List of Recorded Temperatures") {
                ListTempView(currentSessionModel: currentSessionModel)
            }
            NavigationLink("Temperature vs. Time Plot") {
                PlotView(timepassed: currentSessionModel.timeElapsed,
                         temperature: currentSessionModel.temperatureSet,
                         timeStride: userSettingsModel.interval)
            }
        }
        .navigationTitle("Session Record")
        .navigationBarTitleDisplayMode(.inline)
    }
}


struct ListTempView: View {
    @ObservedObject var currentSessionModel: CurrentSessionModel
    
    var body: some View {
        List(currentSessionModel.temperatureSet, id: \.self) { temperature in
            Text(String(format: "%.2f", temperature))
        }
    }
}

#Preview {
    SessionSummary(bluetoothManager: BluetoothManager(),
                   sessionViewModel: SessionViewModel(),
                   userSettingsModel: UserSettingsModel())
}

