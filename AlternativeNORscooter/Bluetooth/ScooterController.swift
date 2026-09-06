//
//  ScooterControl.swift
//  AlternativeNORscooter
//
//  Created by rosenberg on 20.6.2026.
//
import CoreBluetooth
import os

enum ScooterAuth {
    static let CMD_LOGIN: UInt8 = 0x44  // 68
    static let CMD_LOGIN_CONFIRM: UInt8 = 0x45  // 69
}

enum ScooterFrame {
    static let SYNC_HEADER: [UInt8] = [0xAA, 0x55]  // Scooter uses 0xAA instead of 0xAE
    static let FRAME_FOOTER: [UInt8] = [0x14, 0x5A, 0x5A]
}

enum ScooterCmd {
    static let CMD_HEADLIGHT: UInt8 = 0x73  // 115
    static let CMD_GEAR: UInt8 = 0x87 // 135
    static let CMD_HEARTBEAT: UInt8 = 0x5E  // 94
    static let CMD_POWER: UInt8 = 0x40
}

enum Gearing {
    static let P1: UInt8 = 0x02 // ECO
    static let P2: UInt8 = 0x01 // Drive
    static let P3: UInt8 = 0x00 // Sport
    static let P4: UInt8 = 0x03 // Walk
}

class ScooterController: ObservableObject {
    var bleManager: BLEManager
    private var logger: Logger
    
    init(bleManager: BLEManager) {
        self.bleManager = bleManager
        self.logger = Logger()
        
        self.bleManager.onNotificationStreamEstablished = { [weak self] in
            Task { [weak self] in
                await self?.authenticate(sn: AppConfig.bleSerialNumber)
            }
        }
    }
    
    private func makeFrame(payload: [UInt8], cmd: UInt8) -> [UInt8] {
        // Pre-allocate exactly 20 bytes filled with 0
        var frame: [UInt8] = Array(repeating: 0, count: 20)

        // 1. Overwrite indices 0 and 1 with sync header (DO NOT append)
        frame[0..<2] = ScooterFrame.SYNC_HEADER[...]
       
        // 2. Padding with zeros if the payload shorter than 14 bytes
        for (i, b) in payload.enumerated() {
            if i < 14 {
                frame[2 + i] = b
            }
        }
        
        // 3. Command code at index 16
        frame[16] = cmd
        
        // 4. Footer at indices 17, 18, 19
        frame[17..<20] = ScooterFrame.FRAME_FOOTER[...]
        
        logger.debug("Frame is built: \(frame)")
        return frame
    }
    
    private func makeLoginFrame(serialNumber: String) -> [UInt8] {
        var frame: [UInt8] = Array(repeating: 0, count: 20)
        
        frame[0..<2] = ScooterFrame.SYNC_HEADER[...]
        frame[16] = ScooterAuth.CMD_LOGIN
        frame[17..<20] = ScooterFrame.FRAME_FOOTER[...]
       
        var snBytes = Array(serialNumber.uppercased().utf8)
        
        if snBytes.count != 4 && snBytes.count != 17 && snBytes.count != 19 {
            logger.error("Error: Invalid serial number / password length (\(snBytes.count))")
        }
        
        if snBytes.count == 19 {
            snBytes.removeFirst(2) // Strip first 2 elements for EWAY
        }

        // Copy up to 14 bytes into payload window (indices 2 to 15)
        for (i, b) in snBytes.enumerated() {
            if i < 14 {
                frame[2 + i] = b
            }
        }
        
        // Fallback or fill remaining serial bytes into the footer window if required by protocol
        if snBytes.count >= 17 {
            frame[17] = snBytes[14]
            frame[18] = snBytes[15]
            frame[19] = snBytes[16]
        }
        
        logger.debug("Login frame is built: \(frame)")
        return frame
    }
    
    private func sendHeartbeat() async {
        let frame = makeFrame(payload: [], cmd: ScooterCmd.CMD_HEARTBEAT)
        
        // FIXED: Safely check for peripheral and characteristic before writing
        guard let peripheral = bleManager.peripheral,
              let characteristic = bleManager.mainCharacteristic else {
            logger.info("Heartbeat skipped: BLE connection or characteristic not ready yet.")
            return
        }
        
        logger.debug("Sending heartbeat frame: \(frame)")
        peripheral.writeValue(Data(frame), for: characteristic, type: .withoutResponse)
        
        try? await Task.sleep(for: .seconds(0.3))
    }
    
    func authenticate(sn: String) async {
        // Give the peripheral a brief moment to discover characteristics and sub to notifications right after connection
        try? await Task.sleep(for: .seconds(2.5))
        
        let frame = makeLoginFrame(serialNumber: sn)
        // we wait for 0.3 seconds inside the heartbeat
        await sendHeartbeat()

        guard let peripheral = bleManager.peripheral,
              let characteristic = bleManager.mainCharacteristic else {
            logger.error("Authentication aborted: Characteristics not discovered.")
            return
        }
        
        logger.debug("Sending first login frame: \(frame)")
        peripheral.writeValue(Data(frame), for: characteristic, type: .withoutResponse)
        try? await Task.sleep(for: .seconds(0.3))
        
        // Login confirmation
        let confirmFrame = makeFrame(payload: [], cmd: ScooterAuth.CMD_LOGIN_CONFIRM)
        peripheral.writeValue(Data(confirmFrame), for: characteristic, type: .withoutResponse)
        try? await Task.sleep(for: .seconds(0.3))
    }
    
    func turnOnHeadlight(on: Bool) async {
        let frame = makeFrame(payload: [on ? 0x13 : 0x12, 0x00], cmd: ScooterCmd.CMD_HEADLIGHT)
        
        guard let peripheral = bleManager.peripheral,
              let characteristic = bleManager.mainCharacteristic else {
            logger.info("Headlight action skipped: BLE not ready.")
            return
        }
        
        logger.debug("Sending headlight frame: \(frame)")
        peripheral.writeValue(Data(frame), for: characteristic, type: .withoutResponse)
    }
    
    func switchGear(gear: String) {
        logger.debug("Gear change initiated...")
        var frame: [UInt8] = []
        switch gear {
            case "eco":
                frame = makeFrame(payload: [Gearing.P1, 0xE0], cmd: ScooterCmd.CMD_GEAR)
            case "drive":
                frame = makeFrame(payload: [Gearing.P2, 0xE0], cmd: ScooterCmd.CMD_GEAR)
            case "sport":
                frame = makeFrame(payload: [Gearing.P3, 0xE0], cmd: ScooterCmd.CMD_GEAR)
            case "walk":
                frame = makeFrame(payload: [Gearing.P4, 0xE0], cmd: ScooterCmd.CMD_GEAR)
            default:
                logger.info("Unsupported gear: \(gear), setting to Drive")
                frame = makeFrame(payload: [Gearing.P2, 0xE0], cmd: ScooterCmd.CMD_GEAR)
        }
        
        guard let peripheral = bleManager.peripheral,
              let characteristic = bleManager.mainCharacteristic else {
            logger.info("Gear switch action skipped: BLE not ready.")
            return
        }
        
        peripheral.writeValue(Data(frame), for: characteristic, type: .withoutResponse)
    }
    
    func disconnect() {
        guard let peripheral = bleManager.peripheral
            else {
            logger.info("Power off action skipped: BLE not ready.")
            return
        }
        logger.debug("Disconnecting from the peripheral...")
        bleManager.disconnect(from: peripheral)
    }
    
    func powerOff() {
        logger.debug("Powering off...")
        let frame = makeFrame(payload: [], cmd: ScooterCmd.CMD_POWER)
        
        guard let peripheral = bleManager.peripheral,
              let characteristic = bleManager.mainCharacteristic else {
            logger.info("Power off action skipped: BLE not ready.")
            return
        }
        
        peripheral.writeValue(Data(frame), for: characteristic, type: .withoutResponse)
    }
}
