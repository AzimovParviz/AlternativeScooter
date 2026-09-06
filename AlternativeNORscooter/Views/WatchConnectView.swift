//
//  WatchConnectView.swift
//  AlternativeNORscooter Watch App
//
//  Created by rosenberg on 22.6.2026.
//

import SwiftUI

struct WatchConnectView: View {
    @State var bleManager: BLEManager = .init()
    @State var scooter: BLEManager.Scooter?
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    if !bleManager.isConnected {
                        // --- DISCONNECTED / SCANNING STATE ---
                        Button(action: bleManager.startScan) {
                            Label(
                                bleManager.isScanning ? "Searching..." : "Scan for Scooters",
                                systemImage: bleManager.isScanning ? "waveform.and.magnifyingglass" : "antenna.radiowaves.left.and.right"
                            )
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.blue)
                        
                        if bleManager.devices.isEmpty {
                            Text(bleManager.isScanning ? "Bring watch near scooter..." : "Tap scan to begin")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.top, 10)
                        } else {
                            // Clean, watch-optimized list of devices
                            ForEach(bleManager.devices) { d in
                                Button {
                                    scooter = d
                                    bleManager.connect(to: d)
                                } label: {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(d.name)
                                                .font(.body)
                                                .lineLimit(1)
                                            Text("RSSI \(d.rssi) dBm")
                                                .font(.footnote)
                                                .foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                        Image(systemName: "bolt.horizontal.fill")
                                            .foregroundStyle(.green)
                                    }
                                }
                            }
                        }
                    } else {
                        // --- CONNECTED DASHBOARD STATE ---
                        WatchScooterView(bleManager: bleManager, scooter: scooter)
                    }
                }
                .padding(.horizontal)
            }
            .navigationTitle("AlternativeNOR")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    WatchConnectView()
}
