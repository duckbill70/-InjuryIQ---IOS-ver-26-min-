import CoreBluetooth
import SwiftData
import SwiftUI

struct SettingsView: View {
	@EnvironmentObject private var ble: BLEManager
	@Environment(\.modelContext) private var modelContext
	@Query(sort: \KnownDevice.lastConnectedAt, order: .reverse) private
		var knownDevices: [KnownDevice]

	var body: some View {
		Form {
			Section(header: Text("Bluetooth")) {
				Toggle("Auto-scan on launch", isOn: $ble.autoScanOnLaunch)
				Toggle("Filter duplicate discoveries", isOn: $ble.filterDuplicates)
			}

			Section(header: Text("Known Devices (\(knownDevices.count))")) {
				if knownDevices.isEmpty {
					ContentUnavailableView(
						"None",
						systemImage: "antenna.radiowaves.left.and.right",
						description: Text(
							"Devices you connect to will appear here."
						)
					)
				} else {
					ForEach(knownDevices) { kd in
						HStack {
							VStack(alignment: .leading) {
								HStack {
									Text(kd.name)
										.font(.caption)
									Image(systemName: "circle.fill")
										.foregroundColor(
											isDeviceConnected(kd.uuid) ? .blue :
											isDeviceDiscovered(kd.uuid) ? .green :
											.gray
										)
										
									Spacer()
									Text(
										kd.lastConnectedAt.formatted(
											date: .abbreviated,
											time: .shortened
										)
									)
								}
								.padding(.bottom, 5)
								Text(kd.uuid.uuidString)
									.font(.caption2)
									.foregroundColor(.secondary)
							}
							.font(.caption)
						}
						.swipeActions(edge: .leading, allowsFullSwipe: false) {
							Button(action: {
								handleConnectDisconnect(kd)
							}) {
								Label(
									isDeviceConnected(kd.uuid) ? "Disconnect" : "Connect",
									systemImage: "bolt.fill"
								)
							}
							.tint(.blue)
						}
					}
					.onDelete { idx in
						idx.forEach { modelContext.delete(knownDevices[$0]) }
						try? modelContext.save()
					}
				}
			}

			Section(header: Text("App")) {
				Toggle("Enable Notifications", isOn: .constant(true))
				Toggle("Use Cellular Data", isOn: .constant(false))
			}

			Section(header: Text("About")) {
				HStack {
					Text("Version")
					Spacer()
					Text(
						Bundle.main.infoDictionary?[
							"CFBundleShortVersionString"
						] as? String ?? "-"
					)
					.foregroundColor(.secondary)
				}
				HStack {
					Text("Build")
					Spacer()
					Text(
						Bundle.main.infoDictionary?["CFBundleVersion"]
							as? String ?? "-"
					)
					.foregroundColor(.secondary)
				}
			}
		}
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
	SettingsView()
		.environmentObject(BLEManager.shared)
}
