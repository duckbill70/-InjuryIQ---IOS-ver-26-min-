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
		// Move pages computation inside body for reactivity
		let pages: [AnyView] = {
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

			let locations: [Location] = [.leftfoot, .rightfoot]
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

			result.append(AnyView(
				Image(systemName: "sparkles")
					.font(.system(size: 26, weight: .semibold))
					.frame(width: size, height: size)
					.foregroundColor(.white)
			))
			return result
		}()

		ZStack(alignment: .topTrailing) {
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
		}
		.onAppear {
			startTimer()
		}
		.onDisappear {
			timer?.invalidate()
			timer = nil
		}
		//.onReceive(mlObject.objectWillChange) { _ in
		//	resetPages()
		//}
		// Deterministic resets on relevant published changes
		.onChange(of: mlObject.sessions) { _, _ in
			resetPages()
		}
		.onChange(of: mlObject.distance) { _, _ in
			resetPages()
		}
		.onChange(of: mlObject.setDuration) { _, _ in
			resetPages()
		}
		.onChange(of: mlObject.sets) { _, _ in
			resetPages()
		}
	}

	private func startTimer() {
		timer?.invalidate()
		timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
			withAnimation {
				pageIndex = (pageIndex + 1) % max(1, pageCount)
			}
		}
	}

	private func resetPages() {
		pageIndex = 0
		startTimer()
	}

	private var pageCount: Int {
		var count = 0
		if mlObject.distance > 0 { count += 1 }
		if mlObject.setDuration > 0 { count += 1 }
		count += 2 // for leftfoot and rightfoot
		count += 1 // for sparkles
		return count
	}
}

#Preview {
	let dummySports = Sports()
	var dummyMLObject = MLTrainingObject(type: .running, sets: 3)
	MLTrainingStatusButton(sports: dummySports, mlObject: dummyMLObject)
}
