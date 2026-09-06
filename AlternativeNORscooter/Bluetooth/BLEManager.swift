//
//  BLEManager.swift
//  AlternativeNORscooter
//
//  Created by rosenberg on 19.6.2026.
//

import CoreBluetooth
import Observation
import os

enum BLEIDs {
    static let service = CBUUID(string: "0000ffe0-0000-1000-8000-00805f9b34fb")
    static let CHARACTERISTIC_UUID = CBUUID(string: "0000ffe1-0000-1000-8000-00805f9b34fb")
    static let CLIENT_CONFIG_DESCRIPTOR_UUID = CBUUID(string: "00002902-0000-1000-8000-00805f9b34fb")
}

@Observable
final class BLEManager: NSObject {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            logger.debug("Bluetooth powered on")
            isBluetoothPoweredOn = true
            startScan()
            centralManager.scanForPeripherals(withServices: [BLEIDs.service])
        case .poweredOff:
            isBluetoothPoweredOn = false
        default:
            logger.debug("Bluetooth not powered on")
        }
    }

    var isConnected = false
    var isBluetoothPoweredOn: Bool = false
    var isNotificationEnabled: Bool = false
    var isScanning = false
    
    var onNotificationStreamEstablished: (() -> Void)?

    var devices: [Scooter] = []

    struct Scooter: Identifiable, Hashable {
        let id: UUID
        let name: String
        let rssi: Int
    }

    private var centralManager: CBCentralManager!
    var peripheral: CBPeripheral?
    
    private var logger: Logger = Logger()

    var mainCharacteristic: CBCharacteristic?
    var clientConfigurationDescriptor: CBDescriptor?
    var serviceCharacteristic: CBCharacteristic?

    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }
    
    func startScan() {
        centralManager.scanForPeripherals(withServices: [BLEIDs.service])
        isScanning = true
    }
    
    func stopScan() {
        isScanning = false
        logger.debug("BLEManager - Stopping scan")
        centralManager.stopScan()
    }
    
    func connect(to device: Scooter) {
        guard let p = centralManager.retrievePeripherals(withIdentifiers: [device.id]).first else {
            logger.error("BLEManager.connect - Could not find peripheral")
           return
        }
        
        logger.debug("Connecting to \(device.name)")
        
        peripheral = p
        p.delegate = self
        centralManager.connect(p, options: nil)
        isConnected = true
        stopScan()
    }
    
    func disconnect(from p: CBPeripheral) {
        guard let p = centralManager.retrievePeripherals(withIdentifiers: [p.identifier]).first else {
            logger.error("BLEManager.connect - Could not find peripheral")
           return
        }
        logger.debug("disconnecting from \(p.identifier)")
        
        peripheral = p
        p.delegate = self
        centralManager.cancelPeripheralConnection(p)
        isConnected = false
    }
        
}

// this is here so that you don't need to implement 5 interfaces at the top, adds some fragmentation and easier to maintain when you know what part is what
extension BLEManager: CBCentralManagerDelegate {
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        let name = peripheral.name
            ?? (advertisementData[CBAdvertisementDataLocalNameKey] as? String)
            ?? "Unknown"

        let d = Scooter(id: peripheral.identifier, name: name, rssi: RSSI.intValue)
        if !devices.contains(d) { devices.append(d) }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        isConnected = true
        logger.debug("BLEManager - didConnect")
        peripheral.discoverServices([])
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: (any Error)?) {
        isConnected = false
        self.mainCharacteristic = nil
        logger.debug("BLEManager - didDisconnectPeripheral")
        // this should also fire when just closing the app forcefully so putting the call to cancel connection
        centralManager.cancelPeripheralConnection(peripheral)
    }

    func centralManager(
        _ central: CBCentralManager,
        didFailToConnect peripheral: CBPeripheral,
        error: (any Error)?
    ) {
        isConnected = false
        let errorMessage = error?.localizedDescription ?? "unknown error"
        logger.error("BLEManager didFailToConnect, error: \(errorMessage)")
    }
}

extension BLEManager: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
            guard error == nil else { return }
            guard let services = peripheral.services else { return }
            for s in services where s.uuid == BLEIDs.service {
                logger.debug("discovered service: \(s.uuid)")
                peripheral.discoverCharacteristics([], for: s)
            }
        }

    func peripheral(_ peripheral: CBPeripheral,
                    didDiscoverCharacteristicsFor service: CBService,
                    error: Error?) {
        guard error == nil else {
            logger.debug("error discovering characteristics: \(String(describing: error))")
            return
        }
        guard let chars = service.characteristics else {
            logger.debug("no characteristics found")
            return
        }
        logger.debug("Discovered characteristics: \(chars)")
        for c in chars {
            logger.debug("discovered char: \(c.uuid)")
            if c.uuid == BLEIDs.CHARACTERISTIC_UUID {
                mainCharacteristic = c
                peripheral.setNotifyValue(true, for: c)
                sleep(1)
            }
            if c.uuid == BLEIDs.service { serviceCharacteristic = c}
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: (any Error)?) {
        if let error = error {
            logger.error("error updating notification state: \(error)")
            return
        }
       
        if characteristic.isNotifying {
            logger.debug("subscribed to \(characteristic.uuid)")
            isNotificationEnabled = true
            onNotificationStreamEstablished?()
        } else {
            logger.debug("unsubscribed from \(characteristic.uuid)")
        }
    }

    func peripheral(_ peripheral: CBPeripheral,
                    didUpdateValueFor characteristic: CBCharacteristic,
                    error: Error?) {
        guard error == nil else {
            logger.error("didUpdateValueFor error: \(String(describing: error)) for \(characteristic.uuid)")
            return
        }
        guard let data = characteristic.value else {
            logger.error("No data: \(String(describing: error))")
            return
        }
        let bytes = [UInt8](data)
        let hexStringArray = bytes.map { String(format: "%02X", $0) }
        logger.debug("--- New Packet Received from \(characteristic.uuid) ---")
        logger.debug("As Text:       \(String(data: data, encoding: .utf8) ?? "Malformed UTF-8")")
        logger.debug("As Raw Bytes:  \(bytes)")
        logger.debug("As Hex String: \(hexStringArray.joined(separator: " "))")
    }
}
