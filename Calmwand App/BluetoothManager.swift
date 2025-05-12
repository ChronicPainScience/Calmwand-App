//
//  BluetoothManager.swift
//  calmstone
//
//  Created by Paraparamid on 2024/10/7.
//

import Foundation
import CoreBluetooth

class BluetoothManager: NSObject, ObservableObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    // MARK: - Published properties
    @Published var devices: [CBPeripheral] = []
    @Published var isConnecting: Bool = false
    @Published var isConnected: Bool = false
    @Published var statusMessage: String = ""
    
    @Published var temperatureData: String = ""
    @Published var brightnessData: String = ""
    @Published var inhaleData: String = ""
    @Published var exhaleData: String = ""
    @Published var motorStrengthData: String = ""

    // CoreBluetooth
    var centralManager: CBCentralManager!
    var connectedPeripheral: CBPeripheral?

    //service UUID
    let serviceUUID = CBUUID(string: "87f23fe2-4b42-11ed-bdc3-0242ac120000")
    
    //Characteristic UUID
    let temperatureCharacteristicUUID = CBUUID(string: "87f23fe2-4b42-11ed-bdc3-0242ac12000A")
    let brightnessCharacteristicUUID = CBUUID(string: "87f23fe2-4b42-11ed-bdc3-0242ac12000B")
    let inbreathtimeCharacteristicUUID = CBUUID(string: "87f23fe2-4b42-11ed-bdc3-0242ac12000C")
    let outbreathtimeCharacteristicUUID = CBUUID(string: "87f23fe2-4b42-11ed-bdc3-0242ac12000D")
    let motorStrengthCharacteristicUUID = CBUUID(string: "87f23fe2-4b42-11ed-bdc3-0242ac12000E")



    private var brightnessCharacteristic: CBCharacteristic?
    private var temperatureCharacteristic: CBCharacteristic?
    private var inbreathtimeCharacteristic: CBCharacteristic?
    private var outbreathtimeCharacteristic: CBCharacteristic?
    private var motorStrengthCharacteristic: CBCharacteristic?


    override init() {
        super.init()
        //initializing the centralManager
        centralManager = CBCentralManager(
            delegate: self,
            queue: nil,
            options: [CBCentralManagerOptionRestoreIdentifierKey: "com.Calmwand.bluetoothRestore"]
        )
    }

    // MARK: - CBCentralManagerDelegate

    
    // centralManagerDidUpdateState is a callback function that is called when the state of CBCentralManager changed
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        // If the power is on, then start scanning for nearby devices
        if central.state == .poweredOn {
            statusMessage = "Scanning for Devices..."
            centralManager.scanForPeripherals(withServices: [serviceUUID], options: nil) // withService:[serviceUUID] will target specifically peripherals with this UUID. If deleted, it will scan all peripherals, which is inefficient
        } else {
            statusMessage = "Bluetooth NOT OPEN or UNAVALIABLE"
        }
    }

    // MARK: - Scanning
    func centralManager(_ central: CBCentralManager,
                       didDiscover peripheral: CBPeripheral,
                       advertisementData: [String: Any],
                       rssi RSSI: NSNumber ) { //signal strength
        // update list of devices
        DispatchQueue.main.async {
            if !self.devices.contains(where: { $0.identifier == peripheral.identifier }) { // use identifier to identify if the peripheral has been added
                self.devices.append(peripheral) // if not, append
            }
        }
    }
    
    // MARK: — State Restoration
      func centralManager(
        _ central: CBCentralManager,
        willRestoreState dict: [String: Any]
      ) {
        // iOS is handing back peripherals you were connected to
        if let restoredPeripherals = dict[
           CBCentralManagerRestoredStatePeripheralsKey
        ] as? [CBPeripheral] {
          restoredPeripherals.forEach { p in
            p.delegate = self
            // If you were already connected, rediscover services
            p.discoverServices([serviceUUID])
          }
        }
      }

    // when the user selects a device, this function will be called
    func connect(peripheral: CBPeripheral) {
        isConnecting = true // dispaly "Connecting"
        // stop scanning to save battery life
        centralManager.stopScan()

        connectedPeripheral = peripheral
        connectedPeripheral?.delegate = self
        centralManager.connect(peripheral, options: nil) //connect action
    }

    // Once the connection is successful, this function will be called
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        isConnecting = false
        isConnected = true
        statusMessage = "Connected to \(peripheral.name ?? "Unknown")"

        // Find the service using its specific UUID
        peripheral.discoverServices([serviceUUID])
    }

    // if the connection failed, this function will be called
    func centralManager(_ central: CBCentralManager,
                       didFailToConnect peripheral: CBPeripheral,
                       error: Error?) {
        statusMessage = "Connection failed"
        isConnecting = false
        isConnected = false
    }

    // If the connection was lost, this function will be called
    func centralManager(_ central: CBCentralManager,
                       didDisconnectPeripheral peripheral: CBPeripheral,
                       error: Error?) {
        statusMessage = "Disconnected"
        isConnected = false
        isConnecting = false
        // rescaning devices
        centralManager.scanForPeripherals(withServices: [serviceUUID], options: nil)
    }

    // MARK: - CBPeripheralDelegate

    // if peripheral.didDiscoverSerives is called, this function will be called
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let services = peripheral.services {
            for service in services where service.uuid == serviceUUID {
                // Find characteristics
                peripheral.discoverCharacteristics([temperatureCharacteristicUUID,
                                                    brightnessCharacteristicUUID,
                                                    inbreathtimeCharacteristicUUID,
                                                    outbreathtimeCharacteristicUUID,
                                                    motorStrengthCharacteristicUUID],
                                                   for: service)
            }
        }
    }
    
    // seek characteristic
    func peripheral(_ peripheral: CBPeripheral,
                    didDiscoverCharacteristicsFor service: CBService,
                    error: Error?) {
        guard let characteristics = service.characteristics else { return }

        for characteristic in characteristics {
            switch characteristic.uuid {
            
            // — Temperature: subscribe to notifications —
            case temperatureCharacteristicUUID:
                self.temperatureCharacteristic = characteristic
                peripheral.setNotifyValue(true, for: characteristic)
            
            // — Brightness: just read once —
            case brightnessCharacteristicUUID:
                self.brightnessCharacteristic = characteristic
                peripheral.readValue(for: characteristic)
            
            // — Inhale time: just read once —
            case inbreathtimeCharacteristicUUID:
                self.inbreathtimeCharacteristic = characteristic
                peripheral.readValue(for: characteristic)
            
            // — Exhale time: just read once —
            case outbreathtimeCharacteristicUUID:
                self.outbreathtimeCharacteristic = characteristic
                peripheral.readValue(for: characteristic)
            
            // — Motor strength: just read once —
            case motorStrengthCharacteristicUUID:
                self.motorStrengthCharacteristic = characteristic
                peripheral.readValue(for: characteristic)
            
            default:
                break
            }
        }
    }


    
    // if the received value changed, this functin will be called
    func peripheral(_ peripheral: CBPeripheral,
                      didUpdateValueFor characteristic: CBCharacteristic,
                      error: Error?) {
          // if the characteristic is from temperatureCharacteristicUUID
          if characteristic.uuid == temperatureCharacteristicUUID {
              if let tempdata = characteristic.value,
                 let tempString = String(data: tempdata, encoding: .utf8) {
                  DispatchQueue.main.async {
                      self.temperatureData = tempString
                  }
              }
          }
          // if the characteristic is from brightnessCharacteristicUUID
          else if characteristic.uuid == brightnessCharacteristicUUID {
              if let brightnessdata = characteristic.value,
                 let brightString = String(data: brightnessdata, encoding: .utf8) {
                  DispatchQueue.main.async {
                      self.brightnessData = brightString
                  }
              }
          }
          else if characteristic.uuid == inbreathtimeCharacteristicUUID {
              if let inhaledata = characteristic.value,
                 let inhaleString = String(data: inhaledata, encoding: .utf8) {
                  DispatchQueue.main.async {
                      self.inhaleData = inhaleString
                  }
              }
          }
          else if characteristic.uuid == outbreathtimeCharacteristicUUID {
              if let exhaledata = characteristic.value,
                 let exhaleString = String(data: exhaledata, encoding: .utf8) {
                  DispatchQueue.main.async {
                      self.exhaleData = exhaleString
                  }
              }
          }
          else if characteristic.uuid == motorStrengthCharacteristicUUID {
              if let motorData = characteristic.value,
                 let motorString = String(data: motorData, encoding: .utf8) {
                  DispatchQueue.main.async {
                      self.motorStrengthData = motorString
                  }
              }
          }
    }

    // MARK: - sending values to arduino

    // send brightness value
    func writeBrightness(_ brightness: String) {
        guard let peripheral = connectedPeripheral,
              let characteristic = brightnessCharacteristic
        else {
            print("No connected peripheral or characteristic to write.")
            return
        }
        
        let dataToSend = Data(brightness.utf8)
        peripheral.writeValue(dataToSend, for: characteristic, type: .withResponse)
        print("Sent brightness = \(brightness)")
    }
    
    
    func writeInhaleTime(_ inhaleTime: String) {
        guard let peripheral = connectedPeripheral,
              let characteristic = inbreathtimeCharacteristic
        else {
            print("No connected peripheral or characteristic to write.")
            return
        }
        
        let dataToSend = Data(inhaleTime.utf8)
        peripheral.writeValue(dataToSend, for: characteristic, type: .withResponse)
        print("Sent inhale time = \(inhaleTime)")
    }
    
    
    func writeExhaleTime(_ exhaleTime: String) {
        guard let peripheral = connectedPeripheral,
              let characteristic = outbreathtimeCharacteristic
        else {
            print("No connected peripheral or characteristic to write.")
            return
        }
        
        let dataToSend = Data(exhaleTime.utf8)
        peripheral.writeValue(dataToSend, for: characteristic, type: .withResponse)
        print("Sent exhale time = \(exhaleTime)")
    }
    
    
    func writeMotorStrength(_ strength: String) {
        guard let peripheral = connectedPeripheral,
              let characteristic = motorStrengthCharacteristic
        else {
            print("No connected peripheral or motorStrengthCharacteristic to write.")
            return
        }
        
        let dataToSend = Data(strength.utf8)
        peripheral.writeValue(dataToSend, for: characteristic, type: .withResponse)
        print("Sent motor strength = \(strength)")
    }

}

