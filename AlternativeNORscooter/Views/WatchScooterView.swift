//
//  WatchScooterView.swift
//  AlternativeNORscooter Watch App
//
//  Created by rosenberg on 22.6.2026.
//

import SwiftUI

struct WatchScooterView: View {
    var scooter: BLEManager.Scooter?
    @StateObject var controller: ScooterController
    
    @State private var isHeadlightOn = false
    @State private var selectedGear = "drive"
    
    init(bleManager: BLEManager, scooter: BLEManager.Scooter?) {
        self.scooter = scooter
        _controller = StateObject(wrappedValue: ScooterController(bleManager: bleManager))
    }
    
    // Config matching your exact gears dictionary
    let gears = ["walk", "eco", "drive", "sport"]
    
    var body: some View {
        VStack(spacing: 14) {
            // Scooter Identifier Status
            HeaderStatusView(name: scooter?.name ?? "Scooter Connected")

            // --- CONTROLS SECTION ---
            VStack(spacing: 8) {
                // Large Headlight Toggle
                Button(action: {
                    Task {
                        await controller.turnOnHeadlight(on: isHeadlightOn)
                        isHeadlightOn.toggle()
                        WKInterfaceDevice.current().play(.click) // Haptic feedback
                    }
                }) {
                    Label(
                        isHeadlightOn ? "Lights On" : "Lights Off",
                        systemImage: isHeadlightOn ? "lightbulb.fill" : "lightbulb"
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .tint(isHeadlightOn ? .yellow.opacity(0.3) : .gray)
                .foregroundColor(isHeadlightOn ? .yellow : .primary)

                // Large Disconnect Button
                Button(role: .destructive, action: {
                    WKInterfaceDevice.current().play(.directionDown)
                    controller.disconnect()
                }) {
                    Label("Disconnect", systemImage: "xmark.circle")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            Divider()
                .padding(.vertical, 4)

            // --- RIDING MODE SELECTION (Crown Integrated Picker) ---
            VStack(alignment: .leading, spacing: 4) {
                Label("Riding Mode", systemImage: "gauge.with.needle")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                
                Picker("Gear Selection", selection: $selectedGear) {
                    ForEach(gears, id: \.self) { gear in
                        Text(gear.capitalized).tag(gear)
                    }
                }
                .labelsHidden() // Keeps it strictly minimal on watchOS
                .pickerStyle(.wheel) // Turns digital crown scrolling into gear shifts
                .frame(height: 55)
                .onChange(of: selectedGear) { _, newGear in
                    WKInterfaceDevice.current().play(.click)
                    controller.switchGear(gear: newGear)
                }
            }
            
            // --- CRITICAL EMERGENCY POWER OFF ---
            Button(action: {
                WKInterfaceDevice.current().play(.failure)
                controller.powerOff()
            }) {
                Label("Power Off Scooter", systemImage: "power")
                    .foregroundColor(.red)
            }
            .buttonStyle(.borderless)
            .padding(.top, 8)
        }
    }
}

// Subview to optimize layout constraints for small screens
struct HeaderStatusView: View {
    let name: String
    
    var body: some View {
        HStack {
            Circle()
                .frame(width: 8, height: 8)
                .foregroundColor(.green)
            Text(name)
                .font(.headline)
                .lineLimit(1)
            Spacer()
        }
        .padding(.bottom, 2)
    }
}
