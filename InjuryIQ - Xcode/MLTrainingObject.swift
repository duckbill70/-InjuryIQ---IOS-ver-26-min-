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
	let timestamp: TimeInterval
	let accl: Accl
	let mag: Mag
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
		case .fresh : return "1.circle"
		case .moderate : return "2.circle"
		case .fatigued : return "3.circle"
		case .exhausted : return "exclamationmark.triangle.fill"
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
	var data: Data
	var fatigue: mlFatigueLevel

	static func == (lhs: mlTrainingSession, rhs: mlTrainingSession) -> Bool {
		lhs.id == rhs.id && lhs.data == rhs.data && lhs.fatigue == rhs.fatigue
	}
}

extension mlTrainingSession {
	var dataPointsCount: Int {
		(try? JSONDecoder().decode([MLDataPoint].self, from: data))?.count ?? 0
	}
	var dataPoints: [MLDataPoint] {
		(try? JSONDecoder().decode([MLDataPoint].self, from: data)) ?? []
	}
	var frequencyHz: Double? {
		let points = dataPoints
		guard points.count > 1 else { return nil }
		let duration = points.last!.timestamp - points.first!.timestamp
		guard duration > 0 else { return nil }
		return Double(points.count) / duration
	}
}

extension Array where Element == mlTrainingSession {
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
	@Published var sessions: [Location: [mlTrainingSession]]
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
		self.sessions = sessions
		self.distance = distance ?? type.mlDistance
		self.sets = sets ?? type.mlSets
		self.setDuration = setDuration ?? type.mlDuration
	}

	required init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		self.uuid = try container.decode(UUID.self, forKey: .uuid)
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

	static func fileURL(for type: ActivityType) -> URL {
		let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
		return documents.appendingPathComponent("MLTrainingObject_\(type.rawValue).json")
	}

	func save() throws {
		let data = try JSONEncoder().encode(self)
		try data.write(to: MLTrainingObject.fileURL(for: type))
		print("[MLTrainingObject] 'Save' mlObject : \(self)")
	}

	static func load(type: ActivityType) throws -> MLTrainingObject {
		let data = try Data(contentsOf: fileURL(for: type))
		let obj = try JSONDecoder().decode(MLTrainingObject.self, from: data)
		return obj
	}

	static func reset(type: ActivityType) throws {
		let obj = MLTrainingObject(type: type)
		try obj.save()
		// Clear or rewrite the export so there is no stale file
		do {
			try obj.deleteExport()
		} catch {
			try? obj.writeExport()
		}
		print("[MLTrainingObject] Reset: \(obj)")
	}

	// MARK: - Export

	var exportURL: URL {
		let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
		let exportFolder = documents.appendingPathComponent("Exports")
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

/// Session helpers
extension MLTrainingObject {
	func canAddSession(for location: Location) -> Bool {
		let sessionsForLocation = sessions[location] ?? []
		return sessionsForLocation.count < sets
	}

	func addSession(_ session: mlTrainingSession, for location: Location) {
		var sessionsForLocation = sessions[location] ?? []
		if sessionsForLocation.count >= sets {
			sessionsForLocation.removeFirst()
		}
		sessionsForLocation.append(session)
		var newSessions = sessions
		newSessions[location] = sessionsForLocation
		sessions = newSessions
	}

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

extension MLTrainingObject {
	func update(from other: MLTrainingObject) {
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
