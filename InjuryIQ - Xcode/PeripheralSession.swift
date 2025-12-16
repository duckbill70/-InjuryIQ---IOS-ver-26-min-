//
//  PeripheralSession.swift
//  InjuryIQ - Xcode
//
//  Created by Platts Andrew on 16/12/2025.
//

// PeripheralSession.swift
import CoreBluetooth

class PeripheralSession {
	let peripheral: CBPeripheral
	var characteristics: [CBUUID: CBCharacteristic]

	// UUIDs for Command Service and its characteristics
	static let commandServiceUUID = CBUUID(string: "12345679-1234-5678-1234-56789abcdef0")
	static let commandCharUUID    = CBUUID(string: "12345679-1234-5678-1234-56789abcdef1")
	static let statsCharUUID      = CBUUID(string: "12345679-1234-5678-1234-56789abcdef2")
	static let locationCharUUID   = CBUUID(string: "12345679-1234-5678-1234-56789abcdef3")
	static let snapshotCharUUID   = CBUUID(string: "12345679-1234-5678-1234-56789abcdef4")
	static let errorCharUUID      = CBUUID(string: "12345679-1234-5678-1234-56789abcdef5")

	init(peripheral: CBPeripheral, characteristics: [CBUUID: CBCharacteristic]) {
		self.peripheral = peripheral
		self.characteristics = characteristics
	}

	// Write a command (e.g., CMD_RUN)
	func writeCommand(_ value: UInt8) {
		if let char = characteristics[Self.commandCharUUID] {
			let data = Data([value])
			peripheral.writeValue(data, for: char, type: .withResponse)
		}
	}

	// Read device state
	func readCommandState() {
		if let char = characteristics[Self.commandCharUUID] {
			peripheral.readValue(for: char)
		}
	}

	// Subscribe to notifications for Command Characteristic
	func subscribeCommandNotifications(_ enable: Bool) {
		if let char = characteristics[Self.commandCharUUID] {
			peripheral.setNotifyValue(enable, for: char)
		}
	}

	// Read stats
	func readStats() {
		if let char = characteristics[Self.statsCharUUID] {
			peripheral.readValue(for: char)
		}
	}

	// Subscribe to stats notifications
	func subscribeStatsNotifications(_ enable: Bool) {
		if let char = characteristics[Self.statsCharUUID] {
			peripheral.setNotifyValue(enable, for: char)
		}
	}

	// ...repeat for other characteristics as needed
}

// In PeripheralSession.swift
extension PeripheralSession: CustomStringConvertible {
	var description: String {
		//let charList = characteristics.keys.map { $0.uuidString }.joined(separator: ", ")
		//return "PeripheralSession(peripheral: \(peripheral.identifier), characteristics: [\(charList)])"
		//let uuidStr = peripheral.identifier.uuidString
		//let last4 = String(uuidStr.suffix(4))
		let charCount = characteristics.count
		return "characteristics count: \(charCount))"
	}
}

extension PeripheralSession {
	
	func addCharacteristic(_ char: CBCharacteristic) {
		characteristics[char.uuid] = char
		if char.properties.contains(.notify) {
			peripheral.setNotifyValue(true, for: char)
			print("[BLE] Subscribed to notifications for characteristic: \(char.uuid)")
		}
	}
	
	func handleNotification(for characteristic: CBCharacteristic, value: Data) {
			// Process the notification data as needed
			print("[PeripheralSession] Notification for \(characteristic.uuid): \(value as NSData)")
			// Add your custom logic here
		}
	
}


