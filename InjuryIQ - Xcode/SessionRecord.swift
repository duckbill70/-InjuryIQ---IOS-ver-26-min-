//
//  SessionRecord.swift
//  InjuryIQ - Xcode
//
//  Created by Platts Andrew on 28/12/2025.
//

import Foundation
import SwiftData

@Model
final class SessionRecord: Codable {
	@Attribute(.unique) var id: UUID
	var startedAt: Date
	var stoppedAt: Date?
	var activity: String
	var stateAtStop: String
	// Persist events as Data (JSON) to avoid complex @Model graphs
	var eventsJSON: Data

	init(id: UUID = UUID(),
		 startedAt: Date,
		 stoppedAt: Date? = nil,
		 activity: String,
		 stateAtStop: String,
		 eventsJSON: Data) {
		self.id = id
		self.startedAt = startedAt
		self.stoppedAt = stoppedAt
		self.activity = activity
		self.stateAtStop = stateAtStop
		self.eventsJSON = eventsJSON
	}
	
	enum CodingKeys: String, CodingKey {
		case id, startedAt, stoppedAt, activity, stateAtStop, eventsJSON
	}

	// Decodable
	required init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		id = try container.decode(UUID.self, forKey: .id)
		startedAt = try container.decode(Date.self, forKey: .startedAt)
		stoppedAt = try container.decodeIfPresent(Date.self, forKey: .stoppedAt)
		activity = try container.decode(String.self, forKey: .activity)
		stateAtStop = try container.decode(String.self, forKey: .stateAtStop)
		eventsJSON = try container.decode(Data.self, forKey: .eventsJSON)
	}

	// Encodable
	func encode(to encoder: Encoder) throws {
		var container = encoder.container(keyedBy: CodingKeys.self)
		try container.encode(id, forKey: .id)
		try container.encode(startedAt, forKey: .startedAt)
		try container.encode(stoppedAt, forKey: .stoppedAt)
		try container.encode(activity, forKey: .activity)
		try container.encode(stateAtStop, forKey: .stateAtStop)
		try container.encode(eventsJSON, forKey: .eventsJSON)
	}
}

// Swift

extension SessionRecord {
	var shareableText: String? {
		let decoder = JSONDecoder()
		decoder.dateDecodingStrategy = .iso8601
		let events = (try? decoder.decode([SessionEvent].self, from: eventsJSON)) ?? []
		let dict: [String: Any] = [
			"id": id.uuidString,
			"startedAt": startedAt.iso8601String,
			"stoppedAt": stoppedAt?.iso8601String as Any,
			"activity": activity,
			"stateAtStop": stateAtStop,
			"events": events.map { $0.dictionary }
		]
		guard let data = try? JSONSerialization.data(withJSONObject: dict, options: .prettyPrinted),
			  let str = String(data: data, encoding: .utf8) else { return nil }
		return str
	}
}

// Helper extensions (add these if not present)
extension Date {
	var iso8601String: String {
		ISO8601DateFormatter().string(from: self)
	}
}

extension SessionEvent {
	var dictionary: [String: Any] {
		[
			"timestamp": timestamp.iso8601String,
			"kind": kind.rawValue,
			"metadata": metadata ?? [:]
		]
	}
}

