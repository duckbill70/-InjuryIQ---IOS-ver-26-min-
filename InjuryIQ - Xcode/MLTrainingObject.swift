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

struct mlTrainingSession: Codable, Identifiable, Equatable {
	var id: UUID
	var data: Data // or String, to store raw JSON or binary data
	// Add more properties as needed
	static func == (lhs: mlTrainingSession, rhs: mlTrainingSession) -> Bool {
		lhs.id == rhs.id && lhs.data == rhs.data
	}
}

extension mlTrainingSession {
	
	/// Returns the count of data points for this session.
	var dataPointsCount: Int {
		(try? JSONDecoder().decode([MLDataPoint].self, from: data))?.count ?? 0
	}
	
	/// Returns the decoded data points for this session.
	var dataPoints: [MLDataPoint] {
		(try? JSONDecoder().decode([MLDataPoint].self, from: data)) ?? []
	}
		
	/// Returns the frequency (Hz) of data collection for this session.
	var frequencyHz: Double? {
		let points = dataPoints
		guard points.count > 1 else { return nil }
		let duration = points.last!.timestamp - points.first!.timestamp
		guard duration > 0 else { return nil }
		return Double(points.count) / duration
	}
}

extension Array where Element == mlTrainingSession {
	/// Average frequency (Hz) across all sessions in this location.
	var averageFrequencyHz: Double? {
		let freqs = self.compactMap { $0.frequencyHz }
		guard !freqs.isEmpty else { return nil }
		return freqs.reduce(0, +) / Double(freqs.count)
	}
}

class MLTrainingObject: ObservableObject, Codable {
	
	var uuid: UUID
	
	var active: Bool {
		let requiredLocations: [Location] = type.mlLocations
		for location in requiredLocations {
			let sessionsForLocation = sessions[location] ?? []
			if sessionsForLocation.count != sets {
				return true
			}
		}
		return false
	}
	
	@Published var type: ActivityType
	@Published var sessions: [Location: [mlTrainingSession]] {
		didSet { objectWillChange.send() }
	}
	@Published var distance: Int
	@Published var sets: Int
	@Published var setDuration: Int

	enum CodingKeys: String, CodingKey {
		case uuid
		case active, type, sessions, distance, sets, setDuration
	}

	init(type: ActivityType, sessions: [Location: [mlTrainingSession]] = [:], distance: Int? = nil, sets: Int? = nil, setDuration: Int? = nil, uuid: UUID = UUID()) {
		self.uuid = uuid
		self.type = type
		//self.active = active
		self.sessions = sessions
		self.distance = distance ?? type.mlDistance
		self.sets = sets ?? type.mlSets
		self.setDuration = setDuration ?? type.mlDuration
	}

	required init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		self.uuid = try container.decode(UUID.self, forKey: .uuid)
		//self.active = try container.decode(Bool.self, forKey: .active)
		self.type = try container.decode(ActivityType.self, forKey: .type)
		self.sessions = try container.decode([Location: [mlTrainingSession]].self, forKey: .sessions)
		self.distance = try container.decode(Int.self, forKey: .distance)
		self.sets = try container.decode(Int.self, forKey: .sets)
		self.setDuration = try container.decode(Int.self, forKey: .setDuration)
	}

	func encode(to encoder: Encoder) throws {
		var container = encoder.container(keyedBy: CodingKeys.self)
		try container.encode(uuid, forKey: .uuid)
		try container.encode(active, forKey: .active)
		try container.encode(type, forKey: .type)
		try container.encode(sessions, forKey: .sessions)
		try container.encode(distance, forKey: .distance)
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
	
	// MARK: - Stable export URL and writer
	
	/// Directory for exports: Documents/Exports
	private static var exportsDirectory: URL {
		let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
		return documents.appendingPathComponent("Exports", isDirectory: true)
	}
	
	/// A stable URL for this object's export, overwriting per activity type.
	/// Example: Documents/Exports/Running.json
	var exportURL: URL {
		let dir = Self.exportsDirectory
		return dir.appendingPathComponent("\(type.rawValue).json")
	}
	
	/// Writes the current export JSON to the stable exportURL, creating the directory if needed.
	/// Returns the URL on success.
	@discardableResult
	func writeExport() throws -> URL {
		// Ensure directory exists
		let dir = Self.exportsDirectory
		if !FileManager.default.fileExists(atPath: dir.path) {
			try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
		}
		let export = MLTrainingExport(from: self)
		let jsonData = try export.toJSONData()
		try jsonData.write(to: exportURL, options: .atomic)
		return exportURL
	}
	
}

///Saving and checking a set can be saved
extension MLTrainingObject {
	/// Returns true if a new session can be added for the given location.
	func canAddSession(for location: Location) -> Bool {
		let sessionsForLocation = sessions[location] ?? []
		return sessionsForLocation.count < sets
	}

	/// Adds a session for a location, enforcing FIFO and max count.
	func addSession(_ session: mlTrainingSession, for location: Location) {
		var sessionsForLocation = sessions[location] ?? []
		if sessionsForLocation.count >= sets {
			// FIFO: remove oldest
			sessionsForLocation.removeFirst()
		}
		sessionsForLocation.append(session)
		sessions[location] = sessionsForLocation
		objectWillChange.send()
	}
}

extension MLTrainingObject {
	var trainingType: MLTrainingType {
		type.mltype
	}
}


// In MLTrainingObject.swift for outpuring the object -
extension MLTrainingObject {
	func update(from other: MLTrainingObject) {
		objectWillChange.send()
		self.type = other.type
		self.sessions = other.sessions
		self.distance = other.distance
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
		let sessionSummary = sessions.map { (location, sessions) in
			"\(location.displayName): \(sessions.count) session(s)"
		}.joined(separator: ", ")
		return "MLTrainingObject (\(uuid)) -- (type: \(type), active: \(active), sessions: [\(sessionSummary)], distance: \(distance), sets: \(sets), setDuration: \(setDuration))"
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
