import SwiftUI
import SwiftData



struct HomeView: View {
    
    @State private var showDisclaimer: Bool = !UserDefaults.standard.bool(forKey: "didAcceptDisclaimer")
    
    @StateObject var sessionViewModel = SessionViewModel()
    @StateObject var userSettingsModel = UserSettingsModel()
    @StateObject var bluetoothManager = BluetoothManager()
    
    var body: some View {
        TabView {
            SessionSummary(bluetoothManager: bluetoothManager, sessionViewModel: sessionViewModel, userSettingsModel: userSettingsModel)
                .tabItem {
                    Label("Session Summary", systemImage: "trophy.fill")
                }
            
            SessionHistoryView(sessionViewModel: sessionViewModel, userSettingsModel: userSettingsModel)
                .tabItem {
                    Label("Session History", systemImage: "chart.line.uptrend.xyaxis")
                }
            
            SettingView(userSettingsModel: userSettingsModel, bluetoothManager: bluetoothManager)
                .tabItem {
                    Label("Settings", systemImage: "person.crop.circle")
                }
            // NEW: Info tab directly accessible from HomeView
            InfoView()
                .tabItem {
                    Label("Info", systemImage: "info.circle")
                }
        }
        .applyBackgroundGradient()
        .onAppear {
            // Disable idle timer when the view appears
            UIApplication.shared.isIdleTimerDisabled = true
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                    // Reapply the idle timer disable setting when the app becomes active
            UIApplication.shared.isIdleTimerDisabled = true
        }
        // Present disclaimer when app opened, close after and doesn't show again
        .fullScreenCover(isPresented: $showDisclaimer) {
                    DisclaimerView(isPresented: $showDisclaimer)
                }
    }
}


#Preview {
    HomeView()
        .modelContainer(for: Item.self, inMemory: true)
}

