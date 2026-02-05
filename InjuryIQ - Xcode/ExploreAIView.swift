import SwiftUI
import _SwiftData_SwiftUI
import CoreBluetooth
import SwiftData
import Combine

struct ExploreAIView: View {
	@EnvironmentObject private var ble: BLEManager
	@Environment(\.modelContext) var modelContext
	@Environment(Session.self) var session
	@Bindable var sports: Sports
	@ObservedObject var mlObject: MLTrainingObject
	@State private var selectedActivity: ActivityType

	init(sports: Sports, mlObject: MLTrainingObject) {
		self.sports = sports
		self._mlObject = ObservedObject(wrappedValue: mlObject)
		_selectedActivity = State(initialValue: sports.selectedActivity)
	}

	var body: some View {
		VStack(alignment: .center, spacing: 16) {
			MLActivityButtons(sports: sports)
				.padding(0)
				//.padding(.top)

			ScrollView() {
				MLObjectHeader(obj: mlObject)
					.overlay(
						RoundedRectangle(cornerRadius: 14)
							.strokeBorder(Color.primary.opacity(0.5))
					)

				if mlObject.sessions.values.flatMap({ $0 }).isEmpty {
					NoMLTraingObjectSessions()
						.padding()
						.overlay(
							RoundedRectangle(cornerRadius: 14)
								.strokeBorder(Color.primary.opacity(0.5))
						)
					//MLObjectFooter(obj: mlObject)
					//	.padding()
					//	.overlay(
					//		RoundedRectangle(cornerRadius: 14)
					//			.strokeBorder(Color.primary.opacity(0.5))
					//	)
				} else {
					mlObjectView(obj: mlObject)
						.padding()
						.overlay(
							RoundedRectangle(cornerRadius: 14)
								.strokeBorder(Color.primary.opacity(0.5))
						)
					//MLObjectFooter(obj: mlObject)
					//	.padding()
					//	.overlay(
					//		RoundedRectangle(cornerRadius: 14)
					//			.strokeBorder(Color.primary.opacity(0.5))
					//	)
				}
			}
		}
		.padding()
		.frame(maxHeight: .infinity, alignment: .top)
		.onAppear {
			let activity = sports.selectedActivity
			if selectedActivity != activity {
				selectedActivity = activity
			}
			// Ensure export reflects current object when view appears (debounced)
			mlObject.debounceExport()
		}
		.onChange(of: sports.selectedActivity) { _, newValue in
			selectedActivity = newValue
		}
		.onChange(of: mlObject.sessions) { _, _ in
			// Coalesce export writes when session data changes
			mlObject.debounceExport()
		}
		.onChange(of: mlObject) { _, _ in
			// Defensive: keep export fresh after wholesale object updates
			mlObject.debounceExport()
		}
	}
}


struct MLActivityButtons: View {
	@Bindable var sports: Sports
	@Environment(Session.self) var session

	var body: some View {
		ScrollViewReader { proxy in
			ScrollView(.horizontal, showsIndicators: false) {
				HStack(spacing: 12) {
					ForEach(ActivityButton.activities) { activity in
						Button {
							sports.selectedActivity = activity.type
						} label: {
							VStack {
								Image(systemName: activity.icon)
									.font(.title2)
								Text(activity.name)
									.font(.caption)
							}
							.frame(width: 50, height: 50)
							.padding()
							.background( sports.selectedActivity == activity.type ? activity.selectedColor : activity.unselectedColor )
							.foregroundColor( sports.selectedActivity == activity.type ? .white : .primary )
							.cornerRadius(10)
						}
						.id(activity.type)
						.disabled(session.state == .running)
					}
				}
			}
			.padding(0)
			.onAppear { proxy.scrollTo(sports.selectedActivity, anchor: .center) }
			.onChange(of: sports.selectedActivity) { _, newValue in
				proxy.scrollTo(newValue, anchor: .center)
			}
		}
	}
}

struct MLObjectHeader: View {
	@ObservedObject var obj: MLTrainingObject
	var headerFontSize: CGFloat = 20
	var chipHeight: CGFloat = 28

	var body: some View {
			VStack(spacing: 16) {
				HStack() {
					Image(systemName: obj.type.icon)
						.font(.system(size: chipHeight, weight: .semibold))
						.foregroundStyle(obj.type.activityColor)
						.frame(width: chipHeight, height: chipHeight)
						.padding(.leading, -5)
						.padding(.trailing, 4)
					VStack(alignment: .leading, spacing: 2) {
						Text(obj.type.descriptor)
							.font(.system(size: headerFontSize, weight: .heavy))
					}
					Spacer()
					Text(obj.active ? "Active" : "Complete")
						.font(.subheadline.weight(.semibold))
						.padding(.horizontal, 10)
						.frame(height: chipHeight)
						.background(Capsule().fill((obj.active ? Color.green : Color.orange).opacity(0.18)))
						.overlay(Capsule().stroke((obj.active ? Color.green : Color.orange).opacity(0.35)))
				}
				
				HStack(){
					Image(systemName: obj.trainingType == .distance ? "ruler" : "clock")
						.font(.system(size: chipHeight, weight: .semibold))
						.foregroundStyle(.blue)
						.frame(width: chipHeight-10, height: chipHeight-10)
						.padding(.trailing, 10)
					Text(obj.trainingType == .distance ? "Distance:" : "Interval:")
						.font(.footnote)
					Text(obj.trainingType == .distance ? "\(obj.distance)km" : "\(String(format: "%.1f", obj.setDuration))min")
						.font(.footnote)
					Spacer()
					shareButton(obj: obj)
				}
				.frame(maxWidth: .infinity, alignment: .leading)
				.font(.subheadline)
				.foregroundStyle(.secondary)
					//Spacer()
				HStack(){
					Image(systemName: "chart.xyaxis.line")
						.font(.system(size: chipHeight, weight: .semibold))
						.foregroundStyle(.blue)
						.frame(width: chipHeight-10, height: chipHeight-10)
						.padding(.trailing, 10)
					Text("\(obj.sets) sets ")
						.font(.footnote)
					Spacer()
					resetButton(obj: obj)
				}
				.frame(maxWidth: .infinity, alignment: .leading)
				.font(.subheadline)
				.foregroundStyle(.secondary)
		}
		.padding(20)
	}
}

struct shareButton: View {
	@ObservedObject var obj: MLTrainingObject
	@Environment(Session.self) var session
	
	var headerFontSize: CGFloat = 20
	var chipHeight: CGFloat = 20
	var body: some View {
		HStack(){
			ShareLink(item: obj.exportURL) {
				Image(systemName: "square.and.arrow.up")
					.resizable()
					.scaledToFit()
					.frame(width: chipHeight, height: chipHeight)
					.padding(10)
			}
			.disabled(session.state == .running)
			.background(.ultraThinMaterial, in: Circle())
			.overlay(
				Circle()
					.stroke(Color.white.opacity(0.2), lineWidth: 1)
			)
			.shadow(radius: 8)
		}
	}
}

struct resetButton: View {
	@ObservedObject var obj: MLTrainingObject
	@Environment(Session.self) var session
	
	var headerFontSize: CGFloat = 20
	var chipHeight: CGFloat = 20
	var body: some View {
		HStack(){
			Button(action: {
				let activity = obj.type
				try? MLTrainingObject.reset(type: activity)
				if let newObj = try? MLTrainingObject.load(type: activity) {
					obj.update(from: newObj)
					// Ensure export is updated after reset (debounced)
					obj.debounceExport()
				}}) {
				Image(systemName: "arrow.trianglehead.clockwise")
					.resizable()
					.scaledToFit()
					.frame(width: chipHeight, height: chipHeight)
					.padding(10)
			}
			.disabled(session.state == .running)
			.background(.ultraThinMaterial, in: Circle())
			.overlay(
				Circle()
					.stroke(Color.white.opacity(0.2), lineWidth: 1)
			)
			.shadow(radius: 8)
		}
	}
}


struct MLObjectFooter: View {
	@ObservedObject var obj: MLTrainingObject
	var headerFontSize: CGFloat = 20
	var chipHeight: CGFloat = 28

	var body: some View {
		HStack(){
			ShareLink(item: obj.exportURL) {
				Image(systemName: "square.and.arrow.up")
					.resizable()
					.scaledToFit()
					.frame(width: chipHeight, height: chipHeight)
					.padding()
			}
			.background(.ultraThinMaterial, in: Circle())
			.overlay(
				Circle()
					.stroke(Color.white.opacity(0.2), lineWidth: 1)
			)
			.shadow(radius: 8)

			//Spacer()

			Button(action: {
				let activity = obj.type
				try? MLTrainingObject.reset(type: activity)
				if let newObj = try? MLTrainingObject.load(type: activity) {
					obj.update(from: newObj)
					// Ensure export is updated after reset (debounced)
					obj.debounceExport()
				}}) {
				Image(systemName: "arrow.trianglehead.clockwise")
					.resizable()
					.scaledToFit()
					.frame(width: chipHeight, height: chipHeight)
					.padding()
			}
			.background(.ultraThinMaterial, in: Circle())
			.overlay(
				Circle()
					.stroke(Color.white.opacity(0.2), lineWidth: 1)
			)
			.shadow(radius: 8)

		}
		//.padding()
	}
}

struct mlObjectView: View {
	@ObservedObject var obj: MLTrainingObject

	var chipHeight: CGFloat = 35

	var body: some View {
		ForEach(obj.sessions.sorted(by: { $0.key.displayName < $1.key.displayName }), id: \.key) { location, sessions in
			VStack(alignment: .leading, spacing: 0) {

				let freq = sessions.averageFrequencyHz ?? 0.0
				let countText = "\(sessions.count)/\(obj.sets)"
				let freqText = String(format: "%.1f Hz", freq)

				HStack(spacing: 6) {
					location.iconView
					Text("\(location.displayName)")
					Text("\(countText)  •  \(freqText)")
				}
				.font(.subheadline.weight(.semibold))
				.frame(height: chipHeight)
				.frame(maxWidth: .infinity, alignment: .center)
				.foregroundColor(.white)
				.background(Capsule().fill((Color.blue).opacity(1)))
				.overlay(Capsule().stroke((Color.blue).opacity(1)))

				VStack(spacing: 0) {
					ForEach(Array(sessions.enumerated()), id: \.element.id) { index, session in
						FatigueSelector(obj: obj, location: location, session: session, index: index)
					}
				}
				.font(.caption)
				.foregroundColor(.secondary)

			}
		}
	}
}

struct FatigueSelector: View {
	@ObservedObject var obj: MLTrainingObject
	var chipHeight: CGFloat = 28
	let location: Location
	let session: mlTrainingSession
	let index: Int

	var body: some View {
		GeometryReader { geometry in
			ZStack {
				HStack(spacing: 0) {
					Spacer()
					ForEach([mlFatigueLevel.fresh, .moderate, .fatigued, .exhausted], id: \.self) { level in
						Button(action: {
							if var sessionsForLocation = obj.sessions[location],
							   let sessIdx = sessionsForLocation.firstIndex(where: { $0.id == session.id }) {
								var updatedSession = sessionsForLocation[sessIdx]
								updatedSession.fatigue = level
								sessionsForLocation[sessIdx] = updatedSession
								obj.sessions[location] = sessionsForLocation
								try? obj.save()
								// Debounced export instead of immediate write
								obj.debounceExport()
							}
						}) {
							Image(systemName: level.iconName)
								.resizable()
								.scaledToFit()
								.frame(width: chipHeight, height: chipHeight)
								.padding()
								.foregroundColor(Color(session.fatigue == level ? level.fatigueColor : .gray ))
						}
						.background(.ultraThinMaterial, in: Circle())
						.overlay(
							Circle()
								.stroke(Color(session.fatigue == level ? level.fatigueColor : Color.white.opacity(0.2)), lineWidth: 1))
						.shadow(radius: 8)
						.frame(maxWidth: .infinity)
						if level != .exhausted { Spacer() }
					}
				}
				.padding()
				.overlay(
					RoundedRectangle(cornerRadius: 14)
						.strokeBorder(Color.primary.opacity(0.25))
				)

				Text("Fatigue (Set:\(index + 1 ))")
					.font(.caption.bold())
					.padding(.horizontal, 8)
					.background(Color(.systemBackground))
					.position(x: geometry.size.width / 2, y: 0)
			}
			.frame(maxWidth: .infinity)
		}
		.frame(height: 80)
		.padding(.vertical)
	}
}

struct NoMLTraingObjectSessions: View {
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

///Preview
extension MLTrainingObject {
	static var preview: MLTrainingObject {
		let sessionA = mlTrainingSession(
			id: UUID(),
			data: Data(),
			fatigue: .moderate
		)
		let sessionB = mlTrainingSession(
			id: UUID(),
			data: Data(),
			fatigue: .exhausted
		)
		let sessionC = mlTrainingSession(
			id: UUID(),
			data: Data(),
			fatigue: .fresh
		)
		return MLTrainingObject(
			type: .running,
			sessions: [.leftfoot: [sessionC, sessionB, sessionA], .rightfoot: [sessionC, sessionB, sessionA]],
			distance: 5,
			sets: 2,
			setDuration: 10
		)
	}
}


#Preview {
	let previewObj = MLTrainingObject.preview
	try? previewObj.save()
	
	let sports = Sports()
	sports.selectedActivity = .skiing
	
	let previewSession = Session(mlTrainingObject: MLTrainingObject(type: .running))
	previewSession.state = .stopped // Toggle to test disabled state
	
	return ExploreAIView(sports: sports, mlObject: previewObj)
		.environmentObject(BLEManager.shared)
		.environment(previewSession)
}
