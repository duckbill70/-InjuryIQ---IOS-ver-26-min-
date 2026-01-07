//
//  LocationManager.swift
//  InjuryIQ - Xcode
//
//  Created by Platts Andrew on 07/01/2026.
//

import Foundation
import CoreLocation
import Combine

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
	private let manager = CLLocationManager()
	@Published var locations: [CLLocation] = []
	
	var onLocationsUpdate: (([CLLocation]) -> Void)?

	override init() {
		super.init()
		manager.delegate = self
		manager.activityType = .fitness
		manager.desiredAccuracy = kCLLocationAccuracyBest
		manager.allowsBackgroundLocationUpdates = true
	}

	func requestAuthorization() {
		manager.requestWhenInUseAuthorization()
	}

	func startUpdating() {
		manager.startUpdatingLocation()
	}

	func stopUpdating() {
		manager.stopUpdatingLocation()
	}

	func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
		self.locations.append(contentsOf: locations)
		onLocationsUpdate?(locations)
	}
	
}

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
