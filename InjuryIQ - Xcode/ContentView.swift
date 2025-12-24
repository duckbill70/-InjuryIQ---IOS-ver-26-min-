//
//  ContentView.swift
//  InjuryIQ - Xcode
//
//  Created by Platts Andrew on 13/12/2025.
//

import SwiftData
import SwiftUI


struct ContentView: View {
	@Environment(\.modelContext) private var modelContext
	@EnvironmentObject private var ble: BLEManager
	@Query private var items: [Item]
	//@AppStorage("selectedActivity") private var selectedActivity: ActivityType = .running
	@Bindable var sports: Sports
	
	var body: some View {
		TabView {
			// Home tab renders inline content here
			NavigationStack {
				VStack(spacing: 16) {
					//Text("Welcome to InjuryIQ")
					//	.font(.title2)
					//	.fontWeight(.semibold)
					//Text("This is the Home screen.")
					//	.foregroundColor(.secondary)

					HStack(spacing: 12) {
						
						//Activity Buttons
						ForEach(ActivityButton.activities) { activity in
							Button(action: {
								///Button Action
								sports.selectedActivity = activity.type
							}) {
								VStack {
									Image(systemName: activity.icon)
										.font(.title2)
									Text(activity.name)
										.font(.caption)
								}
								.frame(maxWidth: .infinity)
								.padding()
								.background(
									sports.selectedActivity == activity.type
									? activity.selectedColor
									: activity.unselectedColor
								)
								.foregroundColor(
									sports.selectedActivity == activity.type
									? .white
									: .primary
								)
								.cornerRadius(10)
							}
						}
					}
					.padding(.horizontal)
					.padding(.top)
					
					Spacer()
					
					let sessions = Array(ble.sessionsByPeripheral.values)
					
					let fatigueLeft = sessions.indices.contains(0) ? sessions[0].data.fatiguePercent.map(Double.init) : nil
					let fatigueRight = sessions.indices.contains(1) ? sessions[1].data.fatiguePercent.map(Double.init) : nil

					SessionStatusIndicator(
						leftFatiguePct: fatigueLeft,
						rightFatiguePct: fatigueRight,
						leftConnected: sessions.indices.contains(0),
						rightConnected: sessions.indices.contains(1),
						duration: 0,
						sessionState: .idle,
						activity: sports.selectedActivity.toSessionActivity(),
						subtitle: nil
					)
					.frame(width: 320)
					.padding()
							
					let statusLeft = sessions.indices.contains(0) ? sessions[0].data.commandState : .unknown
					
					let statusRight = sessions.indices.contains(1) ? sessions[1].data.commandState : .unknown
					
					let locationLeft = sessions.indices.contains(0)
					? (sessions[0].data.location.flatMap { DeviceSide(rawValue: Int($0)) } ?? .unknown) : .unknown
					
					let locationRight = sessions.indices.contains(1)
					? (sessions[1].data.location.flatMap { DeviceSide(rawValue: Int($0)) } ?? .unknown) : .unknown
					
					let batteryLeft = sessions.indices.contains(0) ? sessions[0].data.batteryPercent : 0
					
					let batteryRight = sessions.indices.contains(1) ? sessions[1].data.batteryPercent : 0
					
					let a = BLEDevice(
						name: "Device A",
						status: DeviceStatus(from: statusLeft),
						batteryPercent: batteryLeft ?? 0,
						rssi: -58,
						hz: 0,
						side: locationLeft
				   )
				   let b = BLEDevice(
					   name: "Device B",
					   status: DeviceStatus(from: statusRight),
					   batteryPercent: batteryRight ?? 0,
					   rssi: -86,
					   hz: 0,
					   side: locationRight
				   )
				   
				   Group {
					   HStack(spacing: 16) {
						   DeviceCard(device: a)
						   DeviceCard(device: b)
					}
				   .padding()
					Spacer()
		   }
					
				}
				.frame(maxWidth: .infinity, maxHeight: .infinity)
			}
			.toolbar(.hidden, for: .navigationBar)
			.tabItem { Label("Home", systemImage: "house") }

			// Explore tab
			NavigationStack {
				ExploreView()
			}
			.toolbar(.hidden, for: .navigationBar)
			.tabItem { Label("Explore", systemImage: "sparkles") }

			// Settings tab
			NavigationStack {
				SettingsView()
			}
			.toolbar(.hidden, for: .navigationBar)
			.tabItem { Label("Settings", systemImage: "gear") }
		}
		.onAppear {
			// Ensure BLE uses the exact same ModelContext as SwiftUI
			if ble.modelContext == nil {
				ble.attach(modelContext: modelContext)
				print("[ContentView] Attached BLE to view modelContext")
			}
		}

	}
	
	private func deviceTable() -> some View {
		
		return ScrollView(.horizontal, showsIndicators: false) {
			
			HStack(spacing: 12) {
								
			   ForEach(Array(ble.sessionsByPeripheral.values), id: \.peripheral.identifier) { session in
				   VStack {
					   
					   Text(session.data.localName ?? "Unknown")
						   .font(.caption)
						   .lineLimit(1)
				   }
				   .frame(width: 80)
				   .padding(8)
				   .background(Color(.systemBlue))
				   .foregroundColor(.white)
				   .cornerRadius(10)
			   }
		   }
		   .padding(.vertical, 8)
		}
	}

	private func addItem() {
		withAnimation {
			let newItem = Item(timestamp: Date())
			modelContext.insert(newItem)
		}
	}

	private func deleteItems(offsets: IndexSet) {
		withAnimation {
			for index in offsets {
				modelContext.delete(items[index])
			}
		}
	}
}

#Preview {
	@Previewable @State var sports = Sports()
	
	ContentView(sports: sports)
		.environmentObject(BLEManager.shared)
		.modelContainer(
			{
				let schema = Schema([Item.self, KnownDevice.self])
				let config = ModelConfiguration(
					schema: schema,
					isStoredInMemoryOnly: true
				)
				return try! ModelContainer(
					for: schema,
					configurations: [config]
				)
			}()
		)
}
