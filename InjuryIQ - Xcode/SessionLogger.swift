//
//  SessionLogger.swift
//  InjuryIQ - Xcode
//
//  Created by Platts Andrew on 28/12/2025.
//

import Foundation
import SwiftData
import Observation

@Observable
@MainActor
final class SessionLogger {

	private(set) var isActive: Bool = false
	private(set) var startedAt: Date?
	private(set) var events: [SessionEvent] = []
	private var activityName: String = "Unknown"

	var modelContext: ModelContext?

	init(modelContext: ModelContext? = nil) {
		self.modelContext = modelContext
	}

	func attach(modelContext: ModelContext) {
		self.modelContext = modelContext
	}

	func start(activity: String) {
		reset()
		isActive = true
		startedAt = Date()
		activityName = activity
		append(.init(kind: .start, metadata: ["activity": activity]))
	}

	func append(_ event: SessionEvent) {
		guard isActive else { return }
		events.append(event)
	}

	func append(kind: SessionEventKind, metadata: [String: String]? = nil) {
		append(SessionEvent(kind: kind, metadata: metadata))
	}

	func stop(finalState: String) {
		guard isActive else { return }
		append(.init(kind: .stop, metadata: ["finalState": finalState]))
		persist(finalState: finalState)
		reset()
	}

	private func reset() {
		isActive = false
		startedAt = nil
		events.removeAll()
		activityName = "Unknown"
	}

	private func persist(finalState: String) {
		guard let ctx = modelContext else {
			print("[SessionLogger] No ModelContext; cannot persist")
			return
		}
		let start = startedAt ?? Date()
		let stoppedAt = Date()
		do {
			let encoder = JSONEncoder()
			encoder.dateEncodingStrategy = .iso8601
			let blob = try encoder.encode(events)

			let rec = SessionRecord(
				startedAt: start,
				stoppedAt: stoppedAt,
				activity: activityName,
				stateAtStop: finalState,
				eventsJSON: blob
			)
			ctx.insert(rec)
			try ctx.save()
			print("[SessionLogger] Saved SessionRecord with \(events.count) events")
		} catch {
			print("[SessionLogger] Persist error: \(error.localizedDescription)")
		}
	}
}

