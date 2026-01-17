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

enum CommandState: UInt8 {
	case cmd_state_off 		= 0x00
	case cmd_state_idle 	= 0x01
	case cmd_state_running 	= 0x02
	case cmd_state_location = 0x03
	case cmd_state_snapshot = 0x04
	case unknown 			= 0xFF
}

enum Location: String, CaseIterable, Identifiable {
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
}

struct PeripheralData {
	
	var localName		: String?
	var batteryLevel	: UInt8?
	var command			: CommandState?
	var location		: Location?
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

//extension PeripheralData {
//	var locationColor: Color {
//		switch location {
//		case nil: return .clear      // none
//		case 0x00: return .red       // 0x00
//		case 0x01: return .green     // 0x01
//		default: return .gray        // unexpected values
//		}
//	}
//}

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
	static let commandServiceUUID = CBUUID(string: "12345679-1234-5678-1234-56789abcdef0")
	static let commandCharUUID    = CBUUID(string: "12345679-1234-5678-1234-56789abcdef1")
	static let errorCharUUID      = CBUUID(string: "12345679-1234-5678-1234-56789abcdef5")
	static let sampleRateUUID      = CBUUID(string: "12345679-1234-5678-1234-56789abcdef6")
	
	///UUIDs Fatigue Service and its characteristics
	static let fatigueServiceUUID = CBUUID(string: "12345678-1234-5678-1234-56789abcdef0")
	static let fatigueCharUUID    = CBUUID(string: "12345678-1234-5678-1234-56789abcdef1")
	
	///UUIDs Fifo Streaming Service
	static let fifoServiceUUID 		= CBUUID(string: "12345680-1234-5678-1234-56789abcdef0")
	static let fifoStreamCharUUID   = CBUUID(string: "12345680-1234-5678-1234-56789abcdef1")
	static let fifoStatusCharUUID   = CBUUID(string: "12345680-1234-5678-1234-56789abcdef2")
	static let fifoL2CAPCharUUID	= CBUUID(string: "12345680-1234-5678-1234-56789ABCDEF3")
	
	///UUIDs Battery Service and its characteristics
	static let batteryServiceUUID = CBUUID(string: "180F") // Standard UUID for
	static let batteryCharUUID    = CBUUID(string: "2A19") // Standard UUID for Battery Level Characteristic
	

	init(peripheral: CBPeripheral, characteristics: [CharKey: CBCharacteristic], localName: String? = nil) {
		self.peripheral = peripheral
		self.characteristics = characteristics
		self.data = PeripheralData(
			localName: localName,
			batteryLevel: nil,
			command: nil,
			location: nil,
			sampleRate: nil,
		)
	}
	
	///Stream Delegate:
	func stream(_ aStream: Stream, handle eventCode: Stream.Event) {
			switch eventCode {
			case .hasBytesAvailable:
				if let inputStream = aStream as? InputStream {
					var buffer = [UInt8](repeating: 0, count: 1024)
					while inputStream.hasBytesAvailable {
						let bytesRead = inputStream.read(&buffer, maxLength: buffer.count)
						if bytesRead > 0 {
							let data = Data(buffer.prefix(bytesRead))
							
							///Next STEPS HERE!!!!!!!!!!!!!!!
							//print("[PeripheralSession] Received L2CAP data: \(data as NSData)")
							// Process data as needed
						}
					}
				}
			case .endEncountered, .errorOccurred:
				print("[PeripheralSession] L2CAP input stream closed or error")
			default:
				break
			}
		}
	
	// Method to update RSSI
	func updateRSSI(_ rssi: Int) {
		data.rssi = rssi
		//print ("[PeripheralSession] Updating RSSI : \(rssi) for peripheral: \(data.localName)")
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

	// Subscribe to notifications for Command Characteristic
	//func subscribeCommandNotifications(_ enable: Bool) {
	//	if let char = characteristics[Self.commandCharUUID] {
	//		peripheral.setNotifyValue(enable, for: char)
	//	}
	//}



	// Subscribe to stats notifications
	//func subscribeStatsNotifications(_ enable: Bool) {
	//	if let char = characteristics[Self.statsCharUUID] {
	//		peripheral.setNotifyValue(enable, for: char)
	//	}
	//}

}

// In PeripheralSession.swift
//extension PeripheralSession: CustomStringConvertible {
//	var description: String {
		//let charList = characteristics.keys.map { $0.uuidString }.joined(separator: ", ")
		//return "PeripheralSession(peripheral: \(peripheral.identifier), characteristics: [\(charList)])"
		//let uuidStr = peripheral.identifier.uuidString
		//let last4 = String(uuidStr.suffix(4))
//		let charCount = characteristics.count
//		return "characteristics count: \(charCount))"
//	}
//}

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
			// Add more cases as needed
			default: return uuid.uuidString
		}
	}

	static func characteristicName(for charUUID: CBUUID, in serviceUUID: CBUUID) -> String {
		switch (serviceUUID, charUUID) {
			
		// Command Service
		case (commandServiceUUID, commandCharUUID): return "Command"
		case (commandServiceUUID, errorCharUUID): return "Error"
		case (commandServiceUUID, sampleRateUUID): return "Sample Rate"
			
		// Fatigue Service
		case (fatigueServiceUUID, fatigueCharUUID): return "Fatigue"
		
		// Fifo Streaming Service
		case (fifoServiceUUID, fifoStreamCharUUID): return "Fifo Stream"
		case (fifoServiceUUID, fifoStatusCharUUID): return "Fifo Status"
		case (fifoServiceUUID, fifoL2CAPCharUUID): return "Fifo L2CAP"
			
		// Battery Service
		case (batteryServiceUUID, batteryCharUUID): return "Battery Level"
			
		// Add more (service, char) pairs as needed
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

		/// Only subscribe to notifications for notify-only characteristics
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
		// Only attempt to open once per session
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
		
		//if 	characteristic.service?.uuid != Self.batteryServiceUUID && characteristic.service?.uuid != Self.fatigueServiceUUID  {
		//	print("[PeripheralSession] Notification from \(data.localName ?? peripheral.identifier.uuidString) for \(serviceText) / \(charText): \(value as NSData)")
		//}
		
		switch (characteristic.service?.uuid, characteristic.uuid) {
			
			/// Command Characteristic
			case (PeripheralSession.commandServiceUUID, PeripheralSession.commandCharUUID):
				data.command = CommandState(rawValue: value.first ?? 0) ?? .unknown
				print("[PeripheralSession] Notification from \(data.localName ?? peripheral.identifier.uuidString) for \(serviceText) / \(charText): \(value as NSData)")
			
			/// Sample Rate Characteristic
			case (PeripheralSession.commandServiceUUID, PeripheralSession.sampleRateUUID):
				if value.count >= 2 {
					let lo = UInt16(value[0])
					let hi = UInt16(value[1]) << 8
					data.sampleRate = hi | lo
				}
			
			///Battery Characteristic
			case (PeripheralSession.batteryServiceUUID, PeripheralSession.batteryCharUUID):
				data.batteryLevel = value.first
			
			///Fatigue Characteristic
			case (PeripheralSession.fatigueServiceUUID, PeripheralSession.fatigueCharUUID):
				data.fatigue = value.first
			
			///Error Characteristic
			case (PeripheralSession.commandServiceUUID, PeripheralSession.errorCharUUID):
				data.errorCode = value.first
				print("[PeripheralSession] Notification from \(data.localName ?? peripheral.identifier.uuidString) for \(serviceText) / \(charText): \(value as NSData)")
			
			/// FIFO Stream Char
			case (PeripheralSession.fifoServiceUUID, PeripheralSession.fifoStreamCharUUID):
				print("[PeripheralSession] Notification from \(data.localName ?? peripheral.identifier.uuidString) for \(serviceText) / \(charText): \(value as NSData)")

			/// FIFO Stream Status Char
			case (PeripheralSession.fifoServiceUUID, PeripheralSession.fifoStatusCharUUID):
				if let status = FIFOStatusPayload(data: value) {
					//print("[PeripheralSession] FIFOStatus: \(status)")
					data.fifoStats = status
				} else {
					print("[PeripheralSession] Invalid FIFOStatus payload")
				}
			
			///FIFO L2CAP
			case (PeripheralSession.fifoServiceUUID, PeripheralSession.fifoL2CAPCharUUID):
				// Call handlePSMCharacteristic to open L2CAP channel
				handlePSMCharacteristic(characteristic)
				print("[PeripheralSession] Notification from \(data.localName ?? peripheral.identifier.uuidString) for \(serviceText) / \(charText): \(value as NSData)")
				
			
			default:
				return
		}
		
		//
		// Custom logic here
	}
	
}
