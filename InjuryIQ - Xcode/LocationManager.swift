//
//  LocationManager.swift
//  InjuryIQ - Xcode
//
//  Created by Platts Andrew on 07/01/2026.
//

import Foundation
import CoreLocation

@Observable
final class LocationManager: NSObject, CLLocationManagerDelegate {

	private let manager = CLLocationManager()

	// Observation will track reads to this property and invalidate views when it changes.
	var locations: [CLLocation] = []

	// Optional callback for external consumers (Session uses this for logging).
	var onLocationsUpdate: (([CLLocation]) -> Void)?

	// MARK: - Derived metrics

	var maxSpeed: CLLocationSpeed {
		locations.map { $0.speed }.max() ?? 0
	}

	var averageSpeed: CLLocationSpeed {
		guard !locations.isEmpty else { return 0 }
		// Speeds can be negative; clamp to 0 for averaging.
		let speeds = locations.map { max($0.speed, 0) }
		return speeds.reduce(0, +) / Double(speeds.count)
	}

	var currentAltitude: CLLocationDistance {
		locations.last?.altitude ?? 0
	}

	// MARK: - Lifecycle

	override init() {
		super.init()
		manager.delegate = self
		manager.activityType = .fitness
		manager.desiredAccuracy = kCLLocationAccuracyBest
		manager.allowsBackgroundLocationUpdates = true
	}

	// MARK: - Authorization & updates

	func requestAuthorization() {
		manager.requestWhenInUseAuthorization()
	}

	func startUpdating() {
		manager.startUpdatingLocation()
	}

	func stopUpdating() {
		manager.stopUpdatingLocation()
	}

	// MARK: - CLLocationManagerDelegate

	func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
		// Core Location typically calls on the main thread. If needed, assert or dispatch to main.
		self.locations.append(contentsOf: locations)
		onLocationsUpdate?(locations)
	}

	// You can add error handling if desired:
	// func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) { ... }
}

// MARK: - Convenience computed values

extension LocationManager {

	var totalDistance: CLLocationDistance {
		guard locations.count > 1 else { return 0 }
		return zip(locations, locations.dropFirst()).reduce(0) { $0 + $1.0.distance(from: $1.1) }
	}

	var currentSpeed: CLLocationSpeed {
		let speed = locations.last?.speed ?? 0
		return speed >= 0 ? speed : 0
	}

	var currentSpeedKmph: Double {
		currentSpeed * 3.6
	}
}
