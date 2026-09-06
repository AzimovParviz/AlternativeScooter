//
//  ScooterView.swift
//  AlternativeNORscooter
//
//  Created by rosenberg on 20.6.2026.
//  Google Gemini 3.5 Flash was used to generate this View (stacks and styling)
//
import SwiftUI


struct ScooterView: View {
    var scooter: BLEManager.Scooter?
    
    @StateObject var controller: ScooterController
    
    init(bleManager: BLEManager) {
        _controller = StateObject(wrappedValue: ScooterController(bleManager: bleManager))
    }
    
    // State variables to track button presses
    @State private var isHeadlightOn = false
    @State private var selectedGear = "drive"
    
    var body: some View {
        VStack(spacing: 30) {
            Text(scooter?.name ?? "No name idk")
                .font(.title)
                .fontWeight(.bold)
                .padding(.top)
            
            // --- STACK 1: Controls (Headlight & Power) ---
            HStack(spacing: 20) {
                // Headlight Button
                Button(action: {
                    Task {
                        await controller.turnOnHeadlight(on: isHeadlightOn)
                        isHeadlightOn.toggle()
                    }
                }) {
                    Label(
                        isHeadlightOn ? "Lights On" : "Lights Off",
                        systemImage: isHeadlightOn ? "lightbulb.fill" : "lightbulb"
                    )
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(isHeadlightOn ? Color.yellow.opacity(0.2) : Color(.gray))
                    .foregroundColor(isHeadlightOn ? .orange : .primary)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                
                // Red Turn Off Button
                Button(action: {
                    print("Turn off scooter")
                    controller.powerOff()
                }) {
                    Label("Turn Off", systemImage: "power")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                // Red Turn Off Button
                Button(action: {
                    print("Disconnect")
                    controller.disconnect()
                }) {
                    Label("Disconnect", systemImage: "rectangle.portrait.and.arrow.right")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding(.horizontal)
            
            // --- STACK 2: Gears (Walk, Eco, Drive, Sport) ---
            VStack(alignment: .leading, spacing: 10) {
                Text("Riding Mode")
                    .font(.headline)
                    .foregroundColor(.secondary)
                    .padding(.leading, 5)
                
                HStack(spacing: 10) {
                    let gears = [
                        ("Walk", "figure.walk", Color.blue),
                        ("Eco", "leaf.fill", Color.green),
                        ("Drive", "d.circle.fill", Color.orange),
                        ("Sport", "bolt.fill", Color.purple)
                    ]
                    
                    ForEach(gears, id: \.0) { name, icon, activeColor in
                        let isSelected = selectedGear.lowercased() == name.lowercased()
                        
                        Button(action: {
                            selectedGear = name.lowercased()
                            controller.switchGear(gear: selectedGear)
                        }) {
                            VStack(spacing: 8) {
                                Image(systemName: icon)
                                    .font(.title2)
                                Text(name)
                                    .font(.caption)
                                    .fontWeight(.medium)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(isSelected ? activeColor : Color(.gray))
                            .foregroundColor(isSelected ? .white : .primary)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .animation(.snappy, value: selectedGear)
                        }
                    }
                }
            }
            .padding(.horizontal)
            
            Spacer() // Pushes everything to the top neatly
        }
    }
}
