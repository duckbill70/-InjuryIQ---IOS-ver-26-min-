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
	let localName: String
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
		  //print("[BLEmanager] connectedPeripherals updated: \(connectedPeripherals)")
		}
	}
	
	@Published var connectedInfo: [ConnectedInfo] = []
	@Published var services: [CBService] = []
	
	@Published var characteristicsByPeripheral: [UUID: [CBUUID: CBCharacteristic]] = [:] {
		didSet {
		  //print("[BLEmanager] characteristicsByPeripheral updated: \(characteristicsByPeripheral)")
		}
	}
	
	///Device Sessions
	@Published var sessionsByPeripheral: [UUID: PeripheralSession] = [:]
	{
	   didSet {
		 //print("[BLEmanager] sessionsByPeripheral updated: \(sessionsByPeripheral)")
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
	
	private var session: Session?
	
	private var rssiTimer : Timer?

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
            "[BLEmanager] BLEManager initialized - CBCentralManager created with power alert option"
        )
    }

	///Used to attach the current session
	func attachSession(_ session: Session) {
		self.session = session
	}
	
    func attach(modelContext: ModelContext) {
        precondition(Thread.isMainThread, "[BLEmanager] attach must run on main thread")
        self.modelContext = modelContext
        print("[BLEmanager] ModelContext attached")

        // If you want a runtime smoke test, do a tiny fetch in a do/catch block:
        do {
            var descriptor = FetchDescriptor<KnownDevice>()
            descriptor.fetchLimit = 1
            _ = try modelContext.fetch(descriptor) // will throw if KnownDevice not in schema
            print("[BLEmanager] Runtime schema check passed for KnownDevice")
        } catch {
            let nsError = error as NSError
            print("[BLEmanager] Schema check failed: \(nsError.domain) (\(nsError.code)) - \(nsError.localizedDescription)")
            // You can assert in debug builds if desired:
            // assertionFailure("[BLEmanager] KnownDevice not available in this ModelContainer schema")
        }
    }



    /// Persist known device info to SwiftData
    private func persistKnownDevice(uuid: UUID, name: String) {
        assert(Thread.isMainThread, "[BLEmanager] persistKnownDevice must run on main thread")
        guard let ctx = self.modelContext else {
            print("[BLEmanager] No ModelContext attached - cannot persist device")
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
                print("[BLEmanager] Updated known device: \(name) (\(uuid))")
            } else {
                let kd = KnownDevice(uuid: uuid, name: name, lastConnectedAt: Date())
                ctx.insert(kd)
                print("[BLEmanager] Saved new known device: \(name) (\(uuid))")
            }

            try ctx.save()
            print("[BLEmanager] SwiftData save OK (KnownDevice)")

        } catch {
            let nsError = error as NSError
            print("[BLEmanager] SwiftData Error: \(nsError.domain) (\(nsError.code)) - \(nsError.localizedDescription)")
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
        print("[BLEmanager] requestBluetoothPermission() called")
        _ = central.state  // touch state; callbacks will fire as needed
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.checkBluetoothState()
        }
    }


    /// Check and log the current Bluetooth state
    func checkBluetoothState() {
        let state = central.state
        print("[BLEmanager] checkBluetoothState() - current state: \(state.rawValue)")
        updateStateUI(state)
    }

    private func updateStateUI(_ state: CBManagerState) {
        switch state {
        case .unknown:
            bluetoothState = "⏳ Waiting for Bluetooth to initialize..."
            isBluetoothOn = false
            print("[BLEmanager] State: UNKNOWN (0)")
        case .resetting:
            bluetoothState = "⏳ Bluetooth is resetting..."
            isBluetoothOn = false
            print("[BLEmanager] State: RESETTING (1)")
        case .unsupported:
            bluetoothState = "❌ Bluetooth not supported on this device"
            isBluetoothOn = false
            print("[BLEmanager] State: UNSUPPORTED (2)")
        case .unauthorized:
            bluetoothState =
                "❌ Bluetooth permission denied.\nEnable in Settings > Privacy & Security > Bluetooth"
            isBluetoothOn = false
            print("[BLEmanager] State: UNAUTHORIZED (3)")
        case .poweredOff:
            bluetoothState =
                "❌ Bluetooth is OFF.\nEnable in Settings > Bluetooth"
            isBluetoothOn = false
            print("[BLEmanager] State: POWERED_OFF (4)")
        case .poweredOn:
            bluetoothState = "✅ Bluetooth is ready"
            isBluetoothOn = true
            print("[BLEmanager] State: POWERED_ON (5) ✅")
        @unknown default:
            bluetoothState = "⚠️ Unknown Bluetooth state"
            isBluetoothOn = false
            print("[BLEmanager] State: UNKNOWN_DEFAULT")
        }
    }

    func startScan(serviceUUIDs: [CBUUID]? = nil) {
        guard isBluetoothOn else {
            print("[BLEmanager] Cannot start scan - Bluetooth is not on")
            return
        }
        if !filterDuplicates { discovered.removeAll() }
        isScanning = true
        print("[BLEmanager] Starting BLE scan...")
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
        print("[BLEmanager] Stopped BLE scan")
    }

    func connect(_ dp: DiscoveredPeripheral) {
        services.removeAll()
        characteristicsByService.removeAll()
        lastError = nil
        print("[BLEmanager] Connecting to: \(dp.name)")
        central.connect(dp.peripheral, options: nil)
    }

    func disconnect(_ peripheral: CBPeripheral) {
        //if let p = connectedPeripheral {
            print("[BLEmanager] Disconnecting from: \(peripheral.name ?? "Unknown")")
        //    central.cancelPeripheralConnection(p)
        //}
		central.cancelPeripheralConnection(peripheral)
    }
}

// MARK: - CBCentralManagerDelegate
extension BLEManager: CBCentralManagerDelegate {
	
	func centralManagerDidUpdateState(_ central: CBCentralManager) {
        print("[BLEmanager] centralManagerDidUpdateState: \(central.state.rawValue)")
        updateStateUI(central.state)

        if central.state == .poweredOn && autoScanOnLaunch {
            print("[BLEmanager] Auto-scan enabled and Bluetooth is on - starting scan")
            startScan()
        } else if central.state != .poweredOn {
            stopScan()
            discovered.removeAll()
        }
    }
	
	private func updateRSSIForConnectedPeripherals() {
		for peripheral in connectedPeripherals {
			peripheral.readRSSI()
		}
	}

    func centralManager( _ central: CBCentralManager,  didDiscover peripheral: CBPeripheral, advertisementData: [String: Any],  rssi RSSI: NSNumber ) {
		let name = peripheral.name ?? "Unknown"
		let localName = advertisementData[CBAdvertisementDataLocalNameKey] as? String
		//print("[BLEmanager] Discovered: \(localName ?? name) - RSSI: \(RSSI)")
		
		///Create a PeripheralSession Obhect for STINGRAY devices
		//if name == "STINGRAY" {
		//	let session = PeripheralSession(peripheral: peripheral, characteristics: [:], localName: localName)
		//	sessionsByPeripheral[peripheral.identifier] = session
		//}
		
		///Update a lits of Discovered Devices
        let dp = DiscoveredPeripheral(
            id: peripheral.identifier,
            name: name,
            rssi: RSSI.intValue,
            peripheral: peripheral,
			localName: localName ?? "Stringray Unknown"
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
		let localName = discovered.first(where: { $0.id == uuid })?.localName ?? "Unknown"

        //connectedPeripheral = peripheral
		connectedPeripherals.append(peripheral)
		connectedInfo.append(ConnectedInfo(uuid: uuid, name: name))
		
		lastConnectedInfo = ConnectedInfo(uuid: uuid, name: name)
		
		// Create session on connection
		if sessionsByPeripheral[uuid] == nil {
			let session = PeripheralSession(peripheral: peripheral, characteristics: [:], localName: localName)
			session.session = self.session
			sessionsByPeripheral[uuid] = session
		}
	
        
        print("[BLEmanager] Connected to: \(name)")

        peripheral.delegate = self
        peripheral.discoverServices(nil)

        Task { @MainActor in
            persistKnownDevice(uuid: peripheral.identifier, name: name)
            updateKnownDevice(uuid: uuid, isConnected: true)
        }
		
		rssiTimer?.invalidate()
		rssiTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
			guard let self else { return }
			Task { @MainActor in self.updateRSSIForConnectedPeripherals() }
		}
		
		session?.logger.append(kind: .bleConnected, metadata: ["device": "\(localName)"])

    }

    func centralManager( _ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error? ) {
        let errorMsg = error?.localizedDescription ?? "Unknown error"
        print("[BLEmanager] Failed to connect: \(errorMsg)")
        lastError = errorMsg
    }

    func centralManager( _ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error? ) {
		
		let localName = discovered.first(where: { $0.id == peripheral.identifier })?.localName ?? "Unknown"
		print("[BLEmanager] Disconnected from: \(localName)")

		connectedPeripherals.removeAll { $0.identifier == peripheral.identifier }
		connectedInfo.removeAll { $0.uuid == peripheral.identifier }
        services.removeAll()
        characteristicsByService.removeAll()
		
		// Remove characteristics and sessions for the disconnected peripheral
		characteristicsByPeripheral.removeValue(forKey: peripheral.identifier)
		sessionsByPeripheral.removeValue(forKey: peripheral.identifier)
		
        updateKnownDevice(uuid: peripheral.identifier, isConnected: false)
		
		if connectedPeripherals.isEmpty {
			rssiTimer?.invalidate()
			rssiTimer = nil
		}
		
		session?.logger.append(kind: .bleDisconnected, metadata: ["device": "\(localName)"])
    }
}

// MARK: - CBPeripheralDelegate
extension BLEManager: CBPeripheralDelegate {
	
    func peripheral( _ peripheral: CBPeripheral, didDiscoverServices error: Error? ) {
        if let error = error {
            lastError = error.localizedDescription
            print("[BLEmanager] Error discovering services: \(error)")
            return
        }
        guard let svcs = peripheral.services else { return }
        //print("[BLEmanager] Discovered \(svcs.count) services")
        services = svcs
        svcs.forEach { peripheral.discoverCharacteristics(nil, for: $0) }
    }

    func peripheral( _ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService,  error: Error? ) {
		if let error = error {
				lastError = error.localizedDescription
				print("[BLEmanager] Error discovering characteristics: \(error)")
				return
		}
		let chars = service.characteristics ?? []
		characteristicsByService[service] = chars

		
		///Update PeripheralSession with discovered characteristics
		// Use existing session - don't create new one
		guard let session = sessionsByPeripheral[peripheral.identifier] else {
			print("[BLEmanager] Warning: No session found for peripheral \(peripheral.identifier)")
			return
		}
		
		for char in chars {
			session.addCharacteristic(char, from: peripheral)
		}
		sessionsByPeripheral[peripheral.identifier] = session
		
    }
	
	func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
		if let error = error {
			print("[BLEmanager] Error receiving notification for \(characteristic.uuid): \(error)")
			lastError = error.localizedDescription
			return
		}
		guard let value = characteristic.value else {
			print("[BLEmanager] No value received for \(characteristic.uuid)")
			return
		}
		
		// Pass the value to the PeripheralSession
		if let session = sessionsByPeripheral[peripheral.identifier] {
			session.handleNotification(from: peripheral, for: characteristic, value: value)
			sessionsByPeripheral[peripheral.identifier] = session
		}
	}
	
	func peripheral(_ peripheral: CBPeripheral, didReadRSSI RSSI: NSNumber, error: Error?) {
		
		if let session = sessionsByPeripheral[peripheral.identifier] {
			//print ("[BLEmanager] Updating RSSI : \(RSSI.intValue) for peripheral: \(session.data.localName ?? "unknown")")
			session.updateRSSI(RSSI.intValue)
			sessionsByPeripheral[peripheral.identifier] = session
		}
	}

	func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
		if let error = error {
			print("[BLEManager] Error writing to \(characteristic.uuid) for peripheral \(peripheral.identifier): \(error.localizedDescription)")
			lastError = error.localizedDescription
		} else {
			print("[BLEManager] Successfully wrote to \(characteristic.uuid) for peripheral \(peripheral.identifier)")
		}
	}
	
	func peripheral(_ peripheral: CBPeripheral, didOpen channel: CBL2CAPChannel?, error: Error?) {
		if let session = sessionsByPeripheral[peripheral.identifier] {
			if let error = error {
				print("[PeripheralSession] Failed to open L2CAP channel: \(error)")
				// Optionally: session.l2capOpenAttempted = false
			} else if let channel = channel {
				print("[PeripheralSession] L2CAP channel opened: \(channel)")
				session.l2capChannel = channel
				if let inputStream = channel.inputStream {
					inputStream.delegate = session
					inputStream.schedule(in: .main, forMode: .default)
					inputStream.open()
				}
			}
			sessionsByPeripheral[peripheral.identifier] = session
		} else {
			print("[BLEManager] No session found for peripheral \(peripheral.identifier)")
		}
	}
	
}
