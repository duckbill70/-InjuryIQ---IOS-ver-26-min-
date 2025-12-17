import Combine
import CoreBluetooth
import Foundation
import SwiftData

// Lightweight model for discovered peripherals
struct DiscoveredPeripheral: Identifiable, Hashable {
    let id: UUID
    let name: String
    let rssi: Int
    let peripheral: CBPeripheral
}

struct ConnectedInfo: Equatable {
    let uuid: UUID
    let name: String
}

@MainActor
final class BLEManager: NSObject, ObservableObject {
    static let shared = BLEManager()

    // Published state
    @Published var isBluetoothOn: Bool = false
    @Published var isScanning: Bool = false
    @Published var discovered: [DiscoveredPeripheral] = []
	
	@Published var connectedPeripherals: [CBPeripheral] = [] {
		didSet {
		  //print("[BLE] connectedPeripherals updated: \(connectedPeripherals)")
		}
	}
	
	@Published var connectedInfo: [ConnectedInfo] = []
	@Published var services: [CBService] = []
	
	@Published var characteristicsByPeripheral: [UUID: [CBUUID: CBCharacteristic]] = [:] {
		didSet {
		  //print("[BLE] characteristicsByPeripheral updated: \(characteristicsByPeripheral)")
		}
	}
	
	///Device Sessions
	@Published var sessionsByPeripheral: [UUID: PeripheralSession] = [:]
	{
	   didSet {
		 //print("[BLE] sessionsByPeripheral updated: \(sessionsByPeripheral)")
	   }
   }
    
	@Published var characteristicsByService: [CBService: [CBCharacteristic]] = [:]
    @Published var lastError: String?
    @Published var bluetoothState: String = "Initializing..."
    @Published var lastConnectedInfo: ConnectedInfo?

    // Settings
    @Published var autoScanOnLaunch: Bool = false
    @Published var filterDuplicates: Bool = true

    // Persistence
    ///var modelContext: ModelContext?
    private(set) var modelContext: ModelContext?

    private var central: CBCentralManager!
    private var disposables: Set<AnyCancellable> = []

    override init() {
        super.init()
        // Initialize CBCentralManager with options to show power alert
        let options: [String: Any] = [
            CBCentralManagerOptionShowPowerAlertKey: true
        ]
        central = CBCentralManager(
            delegate: self,
            queue: .main,
            options: options
        )
        print(
            "[BLE] BLEManager initialized - CBCentralManager created with power alert option"
        )
    }

    
    func attach(modelContext: ModelContext) {
        precondition(Thread.isMainThread, "[BLE] attach must run on main thread")
        self.modelContext = modelContext
        print("[BLE] ModelContext attached")

        // If you want a runtime smoke test, do a tiny fetch in a do/catch block:
        do {
            var descriptor = FetchDescriptor<KnownDevice>()
            descriptor.fetchLimit = 1
            _ = try modelContext.fetch(descriptor) // will throw if KnownDevice not in schema
            print("[BLE] Runtime schema check passed for KnownDevice")
        } catch {
            let nsError = error as NSError
            print("[BLE] Schema check failed: \(nsError.domain) (\(nsError.code)) - \(nsError.localizedDescription)")
            // You can assert in debug builds if desired:
            // assertionFailure("[BLE] KnownDevice not available in this ModelContainer schema")
        }
    }



    /// Persist known device info to SwiftData
    private func persistKnownDevice(uuid: UUID, name: String) {
        assert(Thread.isMainThread, "[BLE] persistKnownDevice must run on main thread")
        guard let ctx = self.modelContext else {
            print("[BLE] No ModelContext attached - cannot persist device")
            return
        }

        do {
            var descriptor = FetchDescriptor<KnownDevice>(
                predicate: #Predicate { $0.uuid == uuid }
            )
            descriptor.fetchLimit = 1

            let existing = try ctx.fetch(descriptor).first

            if let kd = existing {
                kd.name = name
                kd.lastConnectedAt = Date()
                print("[BLE] Updated known device: \(name) (\(uuid))")
            } else {
                let kd = KnownDevice(uuid: uuid, name: name, lastConnectedAt: Date())
                ctx.insert(kd)
                print("[BLE] Saved new known device: \(name) (\(uuid))")
            }

            try ctx.save()
            print("[BLE] SwiftData save OK (KnownDevice)")

        } catch {
            let nsError = error as NSError
            print("[BLE] SwiftData Error: \(nsError.domain) (\(nsError.code)) - \(nsError.localizedDescription)")
        }
    }
    
    /// Update KnownDevices
    private func updateKnownDevice(uuid: UUID, isConnected: Bool) {
        if let modelContext = modelContext {
            let predicate = #Predicate<KnownDevice> { $0.uuid == uuid }
            if let device = try? modelContext.fetch(FetchDescriptor(predicate: predicate)).first {
                device.isConnected = isConnected
                try? modelContext.save()
            }
        }
    }


    /// Request Bluetooth permissions explicitly
    func requestBluetoothPermission() {
        print("[BLE] requestBluetoothPermission() called")
        _ = central.state  // touch state; callbacks will fire as needed
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.checkBluetoothState()
        }
    }


    /// Check and log the current Bluetooth state
    func checkBluetoothState() {
        let state = central.state
        print("[BLE] checkBluetoothState() - current state: \(state.rawValue)")
        updateStateUI(state)
    }

    private func updateStateUI(_ state: CBManagerState) {
        switch state {
        case .unknown:
            bluetoothState = "⏳ Waiting for Bluetooth to initialize..."
            isBluetoothOn = false
            print("[BLE] State: UNKNOWN (0)")
        case .resetting:
            bluetoothState = "⏳ Bluetooth is resetting..."
            isBluetoothOn = false
            print("[BLE] State: RESETTING (1)")
        case .unsupported:
            bluetoothState = "❌ Bluetooth not supported on this device"
            isBluetoothOn = false
            print("[BLE] State: UNSUPPORTED (2)")
        case .unauthorized:
            bluetoothState =
                "❌ Bluetooth permission denied.\nEnable in Settings > Privacy & Security > Bluetooth"
            isBluetoothOn = false
            print("[BLE] State: UNAUTHORIZED (3)")
        case .poweredOff:
            bluetoothState =
                "❌ Bluetooth is OFF.\nEnable in Settings > Bluetooth"
            isBluetoothOn = false
            print("[BLE] State: POWERED_OFF (4)")
        case .poweredOn:
            bluetoothState = "✅ Bluetooth is ready"
            isBluetoothOn = true
            print("[BLE] State: POWERED_ON (5) ✅")
        @unknown default:
            bluetoothState = "⚠️ Unknown Bluetooth state"
            isBluetoothOn = false
            print("[BLE] State: UNKNOWN_DEFAULT")
        }
    }

    func startScan(serviceUUIDs: [CBUUID]? = nil) {
        guard isBluetoothOn else {
            print("[BLE] Cannot start scan - Bluetooth is not on")
            return
        }
        if !filterDuplicates { discovered.removeAll() }
        isScanning = true
        print("[BLE] Starting BLE scan...")
        central.scanForPeripherals(
            withServices: serviceUUIDs,
            options: [
                CBCentralManagerScanOptionAllowDuplicatesKey: !filterDuplicates
            ]
        )
    }

    func stopScan() {
        isScanning = false
        central.stopScan()
        print("[BLE] Stopped BLE scan")
    }

    func connect(_ dp: DiscoveredPeripheral) {
        services.removeAll()
        characteristicsByService.removeAll()
        lastError = nil
        print("[BLE] Connecting to: \(dp.name)")
        central.connect(dp.peripheral, options: nil)
    }

    func disconnect(_ peripheral: CBPeripheral) {
        //if let p = connectedPeripheral {
            print("[BLE] Disconnecting from: \(peripheral.name ?? "Unknown")")
        //    central.cancelPeripheralConnection(p)
        //}
		central.cancelPeripheralConnection(peripheral)
    }
}

// MARK: - CBCentralManagerDelegate
extension BLEManager: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        print("[BLE] centralManagerDidUpdateState: \(central.state.rawValue)")
        updateStateUI(central.state)

        if central.state == .poweredOn && autoScanOnLaunch {
            print("[BLE] Auto-scan enabled and Bluetooth is on - starting scan")
            startScan()
        } else if central.state != .poweredOn {
            stopScan()
            discovered.removeAll()
        }
    }

    func centralManager( _ central: CBCentralManager,  didDiscover peripheral: CBPeripheral, advertisementData: [String: Any],  rssi RSSI: NSNumber ) {
		let name = peripheral.name ?? "Unknown"
		let localName = advertisementData[CBAdvertisementDataLocalNameKey] as? String
		print("[BLE] Discovered: \(localName ?? name) - RSSI: \(RSSI)")
		
		///Create a PeripheralSession Obhect for STINGRAY devices
		if name == "STINGRAY" {
			let session = PeripheralSession(peripheral: peripheral, characteristics: [:], localName: localName)
			sessionsByPeripheral[peripheral.identifier] = session
		}
		
		///Update a lits of Discovered Devices
        let dp = DiscoveredPeripheral(
            id: peripheral.identifier,
            name: name,
            rssi: RSSI.intValue,
            peripheral: peripheral
        )
        if filterDuplicates {
            if let idx = discovered.firstIndex(where: { $0.id == dp.id }) {
                discovered[idx] = dp
            } else {
                discovered.append(dp)
            }
        } else {
            discovered.append(dp)
        }
    }

    func centralManager( _ central: CBCentralManager,  didConnect peripheral: CBPeripheral ) {
        let uuid = peripheral.identifier
        let name = peripheral.name ?? "Unknown"

        //connectedPeripheral = peripheral
		connectedPeripherals.append(peripheral)
		connectedInfo.append(ConnectedInfo(uuid: uuid, name: name))
		
		lastConnectedInfo = ConnectedInfo(uuid: uuid, name: name)
        
        print("[BLE] Connected to: \(name)")

        peripheral.delegate = self
        peripheral.discoverServices(nil)

        Task { @MainActor in
            persistKnownDevice(uuid: peripheral.identifier, name: name)
            updateKnownDevice(uuid: uuid, isConnected: true)
        }

    }

    func centralManager( _ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error? ) {
        let errorMsg = error?.localizedDescription ?? "Unknown error"
        print("[BLE] Failed to connect: \(errorMsg)")
        lastError = errorMsg
    }

    func centralManager( _ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error? ) {
        print("[BLE] Disconnected from: \(peripheral.name ?? "Unknown")")

		connectedPeripherals.removeAll { $0.identifier == peripheral.identifier }
		connectedInfo.removeAll { $0.uuid == peripheral.identifier }
        services.removeAll()
        characteristicsByService.removeAll()
		
		// Remove characteristics and sessions for the disconnected peripheral
		characteristicsByPeripheral.removeValue(forKey: peripheral.identifier)
		sessionsByPeripheral.removeValue(forKey: peripheral.identifier)
		
        updateKnownDevice(uuid: peripheral.identifier, isConnected: false)
    }
}

// MARK: - CBPeripheralDelegate
extension BLEManager: CBPeripheralDelegate {
	
    func peripheral( _ peripheral: CBPeripheral, didDiscoverServices error: Error? ) {
        if let error = error {
            lastError = error.localizedDescription
            print("[BLE] Error discovering services: \(error)")
            return
        }
        guard let svcs = peripheral.services else { return }
        //print("[BLE] Discovered \(svcs.count) services")
        services = svcs
        svcs.forEach { peripheral.discoverCharacteristics(nil, for: $0) }
    }

    func peripheral( _ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService,  error: Error? ) {
		if let error = error {
				lastError = error.localizedDescription
				print("[BLE] Error discovering characteristics: \(error)")
				return
		}
		let chars = service.characteristics ?? []
		//print("[BLE] Discovered \(chars.count) characteristics for service")
		characteristicsByService[service] = chars

			//var session = sessionsByPeripheral[peripheral.identifier] ?? PeripheralSession(peripheral: peripheral, characteristics: [:])
		
		///Update PeripheralSession with discovered characteristics
		let session = sessionsByPeripheral[peripheral.identifier] ?? PeripheralSession(peripheral: peripheral, characteristics: [:], localName: nil)
		for char in chars {
			session.addCharacteristic(char, from: peripheral)
		}
		sessionsByPeripheral[peripheral.identifier] = session
		
    }
	
	func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
		if let error = error {
			print("[BLE] Error receiving notification for \(characteristic.uuid): \(error)")
			lastError = error.localizedDescription
			return
		}
		guard let value = characteristic.value else {
			print("[BLE] No value received for \(characteristic.uuid)")
			return
		}
		// Pass the value to the PeripheralSession
		if let session = sessionsByPeripheral[peripheral.identifier] {
			session.handleNotification(from: peripheral, for: characteristic, value: value)
			sessionsByPeripheral[peripheral.identifier] = session
		}
	}
}
