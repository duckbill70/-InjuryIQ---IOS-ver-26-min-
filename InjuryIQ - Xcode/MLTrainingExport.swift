//
//  MLTrainingExport.swift
//  InjuryIQ - Xcode
//
//  Created by Platts Andrew on 21/01/2026.
//
import Foundation

struct MLTrainingExport: Encodable {
	
	struct ExportDataPoint: Encodable {
		let time: TimeInterval
		let accX: Double
		let accY: Double
		let accZ: Double
		let magX: Double
		let magY: Double
		let magZ: Double
	}

	struct ExportSession: Encodable {
		let id: UUID
		let fatigue: String
		let dataPoints: [ExportDataPoint]
	}

	struct ExportLocation: Encodable {
		let name: String
		let sessions: [ExportSession]
	}

	let locations: [ExportLocation]
	
	struct Header: Encodable {
			let uuid: UUID
			let sport: String
			let sets: Int
			let duration: Int
			let distance: Int
		}

		let header: Header

	init(from obj: MLTrainingObject) {
		
		self.header = Header(
			uuid: obj.uuid,
			sport: obj.type.rawValue,
			sets: obj.sets,
			duration: obj.setDuration,
			distance: obj.distance
		)

		self.locations = obj.sessions.map { (location, sessionArray) in
			ExportLocation(
				name: location.displayName,
				sessions: sessionArray.map { session in
					ExportSession(
						id: session.id,
						fatigue: session.fatigue.descriptor,
						dataPoints: session.dataPoints.map { point in
							ExportDataPoint(
								time: point.timestamp,
								accX: point.accl.x,
								accY: point.accl.y,
								accZ: point.accl.z,
								magX: point.mag.x,
								magY: point.mag.y,
								magZ: point.mag.z
							)
						}
					)
				}
			)
		}
	}

	func toJSONData() throws -> Data {
		let encoder = JSONEncoder()
		encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
		return try encoder.encode(self)
	}
}
