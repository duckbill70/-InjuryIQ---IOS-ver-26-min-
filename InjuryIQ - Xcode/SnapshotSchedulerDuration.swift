//
//  SnapshotScheduler.swift
//  InjuryIQ - Xcode
//
//  Created by Platts Andrew on 07/01/2026.
//


// InjuryIQ - Xcode/SnapshotScheduler.swift
import Foundation

final class SnapshotSchedulerDuration {
    private weak var session: Session?
    private var nextSnapshotTime: TimeInterval?
    private var snapshotInterval: TimeInterval? {
        guard let obj = session?.mlTrainingObject, obj.sets > 0 else { return nil }
        return (Double(obj.setDuration) * 60.0) / Double(obj.sets)
    }

    init(session: Session) {
        self.session = session
    }

    func reset() {
        if let interval = snapshotInterval {
            nextSnapshotTime = interval
        } else {
            nextSnapshotTime = nil
        }
    }

    func tick(currentDuration: TimeInterval) {
        guard let session = session,
			session.state == .running,
			!session.mlTrainingObject.active, // <-- Only proceed if active
			let interval = snapshotInterval,
			let nextTime = nextSnapshotTime else { return }
        if currentDuration >= nextTime {
			session.logger.append(kind: .bleCommand, metadata: ["snapshot": "Requested at \(Int(currentDuration))s"])
			session.sendCommandToDevices(4)
            print("[SnapshotScheduler] Snapshot request at \(Int(currentDuration))s")
            nextSnapshotTime = nextTime + interval
        }
    }
}
