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

public enum mlFatigueLevel : String, Codable {
	case fresh
	case moderate
	case fatigued
	case exhausted
}

extension mlFatigueLevel {
	
	var descriptor: String {
		switch self {
		case .fresh : return "Fresh"
		case .moderate : return "Moderate"
		case .fatigued : return "Fatigued"
		case .exhausted : return "Exhausted"
		}
	}
	
	var shortDescription: String {
		switch self {
		case .fresh : return "No fatigue"
		case .moderate : return "Onset of fatigue"
		case .fatigued : return "Clear fatigue"
		case .exhausted : return "Severe fatigue"
		}
	}
	
	var fatigueColor: Color {
		switch self {
		case .fresh : return .green
		case .moderate : return .yellow
		case .fatigued : return .orange
		case .exhausted : return .red
		}
	}
	
	var iconName: String {
		switch self {
		case .fresh : return "1.circle" //"figure.stand"
		case .moderate : return "2.circle" //"figure.walk"
		case .fatigued : return "3.circle" //"figure.walk.motion"
		case .exhausted : return "exclamationmark.triangle.fill" //"4.circle" //"figure.walk.motion.trianglebadge.exclamationmark"
		}
	}
	
	var description: String {
		switch self {
		case .fresh : return "I could continue at this intensity for a long time"
		case .moderate : return "I’m working harder, but performance feels stable"
		case .fatigued : return "CMy movement or timing is clearly worse"
		case .exhausted : return "I’m struggling to keep proper form"
		}
	}
}
	

struct mlTrainingSession: Codable, Identifiable, Equatable {
	var id: UUID
	var data: Data // or String, to store raw JSON or binary data
	var fatigue: mlFatigueLevel
	
	// Add more properties as needed
	static func == (lhs: mlTrainingSession, rhs: mlTrainingSession) -> Bool {
		lhs.id == rhs.id && lhs.data == rhs.data && lhs.fatigue == rhs.fatigue
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
	@Published var sessions: [Location: [mlTrainingSession]] //{
		//didSet { objectWillChange.send() }
	//}
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
		// Also clear/rewrite the export so ShareLink doesn't use a stale file
		do {
			try obj.deleteExport()
		} catch {
			// Non-fatal: if delete fails, try to at least write a fresh (empty) export
			try? obj.writeExport()
		}
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
		let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
		let exportFolder = documents.appendingPathComponent("Exports")
		// Ensure the folder exists
		if !FileManager.default.fileExists(atPath: exportFolder.path) {
			try? FileManager.default.createDirectory(at: exportFolder, withIntermediateDirectories: true)
		}
		return exportFolder.appendingPathComponent("\(type.rawValue).json")
	}

	func writeExport() throws {
		let export = MLTrainingExport(from: self)
		let data = try export.toJSONData()
		try data.write(to: exportURL)
	}
	
	func deleteExport() throws {
		let url = exportURL
		if FileManager.default.fileExists(atPath: url.path) {
			try FileManager.default.removeItem(at: url)
		}
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
		//sessionsForLocation.append(session)
		//sessions[location] = sessionsForLocation
		//objectWillChange.send()
		sessionsForLocation.append(session)
		var newSessions = sessions
		newSessions[location] = sessionsForLocation
		sessions = newSessions // <- This triggers SwiftUI updates
	}
	
	///Ahs any sessions:
	var hasAnySessions: Bool {
		sessions.values.contains { !$0.isEmpty }
	}
}

extension MLTrainingObject: Equatable {
	static func == (lhs: MLTrainingObject, rhs: MLTrainingObject) -> Bool {
		lhs.uuid == rhs.uuid
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
		//objectWillChange.send()
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
		// Also delete export file for completeness
		let temp = MLTrainingObject(type: type)
		try? temp.deleteExport()
	}
}

extension MLTrainingObject: CustomStringConvertible {
	var description: String {
		let sessionSummary = sessions.map { (location, sessions) in
			let fatigueList = sessions.map { $0.fatigue.descriptor }.joined(separator: ", ")
			return "\(location.displayName): \(sessions.count) session(s) [fatigue: \(fatigueList)]"
		}.joined(separator: ", ")
		return "MLTrainingObject (\(uuid)) -- (type: \(type), active: \(active), sessions: [\(sessionSummary)], distance: \(distance), sets: \(sets), setDuration: \(setDuration))"
	}
}

extension mlTrainingSession: CustomStringConvertible {
	var description: String {
		"MLSession(id: \(id.uuidString), fatigue: \(fatigue.descriptor) ,data: \(data.count) bytes)"
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
