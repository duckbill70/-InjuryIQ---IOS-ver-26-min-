import SwiftUI
import SwiftData

struct SettingsView: View {
    @EnvironmentObject private var ble: BLEManager
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \KnownDevice.lastConnectedAt, order: .reverse) private var knownDevices: [KnownDevice]

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
                        description: Text("Devices you connect to will appear here.")
                    )
                } else {
                    ForEach(knownDevices) { kd in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(kd.name)
                                Text(kd.uuid.uuidString)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            
                            Text(kd.lastConnectedAt.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption)
                               

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
                    Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "-")
                        .foregroundColor(.secondary)
                }
                HStack {
                    Text("Build")
                    Spacer()
                    Text(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "-")
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(BLEManager.shared)
}
