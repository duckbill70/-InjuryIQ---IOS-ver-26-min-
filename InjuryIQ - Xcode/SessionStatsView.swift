//
//  SessionStatsView.swift
//  InjuryIQ - Xcode
//
//  Created by Platts Andrew on 02/02/2026.
//


import SwiftUI
import CoreLocation

struct SessionStatsView: View {

	@Bindable var session: Session

	var body: some View {

		///1 m/s × 3.6 = 3.6 km/h
		
		HStack() {
			VStack(alignment: .leading, spacing: 10) {
				StatItem(label: "Max Speed", value: String(format: "%.1f km/h", max(0, session.locationManager.maxSpeed) * 3.6))
				StatItem(label: "Distance", value: String(format: "%.1f km", session.currentDistance / 1000))
			}
			Spacer()
			VStack(alignment: .leading, spacing: 10) {
				StatItem(label: "Current", value: String(format: "%.1f km/h", session.currentSpeedKmph))
				StatItem(label: "Altitude", value: String(format: "%.0f m", session.locationManager.currentAltitude))
			}
			Spacer()
			VStack(alignment: .leading, spacing: 10) {
				StatItem(label: "Avg Speed", value: String(format: "%.1f km/h", max(0, session.locationManager.averageSpeed) * 3.6))
				StatItem(label: "Pace", value: String(format: "%.1f min/km", session.currentSpeed > 0 ? Double(1000) / (session.currentSpeed * 60) : 0.0))
			}
		}
		.padding(.horizontal)
		.padding(.vertical, 8)
		.background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemGray6)))
		.shadow(radius: 2)
		.frame(maxWidth: .infinity, alignment: .center)
		
		
	}

	func formatDuration(_ duration: TimeInterval) -> String {
		let minutes = Int(duration) / 60
		let seconds = Int(duration) % 60
		return String(format: "%02d:%02d", minutes, seconds)
	}
}

struct StatItem: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.body)
                .bold()
        }
        .frame(minWidth: 80, alignment: .leading)
    }
}

#Preview {
	let mockSession = Session(activityType: .running, mlTrainingObject: MLTrainingObject(type: .running))

	SessionStatsView(session: mockSession)
		.padding()
}
