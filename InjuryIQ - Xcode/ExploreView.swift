import SwiftUI
import CoreBluetooth

struct ExploreView: View {
    @EnvironmentObject private var ble: BLEManager

    var body: some View {
        VStack(spacing: 0) {

            // Controls
            HStack(spacing: 12) {
                Button(action: { ble.startScan() }) {
                    Label("Scan", systemImage: ble.isBluetoothOn ? "wifi" : "wifi.slash")
                }
                .buttonStyle(.borderedProminent)
                .disabled(!ble.isBluetoothOn || ble.isScanning)

                Button(action: { ble.stopScan() }) {
                    Label("Stop", systemImage: "stop.circle")
                }
                .buttonStyle(.bordered)
                .disabled(!ble.isScanning)
            }
            .padding()

            // Device list
            List {
                ForEach(ble.discovered) { dp in
                    NavigationLink(value: dp) {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(dp.name.isEmpty ? "Unknown" : dp.name)
                                    .font(.headline)
                                Text(dp.id.uuidString)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Text("RSSI \(dp.rssi)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button("Connect") { ble.connect(dp) }
                            .tint(.blue)
                    }
                }
            }
            .overlay {
                if ble.discovered.isEmpty && ble.isBluetoothOn {
                    ContentUnavailableView("No Devices", systemImage: "dot.radiowaves.left.and.right", description: Text("Tap Scan to discover nearby BLE devices."))
                } else if ble.discovered.isEmpty && !ble.isBluetoothOn {
                    ContentUnavailableView("Bluetooth Disabled", systemImage: "bluetooth.slash", description: Text("Enable Bluetooth to discover devices."))
                }
            }

            if let err = ble.lastError {
                Text(err).font(.footnote).foregroundColor(.red).padding(.horizontal)
            }
        }
        .navigationDestination(for: DiscoveredPeripheral.self) { dp in
            PeripheralDetailView(dp: dp)
        }
    }
}

struct PeripheralDetailView: View {
    let dp: DiscoveredPeripheral
    @EnvironmentObject private var ble: BLEManager

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading) {
                    Text(dp.name.isEmpty ? "Unknown" : dp.name)
                        .font(.title3).bold()
                    Text(dp.id.uuidString)
                        .font(.caption2).foregroundColor(.secondary)
                }
                Spacer()
                Button(action: { ble.connect(dp) }) {
                    Label("Connect", systemImage: "link")
                }
                .buttonStyle(.borderedProminent)
            }
            Divider()

            if let connected = ble.connectedPeripheral, connected.identifier == dp.id {
                List {
                    Section("Services") {
                        ForEach(ble.services, id: \ .uuid) { service in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(service.uuid.uuidString).font(.subheadline).bold()
                                if let chars = ble.characteristicsByService[service] {
                                    ForEach(chars, id: \ .uuid) { ch in
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(ch.uuid.uuidString)
                                                .font(.caption)
                                            HStack(spacing: 8) {
                                                if ch.properties.contains(.read) { Label("read", systemImage: "doc.text.magnifyingglass") }
                                                if ch.properties.contains(.write) { Label("write", systemImage: "pencil") }
                                                if ch.properties.contains(.notify) { Label("notify", systemImage: "bell") }
                                                if ch.properties.contains(.indicate) { Label("indicate", systemImage: "exclamationmark.bubble") }
                                            }
                                            .labelStyle(.iconOnly)
                                            .foregroundColor(.secondary)
                                        }
                                        .padding(.vertical, 2)
                                    }
                                } else {
                                    Text("No characteristics discovered yet").font(.footnote).foregroundColor(.secondary)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            } else {
                ContentUnavailableView("Not Connected", systemImage: "link.badge.plus", description: Text("Press Connect to discover services and characteristics."))
            }
        }
        .padding()
    }
}

#Preview {
    ExploreView()
        .environmentObject(BLEManager.shared)
}
