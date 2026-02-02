//
//  SnapshotScheduler.swift
//  InjuryIQ - Xcode
//
//  Created by Platts Andrew on 07/01/2026.
//


// InjuryIQ - Xcode/SnapshotScheduler.swift
import Foundation
import AudioToolbox
import UIKit
import CoreHaptics

final class SnapshotSchedulerDuration {
    private weak var session: Session?
    private var nextSnapshotTime: TimeInterval?
    private var snapshotInterval: TimeInterval? {
        guard let obj = session?.mlTrainingObject, obj.sets > 0 else { return nil }
        return (Double(obj.setDuration) * 60.0) / Double(obj.sets)
    }

	public private(set) var countdown: Int? {
		didSet {
			if oldValue != countdown {
				// Play a default system sound (e.g., 1057 is the "Tock" sound)
				AudioServicesPlaySystemSound(1057)
				// Vibrate the phone
				let generator = UIImpactFeedbackGenerator(style: .heavy)
				generator.impactOccurred()
				//playCustomHaptic()
			}
		}
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
		countdown = nil
    }

    func tick(currentDuration: TimeInterval) {
        guard let session = session,
			session.state == .running,
			session.mlTrainingObject.active, // <-- Only proceed if active
			let interval = snapshotInterval,
			let nextTime = nextSnapshotTime else { return }
		
		let timeToNext = nextTime - currentDuration
		if timeToNext <= 10 && timeToNext > 0 {
			countdown = Int(ceil(timeToNext))
		} else {
			countdown = nil
		}
		
		if currentDuration >= nextTime {
			session.logger.append(kind: .bleCommand, metadata: ["snapshot": "Requested at \(Int(currentDuration))s for \(session.mlTrainingObject.type)"])
			session.sendCommandToDevices(4)
			print("[SnapshotSchedulerDuration] Snapshot request at \(Int(currentDuration))s for \(session.mlTrainingObject.type)")
			nextSnapshotTime = nextTime + interval
			countdown = nil
		}
    }
	
	var engine: CHHapticEngine?

	func playCustomHaptic() {
		guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
		do {
			engine = try CHHapticEngine()
			try engine?.start()
			let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5)
			let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0)
			let event = CHHapticEvent(eventType: .hapticContinuous, parameters: [sharpness, intensity], relativeTime: 0, duration: 1.0)
			let pattern = try CHHapticPattern(events: [event], parameters: [])
			let player = try engine?.makePlayer(with: pattern)
			try player?.start(atTime: 0)
		} catch {
			print("Haptic error: \(error)")
		}
	}
	
	
}
