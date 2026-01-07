//
//  MLObject.swift
//  InjuryIQ - Xcode
//
//  Created by Platts Andrew on 30/12/2025.
//

/// Create and save
/// let obj = MLObject(type: .running, value: 42.0)
/// try? obj.save() // Saves to a file named mlobject_running.json
///
/// Load and modify
///	if let loaded = try? MLObject.load(type: .running) {
///		{Use loaded object}
///	}
///
///	Modify and save
///	if var loaded = try? MLObject.load(type: .running) {
///		loaded.value = 100.0
///		try? loaded.save() // Overwrites the previous file
///	}

import Foundation
import SwiftUI
import Combine

struct MLSession: Codable, Identifiable {
	var id: UUID
	var data: Data // or String, to store raw JSON or binary data
	// Add more properties as needed
}

enum MLObjectType: String, Codable, CaseIterable {
	case running
	case walking
	case agility
	case cycling
	case stairs
}

extension MLObjectType {
	var iconName: String {
		switch self {
		case .running: return "figure.run"
		case .walking: return "figure.walk"
		case .agility: return "figure.play" ///bolt"
		case .cycling: return "bicycle"
		case .stairs: return "stairs"
		}
	}

	var descriptor: String {
		switch self {
		case .running: return "Running"
		case .walking: return "Walking"
		case .agility: return "Agility"
		case .cycling: return "Cycling"
		case .stairs: return "Stairs"
		}
	}
	
	var color: Color {
		switch self {
		case .running: return .blue
		case .walking: return .green
		case .agility: return .red
		case .cycling: return .white
		case .stairs: return .yellow
		}
	}
	
	var disableDistance: Bool {
		switch self {
		case .running: return false
		case .walking: return false
		case .agility: return true
		case .cycling: return false
		case .stairs: return true
		}
	}
	
	var explaination: String {
		switch self {
		case .running: "During a running training session, the AI will automatically select three specific points along the total distance you’ve chosen. At each of these points, the system will collect live data. This data is then used to help train and improve the model, ensuring it learns from your performance at different stages of the run."
		case .walking: "During a hiking training session, the AI will automatically select three specific points along the total distance you’ve chosen. At each of these points, the system will collect live data. This data is then used to help train and improve the model, ensuring it learns from your performance at different stages of the hike."
		case .agility: "Agility sessions involve performing a specific activity, such as padel tennis, to improve coordination, speed, and responsiveness. The system tracks your performance during these activities to help assess and enhance your agility."
		case .cycling: "During a cycling training session, the AI will automatically select three specific points along the total distance you’ve chosen. At each of these points, the system will collect live data. This data is then used to help train and improve the model, ensuring it learns from your performance at different stages of the cycle."
		case .stairs: "During a stairs session, the focus is on improving your step count and measuring fatigue. The system tracks your performance as you go up and down the stairs, helping to assess endurance and monitor signs of fatigue."
		}
	}
	
}

class MLObject: ObservableObject, Codable {
	@Published var active: Bool = false
	var type: MLObjectType
	var sessions: [MLSession]
	var distnace: Double = 3.0
	var sets: Int = 3
	var setDuration: Int = 30

	enum CodingKeys: String, CodingKey {
		case active, type, sessions, distnace, sets, setDuration
	}

	init(type: MLObjectType, active: Bool = false, sessions: [MLSession] = [], distance: Double = 3.0, sets: Int = 3, setDuration: Int = 30) {
		self.type = type
		self.active = active
		self.sessions = sessions
		self.distnace = distance
		self.sets = sets
		self.setDuration = setDuration
	}

	required init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		self.active = try container.decode(Bool.self, forKey: .active)
		self.type = try container.decode(MLObjectType.self, forKey: .type)
		self.sessions = try container.decode([MLSession].self, forKey: .sessions)
		self.distnace = try container.decode(Double.self, forKey: .distnace)
		self.sets = try container.decode(Int.self, forKey: .sets)
		self.setDuration = try container.decode(Int.self, forKey: .setDuration)
	}

	func encode(to encoder: Encoder) throws {
		var container = encoder.container(keyedBy: CodingKeys.self)
		try container.encode(active, forKey: .active)
		try container.encode(type, forKey: .type)
		try container.encode(sessions, forKey: .sessions)
		try container.encode(distnace, forKey: .distnace)
		try container.encode(sets, forKey: .sets)
		try container.encode(setDuration, forKey: .setDuration)
	}
	
	// File URL for persistence, unique per type
	static func fileURL(for type: MLObjectType) -> URL {
		let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
		return documents.appendingPathComponent("mlobject_\(type.rawValue).json")
	}

	// Save to disk
	func save() throws {
		let data = try JSONEncoder().encode(self)
		try data.write(to: MLObject.fileURL(for: type))
		print("[MLObject] 'Save' mlObject : \(self)")
	}

	// Load from disk
	static func load(type: MLObjectType) throws -> MLObject {
		let data = try Data(contentsOf: fileURL(for: type))
		return try JSONDecoder().decode(MLObject.self, from: data)
	}
	
}

extension MLObject {
	static func delete(type: MLObjectType) throws {
		let url = fileURL(for: type)
		if FileManager.default.fileExists(atPath: url.path) {
			try FileManager.default.removeItem(at: url)
		}
	}
}

extension MLObject: CustomStringConvertible {
	var description: String {
		"MLObject(type: \(type), active: \(active), sessions: \(sessions), distance: \(distnace), disableDistance: \(self.type.disableDistance), sets: \(sets), setDuration: \(setDuration))"
	}
}

extension MLSession: CustomStringConvertible {
	var description: String {
		"MLSession(id: \(id.uuidString), data: \(data.count) bytes)"
	}
}

