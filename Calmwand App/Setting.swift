//
//  Profile.swift
//  Calmwand App
//
//  Created by Paraparamid on 2024/9/10.
//


import SwiftUI
import PDFKit


// MARK: - SettingView
struct SettingView: View {
    @ObservedObject var userSettingsModel: UserSettingsModel
    @ObservedObject var bluetoothManager: BluetoothManager
    
    @State private var inhaleThrottleWorkItem: DispatchWorkItem?
    @State private var exhaleThrottleWorkItem: DispatchWorkItem?
    
    @State var brightness: Float = 130
    @State var inhaleTime: Float = 4.5
    @State var exhaleTime: Float = 9.0
    @State var motorStrength: Float = 180
    
    @State private var showEgg: Bool = false
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    NavigationLink(destination: InfoView()) {
                                            HStack(spacing: 12) {
                                                Image(systemName: "info.circle")
                                                    .font(.system(size: 24))
                                                    .foregroundColor(.blue)
                                                Text("Contact & About")
                                                    .font(.headline)
                                            }
                                            .padding(.vertical, 8)
                                            .onLongPressGesture(minimumDuration: 3.0) {
                                                    withAnimation { showEgg.toggle() }          // showEgg is a @State Bool
                                                }
                                        }
                    .sheet(isPresented: $showEgg) {
                        VStack(spacing: 20) {
                            Text("Hello!")
                                .font(.title)
                                .bold()
                            Text("""
                            🪄  Congratulations, traveler!  
                            You’ve just uncovered the **Super-Secret Calmwand Credits Screen**.

                            This entire app was hand-crafted by **Niketh**:
                            • Besties with Claude  
                            • Code Whisperer  
                            • Professional Yerba Mate Consumer  
                            • World-Record Holder for Longest Breath Held 
                              While Waiting for Xcode to Re-index 
                              (unverified)

                            Fun facts:
                            🫧  Lines of Swift written: \(Int.random(in: 5_000...9_999)) 
                            👌🏻  Lines of Swift properly commented: 0
                            🪄  Bugs intentionally left so future archaeologists have something to do: 3.14  
                            🐛  Actual bugs squashed during development: 3 (2 on the keyboard, 1 inside the calmwand?!)  
                            🧘‍♂️  Deep breaths taken to stay calm during Bluetooth debugging: …lost count.

                            Remember: if at first you don’t succeed, inhale for 4 s, exhale for 8 s, and try turning it off and on again.

                            Thank you for exploring Calmwand!  
                            Now exhale… close this screen and go away.
                            """)
                            .font(.caption.monospaced())            // fun tiny console-style text
                            .multilineTextAlignment(.leading)
                            .padding()
                            //Text("Version \(Bundle.main.versionString) (\(Bundle.main.buildNumber))")
                                .font(.caption)
                            Spacer()
                        }
                        .padding()
                    }
                   /* NavigationLink(destination: AccountView()) {
                        HStack(spacing: 12) {
                            Image(systemName: "person.crop.circle")
                                .font(.system(size: 24))
                                .foregroundColor(.blue)
                            Text("Account")
                                .font(.headline)
                        }
                        .padding(.vertical, 8)
                    }
                    
                    NavigationLink(destination: CalmingMethodView()) {
                        HStack(spacing: 12) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 24))
                                .foregroundColor(.purple)
                            Text("Calming Method Description")
                                .font(.headline)
                        }
                        .padding(.vertical, 8)
                    }
                    
                    NavigationLink(destination: InstructionView()) {
                        HStack(spacing: 12) {
                            Image(systemName: "info.circle")
                                .font(.system(size: 24))
                                .foregroundColor(.green)
                            Text("CalmWand Instruction")
                                .font(.headline)
                        }
                        .padding(.vertical, 8)
                    } */
                    
                    // Future function
//                    Toggle(isOn: $userSettingsModel.isCelcius) {
//                        HStack(spacing: 12) {
//                            Image(systemName: "thermometer")
//                                .font(.system(size: 24))
//                                .foregroundColor(.red)
//                            Text("Use Celsius")
//                                .font(.headline)
//                        }
//                    }
//                    .padding(.vertical, 8)
                }
                .listRowBackground(Color.clear)
                
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "sun.max")
                                .foregroundColor(.yellow)
                            Text("Brightness: \(Int(brightness))")
                                .font(.subheadline)
                        }
                        Slider(value: $brightness, in: 0...255, step: 1) { isEditing in
                            if !isEditing {
                                bluetoothManager.writeBrightness(String(format: "%.0f", brightness))
                            }
                        }
                    }
                    .cardStyle()
                    .onAppear {
                        brightness = Float(bluetoothManager.brightnessData) ?? 130
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Stepper(value: $inhaleTime, in: 2.0...15.0, step: 0.5) {
                            HStack {
                                Image(systemName: "arrow.up.circle")
                                    .foregroundColor(.blue)
                                Text("Inhale Time: \(String(format: "%.1f", inhaleTime)) s")
                                    .font(.subheadline)
                            }
                        }
                        .onChange(of: inhaleTime) {

                            inhaleThrottleWorkItem?.cancel()

                            inhaleThrottleWorkItem = DispatchWorkItem {
                                bluetoothManager.writeInhaleTime(String(format: "%.0f", inhaleTime * 1000))
                            }
                        
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: inhaleThrottleWorkItem!)
                        }
                        
                        Stepper(value: $exhaleTime, in: 2.0...15.0, step: 0.5) {
                            HStack {
                                Image(systemName: "arrow.down.circle")
                                    .foregroundColor(.orange)
                                Text("Exhale Time: \(String(format: "%.1f", exhaleTime)) s")
                                    .font(.subheadline)
                            }
                        }
                        .onChange(of: exhaleTime) {
                            exhaleThrottleWorkItem?.cancel()

                            exhaleThrottleWorkItem = DispatchWorkItem {
                                bluetoothManager.writeExhaleTime(String(format: "%.0f", exhaleTime * 1000))
                            }
                        
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: exhaleThrottleWorkItem!)
                        }
                    }
                    .cardStyle()
                    .onAppear {
                        inhaleTime = (Float(bluetoothManager.inhaleData) ?? 4000) / 1000
                        exhaleTime = (Float(bluetoothManager.exhaleData) ?? 9500) / 1000
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "gearshape")
                                .foregroundColor(.gray)
                            Text("Motor Intensity: \(Int(motorStrength))")
                                .font(.subheadline)
                        }
                        Slider(value: $motorStrength, in: 0...255, step: 1) { isEditing in
                            if !isEditing {
                                bluetoothManager.writeMotorStrength(String(format: "%.0f", motorStrength))
                            }
                        }
                    }
                    .cardStyle()
                    .onAppear {
                        motorStrength = Float(bluetoothManager.motorStrengthData) ?? 255
                    }
                }
                .listRowBackground(Color.clear)
            }
            .listStyle(.grouped)
            .scrollContentBackground(.hidden)
            .applyBackgroundGradient()
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.automatic)
            
        }
        .onAppear {
                    OrientationLock.mask = .portrait
                    requestOrientationUpdate(.portrait)
                }
    }
}

// MARK: - Other views

struct AccountView: View {
    var body: some View {
        VStack {
            Text("Account")
                .font(.largeTitle)
                .bold()
        }
        .applyBackgroundGradient()
        .navigationTitle("Account")
    }
}

struct CalmingMethodView: View {
    var body: some View {
        VStack {
            Text("Calming Method Description")
                .font(.title)
                .bold()
        }
        .applyBackgroundGradient()
        .navigationTitle("Calming Method")
    }
}


struct PDFViewerView: UIViewRepresentable {
    let pdfURL: URL
    
    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.document = PDFDocument(url: pdfURL)
        pdfView.autoScales = true  // scaling
        pdfView.displayMode = .singlePageContinuous  // scroll view
        pdfView.displayDirection = .vertical  // vertical scroll
        pdfView.backgroundColor = .white  // background color
        
        // scaling
        pdfView.minScaleFactor = 1.0
        pdfView.maxScaleFactor = 4.0
        pdfView.autoScales = true
        pdfView.isUserInteractionEnabled = true  // interactions
        
        return pdfView
    }
    
    func updateUIView(_ pdfView: PDFView, context: Context) {}
}


struct InstructionView: View {
    var body: some View {
        VStack {
            if let pdfURL = Bundle.main.url(forResource: "How to Use CalmWand (1)", withExtension: "pdf") {
                PDFViewerView(pdfURL: pdfURL)
                    .edgesIgnoringSafeArea(.all)
            } else {
                Text("Failed to load PDF")
                    .foregroundColor(.red)
            }
        }
        .navigationTitle("CalmWand Instruction")
        .navigationBarTitleDisplayMode(.inline)
        .applyBackgroundGradient()
    }
}


#Preview {
    SettingView(userSettingsModel: UserSettingsModel(), bluetoothManager: BluetoothManager())
}
