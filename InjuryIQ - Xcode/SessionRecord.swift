//
//  SessionRecord.swift
//  InjuryIQ - Xcode
//
//  Created by Platts Andrew on 28/12/2025.
//

import Foundation
import SwiftData

@Model
final class SessionRecord {
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
}

