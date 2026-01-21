import SwiftUI
import Combine

struct MLTrainingStatusButton: View {
	@Bindable var sports: Sports
	@ObservedObject var mlObject: MLTrainingObject

	@State private var timer: Timer? = nil
	@State private var pageIndex = 0

	private let dataPoints: Int = 3000
	private let interval: TimeInterval = 2.0 // seconds
	
	var onReset: (() -> Void)?
	
	private let size: CGFloat = 70

	// Compose the pages to rotate through: text (if any), then sparkles
	private var pages: [AnyView] {
		var result: [AnyView] = []
		
		if mlObject.distance > 0 {
			result.append(AnyView(
				Text("\(Int(mlObject.distance))km")
					.font(.system(size: 16, weight: .semibold))
					.frame(width: size, height: size)
					.foregroundColor(.white)
			))
		}
		
		if mlObject.setDuration > 0 {
			result.append(AnyView(
				Text("\(Int(mlObject.setDuration))min")
					.font(.system(size: 16, weight: .semibold))
					.frame(width: size, height: size)
					.foregroundColor(.white)
			))
		}
		
		// Add seesions of Sessions
		let locations: [Location] = [.leftfoot, .rightfoot]
		
		//let totalSets = locations.reduce(0) { $0 + (mlObject.sessions[$1]?.count ?? 0) }
		//let maxSets = mlObject.sets * locations.count
		//result.append(AnyView(
		//	VStack{
		//		Text("\(totalSets)/\(maxSets)")
		//			.font(.system(size: 16, weight: .semibold))

		//		Text("sets")
		//			.font(.system(size: 10, weight: .semibold))
		//	}
		//		.frame(width: 56, height: 56)
		//		.foregroundColor(.white)
		//))
		
		//Add Locations
		for location in locations {
			result.append(AnyView(
				VStack{
					Text("\(mlObject.sessions[location]?.count ?? 0)/\(mlObject.sets)")
						.font(.system(size: 16, weight: .semibold))
					location.iconView
				}
				.frame(width: size, height: size)
				.foregroundColor(.white)
			))
		}
		
		// Always add sparkles as a page
		result.append(AnyView(
			Image(systemName: "sparkles")
				.font(.system(size: 26, weight: .semibold))
				.frame(width: size, height: size)
				.foregroundColor(.white)
		))
		return result
	}

	private var buttonColor: Color {
		if mlObject.sessions.isEmpty {
			return .blue
		} else if !mlObject.active {
			return .green
		} else {
			return .orange
		}
	}

	var body: some View {
		
		ZStack(alignment: .topTrailing) {
			//Button(
			//	action: {
					//try? MLTrainingObject.reset(type: sports.selectedActivity)
					//if let newObj = try? MLTrainingObject.load(type: sports.selectedActivity) {
					//	mlObject.update(from: newObj)
					//	onReset?() // Notify parent/session
					//}
			//	}
			//) {
				ZStack {
					if !pages.isEmpty {
						pages[pageIndex % pages.count]
							.id(pageIndex % pages.count)
							.transition(.asymmetric(
								insertion: .move(edge: .top).combined(with: .opacity),
								removal: .move(edge: .bottom).combined(with: .opacity)
							))
					}
				}
				.animation(.easeInOut, value: pageIndex)
				.background(Color(buttonColor).opacity(0.5))
				.clipShape(Circle())
				.shadow(radius: 4)
				.overlay(
					Circle().stroke(Color(buttonColor), lineWidth: 1)
				)
				.contentShape(Circle())
			//}
			
			///Notification Dot
			//if mlObject.sets > 0 {
			//	Text("\(mlObject.sessions.count)")
			//		.font(.caption2)
			//		.foregroundColor(.white)
			//		.padding(6)
			//		.background(mlObject.sessions.count == mlObject.sets ? Color.green : Color.red)
			//		.clipShape(Circle())
			//		.offset(x: 0, y: -10)
			//}
		}
		.onAppear {
			startTimer()
		}
		.onDisappear {
			timer?.invalidate()
			timer = nil
		}
		//.onChange(of: mlObject.distance) { _, _ in
		//	resetPages()
		//}
		//.onChange(of: mlObject.setDuration) { _, _ in
		//	resetPages()
		//}
		//.onChange(of: mlObject.sessions) { _, _ in
		//	resetPages()
		//}
		//.onChange(of: mlObject.active) { _, _ in
		//	resetPages()
		//}
		.onReceive(mlObject.objectWillChange) { _ in
			resetPages()
		}
	}

	private func startTimer() {
		timer?.invalidate()
		timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
			withAnimation {
				pageIndex = (pageIndex + 1) % max(pages.count, 1)
			}
		}
	}

	private func resetPages() {
		pageIndex = 0
		startTimer()
	}
}

#Preview {
	let dummySports = Sports()
	var dummyMLObject = MLTrainingObject(type: .running, sets: 3)
	MLTrainingStatusButton(sports: dummySports, mlObject: dummyMLObject)
}
