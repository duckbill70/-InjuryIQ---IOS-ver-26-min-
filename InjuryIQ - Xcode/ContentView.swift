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
