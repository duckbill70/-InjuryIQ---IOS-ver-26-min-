//
//  KnownDiscoveredDevicesView.swift
//  InjuryIQ - Xcode
//
//  Created by Platts Andrew on 13/01/2026.
//


import SwiftUI
import SwiftData
import CoreBluetooth

extension CommandState {
	var iconName: String {
		switch self {
		case .cmd_state_off: return "powersleep"
		case .cmd_state_idle: return "stop.fill"
		case .cmd_state_running: return "play.fill"
		case .cmd_state_location: return "dot.scope" //"location.fill"
		case .cmd_state_snapshot: return "recordingtape"
		case .unknown: return "questionmark"
		}
	}
	var label: String {
		switch self {
		case .cmd_state_off: return "Off"
		case .cmd_state_idle: return "Idle"
		case .cmd_state_running: return "Running"
		case .cmd_state_location: return "Location"
		case .cmd_state_snapshot: return "Snapshot"
		case .unknown: return "Unknown"
		}
	}
	var color: Color {
		switch self {
		case .cmd_state_off: return .black
		case .cmd_state_idle: return .blue
		case .cmd_state_running: return .green
		case .cmd_state_location: return .purple
		case .cmd_state_snapshot: return .yellow
		case .unknown: return .gray
		}
	}
}

enum BatteryState: CaseIterable {
	case unknown, empty, quarter, half, threeQuarters, full

	init(percent: Int?) {
		guard let percent = percent else {
			self = .unknown
			return
		}
		switch percent {
		case ..<15: self = .empty
		case ..<40: self = .quarter
		case ..<65: self = .half
		case ..<90: self = .threeQuarters
		case 90...100: self = .full
		default: self = .unknown
		}
	}

	var iconName: String {
		switch self {
		case .unknown:       return "battery.0"
		case .empty:         return "battery.0"
		case .quarter:       return "battery.25"
		case .half:          return "battery.50"
		case .threeQuarters: return "battery.75"
		case .full:          return "battery.100"
		}
	}

	var text: String {
		switch self {
		case .unknown:       return "Unknown"
		case .empty:         return "Empty"
		case .quarter:       return "25%"
		case .half:          return "50%"
		case .threeQuarters: return "75%"
		case .full:          return "Full"
		}
	}
	
	var color: Color {
		switch self {
		case .unknown:       return .gray
		case .empty:         return .red
		case .quarter:       return .orange
		case .half:          return .orange
		case .threeQuarters: return .green
		case .full:          return .green
		}
	}
	
}

struct DeviceManager: View {
	
	@ObservedObject var ble: BLEManager
	@Environment(Session.self) var session
	@Environment(\.modelContext) var modelContext
	
	@Query(sort: \KnownDevice.lastConnectedAt, order: .reverse) private var knownDevices: [KnownDevice]
	
	@State private var boxes: [KnownDevice?] = []
	
	
	@State private var draggingIndex: Int? = nil
	@GestureState private var dragOffset: CGSize = .zero
	@State private var lastKnownCommandStates: [UUID: CommandState] = [:]

	private let maxBoxes = 4

	var body: some View {
		deviceBoxesView
			.onAppear {
				if boxes.isEmpty {
					initializeBoxes()
				}
				updateBoxes()
				if !ble.isScanning && ble.connectedPeripherals.isEmpty {
					ble.startScan()
				}
			}
			.onChange(of: knownDevices) { _, _ in updateBoxes() }
			.onChange(of: ble.sessionsByPeripheral) { _, _ in updateBoxes() }
			.onChange(of: ble.connectedPeripherals) { _, _ in updateBoxes() }
	}
	
	private var deviceBoxesView: some View {
		GeometryReader { geometry in
			let spacing: CGFloat = 16
			let horizontalPadding: CGFloat = 32
			let totalSpacing = spacing * 3
			let availableWidth = geometry.size.width - horizontalPadding - totalSpacing
			let boxSize = availableWidth / 4

			HStack(spacing: spacing) {
				ForEach(Array(boxes.enumerated()), id: \.offset) { idx, device in
					deviceBoxGroup(idx: idx, device: device, boxSize: boxSize)
				}
			}
			.padding(.horizontal, 16)
		}
		.frame(height: 120)
	}
	
	// Helper function for each box
	private func deviceBoxGroup(idx: Int, device: KnownDevice?, boxSize: CGFloat) -> some View {
		ZStack(alignment: .topTrailing) {
			Group {
				if let device = device {
					deviceBox(device, idx)
				} else {
					noDeviceBox(idx)
				}
			}
			.frame(width: boxSize, height: boxSize)
			//.offset(y: -10)
			
			if let device, ble.connectedPeripherals.contains(where: { $0.identifier == device.uuid }) {
				let cmd = ble.sessionsByPeripheral[device.uuid]?.data.commandState ?? .unknown
				commandNotification(cmd, idx)
			}
			
		}
		.frame(width: boxSize, height: boxSize)
		.background(
			RoundedRectangle(cornerRadius: 16)
				.fill(Color(.secondarySystemBackground))
		)
		.overlay(
			RoundedRectangle(cornerRadius: 16)
				.strokeBorder(Color.primary.opacity(0.08))
		)
		.opacity(draggingIndex == idx ? 0.5 : 1)
		.offset(x: draggingIndex == idx ? dragOffset.width : 0)
		.zIndex(draggingIndex == idx ? 1 : 0)
		.gesture(
			DragGesture()
				.updating($dragOffset) { value, state, _ in
					if draggingIndex == idx {
						state = value.translation
					}
				}
				.onChanged { _ in
					draggingIndex = idx
				}
				.onEnded { value in
					let threshold = boxSize + 16 / 2
					var newIndex = idx
					if value.translation.width > threshold, idx < boxes.count - 1 {
						newIndex = idx + 1
					} else if value.translation.width < -threshold, idx > 0 {
						newIndex = idx - 1
					}
					if newIndex != idx {
						withAnimation {
							boxes.move(fromOffsets: IndexSet(integer: idx), toOffset: newIndex > idx ? newIndex + 1 : newIndex)
						}
						// Swap locations between the two devices
						let locA = locationForIndex(idx)
						let locB = locationForIndex(newIndex)
						if let deviceA = boxes[newIndex], let sessionA = ble.sessionsByPeripheral[deviceA.uuid] {
							sessionA.location = locB
						}
						if let deviceB = boxes[idx], let sessionB = ble.sessionsByPeripheral[deviceB.uuid] {
							sessionB.location = locA
						}
					}
					draggingIndex = nil
				}
		)
		.disabled(session.state != .stopped)
	}
	
	private func initializeBoxes() {
		let deviceBoxes = knownDevices.prefix(maxBoxes).map { Optional($0) }
		let emptyBoxes = Array(repeating: Optional<KnownDevice>.none, count: maxBoxes - deviceBoxes.count)
		boxes = deviceBoxes + emptyBoxes
	}

	// Remove the boxes assignment from updateBoxes()
	private func OLDupdateBoxes() {
		// Do NOT reassign boxes here!
		// Only update locations to ensure uniqueness
		var locationToDevice: [Location: UUID] = [:]
		for (idx, device) in boxes.enumerated() {
			let loc = locationForIndex(idx)
			if let device, let peripheralSession = ble.sessionsByPeripheral[device.uuid] {
				peripheralSession.location = loc
				locationToDevice[loc] = device.uuid
			}
		}
		for (uuid, session) in ble.sessionsByPeripheral {
			if let loc = session.location, locationToDevice[loc] != uuid {
				session.location = nil
			}
		}
	}
	
	private func updateBoxes() {
		// Track which locations are already assigned
		var assignedLocations: Set<Location> = []
		// First, assign locations to devices in boxes if not already set
		for (idx, device) in boxes.enumerated() {
			let loc = locationForIndex(idx)
			if let device, let peripheralSession = ble.sessionsByPeripheral[device.uuid] {
				// Only assign if not already set or if location is taken by another device
				if peripheralSession.location != loc && !assignedLocations.contains(loc) {
					peripheralSession.location = loc
				}
				assignedLocations.insert(loc)
			}
		}
		// Remove locations from devices not in boxes
		for (uuid, session) in ble.sessionsByPeripheral {
			if !boxes.contains(where: { $0?.uuid == uuid }) {
				session.location = nil
			}
		}
	}
	
	private func locationForIndex(_ idx: Int) -> Location {
		switch idx {
		case 0: return .leftfoot
		case 1: return .rightfoot
		case 2: return .lefthand
		case 3: return .righthand
		default: return .leftfoot // fallback
		}
	}
	
	private func commandNotification( _ cmd: CommandState, _ idx: Int) -> some View {
		ZStack {
			Circle()
				.fill(cmd.color)
			Image(systemName: cmd.iconName)
				.font(.system(size: 16, weight: .bold))
				.foregroundStyle(.white)
		}
		.frame(width: 30, height: 30)
		.offset(x: 12, y: -14)
		.shadow(radius: 2)
		.accessibilityLabel("Status")
	}
	
	private struct DeviceInfoRotator: View {
		@ObservedObject var ble: BLEManager // <-- Add this
		let pages: [AnyView]
		let interval: TimeInterval
		@State private var timer: Timer? = nil
		@State private var pageIndex = 0

		var body: some View {
			ZStack {
				if !pages.isEmpty {
					pages[pageIndex % pages.count]
						.id(pageIndex % pages.count)
						//.transition(.asymmetric(
						//	insertion: .move(edge: .top).combined(with: .opacity),
						//	removal: .move(edge: .bottom).combined(with: .opacity)
						//))
						.transition(.opacity)
				}
			}
			.frame(height: 18)
			.animation(.easeInOut, value: pageIndex)
			.onAppear {
				timer?.invalidate()
				timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
					withAnimation {
						pageIndex = (pageIndex + 1) % max(pages.count, 1)
					}
				}
			}
			.onDisappear {
				timer?.invalidate()
				timer = nil
			}
			.onChange(of: ble.connectedPeripherals) { _, _ in
				pageIndex = 0
				timer?.invalidate()
				timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
					withAnimation {
						pageIndex = (pageIndex + 1) % max(pages.count, 1)
					}
				}
			}
		}
	}

	private func deviceBox(_ device: KnownDevice, _ idx: Int) -> some View {
		let color: Color
		if isDeviceConnected(device.uuid) {
			color = .blue.opacity(1.0)
		} else if isDeviceDiscovered(device.uuid) {
			color = .green.opacity(0.5)
		} else {
			color = .orange.opacity(0.5) // amber for known but not discovered/connected
		}
		
		let batteryState = isDeviceConnected(device.uuid)
			? BatteryState(percent: Int(ble.sessionsByPeripheral[device.uuid]?.data.batteryPercent ?? 0))
			: BatteryState(percent: nil)
		
		let sampleRate = isDeviceConnected(device.uuid)
			? Int(ble.sessionsByPeripheral[device.uuid]?.data.sampleRate ?? 0)
			: nil
		
		var pages: [AnyView] {
			var result: [AnyView] = []
			if isDeviceConnected(device.uuid) {
				result.append(AnyView(Text(sampleRate != nil ? "\(sampleRate!)Hz" : "--Hz")
					.font(.system(size: 14, weight: .semibold))
					.foregroundColor(.secondary)))
				result.append(AnyView(Image(systemName: batteryState.iconName)
					.font(.system(size: 16, weight: .semibold))
					.frame(width: 56, height: 56)
					.foregroundColor(batteryState.color)
				))
			}
			// Always add sparkles as a page
			result.append(AnyView(Text(device.uuid.uuidString.suffix(4))
				.font(.system(size: 14, weight: .semibold))
				   .foregroundColor(.secondary)),)
			return result
		}
		
		return ZStack {
			VStack(spacing: 0) {
				Image(systemName: watermarkImage(for: idx))
					.resizable()
					.scaledToFit()
					.scaleEffect(x: (idx == 0 || idx == 2) ? -1 : 1, y: 1)
					.scaleEffect((idx == 0 || idx == 1) ? 0.7 : 1.0)
					.foregroundColor(color)
					.frame(height: 40)
				DeviceInfoRotator(ble: ble, pages: pages, interval: 2.0)
					.frame(height: 18)
					.padding(.top, 5)
			}
		}
		.onTapGesture(count: 2) {
			if let peripheralSession = ble.sessionsByPeripheral[device.uuid] {
				peripheralSession.writeCommand(3)
			}
		}
		.onTapGesture(count: 1) {
			// Only trigger connect/disconnect on tap, not during view update
			handleConnectDisconnect(device)
		}
	}
	
	private func noDeviceBox(_ idx: Int) -> some View {

		let pages: [AnyView] = [
			AnyView(Text("----")
				.font(.system(size: 14, weight: .semibold))
				.foregroundColor(.secondary)),
			
			//AnyView(Text("--%")
			//	.font(.system(size: 14, weight: .semibold))
			//	.foregroundColor(.secondary)),
			
			//AnyView(Image(systemName: BatteryState.unknown.iconName)
			//	.font(.system(size: 16, weight: .semibold))
			//	.frame(width: 56, height: 56)
			//	.foregroundColor(BatteryState.unknown.color)),
					
			//AnyView(Text("--Hz")
			//	.font(.system(size: 14, weight: .semibold))
			//	.foregroundColor(.secondary))
		]
		
		return ZStack {
			VStack(spacing: 0) {
				Image(systemName: watermarkImage(for: idx))
					.resizable()
					.scaledToFit()
					.scaleEffect(x: (idx == 0 || idx == 2) ? -1 : 1, y: 1)
					.scaleEffect((idx == 0 || idx == 1) ? 0.7 : 1.0)
					.foregroundColor(.gray)
					.frame(height: 40)
				DeviceInfoRotator(ble: ble, pages: pages, interval: 2.0)
					.frame(height: 18)
					.padding(.top, 5)
			}
		}
	}
	
	private func watermarkImage(for idx: Int) -> String {

		switch idx {
		case 0, 1:
			return "shoe.fill"
		case 2:
			return "hand.raised.fill"
		case 3:
			return "hand.raised.fill"
		default:
			return "questionmark"
		}
	}

	private func isDeviceConnected(_ uuid: UUID) -> Bool {
		ble.connectedPeripherals.contains { $0.identifier == uuid }
	}

	private func isDeviceDiscovered(_ uuid: UUID) -> Bool {
		return ble.discovered.contains { $0.id == uuid }
	}

	private func handleConnectDisconnect(_ kd: KnownDevice) {
		if let connected = ble.connectedPeripherals.first(where: { $0.identifier == kd.uuid }) {
			ble.disconnect(connected)
		} else {
			if let discovered = ble.discovered.first(where: { $0.id == kd.uuid }) {
				ble.connect(discovered)
			} else {
				print("[UI] Device not discovered, starting scan: \(kd.name)")
				ble.startScan()

				DispatchQueue.global().asyncAfter(deadline: .now() + 2.0) {
					DispatchQueue.main.async {
						if let discovered = ble.discovered.first(where: { $0.id == kd.uuid }) {
							ble.connect(discovered)
						} else {
							print("[UI] Device still not found after scan: \(kd.name)")
						}
						ble.stopScan()
					}
				}
			}
		}
	}
}

#Preview {
	let session = Session()
	DeviceManager(ble: BLEManager.shared)
		.environmentObject(BLEManager.shared)
		.environment(session)
}
