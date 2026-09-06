//
//  ConnectView.swift
//  AlternativeNORscooter
//
//  Created by rosenberg on 18.6.2026.
//

import SwiftUI

struct ConnectView: View {
    //    @StateObject var viewModel: ConnectModel = .init()
    @State var bleManager: BLEManager = .init()
    @State var scooter: BLEManager.Scooter?

    var body: some View {
        Button(action: bleManager.startScan) {
            Text("Scan for scooters")
        }

        VStack {
            Text("Devices found: ")
                .font(.headline)
            if bleManager.devices.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .font(.title2)
                        .foregroundStyle(.secondary)

                    Text(
                        bleManager.isScanning
                            ? "Searching…" : "Tap Scan to find your scooter"
                    )
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(18)
                .background(.quaternary.opacity(0.25))
                .clipShape(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                )
            } else {
                List(bleManager.devices) { d in
                    Button {
                        scooter = d
                        bleManager.connect(to: d)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(d.name)
                                    .font(.body)
                                Text("RSSI \(d.rssi)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .contentShape(Rectangle())
                    }
                }
                .listStyle(.automatic)
                .frame(height: 260)
            }
        }
        
        if (bleManager.isConnected && scooter != nil) {
            ScooterView(bleManager: bleManager)
        }
    }
}

#Preview {
    ConnectView()
}
