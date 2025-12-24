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
	case stopped = 0x00
	case running = 0x01
	case dumping = 0x03
	case showingLocation = 0x04
	case unknown = 0xFF
}

struct PeripheralData {
	
	var localName		: String?
	var batteryLevel	: UInt8?
	var command			: CommandState?
	var location		: UInt8?
	// Add more fields as needed for other characteristic values
	
	var errorCode		: UInt8?
	var stats			: UInt16?
	var snapshotCount	: UInt8?
	
	var fatigue			: UInt8?
	
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

extension PeripheralData {
	var locationColor: Color {
		switch location {
		case nil: return .clear      // none
		case 0x00: return .red       // 0x00
		case 0x01: return .green     // 0x01
		default: return .gray        // unexpected values
		}
	}
}

class PeripheralSession: ObservableObject {
	
	let peripheral: CBPeripheral
	
	///Publiched Observable objects in the session
	@Published var characteristics: [CharKey: CBCharacteristic] = [:]
	@Published var data: PeripheralData

	/// UUIDs for Command Service and its characteristics
	static let commandServiceUUID = CBUUID(string: "12345679-1234-5678-1234-56789abcdef0")
	static let commandCharUUID    = CBUUID(string: "12345679-1234-5678-1234-56789abcdef1")
	static let statsCharUUID      = CBUUID(string: "12345679-1234-5678-1234-56789abcdef2")
	static let locationCharUUID   = CBUUID(string: "12345679-1234-5678-1234-56789abcdef3")
	static let snapshotCharUUID   = CBUUID(string: "12345679-1234-5678-1234-56789abcdef4")
	static let errorCharUUID      = CBUUID(string: "12345679-1234-5678-1234-56789abcdef5")
	
	///UUIDs Fatigue Service and its characteristics
	static let fatigueServiceUUID = CBUUID(string: "12345678-1234-5678-1234-56789abcdef0")
	static let fatigueCharUUID    = CBUUID(string: "12345678-1234-5678-1234-56789abcdef1")
	
	///UUIDs Fifo Streaming Service
	static let fifoServiceUUID 		= CBUUID(string: "12345680-1234-5678-1234-56789abcdef0")
	static let fifoStreamCharUUID   = CBUUID(string: "12345680-1234-5678-1234-56789abcdef1")
	static let fifoStatusCharUUID   = CBUUID(string: "12345680-1234-5678-1234-56789abcdef2")
	
	///UUIDs Steps Service and its characteristics
	static let stepsServiceUUID = CBUUID(string: "1814") // Standard UUID for Running Speed and Cadence Service
	static let stepsCharUUID    = CBUUID(string: "2A53") // Standard UUID for RSC Measurement Characteristic
	
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
		)
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
	
	static func serviceName(for uuid: CBUUID) -> String {
		switch uuid {
			case commandServiceUUID: return "Command Service"
			case fatigueServiceUUID: return "Fatigue Service"
			case fifoServiceUUID: return "Fifo Streaming Service"
			case batteryServiceUUID: return "Battery Service"
			case stepsServiceUUID: return "Steps Service"
			// Add more cases as needed
			default: return uuid.uuidString
		}
	}

	static func characteristicName(for charUUID: CBUUID, in serviceUUID: CBUUID) -> String {
		switch (serviceUUID, charUUID) {
			
		// Command Service
		case (commandServiceUUID, commandCharUUID): return "Command"
		case (commandServiceUUID, statsCharUUID): return "Stats"
		case (commandServiceUUID, locationCharUUID): return "Location"
		case (commandServiceUUID, snapshotCharUUID): return "Snapshot"
		case (commandServiceUUID, errorCharUUID): return "Error"
			
		// Fatigue Service
		case (fatigueServiceUUID, fatigueCharUUID): return "Fatigue"
		
		// Fifo Streaming Service
		case (fifoServiceUUID, fifoStreamCharUUID): return "Fifo Stream"
		case (fifoServiceUUID, fifoStatusCharUUID): return "Fifo Status"
			
		// Steps Service
		case (stepsServiceUUID, stepsCharUUID): return "Steps"
			
		// Battery Service
		case (batteryServiceUUID, batteryCharUUID): return "Battery Level"
			
		// Add more (service, char) pairs as needed
		default: return charUUID.uuidString
		}
	}
	
	func addCharacteristic(_ char: CBCharacteristic, from peripheral: CBPeripheral) {
		let serviceText = char.service.map { Self.serviceName(for: $0.uuid) } ?? "Unknown Service"
		let charText = Self.characteristicName(for: char.uuid, in: char.service?.uuid ?? CBUUID())
		
		let key = CharKey(service: char.service?.uuid ?? CBUUID(), characteristic: char.uuid)
		characteristics[key] = char
		if char.properties.contains(.notify) {
			peripheral.setNotifyValue(true, for: char)
			print("[PeripheralSession] Subscribed to notifications for characteristic: \(charText) from \(serviceText) for peripheral \(data.localName ?? peripheral.identifier.uuidString)")
		}
		
		if char.properties.contains(.read) {
			peripheral.readValue(for: char)
			//print("[PeripheralSession] Reading initial value for characteristic: \(charText) from \(serviceText) for peripheral \(data.localName ?? peripheral.identifier.uuidString)")
		}
	}
	
	func handleNotification(from peripheral: CBPeripheral, for characteristic: CBCharacteristic, value: Data) {
		let serviceText = characteristic.service.map { Self.serviceName(for: $0.uuid) } ?? "Unknown Service"
		let charText = Self.characteristicName(for: characteristic.uuid, in: characteristic.service?.uuid ?? CBUUID())
		
		if 	characteristic.service?.uuid != Self.batteryServiceUUID && characteristic.service?.uuid != Self.fatigueServiceUUID && characteristic.service?.uuid != Self.stepsServiceUUID {
			print("[PeripheralSession] Notification from \(data.localName ?? peripheral.identifier.uuidString) for \(serviceText) / \(charText): \(value as NSData)")
		}
		
		switch (characteristic.service?.uuid, characteristic.uuid) {
			
			/// Command Service
			case (PeripheralSession.commandServiceUUID, PeripheralSession.commandCharUUID):
				data.command = CommandState(rawValue: value.first ?? 0) ?? .unknown
			
			///Battery Service
			case (PeripheralSession.batteryServiceUUID, PeripheralSession.batteryCharUUID):
				data.batteryLevel = value.first
			
			///Fa§tigue Service
			case (PeripheralSession.fatigueServiceUUID, PeripheralSession.fatigueCharUUID):
				data.fatigue = value.first
			
			///Location Characteristic
			case (PeripheralSession.commandServiceUUID, PeripheralSession.locationCharUUID):
				data.location = value.first
			
			///Error Characteristic
			case (PeripheralSession.commandServiceUUID, PeripheralSession.errorCharUUID):
				data.errorCode = value.first
			
			///New: snapshot count (assume 2-byte little-endian)
			case (Self.commandServiceUUID, Self.snapshotCharUUID):
				data.snapshotCount = value.first

			/// New: FIFO fill (assume 1 byte 0...100)
			case (Self.fifoServiceUUID, Self.fifoStatusCharUUID):
				if value.count >= 2 {
					let lo = UInt16(value[0])
					let hi = UInt16(value[1]) << 8
					data.stats = hi | lo
				}
				
			
			default:
				return
		}
		
		//
		// Custom logic here
	}
	
}
