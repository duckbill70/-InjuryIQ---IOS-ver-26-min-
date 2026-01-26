
import SwiftUI
import _SwiftData_SwiftUI
import CoreBluetooth
import SwiftData

struct OLDExploreAIView: View {
	
    @EnvironmentObject private var ble: BLEManager
    @Environment(\.modelContext) var modelContext
	@State private var mlObjects: [MLTrainingObject] = []
	
	@Bindable var sports: Sports
	@State private var selectedActivity: ActivityType = .hiking
	
	init(sports: Sports, previewObjects: [MLTrainingObject] = []) {
		   self._sports = Bindable(wrappedValue: sports)
		   self._mlObjects = State(initialValue: previewObjects)
	   }
	
    var body: some View {
        VStack(spacing: 0) {
			//if mlObjects.isEmpty {
			//	MLTrainingObjectEmptyView()
			//		.frame(maxWidth: .infinity, maxHeight: .infinity)
			//} else {
				ScrollView {
					
					OLDMLActivityButtons(selectedActivity: $selectedActivity)
						.padding(.horizontal)
						.padding(.top)

					if let obj = mlObjects.first(where: { $0.type == selectedActivity }) {
						OLDMLTrainingObjectCard(obj: obj, sports: sports) {
							loadMLObjects()
						}
					} else {
						OLDMLTrainingObjectEmptyView()
							.frame(maxWidth: .infinity, maxHeight: .infinity)
					}
					
					
					LazyVStack(spacing: 12, pinnedViews: []) {
						ForEach(mlObjects, id: \.uuid) { obj in
							OLDMLTrainingObjectCard(obj: obj, sports: sports) {
								loadMLObjects()
							}
						}
					}
					.padding(.horizontal)
					.padding(.top, 12)
					.padding(.bottom, 24)
				}
			//}
        }
		.onAppear { loadMLObjects() }
        .navigationDestination(for: DiscoveredPeripheral.self) { dp in
            PeripheralDetailView(dp: dp)
        }
		.onChange(of: selectedActivity) { oldValue, newValue in
			print("selectedActivity changed from \(oldValue) to \(newValue)")
		}
    }
	
	private func loadMLObjects() {
		var loaded: [MLTrainingObject] = []
		for type in ActivityType.allCases {
			if let obj = try? MLTrainingObject.load(type: type) {
				loaded.append(obj)
			}
		}
		mlObjects = loaded
	}
}

struct OLDMLTrainingObjectCard: View {
	@ObservedObject var obj: MLTrainingObject
	let sports : Sports
	var onReset: (() -> Void)?
	
	private let headerFontSize: CGFloat = 20
	private let chipHeight: CGFloat = 32
	private let actionSize: CGFloat = 48

	var body: some View {
		VStack(alignment: .leading, spacing: 12) {
			// Header
			HStack(spacing: 12) {
				Image(systemName: obj.type.icon)
					.font(.system(size: 24, weight: .semibold))
					.foregroundStyle(obj.type.activityColor)
					.frame(width: 28)
				VStack(alignment: .leading, spacing: 2) {
					Text(obj.type.descriptor)
						.font(.system(size: headerFontSize, weight: .heavy))
					Text(obj.trainingType == .distance ? "\(obj.distance) km" : "\(obj.setDuration) min")
						.font(.subheadline)
						.foregroundStyle(.secondary)
				}
				Spacer()
				Text(obj.active ? "Active" : "Complete")
					.font(.subheadline.weight(.semibold))
					.padding(.horizontal, 10).frame(height: chipHeight)
					.background(Capsule().fill((obj.active ? Color.green : Color.orange).opacity(0.18)))
					.overlay(Capsule().stroke((obj.active ? Color.green : Color.orange).opacity(0.35)))
			}
			
			// Sessions per location
			VStack(alignment: .leading, spacing: 8) {
				ForEach(obj.sessions.sorted(by: { $0.key.displayName < $1.key.displayName }), id: \.key) { location, sessions in
					HStack(spacing: 12) {
						HStack(spacing: 6) {
							location.iconView
							Text(location.displayName)
						}
						//.frame(width: 150)
						.font(.subheadline.weight(.semibold))
						.padding(.horizontal, 10).frame(height: chipHeight)
						.background(Capsule().fill(obj.type.activityColor.opacity(0.12)))
						.overlay(Capsule().stroke(obj.type.activityColor.opacity(0.3)))
						
						Spacer(minLength: 8)
						
						let freq = sessions.averageFrequencyHz ?? 0.0
						let countText = "\(sessions.count)/\(obj.sets)"
						let freqText = String(format: "%.1f Hz", freq)
						
						Text("\(countText)  •  \(freqText)")
							.font(.footnote.monospacedDigit())
							.padding(.horizontal, 10).frame(height: chipHeight)
							.background(Capsule().fill((obj.active ? Color.green : Color.orange).opacity(0.12)))
							.overlay(Capsule().stroke((obj.active ? Color.green : Color.orange).opacity(0.3)))
					}
				}
			}
			.padding(.vertical, 12)
			
			//Divider().padding(.vertical, 4)
			
			// Actions
			HStack(spacing: 12) {
				// Reset
				if !obj.sessions.isEmpty {
					Button {
						let activity = obj.type
						try? MLTrainingObject.reset(type: activity)
						if let newObj = try? MLTrainingObject.load(type: activity) {
							obj.update(from: newObj)
							onReset?()
						}
					} label: {
						Image(systemName: "arrow.counterclockwise")
							.font(.system(size: 22, weight: .semibold))
							.frame(width: actionSize, height: actionSize)
							.background(Circle().fill(Color.red.opacity(0.12)))
							.foregroundStyle(Color.red)
							.overlay(Circle().stroke(Color.red.opacity(0.35)))
					}
					.buttonStyle(.plain)
					.accessibilityLabel(Text("Reset Training Data"))
				}
				
				Spacer()
				
				// Share (stable export)
				if !obj.active {
					ShareLink(item: obj.exportURL) {
						Image(systemName: "square.and.arrow.up")
							.font(.system(size: 22, weight: .semibold))
							.frame(width: 48, height: 48)
							.background(Circle().fill(Color.blue.opacity(0.12)))
							.foregroundStyle(Color.blue)
							.overlay(Circle().stroke(Color.blue.opacity(0.35)))
					}
					.buttonStyle(.plain)
					.accessibilityLabel(Text("Share Training Export"))
				}
			}
		}
		.padding(14)
		.background(
			RoundedRectangle(cornerRadius: 14)
				.fill(Color(.secondarySystemBackground))
		)
		.overlay(
			RoundedRectangle(cornerRadius: 14)
				.strokeBorder(Color.primary.opacity(0.08))
		)
		.onAppear() {
			try? obj.writeExport()
		}
		.onChange(of: obj.sessions) { _, _ in
			try? obj.writeExport()
		}
	}

}

struct OLDMLActivityButtons: View {
	
	@Binding var selectedActivity: ActivityType

	var body: some View {
		HStack(spacing: 12) {
			ForEach(ActivityButton.activities) { activity in
				Button {
					selectedActivity = activity.type
				} label: {
					VStack {
						Image(systemName: activity.icon)
							.font(.title2)
						Text(activity.name)
							.font(.caption)
					}
					.frame(maxWidth: .infinity)
					.padding()
					.background(
						selectedActivity == activity.type
						? activity.selectedColor
						: activity.unselectedColor
					)
					.foregroundColor(
						selectedActivity == activity.type
						? .white
						: .primary
					)
					.cornerRadius(10)
				}
			}
		}
	}
}

struct OLDMLTrainingObjectEmptyView: View {
	var body: some View {
		VStack(spacing: 16) {
			Image(systemName: "tray")
				.font(.system(size: 48))
				.foregroundColor(.gray)
			Text("No Training Data")
				.font(.title3)
				.foregroundColor(.gray)
			Text("You haven't recorded any ML training sessions yet.")
				.font(.body)
				.foregroundColor(.secondary)
				.multilineTextAlignment(.center)
				.frame(maxWidth: .infinity)
		}
		.padding()
	}
		
}

//#Preview {
//	let sports = Sports()
//	sports.selectedActivity = .hiking // Set preview to hiking/
//
//	let dummySession = mlTrainingSession(id: UUID(), data: Data())
//	let dummyMLObject = MLTrainingObject(
//		type: .hiking,
//		sessions: [
//			.leftfoot: [dummySession, dummySession],
//			.rightfoot: [dummySession, dummySession]
//		],
//		distance: 0,
//		sets: 3,
//		setDuration: 30
//	)
//	return ExploreAIView(sports: sports, previewObjects: [dummyMLObject])
//		.environmentObject(BLEManager.shared)
//}

//Preview {
//	ExploreAIView(sports: Sports())
 //       .environmentObject(BLEManager.shared)
//}
