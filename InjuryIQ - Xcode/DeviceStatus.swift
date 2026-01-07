//
//  DeviceStatus.swift
//  InjuryIQ - Xcode
//
//  Created by Platts Andrew on 24/12/2025.
//

import SwiftUI

//case stopped = 0x00
//case running = 0x01
//case dumping = 0x03
//case showingLocation = 0x04
//case unknown = 0xFF

enum DeviceStatus: String {
	case running, stopped, dumping, showingLocation, unknown
	
	init(from commandState: CommandState) {
			switch commandState {
			case .stopped: self = .stopped
			case .running: self = .running
			case .dumping: self = .dumping
			case .showingLocation: self = .showingLocation
			default: self = .unknown
			}
		}
	
	var symbolName: String {
		switch self {
		case .running:  return "play.fill"
		case .stopped: return "stop.fill"
		case .dumping: return "recordingtape"
		case .showingLocation: return "location.fill"
		case .unknown: return "questionmark"
		}
	}
	var color: Color {
		switch self {
		case .running:  return .green
		case .stopped: return .red
		case .dumping: return .yellow
		case .showingLocation: return .purple
		case .unknown: return .gray
		}
	}
}

enum DeviceSide: Int {
	case left = 0
	case right = 1
	case unknown = -1
	
	var symbolName: String {
		switch self {
		case .left:  return "chevron.left.chevron.left.dotted"
		case .right: return "chevron.right.dotted.chevron.right"
		case .unknown: return "chevron.up.dotted.2"
		}
	}
	var color: Color {
		switch self {
		case .left:  return .green
		case .right: return .red
		case .unknown: return .gray
		}
	}
	var label: String {
		switch self {
		case .left:  return "Left"
		case .right: return "Right"
		case .unknown: return "Unknown"
		}
	}
}

struct BLEDevice: Identifiable {
	let id = UUID()
	var name: String
	var status: DeviceStatus
	var batteryPercent: Int       // 0...100
	var rssi: Int                 // typically ~ -100 ... -30 dBm
	var hz: Double                // sampling rate
	var side: DeviceSide          // 0 = Left, 1 = Right
	
	// Utility mappings
	var batterySymbolName: String {
		switch batteryPercent {
		case ..<15: return "battery.0"
		case ..<40: return "battery.25"
		case ..<65: return "battery.50"
		case ..<90: return "battery.75"
		default:    return "battery.100"
		}
	}
	var rssiBars: Int {
		// Map RSSI to 0...4 bars
		switch rssi {
		case ..<(-90): return 0
		case ..<(-80): return 1
		case ..<(-70): return 2
		case ..<(-60): return 3
		default:       return 4
		}
	}
}

// MARK: - Components

/// Circular status icon showing play.fill or stop.fill
struct StatusIcon: View {
	let status: DeviceStatus
	var body: some View {
		ZStack {
			Circle()
				.fill(status.color.opacity(0.2))
			Image(systemName: status.symbolName)
				.font(.system(size: 16, weight: .bold))
				.foregroundStyle(status.color)
		}
		.frame(width: 36, height: 36)
		.accessibilityLabel(status == .running ? "Run" : "Stop")
	}
}

/// Compact 0...4 signal bars
struct SignalBars: View {
	let count: Int // 0...4
	var body: some View {
		HStack(alignment: .bottom, spacing: 2) {
			ForEach(0..<4, id: \.self) { i in
				RoundedRectangle(cornerRadius: 1.5)
					.fill(i < count ? Color.green : Color.secondary.opacity(0.25))
					.frame(width: 4, height: CGFloat(6 + (i * 4)))
			}
		}
		.frame(height: 18)
	}
}

/// The requested 2×2 grid under the device name and status icon
struct DeviceInfoGrid: View {
	let device: BLEDevice
	
	var body: some View {
		Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 10) {
			// Row 1
			GridRow {
				// Top-left: Battery icon + percentage
				HStack(spacing: 8) {
					Image(systemName: device.batterySymbolName)
						.foregroundStyle(.green)
					//Text("\(device.batteryPercent)%")
					//	.font(.subheadline)
					//	.monospacedDigit()
				}
				.frame(maxWidth: .infinity, alignment: .leading)
				// Top-right: RSSI bars + dBm value
				HStack(spacing: 8) {
					//Text("\(device.rssi) dBm")
					//	.font(.subheadline)
					//	.monospacedDigit()
					//	.foregroundStyle(.secondary)
					SignalBars(count: device.rssiBars)
				}
				.frame(maxWidth: .infinity, alignment: .trailing)
			}
			// Row 2
			GridRow {
				// Bottom-left: Hz value
				HStack(spacing: 8) {
					Text(String(format: "%.0f Hz", device.hz))
						.font(.subheadline)
						.monospacedDigit()
				}
				.frame(maxWidth: .infinity, alignment: .leading)
				// Bottom-right: Left/Right icon
				HStack(spacing: 8) {
					Image(systemName: device.side.symbolName)
						.foregroundStyle(device.side.color)
				}
				.frame(maxWidth: .infinity, alignment: .trailing)
			}
		}
		.accessibilityElement(children: .contain)
	}
}

/// Example card showing the grid under the header
struct DeviceCard: View {
	let device: BLEDevice
	
	var body: some View {
		VStack(alignment: .leading, spacing: 12) {
			// Header: Device name + play/stop icon
			HStack {
				Text(device.name)
					.font(.subheadline.weight(.semibold))
				Spacer()
				StatusIcon(status: device.status)
			}
			
			// The 2×2 grid exactly as specified
			DeviceInfoGrid(device: device)
		}
		.padding(14)
		.background(
			RoundedRectangle(cornerRadius: 16)
				.fill(Color(.secondarySystemBackground))
		)
		.overlay(
			RoundedRectangle(cornerRadius: 16)
				.strokeBorder(Color.primary.opacity(0.08))
		)
	}
}

// MARK: - Preview

struct DeviceInfoGrid_Previews: PreviewProvider {
	static var previews: some View {
		let a = BLEDevice(
			name: "StingRay A???",
			status: .running,
			batteryPercent: 82,
			rssi: -58,
			hz: 120,
			side: .left
		)
		let b = BLEDevice(
			name: "StingRay B???",
			status: .unknown,
			batteryPercent: 28,
			rssi: -86,
			hz: 0,
			side: .right
		)
		
		Group {
			HStack(spacing: 16) {
				DeviceCard(device: a)
				DeviceCard(device: b)
			}
			.padding()
			.previewDisplayName("Grid under name + status icon")
		}
	}
}

