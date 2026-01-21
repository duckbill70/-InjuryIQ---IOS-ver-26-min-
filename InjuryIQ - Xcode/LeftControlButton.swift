import Combine
import CoreBluetooth
//
//  StopButton.swift
//  InjuryIQ - Xcode
//
//  Created by Platts Andrew on 17/01/2026.
//
import SwiftUI

struct LeftControlButton: View {
	
	@ObservedObject var ble: BLEManager
	@Environment(Session.self) var session
	@State private var showPopover = false
	
	private let size: CGFloat = 70
	
	var body: some View {
		
		let active = session.state == .running || session.state == .paused
		
		Button {
			showPopover = true
		} label: {
			Image( systemName: active ? "lock.slash.fill" : CommandState.cmd_state_location.iconName )
				.font(.system(size: 26, weight: .semibold))
				.frame(width: size, height: size)
				.background(
					Circle()
						.fill(
							Color(CommandState.cmd_state_location.color)
								.opacity(0.5)
						)
				)
				.foregroundStyle(Color.white)
				.overlay(
					Circle()
						.stroke(
							Color(CommandState.cmd_state_location.color).opacity(1),
							lineWidth: 1
						)
				)
				.contentShape(Circle())
		}
		.buttonStyle(.plain)
		.accessibilityLabel(Text("Placeholder Button - Disabled"))
		.disabled(active)
		.popover(isPresented: $showPopover, arrowEdge: .bottom) {
			devicePopoverGroup(ble: ble)
		}
		//.frame(width: 220, height: 260)
	}
	
	func devicePopoverGroup(ble: BLEManager) -> some View {
		VStack {
			Text("Select Device")
				.font(.headline)
				.padding(.top)
			LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 2), spacing: 16) {
				ForEach(Array(ble.sessionsByPeripheral.values.prefix(4)), id: \.peripheral.identifier) { session in
					Button {
						session.writeCommand(CommandState.cmd_state_location.rawValue)
					} label: {
						VStack {
							if let location = session.location {
								location.iconView
									.scaledToFit()
									.frame(height: 32)
									.foregroundColor(.blue)
								Text(location.displayName)
									.font(.caption)
									.lineLimit(1)
							} else {
								Image(systemName: "questionmark")
									.resizable()
									.scaledToFit()
									.frame(height: 32)
									.foregroundColor(.gray)
								Text(session.data.localName ?? "Unknown")
									.font(.caption)
									.lineLimit(1)
							}
						}
						.frame(width: 100, height: 100)
						.background(
							RoundedRectangle(cornerRadius: 12)
								.fill(Color(.secondarySystemBackground))
						)
					}
				}
			}
			.padding()
		}
		.frame(width: 220, height: 150)
	}
}

#Preview {
	let session = Session()
	LeftControlButton(ble: BLEManager.shared)
		.environmentObject(BLEManager.shared)
		.environment(session)
}
