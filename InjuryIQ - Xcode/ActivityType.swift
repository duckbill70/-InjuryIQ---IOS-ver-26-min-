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
	case skiing = "Skiing"
	case gesture = "Gesture"
}

public enum MLTrainingType {
	case distance
	case duration
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
			selectedColor: ActivityType.running.activityColor,
			unselectedColor: Color(.systemGray6)
		),
		ActivityButton(
			type: .hiking,
			icon: ActivityType.hiking.icon,
			selectedColor: ActivityType.hiking.activityColor,
			unselectedColor: Color(.systemGray6)
		),
		ActivityButton(
			type: .racket,
			icon: ActivityType.racket.icon,
			selectedColor: ActivityType.racket.activityColor,
			unselectedColor: Color(.systemGray6)
		),
		ActivityButton(
			type: .cycling,
			icon: ActivityType.cycling.icon,
			selectedColor: ActivityType.cycling.activityColor,
			unselectedColor: Color(.systemGray6)
		),
		ActivityButton(
			type: .skiing,
			icon: ActivityType.skiing.icon,
			selectedColor: ActivityType.skiing.activityColor,
			unselectedColor: Color(.systemGray6)
		),
		ActivityButton(
			type: .gesture,
			icon: ActivityType.gesture.icon,
			selectedColor: ActivityType.gesture.activityColor,
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
		case .skiing: return "Skiing"
		case .gesture: return "Raw"
		}
	}
	
	var icon: String {
		switch self {
		case .running: return "figure.run"
		case .hiking: return "figure.hiking"
		case .racket: return "figure.tennis"
		case .cycling: return "figure.outdoor.cycle"
		case .skiing: return "figure.skiing.downhill"
		case .gesture: return "gyroscope"
		}
	}
	
	var activityColor: Color {
		switch self {
		case .running: return .indigo
		case .hiking: return .black
		case .racket: return .mint
		case .cycling: return .red
		case .skiing: return .green
		case .gesture: return .secondary
		}
	}
	
	var mlDistance: Int {
		switch self {
		case .running: return 3
		case .hiking: return 6
		case .racket: return 0
		case .cycling: return 10
		case .skiing: return 10
		case .gesture: return 0
		}
	}
	
	var mlSets: Int {
		switch self {
		case .running: return 3
		case .hiking: return 3
		case .racket: return 3
		case .cycling: return 3
		case .skiing: return 3
		case .gesture: return 1
		}
	}
	
	///NB there must be enougt time between sets for a 30 second fifo buffer to fill, otherwiise there will be errors
	var mlDuration: Double {
		switch self {
		case .running: return 0
		case .hiking: return 0
		case .racket: return 60
		case .cycling: return 0
		case .skiing: return 0
		case .gesture: return 1
		}
	}
	
	var mltype: MLTrainingType {
		switch self {
		case .running: return .distance
		case .hiking: return .distance
		case .racket: return .duration
		case .cycling: return .distance
		case .skiing: return .distance
		case .gesture: return .duration
		}
	}
	
	var mlLocations: [Location] {
		switch self {
			case .running: return [Location.leftfoot, Location.rightfoot]
			case .hiking: return [Location.leftfoot, Location.rightfoot]
			case .racket: return [Location.leftfoot, Location.rightfoot] ///Furture are left and right hands
			case .cycling: return [Location.leftfoot, Location.rightfoot]
			case .skiing: return [Location.leftfoot, Location.rightfoot]
			case .gesture: return [Location.leftfoot, Location.rightfoot]
			//case .gesture: return [Location.leftfoot]
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
