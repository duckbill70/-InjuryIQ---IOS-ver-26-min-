//
//  Session.swift
//  InjuryIQ - Xcode
//
//  Created by Platts Andrew on 28/12/2025.
//

import Foundation
import SwiftUI
import Observation
import SwiftData
import Combine
internal import _LocationEssentials

// Public so it can be used by public views like SessionStatusIndicator
public enum SessionState: String, CaseIterable {
	//case idle = "Idle"
	case running = "Active"
	case paused = "Paused"
	case stopped = "Stopped"
}

// A small model for rendering session control buttons in the UI
struct SessionButton: Identifiable {
	let id = UUID()
	let state: SessionState
	let icon: String
	let color: Color

	var label: String {
		state.rawValue
	}

	// Adjust icons/colors as desired
	static let states = [
		SessionButton(state: .running, icon: "play.fill",  color: .green),
		SessionButton(state: .paused,  icon: "pause.fill", color: .yellow),
		SessionButton(state: .stopped, icon: "stop.fill",  color: .red)
	]
}

public extension SessionState {
	var accent: Color {
		switch self {
		case .running: return .green
		case .paused:  return .yellow
		case .stopped: return .gray
		//case .idle:    return .blue
		}
	}

	var isAnimated: Bool {
		self == .running
	}

	var isDimmed: Bool {
		switch self {
		case .stopped, .paused ://, .idle:
			return true
		case .running:
			return false
		}
	}
}

// MARK: - Session owner (Observation framework)
@Observable
final class Session {
	var state: SessionState = .stopped
	var duration: TimeInterval = 0
	let logger = SessionLogger()
	private var bleManager: BLEManager?
	private var timer: Timer?
	var activity: String = ""
	var mlTrainingObject: MLTrainingObject = MLTrainingObject(type: .running)
	var type: ActivityType = .running {
		didSet {
			mlTrainingObject = (try? MLTrainingObject.load(type: type)) ?? MLTrainingObject(type: type)
			print("[Session] - New MLTrainingObject: \(mlTrainingObject)")
		}
	}
	
	///For timer based MLTraining
	private var snapshotSchedulerDuration: SnapshotSchedulerDuration?
	private var snapshotSchedulerDistance: SnapshotSchedulerDistance?
	
	///Location Manager
	var locationManager = LocationManager()
	
	init() {
		// ... other initializations ...
		locationManager.onLocationsUpdate = { [weak self] newLocations in
			guard let self = self, self.state == .running else { return }
			for location in newLocations {
				self.logger.append(kind: .location, metadata: [
					"lat": "\(location.coordinate.latitude)",
					"lon": "\(location.coordinate.longitude)",
					"timestamp": "\(location.timestamp)"
				])
			}
		}
	}
	
	
	func attach(modelContext: ModelContext) {
		logger.attach(modelContext: modelContext)
	}
	
	func attachBLEManager(_ manager: BLEManager) {
			self.bleManager = manager
	}
	
	private func sendCommandToDevices(_ value: UInt8) {
		if let sessions = bleManager?.sessionsByPeripheral.values {
			for device in sessions {
				device.writeCommand(value)
			}
		}
	}
	
	// Convenience methods (no BLE side-effects yet)
	func run() {
		switch state {
		case .stopped: //, .idle:
			logger.start(activity: activity.isEmpty ? "Session" : activity)
			///PeripheralSessions
			if let sessions = bleManager?.sessionsByPeripheral.values {
				for device in sessions {
					logger.append(kind: .note, metadata: ["devices": "\(device.data.localName ?? "Unknown")"])
				}
			} else {
				logger.append(kind: .note, metadata: ["devices": "No devices attached:" ])
			}
			
			///TODO(BLE): send "run" command
			sendCommandToDevices(2) // cmd_state_running
			
			state = .running
			duration = 0
			
			///MLTrainign for timer based functions
			if snapshotSchedulerDuration == nil { snapshotSchedulerDuration = SnapshotSchedulerDuration(session: self) }
			snapshotSchedulerDuration?.reset()
			
			if snapshotSchedulerDistance == nil { snapshotSchedulerDistance = SnapshotSchedulerDistance(session: self) }
			snapshotSchedulerDistance?.reset()
			
			startTimer()
			
			locationManager.requestAuthorization()
			locationManager.startUpdating()
			
		case .paused:
			logger.append(kind: .resume, metadata: ["message": "Resumed"])
			
			///TODO(BLE): send "run" command
			sendCommandToDevices(2) // cmd_state_running
			
			state = .running
			startTimer()

		case .running:
			// Already running; do nothing
			break
		}
	}
	
	func pause() {
		if state == .running {
			state = .paused
			stopTimer()
			locationManager.stopUpdating()
			logger.append(kind: .pause, metadata: ["message": "Paused"])

			/// TODO(BLE): send "stop" command
			sendCommandToDevices(1) // cmd_state_idle
		}
	}
	
	func stop() {
		if state != .stopped {
			
			/// TODO(BLE): send "stop" command
			sendCommandToDevices(1) // cmd_state_idle
			
			state = .stopped
			stopTimer()
			locationManager.stopUpdating()
			
			///End state logging
			logger.append(kind: .location, metadata: ["end_distance": "\(currentDistance)"])
			logger.append(kind: .note, metadata: ["messsage": "duration: \(self.duration)"])
			logger.stop(finalState: state.rawValue)
			
			///Reset Session
			duration = 0
			locationManager.locations.removeAll() // Reset distance
			
			
		}
	}
	
	private func startTimer() {
		stopTimer()
		timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
			guard let self = self else { return }
			self.duration += 1
			self.snapshotSchedulerDuration?.tick(currentDuration: self.duration)
			self.snapshotSchedulerDistance?.tick(currentDistance: self.currentDistance)
		}
	}

	private func stopTimer() {
		timer?.invalidate()
		timer = nil
	}
	
}

extension Session {
	var currentDistance: CLLocationDistance {
		locationManager.totalDistance
	}
	var currentSpeed: CLLocationSpeed {
		locationManager.currentSpeed
	}
	
	var currentSpeedKmph: Double {
		currentSpeed * 3.6
	}
}

// MARK: - UI helpers for control buttons
public extension SessionState {
	var runPauseIcon: String {
		switch self {
		case .running: return "pause.fill"
		default:       return "play.fill" // idle, paused, stopped => show play
		}
	}
	var runPauseLabel: String {
		switch self {
		case .running: return "Pause"
		default:       return "Run"
		}
	}
	var runPauseColor: Color {
		switch self {
		case .running: return .yellow
		default:       return .green
		}
	}
	var stopIcon: String { "stop.fill" }
	var stopLabel: String { "Stop" }
	var stopColor: Color { .red }
}

// MARK: - Split controls: Run/Pause and Stop (icon-only circular buttons)
struct RunPauseButton: View {
	@Environment(Session.self) private var session
	var selectedActivity: String

	private let size: CGFloat = 56

	var body: some View {
		Button {
			if session.state == .running {
				session.pause()
			} else {
				session.activity = selectedActivity
				session.run()
			}
		} label: {
			Image(systemName: session.state.runPauseIcon)
				.font(.system(size: 22, weight: .semibold))
				.frame(width: size, height: size)
				.background(
					Circle().fill(session.state.runPauseColor.opacity(0.18))
				)
				.foregroundStyle(session.state.runPauseColor)
				.overlay(
					Circle().stroke(session.state.runPauseColor.opacity(0.35), lineWidth: 1)
				)
				.contentShape(Circle())
		}
		.buttonStyle(.plain)
		.accessibilityLabel(Text(session.state.runPauseLabel))
	}
}

struct StopButton: View {
	@Environment(Session.self) private var session

	private let size: CGFloat = 56

	var body: some View {
		Button {
			session.stop()
		} label: {
			Image(systemName: session.state.stopIcon)
				.font(.system(size: 22, weight: .semibold))
				.frame(width: size, height: size)
				.background(
					Circle().fill(session.state.stopColor.opacity(0.18))
				)
				.foregroundStyle(session.state.stopColor)
				.overlay(
					Circle().stroke(session.state.stopColor.opacity(0.35), lineWidth: 1)
				)
				.contentShape(Circle())
		}
		.buttonStyle(.plain)
		.accessibilityLabel(Text(session.state.stopLabel))
		.disabled(session.state == .stopped)
		.opacity(session.state == .stopped ? 0.4 : 1.0)
	}
}
