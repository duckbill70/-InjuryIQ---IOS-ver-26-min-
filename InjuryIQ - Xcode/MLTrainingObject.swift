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

struct Accl: Codable {
	let x: Double
	let y: Double
	let z: Double
}

struct Mag: Codable {
	let x: Double
	let y: Double
	let z: Double
}

struct MLDataPoint: Codable {
	let timestamp: TimeInterval // or Date if you prefer
	let accl: Accl // 3D position
	let mag: Mag // 3D orientation (Euler angles)
}

struct mlTrainingSession: Codable, Identifiable {
	var id: UUID
	var data: Data // or String, to store raw JSON or binary data
	// Add more properties as needed
}

extension mlTrainingSession {
	var dataPointsCount: Int {
		(try? JSONDecoder().decode([MLDataPoint].self, from: data))?.count ?? 0
	}
}

class MLTrainingObject: ObservableObject, Codable {
	
	//@Published var active: Bool = false
	var active: Bool {
		let requiredDataPoints = 3000
		return sessions.count == sets && sessions.allSatisfy { $0.dataPointsCount >= requiredDataPoints }
	}
	var type: ActivityType
	var sessions: [mlTrainingSession] {
		didSet { objectWillChange.send() }
	}
	var distnace: Int
	@Published var sets: Int
	var setDuration: Int

	enum CodingKeys: String, CodingKey {
		case active, type, sessions, distnace, sets, setDuration
	}

	init(type: ActivityType, sessions: [mlTrainingSession] = [], distance: Int? = nil, sets: Int? = nil, setDuration: Int? = nil) {
		self.type = type
		//self.active = active
		self.sessions = sessions
		self.distnace = distance ?? type.mlDistance
		self.sets = sets ?? type.mlSests
		self.setDuration = setDuration ?? type.mlDurartion
	}

	required init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		//self.active = try container.decode(Bool.self, forKey: .active)
		self.type = try container.decode(ActivityType.self, forKey: .type)
		self.sessions = try container.decode([mlTrainingSession].self, forKey: .sessions)
		self.distnace = try container.decode(Int.self, forKey: .distnace)
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
	static func fileURL(for type: ActivityType) -> URL {
		let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
		return documents.appendingPathComponent("MLTrainingObject_\(type.rawValue).json")
	}

	// Save to disk
	func save() throws {
		let data = try JSONEncoder().encode(self)
		try data.write(to: MLTrainingObject.fileURL(for: type))
		print("[MLTrainingObject] 'Save' mlObject : \(self)")
	}

	// Load from disk
	static func load(type: ActivityType) throws -> MLTrainingObject {
		let data = try Data(contentsOf: fileURL(for: type))
		let obj = try JSONDecoder().decode(MLTrainingObject.self, from: data)
		//print("[MLTrainingObject] Loaded: \(obj)")
		return obj
	}
	
	//Reset an object based on ActivityType
	static func reset(type: ActivityType) throws {
		let obj = MLTrainingObject(type: type)
		try obj.save()
		print("[MLTrainingObject] Reset: \(obj)")
	}
	
	
	
}

// In MLTrainingObject.swift
extension MLTrainingObject {
	func update(from other: MLTrainingObject) {
		self.type = other.type
		self.sessions = other.sessions
		self.distnace = other.distnace
		self.sets = other.sets
		self.setDuration = other.setDuration
	}
}

extension MLTrainingObject {
	static func delete(type: ActivityType) throws {
		let url = fileURL(for: type)
		if FileManager.default.fileExists(atPath: url.path) {
			try FileManager.default.removeItem(at: url)
		}
	}
}

extension MLTrainingObject: CustomStringConvertible {
	var description: String {
		"MLTrainingObject(type: \(type), active: \(active), sessions: \(sessions), distance: \(distnace), sets: \(sets), setDuration: \(setDuration))"
	}
}

extension mlTrainingSession: CustomStringConvertible {
	var description: String {
		"MLSession(id: \(id.uuidString), data: \(data.count) bytes)"
	}
}

func ensureMLTrainingObjectsExist() {
	for type in ActivityType.allCases {
		let url = MLTrainingObject.fileURL(for: type)
		if FileManager.default.fileExists(atPath: url.path) {
			// Exists: load and print
			do {
				let data = try Data(contentsOf: url)
				let obj = try JSONDecoder().decode(MLTrainingObject.self, from: data)
				print("[MLTrainingObject] Exists: \(obj)")
			} catch {
				print("[MLTrainingObject] Error loading \(type): \(error)")
			}
		} else {
			// Does not exist: create and save
			let obj = MLTrainingObject(type: type)
			do {
				try obj.save()
				print("[MLTrainingObject] Created: \(obj)")
			} catch {
				print("[MLTrainingObject] Error saving \(type): \(error)")
			}
		}
	}
}
