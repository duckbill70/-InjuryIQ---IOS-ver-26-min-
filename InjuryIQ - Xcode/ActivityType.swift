//
//  ActivityType.swift
//  InjuryIQ - Xcode
//
//  Created by Platts Andrew on 16/12/2025.
//

import Foundation
import SwiftUI
import Observation

public enum ActivityType: String, Codable, CaseIterable {
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
	var name: String {type.descriptor}
	
	static let activities = [
		ActivityButton(
			type: .running,
			icon: ActivityType.running.icon,
			selectedColor: .blue,
			unselectedColor: Color(.systemGray6)
		),
		ActivityButton(
			type: .hiking,
			icon: ActivityType.hiking.icon,
			selectedColor: .blue,
			unselectedColor: Color(.systemGray6)
		),
		ActivityButton(
			type: .racket,
			icon: ActivityType.racket.icon,
			selectedColor: .blue,
			unselectedColor: Color(.systemGray6)
		),
		ActivityButton(
			type: .cycling,
			icon: ActivityType.cycling.icon,
			selectedColor: .blue,
			unselectedColor: Color(.systemGray6)
		)
	]
}

extension ActivityType {
	
	var descriptor: String {
		switch self {
		case .running: return "Running"
		case .hiking: return "Hiking"
		case .racket: return "Racket"
		case .cycling: return "Cycling"
		}
	}
	
	var icon: String {
		switch self {
		case .running: return "figure.run"
		case .hiking: return "figure.hiking"
		case .racket: return "figure.tennis"
		case .cycling: return "figure.outdoor.cycle"
		}
	}
	
	var mlDistance: Int {
		switch self {
		case .running: return 1
		case .hiking: return 3
		case .racket: return 0
		case .cycling: return 10
		}
	}
	
	var mlSests: Int {
		switch self {
		case .running: return 3
		case .hiking: return 3
		case .racket: return 3
		case .cycling: return 3
		}
	}
	
	var mlDurartion: Int {
		switch self {
		case .running: return 0
		case .hiking: return 0
		case .racket: return 60
		case .cycling: return 0
		}
	}
	
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
