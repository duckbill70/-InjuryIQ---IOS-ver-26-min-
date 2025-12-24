//
//  DeviceCardView.swift
//  InjuryIQ - Xcode
//
//  Created by Platts Andrew on 18/12/2025.
//

import SwiftUI
import CoreBluetooth

struct DeviceCardView: View {
	@ObservedObject var session: PeripheralSession

	private var title: String {
		session.data.localName ?? session.peripheral.identifier.uuidString
	}

	private var fillColor: Color {
		if let err = session.data.errorCode, err != 0 {
			return .orange.opacity(0.85)
		}
		switch session.data.commandState {
		case .running: return session.data.locationColor.opacity(0.9)
		case .stopped: return session.data.locationColor.opacity(0.6)
		case .unknown: return session.data.locationColor.opacity(0.5)
		}
	}

	var body: some View {
		ZStack {
			StingrayArcShape()
				.fill(fillColor)
				.overlay(
					StingrayArcShape()
						.stroke(.gray.opacity(0.4), lineWidth: 1)
				)
				.shadow(radius: 8)

			VStack(spacing: 10) {
				// Top row: name + battery
				HStack {
					Text(title)
						.font(.subheadline).bold()
						.lineLimit(1)
						.foregroundStyle(.primary)
					Spacer()
					BatteryIndicator(level: session.data.batteryPercent)
				}

				// Status banner
				HStack(spacing: 8) {
					Capsule()
						.fill(statusColor(for: session.data.commandState))
						.frame(width: 8, height: 8)
					Text(statusText(for: session.data.commandState))
						.font(.caption).bold()
						.foregroundStyle(.primary)
					Spacer()
					if let code = session.data.errorCode, code != 0 {
						Text(String(format: "ERR 0x%02X", code))
							.font(.caption2).bold()
							.padding(.horizontal, 6).padding(.vertical, 3)
							.background(Color.red.opacity(0.9))
							.foregroundStyle(.white)
							.clipShape(Capsule())
					}
				}

				// FIFO + Snapshots
				VStack(spacing: 6) {
					HStack {
						Text("FIFO")
							.font(.caption2)
							.foregroundStyle(.secondary)
						ProgressView(value: fifoProgress, total: 1.0)
							.progressViewStyle(.linear)
						Text("\(session.data.fifoPercent ?? 0)%")
							.font(.caption2).monospacedDigit()
							.foregroundStyle(.secondary)
					}
					.frame(maxWidth: .infinity)

					HStack {
						Text("Snapshots")
							.font(.caption2)
							.foregroundStyle(.secondary)
						Spacer()
						Text("\(session.data.snapshotCount ?? 0)")
							.font(.caption2).monospacedDigit()
							.foregroundStyle(.primary)
					}
				}

				// Controls
				HStack(spacing: 10) {
					Button {
						//session.writeCommand(PeripheralSession.Command.stop.rawValue)
					} label: {
						Label("Stop", systemImage: "stop.fill")
							.font(.caption)
							.padding(.horizontal, 10).padding(.vertical, 6)
							.background(Color.gray.opacity(0.2))
							.foregroundStyle(.primary)
							.clipShape(Capsule())
					}

					Button {
						//session.writeCommand(PeripheralSession.Command.run.rawValue)
					} label: {
						Label("Run", systemImage: "play.fill")
							.font(.caption)
							.padding(.horizontal, 10).padding(.vertical, 6)
							.background(Color.green.opacity(0.9))
							.foregroundStyle(.white)
							.clipShape(Capsule())
					}

					Spacer()
				}
				.padding(.top, 2)
			}
			.padding(12)
		}
		.frame(width: 180, height: 130)
	}

	private var fifoProgress: Double {
		Double(session.data.fifoPercent ?? 0) / 100.0
	}

	private func statusText(for state: DeviceState) -> String {
		switch state {
		case .running: return "RUN"
		case .stopped: return "STOP"
		case .unknown: return "UNKNOWN"
		}
	}

	private func statusColor(for state: DeviceState) -> Color {
		switch state {
		case .running: return .green
		case .stopped: return .gray
		case .unknown: return .yellow
		}
	}
}
