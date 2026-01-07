//
//  SessionEventModels.swift
//  InjuryIQ - Xcode
//
//  Created by Platts Andrew on 28/12/2025.
//

import Foundation

public enum SessionEventKind: String, Codable {
	case start
	case pause
	case resume
	case stop
	case activityChanged
	case bleConnected
	case bleDisconnected
	case bleCommand
	case metricSnapshot
	case location
	case note
	case custom
}

public struct SessionEvent: Identifiable, Codable, Sendable {
	public let id: UUID
	public let timestamp: Date
	public let kind: SessionEventKind
	public var metadata: [String: String]?

	public init(
		id: UUID = UUID(),
		timestamp: Date = Date(),
		kind: SessionEventKind,
		metadata: [String: String]? = nil
	) {
		self.id = id
		self.timestamp = timestamp
		self.kind = kind
		self.metadata = metadata
	}
}
