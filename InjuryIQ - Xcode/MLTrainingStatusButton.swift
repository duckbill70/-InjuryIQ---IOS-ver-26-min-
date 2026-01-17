import SwiftUI

struct MLTrainingStatusButton: View {
	@Bindable var sports: Sports
	@ObservedObject var mlObject: MLTrainingObject = MLTrainingObject(type: .running)

	@State private var timer: Timer? = nil
	@State private var pageIndex = 0

	private let dataPoints: Int = 3000
	private let interval: TimeInterval = 2.0 // seconds

	// Compose the pages to rotate through: text (if any), then sparkles
	private var pages: [AnyView] {
		var result: [AnyView] = []
		if mlObject.distnace > 0 {
			result.append(AnyView(
				Text("\(Int(mlObject.distnace))km")
					.font(.system(size: 16, weight: .semibold))
					.frame(width: 56, height: 56)
					.foregroundColor(.white)
			))
		}
		if mlObject.setDuration > 0 {
			result.append(AnyView(
				Text("\(Int(mlObject.setDuration))min")
					.font(.system(size: 16, weight: .semibold))
					.frame(width: 56, height: 56)
					.foregroundColor(.white)
			))
		}
		// Always Add seesions of Sessions
		result.append(AnyView(
			Text("\(Int(mlObject.sessions.count))/\(Int(mlObject.sets))")
				.font(.system(size: 16, weight: .semibold))
				.frame(width: 56, height: 56)
				.foregroundColor(.white)
		))
		// Always add sparkles as a page
		result.append(AnyView(
			Image(systemName: "sparkles")
				.font(.system(size: 22, weight: .semibold))
				.frame(width: 56, height: 56)
				.foregroundColor(.white)
		))
		return result
	}

	private var buttonColor: Color {
		if mlObject.sessions.isEmpty {
			return .blue
		} else if mlObject.sessions.allSatisfy({ $0.dataPointsCount >= dataPoints }) {
			return .green
		} else {
			return .orange
		}
	}

	var body: some View {
		ZStack(alignment: .topTrailing) {
			Button(action: {
				try? MLTrainingObject.reset(type: sports.selectedActivity)
			}) {
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
				.background(buttonColor.opacity(0.5))
				.clipShape(Circle())
				.shadow(radius: 4)
				.overlay(
					Circle().stroke(buttonColor, lineWidth: 1)
				)
				.contentShape(Circle())
			}
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
		.onChange(of: mlObject.distnace) { _, _ in
			resetPages()
		}
		.onChange(of: mlObject.setDuration) { _, _ in
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
