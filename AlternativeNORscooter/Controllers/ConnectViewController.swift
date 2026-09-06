//
//  ConnectViewController.swift
//  AlternativeNORscooter
//
//  Created by rosenberg on 18.6.2026.
//
import UIKit
import CoreBluetooth

class ConnectViewController {
    let bleManager = BLEManager()
    
    var devices: Array<Any> = []
    
    init() {
    }
    
    func startScanning() {
        bleManager.startScan()
    }
    
    func connectToDevice(p: BLEManager.Scooter) {
        bleManager.connect(to: p)
    }
   
    func getDevices() -> Array<Any> {
        devices.append(bleManager.devices)
        
        return devices
    }
}
