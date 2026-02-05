//
//  ContentView.swift
//  InjuryIQ - Xcode
//
//  Created by Platts Andrew on 13/12/2025.
//

import SwiftData
import SwiftUI
import CoreBluetooth


struct ContentView: View {
	@Environment(\.modelContext) var modelContext
	@EnvironmentObject private var ble: BLEManager
	@Query private var items: [Item]
	@Bindable var sports: Sports
	@Environment(Session.self) var session

	init(sports: Sports) {
		self._sports = Bindable(wrappedValue: sports)
	}
	
	var body: some View {
		TabView {
			NavigationStack {
				VStack(spacing: 16) {
					
					if session.state == .stopped {
						activityButtons
							.padding(.horizontal)
							.padding(.top)
							.transition(
								.asymmetric(
									insertion: .scale(scale: 1, anchor: .center).combined(with: .opacity),
									removal: .scale(scale: 0.8, anchor: .center).combined(with: .opacity)
								)
							)
					}
					
					Spacer()
					
					let leftFootSession = ble.sessionsByPeripheral.values.first(where: { $0.location == .leftfoot })
					let rightFootSession = ble.sessionsByPeripheral.values.first(where: { $0.location == .rightfoot })
					
					var iconName : String {
						switch session.mlTrainingObject.trainingType {
						case .distance: return "ruler"
						case .duration: return "timer"
						}
					}

					SessionStatusIndicator(
						leftDeviceStatus: leftDeviceStatusForUI(),
						rightDeviceStatus: rightDeviceStatusForUI(),
						leftFatiguePct: leftFootSession?.data.fatiguePercent.map(Double .init),
						rightFatiguePct: rightFootSession?.data.fatiguePercent.map(Double .init),
						leftConnected: ble.connectedPeripherals.contains { $0.identifier == leftFootSession?.peripheral.identifier },
						rightConnected: ble.connectedPeripherals.contains { $0.identifier == rightFootSession?.peripheral.identifier },
						duration: session.duration,
						distance: session.locationManager.totalDistance / 1000, // for kilometers,
						speed: session.currentSpeedKmph,
						sessionState: session.state,
						activity: sports.selectedActivity,
						subtitle: session.snapshotCountdown,
						subtitleIconName: iconName
					)
					.frame(width: 320)
					Spacer()
					
					if session.state != .stopped {
						SessionStatsView(session: session)
							.frame(maxWidth: .infinity)
							.padding(.horizontal)
							.transition(
								.asymmetric(
									insertion: .scale(scale: 1, anchor: .center).combined(with: .opacity),
									removal: .scale(scale: 0.8, anchor: .center).combined(with: .opacity)
								)
							)
						Spacer()
					}
					
					HStack {
						DummyButton()
						Spacer()
						SessionControlButton(
							selectedActivity: sports.selectedActivity.rawValue
						)
						Spacer()
						MLTrainingStatusButton(
							sports: sports,
							mlObject: session.mlTrainingObject,
							onReset: {
								// Reset on disk, then update the same in-memory instance so observers update.
								if let _ = try? MLTrainingObject.reset(type: session.type),
								   let newObj = try? MLTrainingObject.load(type: session.type) {
									session.mlTrainingObject.update(from: newObj)
								}
							}
						)
					}
					.padding(.horizontal)
					
					Spacer()
					if session.state == .stopped {
						DeviceManager(ble: ble)
							.transition(
								.asymmetric(
									insertion: .scale(scale: 1, anchor: .center).combined(with: .opacity),
									removal: .scale(scale: 0.8, anchor: .center).combined(with: .opacity)
								)
							)
					}
					
				}
				.animation(.easeInOut(duration: 1.0), value: session.state)
				.frame(maxWidth: .infinity, maxHeight: .infinity)
			}
			.toolbar(.hidden, for: .navigationBar)
			.tabItem { Label("Home", systemImage: "house") }
			
			// AI tab
			NavigationStack {
				ExploreAIView(sports: sports, mlObject: session.mlTrainingObject)
			}
			.toolbar(.hidden, for: .navigationBar)
			.tabItem { Label("AI", systemImage: "atom") }

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
			session.attach(modelContext: modelContext)
			if session.logger.modelContext == nil {
				session.logger.attach(modelContext: modelContext)
			}
			if ble.modelContext == nil {
				ble.attach(modelContext: modelContext)
				print("[ContentView] Attached BLE to view modelContext")
			}
			if session.logger.modelContext == nil {
				session.attach(modelContext: modelContext)
			}
			// Ensure session type tracks selected activity; Session will load/update its MLTrainingObject.
			if session.type != sports.selectedActivity {
				session.type = sports.selectedActivity
			}
			if BLEManager.shared.session !== session {
				BLEManager.shared.attachSession(session)
			}
			session.locationManager.requestAuthorization()
		}
		.onChange(of: sports.selectedActivity) { _, newActivity in
			// Single source of truth: update session.type; Session updates mlTrainingObject via update(from:)
			session.type = newActivity
		}

	}
	

	func setIMUProfile(for activity: ActivityType) {
		//print("[ContentView] setIMUProfile called for \(activity)")
		guard let profileCode = ImuProfile.from(activity: activity)?.rawValue else { return }
		for session in ble.sessionsByPeripheral.values {
			let data = Data([0x05, profileCode])
			let hexString = data.map { String(format: "%02X", $0) }.joined(separator: " ")
			if let char = session.characteristics[CharKey(
				service: PeripheralSession.commandServiceUUID,
				characteristic: PeripheralSession.commandCharUUID
			)] {
				print("[ContentView] setIMUProfile writeValue to \(session.peripheral.identifier) data (\(data.count) bytes): \(hexString)")
				session.peripheral.writeValue(data, for: char, type: .withResponse)
			}
		}
	}
	
	private var activityButtons: some View {
		
		
		ScrollViewReader { proxy in
			ScrollView(.horizontal, showsIndicators: false) {
				HStack(spacing: 12) {
					ForEach(ActivityButton.activities) { activity in
						Button(
							action: {
								
								
								///Set the sport
								sports.selectedActivity = activity.type
								
								///
								setIMUProfile(for: activity.type)
								
							}
						) {
							VStack {
								Image(systemName: activity.icon)
									.font(.title2)
								Text(activity.name)
									.font(.caption)
							}
							.frame(width: 50, height: 50)
							.padding()
							.background(
								sports.selectedActivity == activity.type
								? activity.selectedColor
								: activity.unselectedColor
							)
							.opacity(session.state == .running ? 0.5 : 1.0)
							.foregroundColor(
								sports.selectedActivity == activity.type
								? .white
								: .primary
							)
							.cornerRadius(10)
						}
						.disabled(session.state == .running)
						.id(activity.type)
					}
				}
				.padding(0)
				.onAppear {
					proxy.scrollTo(sports.selectedActivity, anchor: .center)
				}
				.onChange(of: sports.selectedActivity) { _, newValue in
					proxy.scrollTo(newValue, anchor: .center)
				}
			}
		}
	}
	
	private func deviceTable() -> some View {
		ScrollView(.horizontal, showsIndicators: false) {
			HStack(spacing: 12) {
				ForEach(
					Array(ble.sessionsByPeripheral.values),
					id: \.peripheral.identifier
				) { session in
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

private extension ContentView {
	@MainActor
	func leftDeviceStatusForUI() -> DeviceStatus? {
		let left = ble.sessionsByPeripheral.values.first(where: { $0.location == .leftfoot })
		return left?.data.command.map(DeviceStatus.init(from:))
	}
	@MainActor
	func rightDeviceStatusForUI() -> DeviceStatus? {
		let right = ble.sessionsByPeripheral.values.first(where: { $0.location == .rightfoot })
		return right?.data.command.map(DeviceStatus.init(from:))
	}
}

#Preview {
	@Previewable @State var sports = Sports()
	@Previewable @State var session = Session(mlTrainingObject: MLTrainingObject(type: .running))
	
	ContentView(sports: sports)
		.environmentObject(BLEManager.shared)
		.environment(session)
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

