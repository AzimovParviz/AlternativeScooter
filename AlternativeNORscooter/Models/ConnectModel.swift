//
//  ConnectModel.swift
//  AlternativeNORscooter
//
//  Created by rosenberg on 19.6.2026.
//

import Foundation
import Observation
import CoreBluetooth

class ConnectModel: ObservableObject {
    @Published var isConnected: Bool = false
    
    private var controller = ConnectViewController()
    
    func scan() {
        controller.startScanning()
    }
    
    func connect(to peripheral: BLEManager.Scooter) {
        controller.connectToDevice(p: peripheral)
    }
}
