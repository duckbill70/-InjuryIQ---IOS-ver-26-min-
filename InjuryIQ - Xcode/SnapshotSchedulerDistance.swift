//
//  SnapshotSchedulerDistance.swift
//  InjuryIQ - Xcode
//
//  Created by Platts Andrew on 07/01/2026.
//


// InjuryIQ - Xcode/SnapshotSchedulerDistance.swift
import Foundation

final class SnapshotSchedulerDistance {
    private weak var session: Session?
    private var nextSnapshotDistance: Double?
    private var snapshotDistanceInterval: Double? {
        guard let obj = session?.mlTrainingObject, obj.sets > 0 else { return nil }
        // For example, divide total distance by sets
		return Double(obj.distnace) / Double(obj.sets)
    }

    init(session: Session) {
        self.session = session
    }

    func reset() {
        if let interval = snapshotDistanceInterval {
            nextSnapshotDistance = interval
        } else {
            nextSnapshotDistance = nil
        }
    }

	func tick(currentDistance: Double) {
		guard let session = session,
			  session.state == .running,
			  !session.mlTrainingObject.active,
			  let interval = snapshotDistanceInterval else { return }

		let totalDistance = Double(session.mlTrainingObject.distnace)

		// Take snapshots at each interval
		while let nextDist = nextSnapshotDistance, currentDistance >= nextDist, nextDist < totalDistance {
			session.logger.append(kind: .bleCommand, metadata: ["snapshot": "Requested at \(nextDist)m"])
			print("[SnapshotSchedulerDistance] Snapshot request at \(nextDist)m")
			nextSnapshotDistance = nextDist + interval
		}

		// Always take a snapshot at the end if not already done
		if currentDistance >= totalDistance,
		   (nextSnapshotDistance == nil || nextSnapshotDistance! > totalDistance) {
			session.logger.append(kind: .bleCommand, metadata: ["snapshot": "Final at \(totalDistance)m"])
			print("[SnapshotSchedulerDistance] Final snapshot at \(totalDistance)m")
			nextSnapshotDistance = nil
		}
	}
	
}
