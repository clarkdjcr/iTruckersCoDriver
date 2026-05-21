//
//  ELDBridge.swift
//  iTruckersCoDriver
//
//  Created by Antigravity on 5/19/26.
//

import Foundation
import Combine
import CoreBluetooth

class ELDBridge: NSObject, ObservableObject {
    @Published var isConnected = false
    @Published var discoveredPeripherals: [CBPeripheral] = []
    
    private var centralManager: CBCentralManager!
    private var eldPeripheral: CBPeripheral?
    
    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }
    
    func startScanning() {
        guard centralManager.state == .poweredOn else { return }
        centralManager.scanForPeripherals(withServices: nil, options: nil)
    }
    
    func connect(to peripheral: CBPeripheral) {
        eldPeripheral = peripheral
        centralManager.connect(peripheral, options: nil)
    }
}

extension ELDBridge: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn {
            print("🔋 BLE Powered On")
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        if !discoveredPeripherals.contains(peripheral) {
            discoveredPeripherals.append(peripheral)
        }
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        isConnected = true
        peripheral.delegate = self
        peripheral.discoverServices(nil)
    }
}

extension ELDBridge: CBPeripheralDelegate {
    // Implement service/characteristic discovery for J1939/OBD-II data
}
