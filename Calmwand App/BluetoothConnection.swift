//
//  BluetoothConnection.swift
//  Calmwand App
//
//  Created by Paraparamid on 2024/10/9.
//


import SwiftUI


struct BluetoothConnectionView: View {
    @Binding var popBconnect: Bool
    
    @ObservedObject var bluetoothManager: BluetoothManager
    
    @State private var showTemperatureSheet = false

    var body: some View {
        
        NavigationView {
            VStack {
                // Display status
//                Text(bluetoothManager.statusMessage)
//                    .padding()

                if bluetoothManager.isConnecting {
                    // Display connection progress
                    ProgressView("Connecting")
                } else if bluetoothManager.isConnected {
                    // Display connection successful
                    Text("Connection Successful")
                        .onAppear{
                            popBconnect = false
                        }
//                       .onAppear {
//                           showTemperatureSheet = true
//                       }
                } else {
                    // Display nearby devices
                    List(bluetoothManager.devices, id: \.identifier) { device in
                        Button(action: {
                            bluetoothManager.connect(peripheral: device)
                        }) {
                            Text(device.name ?? "Unknown Device")
                        }
                    }
                }
            }
            .navigationBarTitle("Choose Your Device")
            .sheet(isPresented: $showTemperatureSheet) {
                TemperatureView(temperatureData: bluetoothManager.temperatureData)
            }
        }
    }


}

struct TemperatureView: View {
    var temperatureData: String

    var body: some View {
        VStack {
            let tempF: Double = (Double(temperatureData) ?? 0) / 100
            Text("Temperature Data")
                .font(.largeTitle)
                .padding()
            Text("\(String(format: "%.2f", tempF)) °F")
                .font(.title)
            
            Spacer()
        }
    }
}

