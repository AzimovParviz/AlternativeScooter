//
//  Globals.swift
//  AlternativeNORscooter
//
//  Created by Parviz Azimov on 6.9.2026.
//

import Foundation

enum AppConfig {
    static let bleSerialNumber: String = {
        guard let value = Bundle.main.object(forInfoDictionaryKey: "ScooterSerialNumber") as? String,
              !value.isEmpty else {
            fatalError("ScooterSerialNumber missing from Info.plist — check Config.xcconfig is set up correctly (Config.example.xcconfig).")
        }
        return value
    }()
}
