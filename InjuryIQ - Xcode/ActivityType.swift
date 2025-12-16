//
//  ActivityType.swift
//  InjuryIQ - Xcode
//
//  Created by Platts Andrew on 16/12/2025.
//

import Foundation
import SwiftUI
import Observation

enum ActivityType: String, CaseIterable {
	case running = "Running"
	case hiking = "Hiking"
	case racket = "Racket"
	case cycling = "Cycling"
}

struct ActivityButton: Identifiable {
	let id = UUID()
	let type: ActivityType
	let icon: String
	let selectedColor: Color
	let unselectedColor: Color
	
	var name: String {
			type.rawValue
		}
	
	static let activities = [
		ActivityButton(
			type: .running,
			icon: "figure.run",
			selectedColor: .blue,
			unselectedColor: Color(.systemGray6)
		),
		ActivityButton(
			type: .hiking,
			icon: "figure.hiking",
			selectedColor: .blue,
			unselectedColor: Color(.systemGray6)
		),
		ActivityButton(
			type: .racket,
			icon: "figure.tennis",
			selectedColor: .blue,
			unselectedColor: Color(.systemGray6)
		),
		ActivityButton(
			type: .cycling,
			icon: "figure.outdoor.cycle",
			selectedColor: .blue,
			unselectedColor: Color(.systemGray6)
		)
	]
}

@Observable
class Sports {
	var selectedActivity: ActivityType {
		didSet {
			UserDefaults.standard.set(selectedActivity.rawValue, forKey: "selectedActivity")
		}
	}

	init() {
		if let rawValue = UserDefaults.standard.string(forKey: "selectedActivity"),
		   let activity = ActivityType(rawValue: rawValue) {
			self.selectedActivity = activity
		} else {
			self.selectedActivity = .running
		}
	}
}
