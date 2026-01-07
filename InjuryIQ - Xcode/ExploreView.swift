import SwiftUI
import _SwiftData_SwiftUI
import CoreBluetooth
import SwiftData

struct ExploreView: View {
	
    @EnvironmentObject private var ble: BLEManager
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SessionRecord.startedAt, order: .reverse) private var sessionRecords: [SessionRecord]

    var body: some View {
        VStack(spacing: 0) {

            // TOP HALF: BLE controls and discovered devices
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
            .frame(maxHeight: .infinity)

            Divider()

            // BOTTOM HALF: SessionRecord list (@Query)
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("Sessions")
                        .font(.headline)
                    Spacer()
                    Text("\(sessionRecords.count)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding([.horizontal, .top])

                if sessionRecords.isEmpty {
                    ContentUnavailableView(
                        "No Sessions",
                        systemImage: "clock",
                        description: Text("Your recorded sessions will appear here.")
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(sessionRecords) { rec in
                            SessionRow(record: rec)
                        }
                        .onDelete { idx in
                            for i in idx {
                                modelContext.delete(sessionRecords[i])
                            }
                            try? modelContext.save()
                        }
                    }
                }
            }
			.onAppear {
					print("[ExploreView] Fetched \(sessionRecords.count) session records")
				}
            .frame(maxHeight: .infinity)
        }
        .navigationDestination(for: DiscoveredPeripheral.self) { dp in
            PeripheralDetailView(dp: dp)
        }
    }
}

private struct SessionRow: View {
	let record: SessionRecord
	@State private var showDetail = false
	var onDelete: (() -> Void)? = nil

	var body: some View {
		HStack(alignment: .firstTextBaseline) {
			VStack(alignment: .leading, spacing: 4) {
				
				HStack(spacing: 8) {
					Text(record.activity.isEmpty ? "Session" : record.activity)
						.font(.subheadline).bold()
					
					if let type = ActivityType(rawValue: record.activity),
						let button = ActivityButton.activities.first(where: { $0.type == type }) {
							Image(systemName: button.icon)
								.foregroundColor(.blue)
						}
				}
				
				
				HStack(spacing: 8) {
					Text(record.startedAt, style: .date)
					
					Spacer()
					
					Text(record.startedAt, style: .time)
					if let stop = record.stoppedAt {
						Text("–")
						Text(stop, style: .time)
					}
				}
				.font(.caption)
				.foregroundColor(.secondary)
				
				HStack(spacing: 8) {
					if !record.stateAtStop.isEmpty {
						Text("Ended: \(record.stateAtStop)")
							
					}
					
					Spacer()
					
					if let stop = record.stoppedAt {
						let duration = stop.timeIntervalSince(record.startedAt)
						let formatted = Duration.seconds(duration).formatted(.time(pattern: .hourMinuteSecond))
						Text("Duration: \(formatted)")
					}
				}
				.font(.caption)
				.foregroundColor(.secondary)
				
			}
			Spacer()
		}
		.padding(.vertical, 4)
		// Left swipe: View
		.swipeActions(edge: .leading, allowsFullSwipe: false) {
			Button() {
				showDetail = true
			} label: {
				Label("View", systemImage: "eye")
			}
			.tint(.blue)
		}
		// Right swipe: Delete
		.swipeActions(edge: .trailing, allowsFullSwipe: true) {
			if let onDelete {
				Button(role: .destructive) {
					onDelete()
				} label: {
					Label("Delete", systemImage: "trash")
				}
			}
		}
		.sheet(isPresented: $showDetail) {
			SessionDetailView(record: record)
		}
	}
}

private struct SessionDetailView: View {
	let record: SessionRecord

	private var events: [SessionEvent] {
		let decoder = JSONDecoder()
		decoder.dateDecodingStrategy = .iso8601
		return (try? decoder.decode([SessionEvent].self, from: record.eventsJSON)) ?? []
	}

	var body: some View {
		VStack(alignment: .leading, spacing: 16) {
			Text("Session Details")
				.font(.headline).bold()
			Text("Activity: \(record.activity)")
				.font(.caption)
			Text("Started: \(record.startedAt.formatted())")
				.font(.caption)
			if let stop = record.stoppedAt {
				Text("Stopped: \(stop.formatted())")
					.font(.caption)
			}
			Text("State at Stop: \(record.stateAtStop)")
				.font(.caption)

			Divider()
			Text("Raw Session Log")
				.font(.headline)
			if events.isEmpty {
				Text("No events found.")
					.foregroundColor(.secondary)
			} else {
				ScrollView {
					VStack(alignment: .leading, spacing: 8) {
						ForEach(events) { event in
							VStack(alignment: .leading, spacing: 2) {
								Text("\(event.timestamp.formatted()) • \(event.kind.rawValue)")
									.font(.caption)
								if let meta = event.metadata, !meta.isEmpty {
									Text(meta.map { "\($0): \($1)" }.joined(separator: ", "))
										.font(.caption2)
										.foregroundColor(.secondary)
								}
							}
							.padding(.vertical, 2)
						}
					}
				}
			}
			Spacer()
		}
		.padding()
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

			if let connected = ble.connectedPeripherals.first(where: { $0.identifier == dp.id }) {
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
