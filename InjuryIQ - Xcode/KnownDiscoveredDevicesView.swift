//
//  KnownDiscoveredDevicesView.swift
//  InjuryIQ - Xcode
//
//  Created by Platts Andrew on 13/01/2026.
//


import SwiftUI
import SwiftData
import CoreBluetooth

struct KnownDiscoveredDevicesView: View {
    @ObservedObject var ble: BLEManager
	@Environment(\.modelContext) private var modelContext
	@Query(sort: \KnownDevice.lastConnectedAt, order: .reverse) private var knownDevices: [KnownDevice]

    var body: some View {

        //ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
				
				
                ForEach(knownDevices) { device in
					Button(action: { handleConnectDisconnect(device) }) {
						Text("\(device.uuid.uuidString.suffix(4))")
							.font(.caption)
							.padding(.horizontal, 10)
							.padding(.vertical, 4)
							.frame(width: 60)
							.background(.ultraThinMaterial)
							.clipShape(RoundedRectangle(cornerRadius: 12))
							.overlay(
								RoundedRectangle(cornerRadius: 12)
									.stroke(
										Color(isDeviceConnected(device.uuid) ? .blue : isDeviceDiscovered(device.uuid) ? .green : .gray),lineWidth: 2)
									)
							}
							.buttonStyle(.plain)
                }
				
				let empty = max(0, 4 - knownDevices.count)
				let symbolSet: [String] = ["cloud.bolt.rain.fill", "sun.rain.fill", "moon.stars.fill", "moon.fill"]
				ForEach(0..<empty, id: \.self) { _ in
					Button(action: { /* action */ }) {
						Text("ABCD")
							.font(.subheadline)
							.padding()
							.glassEffect()
					}
				}
				
				VStack(alignment: .leading, spacing: 12) {
					// Header: Device name + play/stop icon
					HStack {
						Text("ABCD")
							.font(.subheadline.weight(.semibold))
					}
				}
				.padding(14)
				.background(
					RoundedRectangle(cornerRadius: 16)
						.fill(Color(.secondarySystemBackground))
				)
				.overlay(
					RoundedRectangle(cornerRadius: 16)
						.strokeBorder(Color.primary.opacity(0.08))
				)
				
            }
			.frame(maxWidth: .infinity, alignment: .center)
			.padding(.horizontal)
        //}
		//.frame(maxWidth: .infinity, alignment: .center)
    }
	
	private func isDeviceConnected(_ uuid: UUID) -> Bool {
		ble.connectedPeripherals.contains { $0.identifier == uuid }
	}
	
	private func isDeviceDiscovered(_ uuid: UUID) -> Bool {
		return ble.discovered.contains { $0.id == uuid }
	}
	
	private func handleConnectDisconnect(_ kd: KnownDevice) {
		if let connected = ble.connectedPeripherals.first(where: { $0.identifier == kd.uuid }) {
			ble.disconnect(connected)
		} else {
			if let discovered = ble.discovered.first(where: { $0.id == kd.uuid }) {
				ble.connect(discovered)
			} else {
				print("[UI] Device not discovered, starting scan: \(kd.name)")
				ble.startScan()

				DispatchQueue.global().asyncAfter(deadline: .now() + 2.0) {
					DispatchQueue.main.async {
						if let discovered = ble.discovered.first(where: { $0.id == kd.uuid }) {
							ble.connect(discovered)
						} else {
							print("[UI] Device still not found after scan: \(kd.name)")
						}
						ble.stopScan()
					}
				}
			}
		}
	}
	
}

#Preview {
	KnownDiscoveredDevicesView(ble: BLEManager.shared)
		.environmentObject(BLEManager.shared)
}
