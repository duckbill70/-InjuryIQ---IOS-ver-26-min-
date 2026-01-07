
//
//  TrainingStatusButton.swift
//  InjuryIQ - Xcode
//
//  Created by Platts Andrew on 05/01/2026.
//


import SwiftUI

struct MLTrainingStatusButton: View {
	
    @Bindable var sports: Sports
    @ObservedObject var mlObject: MLTrainingObject = MLTrainingObject(type: .running)
	
	@State private var showDetails = false
	@State private var showText = false
	@State private var timer: Timer? = nil

	
	private let dataPoints : Int = 3000
	private let interval: TimeInterval = 2.0 // seconds

    // Determine color based on sessions
    private var buttonColor: Color {
        if mlObject.sessions.isEmpty {
            return .blue
        } else if mlObject.sessions.allSatisfy({ $0.dataPointsCount >= dataPoints }) {
            return .green
        } else {
            return .orange
        }
    }
	
	private var displayText: String? {
			if mlObject.distnace > 0 {
				//return String(format: "%.1f km", mlObject.distnace)
				return "\(Int(mlObject.distnace))km"
			} else if mlObject.setDuration > 0 {
				return "\(Int(mlObject.setDuration))min"
			}
			return nil
		}

	var body: some View {
		ZStack(alignment: .topTrailing) {
			Button(action: {
				try? MLTrainingObject.reset(type: sports.selectedActivity)
			}) {
				ZStack {
					if showText, let text = displayText {
						Text(text)
							.font(.system(size: 16, weight: .semibold))
							.frame(width: 56, height: 56)
							.foregroundColor(.white)
					} else {
						Image(systemName: "sparkles")
							.font(.system(size: 22, weight: .semibold))
							.frame(width: 56, height: 56)
							.foregroundColor(.white)
					}
				}
				.background(buttonColor.opacity(0.5))
				.clipShape(Circle())
				.shadow(radius: 4)
				.overlay(
					Circle().stroke(buttonColor, lineWidth: 1)
				)
				.contentShape(Circle())
			}
			if mlObject.sets > 0 {
				Text("\(mlObject.sessions.count)")
					.font(.caption2)
					.foregroundColor(.white)
					.padding(6)
					.background(mlObject.sessions.count == mlObject.sets ? Color.green : Color.red)
					.clipShape(Circle())
					.offset(x: 0, y: -10)
			}
		}
		.onAppear {
			timer?.invalidate()
			timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
				withAnimation {
					showText.toggle()
				}
			}
		}
		.onDisappear {
			timer?.invalidate()
			timer = nil
		}
	}
}

#Preview {
	let dummySports = Sports()
	var dummyMLObject = MLTrainingObject(type: .running, sets: 3)
	MLTrainingStatusButton(sports: dummySports, mlObject: dummyMLObject)
}
