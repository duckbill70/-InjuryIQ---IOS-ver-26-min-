//
//  PeripheralSession.swift
//  InjuryIQ - Xcode
//
//  Created by Platts Andrew on 16/12/2025.
//

// PeripheralSession.swift
import CoreBluetooth
import Combine
import SwiftUI
import AudioToolbox

struct FIFOStatusPayload {
	let samplesStored: UInt32
	let samplesDropped: UInt32
	let totalCaptured: UInt32
	let memoryUsedBytes: UInt32
	let bufferCapacity: UInt32
	let recordingDurationMs: UInt32
	let actualSampleRateHz: UInt16
	let configuredRateHz: UInt16
	let isRecording: UInt8
	let isFull: UInt8

	init?(data: Data) {
		guard data.count >= 30 else { return nil }
		samplesStored        = data.subdata(in: 0..<4).withUnsafeBytes { $0.load(as: UInt32.self) }
		samplesDropped       = data.subdata(in: 4..<8).withUnsafeBytes { $0.load(as: UInt32.self) }
		totalCaptured        = data.subdata(in: 8..<12).withUnsafeBytes { $0.load(as: UInt32.self) }
		memoryUsedBytes      = data.subdata(in: 12..<16).withUnsafeBytes { $0.load(as: UInt32.self) }
		bufferCapacity       = data.subdata(in: 16..<20).withUnsafeBytes { $0.load(as: UInt32.self) }
		recordingDurationMs  = data.subdata(in: 20..<24).withUnsafeBytes { $0.load(as: UInt32.self) }
		actualSampleRateHz   = data.subdata(in: 24..<26).withUnsafeBytes { $0.load(as: UInt16.self) }
		configuredRateHz     = data.subdata(in: 26..<28).withUnsafeBytes { $0.load(as: UInt16.self) }
		isRecording          = data[28]
		isFull               = data[29]
	}
}

struct CharKey: Hashable {
	let service: CBUUID
	let characteristic: CBUUID

	func hash(into hasher: inout Hasher) {
		// Use stable string representations for hashing
		hasher.combine(service.uuidString)
		hasher.combine(characteristic.uuidString)
	}

	static func == (lhs: CharKey, rhs: CharKey) -> Bool {
		lhs.service.uuidString == rhs.service.uuidString &&
		lhs.characteristic.uuidString == rhs.characteristic.uuidString
	}
}

enum DeviceState: String {
	case stopped, running, unknown
}

public enum CommandState: UInt8 {
	case cmd_state_off 		= 0x00
	case cmd_state_idle 	= 0x01
	case cmd_state_running 	= 0x02
	case cmd_state_location = 0x03
	case cmd_state_snapshot = 0x04
	case unknown 			= 0xFF
}

enum Location: String, CaseIterable, Identifiable, Codable {
	case rightfoot
	case leftfoot
	case righthand
	case lefthand

	var id: String { rawValue }

	var displayName: String {
		switch self {
		case .rightfoot: return "Right Foot"
		case .leftfoot: return "Left Foot"
		case .lefthand: return "Left Hand"
		case .righthand: return "Right Hand"
		}
	}
	
	var iconView: some View {
		let image: Image
		let flip: Bool

		switch self {
		case .rightfoot:
			image = Image(systemName: "shoe.fill")
			flip = false
		case .leftfoot:
			image = Image(systemName: "shoe.fill")
			flip = true
		case .lefthand:
			image = Image(systemName: "hand.raised.fill")
			flip = true
		case .righthand:
			image = Image(systemName: "hand.raised.fill")
			flip = false
		}

		return image
			.scaleEffect(x: flip ? -1 : 1, y: 1)
	}
	
}

public enum ImuProfile: UInt8 {
	
	case racket 	= 0x00
	case running 	= 0x01
	case hiking 	= 0x02
	case cycling 	= 0x03
	case skiing 	= 0x04
	case gesture 	= 0x05
	
}

extension ImuProfile {
	var displayName: String {
		switch self {
		case .racket:   return "Racket"
		case .running:  return "Running"
		case .hiking:   return "Hiking"
		case .cycling:  return "Cycling"
		case .skiing:   return "Skiing"
		case .gesture:  return "Gesture"
		}
	}
	
	static func from(activity: ActivityType) -> ImuProfile? {
			switch activity {
			case .racket:   return .racket
			case .running:  return .running
			case .hiking:   return .hiking
			case .cycling:  return .cycling
			case .skiing:   return .skiing
			case .gesture:  return .gesture
			}
		}
}

struct PeripheralData {
	
	var localName		: String?
	var batteryLevel	: UInt8?
	var command			: CommandState?
	var location		: Location?
	var imuProfile		: ImuProfile?
	
	// Add more fields as needed for other characteristic values
	
	var errorCode		: UInt8?
	var stats			: UInt16?
	var fatigue			: UInt8?
	var sampleRate		: UInt16?
	var rssi			: Int?
	
	var fifoStats		: FIFOStatusPayload?
	
	var commandState: CommandState {
		return command ?? .unknown
	}

	var batteryPercent: Int? {
		guard let b = batteryLevel else { return nil }
		return Int(min(100, max(0, b)))
	}

	var fifoPercent: Int? {
		guard let f = stats else { return nil }
		return Int(min(100, max(0, f)))
	}
	
	var fatiguePercent: Int? {
		guard let f = fatigue else { return nil }
		return Int(min(100, max(0, f)))
	}
	
}

class PeripheralSession: NSObject, ObservableObject, StreamDelegate {
	
	let peripheral: CBPeripheral
	weak var session: Session?
	
	///lccap channel management
	var l2capChannel: CBL2CAPChannel?
	var l2capOpenAttempted = false // Add this flag
	
	///Publiched Observable objects in the session
	@Published var characteristics: [CharKey: CBCharacteristic] = [:]
	@Published var data: PeripheralData

	/// UUIDs for Command Service and its characteristics
	static let commandServiceUUID 	= CBUUID(string: "12345679-1234-5678-1234-56789abcdef0")
	static let commandCharUUID    	= CBUUID(string: "12345679-1234-5678-1234-56789abcdef1")
	static let errorCharUUID      	= CBUUID(string: "12345679-1234-5678-1234-56789abcdef5")
	static let sampleRateUUID      	= CBUUID(string: "12345679-1234-5678-1234-56789abcdef6")
	static let imuProfileUUID		= CBUUID(string: "12345679-1234-5678-1234-56789abcdef7")
	
	///UUIDs Fatigue Service and its characteristics
	static let fatigueServiceUUID = CBUUID(string: "12345678-1234-5678-1234-56789abcdef0")
	static let fatigueCharUUID    = CBUUID(string: "12345678-1234-5678-1234-56789abcdef1")
	
	///UUIDs Fifo Streaming Service
	static let fifoServiceUUID 		= CBUUID(string: "12345680-1234-5678-1234-56789abcdef0")
	static let fifoStreamCharUUID   = CBUUID(string: "12345680-1234-5678-1234-56789abcdef1")
	static let fifoStatusCharUUID   = CBUUID(string: "12345680-1234-5678-1234-56789abcdef2")
	static let fifoL2CAPCharUUID	= CBUUID(string: "12345680-1234-5678-1234-56789ABCDEF3")
	
	///UUIDs Battery Service and its characteristics
	static let batteryServiceUUID = CBUUID(string: "180F")
	static let batteryCharUUID    = CBUUID(string: "2A19")
	
	///Data Buffer
	private var l2capDataBuffer = Data()
	
	private struct IMUSample {
		let position: UInt32
		let timestamp_ms: UInt32
		let accel_x: Float
		let accel_y: Float
		let accel_z: Float
		let gyro_x: Float
		let gyro_y: Float
		let gyro_z: Float
	}
	

	init(peripheral: CBPeripheral, characteristics: [CharKey: CBCharacteristic], localName: String? = nil) {
		self.peripheral = peripheral
		self.characteristics = characteristics
		self.data = PeripheralData(
			localName: localName,
			batteryLevel: nil,
			command: nil,
			location: nil,
			sampleRate: nil
		)
	}
	
	///Stream Delegate:
	func stream(_ aStream: Stream, handle eventCode: Stream.Event) {
		switch eventCode {
		case .hasBytesAvailable:
			if let inputStream = aStream as? InputStream {
				var buffer = [UInt8](repeating: 0, count: 4096)
				while inputStream.hasBytesAvailable {
					let bytesRead = inputStream.read(&buffer, maxLength: buffer.count)
					if bytesRead > 0 {
						l2capDataBuffer.append(buffer, count: bytesRead)
						
						// Check if we have at least the header
						if l2capDataBuffer.count >= 8 {
							let totalBytes = l2capDataBuffer.withUnsafeBytes { $0.load(fromByteOffset: 0, as: UInt32.self) }
							let expectedLength = 8 + Int(totalBytes)
							if l2capDataBuffer.count >= expectedLength {
								// Full stream received
								if let samples = decodeCoCStream(data: l2capDataBuffer) {
									saveIMUSamplesToMLTrainingObject(samples: samples)
								}
								l2capDataBuffer.removeAll()
							}
						}
					}
				}
			}
		case .endEncountered, .errorOccurred:
			print("[PeripheralSession] L2CAP input stream closed or error")
			l2capDataBuffer.removeAll()
		default:
			break
		}
	}
	
	///Decode Function
	private func decodeCoCStream(data: Data) -> [IMUSample]? {
		guard data.count >= 8 else { return nil }
		let totalBytes = data.withUnsafeBytes { $0.load(fromByteOffset: 0, as: UInt32.self) }
		let totalSamples = data.withUnsafeBytes { $0.load(fromByteOffset: 4, as: UInt16.self) }
		let payloadData = data.subdata(in: 8..<data.count)
		guard payloadData.count == Int(totalBytes) else { return nil }
		var samples: [IMUSample] = []
		let entrySize = 32
		for i in 0..<Int(totalSamples) {
			let offset = i * entrySize
			guard offset + entrySize <= payloadData.count else { break }
			let entryData = payloadData.subdata(in: offset..<(offset + entrySize))
			let sample = IMUSample(
				position: entryData.withUnsafeBytes { $0.load(fromByteOffset: 0, as: UInt32.self) },
				timestamp_ms: entryData.withUnsafeBytes { $0.load(fromByteOffset: 4, as: UInt32.self) },
				accel_x: entryData.withUnsafeBytes { $0.load(fromByteOffset: 8, as: Float.self) },
				accel_y: entryData.withUnsafeBytes { $0.load(fromByteOffset: 12, as: Float.self) },
				accel_z: entryData.withUnsafeBytes { $0.load(fromByteOffset: 16, as: Float.self) },
				gyro_x: entryData.withUnsafeBytes { $0.load(fromByteOffset: 20, as: Float.self) },
				gyro_y: entryData.withUnsafeBytes { $0.load(fromByteOffset: 24, as: Float.self) },
				gyro_z: entryData.withUnsafeBytes { $0.load(fromByteOffset: 28, as: Float.self) }
			)
			samples.append(sample)
		}
		return samples
	}
	
	///Save IMU Object to MLSession
	private func saveIMUSamplesToMLTrainingObject(samples: [IMUSample]) {
		guard let session = self.session, let location = self.location else { return }

		// Offload heavy work to a background task
		Task.detached(priority: .utility) {
			// Map to MLDataPoint off-main
			let dataPoints: [MLDataPoint] = samples.map { sample in
				MLDataPoint(
					timestamp: TimeInterval(sample.timestamp_ms) / 1000.0,
					accl: Accl(x: Double(sample.accel_x), y: Double(sample.accel_y), z: Double(sample.accel_z)),
					mag: Mag(x: Double(sample.gyro_x), y: Double(sample.gyro_y), z: Double(sample.gyro_z))
				)
			}

			// Encode JSON off-main
			guard let jsonData = try? JSONEncoder().encode(dataPoints) else {
				print("[PeripheralSession] JSON encode failed for IMU samples")
				return
			}

			// Compute fatigue based on existing count (need main actor to read the object safely)
			let newMLSess: mlTrainingSession? = await MainActor.run {
				let count = session.mlTrainingObject.sessions[location]?.count ?? 0
				let fatigue: mlFatigueLevel
				switch count {
				case 0: fatigue = .fresh
				case 1: fatigue = .moderate
				case 2: fatigue = .fatigued
				default: fatigue = .exhausted
				}
				return mlTrainingSession(id: UUID(), data: jsonData, fatigue: fatigue)
			}

			guard let mlSession = newMLSess else { return }

			// Mutate MLTrainingObject on main actor (UI object)
			let canAdd: Bool = await MainActor.run {
				session.mlTrainingObject.canAddSession(for: location)
			}
			guard canAdd else {
				//print("[PeripheralSession] Maximum number of sessions (\(await MainActor.run { session.mlTrainingObject.sets })) reached for \(location.displayName); snapshot ignored.")
				return
			}

			await MainActor.run {
				session.mlTrainingObject.addSession(mlSession, for: location)
			}

			// Save and export off-main
			do {
				try await Task.detached(priority: .utility) {
					// Snapshot the current object for writing
					let obj = await MainActor.run { session.mlTrainingObject }
					try obj.save()
					try obj.writeExport()
				}.value
				//print("[PeripheralSession] Saved \(dataPoints.count) IMU samples to MLTrainingObject for \(location.displayName)")
				//postImmediateNotification(with: "Saved \(dataPoints.count) training samples for \(location.displayName)")
				
			} catch {
				print("[PeripheralSession] Error saving/exporting MLTrainingObject: \(error)")
			}
		}
	}
	
	
	// Method to update RSSI
	func updateRSSI(_ rssi: Int) {
		data.rssi = rssi
		objectWillChange.send()
	}

	// Write a command (e.g., CMD_RUN)
	func writeCommand(_ value: UInt8) {
		let key = CharKey(service: PeripheralSession.commandServiceUUID, characteristic: PeripheralSession.commandCharUUID)
		if let char = characteristics[key] {
			let data = Data([value])
			peripheral.writeValue(data, for: char, type: .withResponse)
		}
	}

	// Read command state
	func readCommandState() {
		let key = CharKey(service: PeripheralSession.commandServiceUUID, characteristic: PeripheralSession.commandCharUUID)
		if let char = characteristics[key] {
			peripheral.readValue(for: char)
		}
	}
}

extension PeripheralSession: Identifiable {
	var id: UUID {
		peripheral.identifier
	}
}

extension PeripheralSession {
	var location: Location? {
		get { data.location }
		set {
			let oldValue = data.location
			data.location = newValue
			if oldValue != newValue {
				print("[PeripheralSession] Location changed from \(oldValue?.displayName ?? "nil") to \(newValue?.displayName ?? "nil") for peripheral \(data.localName ?? peripheral.identifier.uuidString)")
				session?.logger.append(
					kind: .location,
					metadata: ["location": "\(data.localName ?? "unknown") location \(newValue?.displayName ?? "nil") for peripheral \(data.localName ?? peripheral.identifier.uuidString)"]
				)
			}
		}
	}
}

extension PeripheralSession {
	
	static func serviceName(for uuid: CBUUID) -> String {
		switch uuid {
			case commandServiceUUID: return "Command Service"
			case fatigueServiceUUID: return "Fatigue Service"
			case fifoServiceUUID: return "Fifo Streaming Service"
			case batteryServiceUUID: return "Battery Service"
			default: return uuid.uuidString
		}
	}

	static func characteristicName(for charUUID: CBUUID, in serviceUUID: CBUUID) -> String {
		switch (serviceUUID, charUUID) {
		case (commandServiceUUID, commandCharUUID):	return "Command"
		case (commandServiceUUID, errorCharUUID): 	return "Error"
		case (commandServiceUUID, sampleRateUUID): 	return "Sample Rate"
		case (commandServiceUUID, imuProfileUUID): 	return "IMU Profile"
		case (fatigueServiceUUID, fatigueCharUUID): return "Fatigue"
		case (fifoServiceUUID, fifoStreamCharUUID): return "Fifo Stream"
		case (fifoServiceUUID, fifoStatusCharUUID): return "Fifo Status"
		case (fifoServiceUUID, fifoL2CAPCharUUID): 	return "Fifo L2CAP"
		case (batteryServiceUUID, batteryCharUUID): return "Battery Level"
		default: return charUUID.uuidString
		}
	}
	
	func addCharacteristic(_ char: CBCharacteristic, from peripheral: CBPeripheral) {
		let serviceText = char.service.map { Self.serviceName(for: $0.uuid) } ?? "Unknown Service"
		let charText = Self.characteristicName(for: char.uuid, in: char.service?.uuid ?? CBUUID())
		let mtu = peripheral.maximumWriteValueLength(for: .withResponse)
		print("[PeripheralSession] Characteristic: \(charText) from \(serviceText) for peripheral \(data.localName ?? peripheral.identifier.uuidString) - mtu = \(mtu)")

		let key = CharKey(service: char.service?.uuid ?? CBUUID(), characteristic: char.uuid)
		characteristics[key] = char

		if char.uuid == PeripheralSession.fifoL2CAPCharUUID {
			peripheral.readValue(for: char)
			print("[PeripheralSession] Subscribed to notifications for characteristic: \(charText) from \(serviceText) for peripheral \(data.localName ?? peripheral.identifier.uuidString)")
		}
		
		// If this is the command characteristic, send the IMU profile
		if char.uuid == PeripheralSession.commandCharUUID {
			if let getActivity = session?.type,
			   let profileCode = ImuProfile.from(activity: getActivity)?.rawValue {
				let data = Data([0x05, profileCode])
				peripheral.writeValue(data, for: char, type: .withResponse)
				print("[PeripheralSession] Sent IMU profile \(profileCode) to \(self.data.localName ?? peripheral.identifier.uuidString)")
			}
		}

		if char.properties.contains(.notify) {
			peripheral.setNotifyValue(true, for: char)
			print("[PeripheralSession] Subscribed to notifications for characteristic: \(charText) from \(serviceText) for peripheral \(data.localName ?? peripheral.identifier.uuidString)")
		}
		if char.properties.contains(.read) {
			peripheral.readValue(for: char)
		}
	}
	
	func handlePSMCharacteristic(_ characteristic: CBCharacteristic) {
		guard let value = characteristic.value else { return }
		let psm: UInt16
		if value.count == 2 {
			psm = UInt16(value[0]) | (UInt16(value[1]) << 8)
		} else if value.count == 1 {
			psm = UInt16(value[0])
		} else {
			print("[PeripheralSession] Unexpected PSM value length: \(value.count)")
			return
		}
		if l2capChannel == nil && !l2capOpenAttempted {
			l2capOpenAttempted = true
			print("[PeripheralSession] Attempting to open L2CAP channel with PSM: \(psm)")
			peripheral.openL2CAPChannel(CBL2CAPPSM(psm))
		} else if l2capChannel != nil {
			print("[PeripheralSession] L2CAP channel already open")
		} else {
			print("[PeripheralSession] L2CAP open already attempted, waiting for result")
		}
	}
	
	func handleNotification(from peripheral: CBPeripheral, for characteristic: CBCharacteristic, value: Data) {
		 
		let serviceText = characteristic.service.map { Self.serviceName(for: $0.uuid) } ?? "Unknown Service"
		let charText = Self.characteristicName(for: characteristic.uuid, in: characteristic.service?.uuid ?? CBUUID())
		
		switch (characteristic.service?.uuid, characteristic.uuid) {
			
			case (PeripheralSession.commandServiceUUID, PeripheralSession.commandCharUUID):
				data.command = CommandState(rawValue: value.first ?? 0) ?? .unknown
				print("[PeripheralSession] Notification from \(data.localName ?? peripheral.identifier.uuidString) for \(serviceText) / \(charText): \(value as NSData)")
			
			case (PeripheralSession.commandServiceUUID, PeripheralSession.sampleRateUUID):
				if value.count >= 2 {
					let lo = UInt16(value[0])
					let hi = UInt16(value[1]) << 8
					data.sampleRate = hi | lo
				}
			
			case (PeripheralSession.batteryServiceUUID, PeripheralSession.batteryCharUUID):
				data.batteryLevel = value.first
			
			case (PeripheralSession.fatigueServiceUUID, PeripheralSession.fatigueCharUUID):
				data.fatigue = value.first
			
			case (PeripheralSession.commandServiceUUID, PeripheralSession.errorCharUUID):
				data.errorCode = value.first
				print("[PeripheralSession] Notification from \(data.localName ?? peripheral.identifier.uuidString) for \(serviceText) / \(charText): \(value as NSData)")
			
			case (PeripheralSession.commandServiceUUID, PeripheralSession.imuProfileUUID) :
				if let raw = value.first, let profile = ImuProfile(rawValue: raw) {
					data.imuProfile = profile
				}
			print("[PeripheralSession] Notification from \(data.localName ?? peripheral.identifier.uuidString) for \(serviceText) / \(charText): \(data.imuProfile?.displayName ?? "unknown")")
			
			case (PeripheralSession.fifoServiceUUID, PeripheralSession.fifoStreamCharUUID):
				print("[PeripheralSession] Notification from \(data.localName ?? peripheral.identifier.uuidString) for \(serviceText) / \(charText): \(value as NSData)")

			case (PeripheralSession.fifoServiceUUID, PeripheralSession.fifoStatusCharUUID):
				if let status = FIFOStatusPayload(data: value) {
					data.fifoStats = status
				} else {
					print("[PeripheralSession] Invalid FIFOStatus payload")
				}
			
			case (PeripheralSession.fifoServiceUUID, PeripheralSession.fifoL2CAPCharUUID):
				handlePSMCharacteristic(characteristic)
				print("[PeripheralSession] Notification from \(data.localName ?? peripheral.identifier.uuidString) for \(serviceText) / \(charText): \(value as NSData)")
				
			default:
				return
		}
	}
	
}
