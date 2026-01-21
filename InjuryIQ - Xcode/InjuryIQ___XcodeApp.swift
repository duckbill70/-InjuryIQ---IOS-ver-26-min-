
//___FILEHEADER___

import SwiftUI
import SwiftData
import CoreBluetooth
import Foundation

@main
struct InjuryIQApp: App {
    private var modelContainer: ModelContainer?
    private var showLaunch: Bool = true
    @State private var showLaunchState: Bool = true
	
	@Environment(\.modelContext) var modelContext
	//@Environment(Session.self) private var session
	
	@State private var sports = Sports()
	@State var session = Session() // Injected via environment
    
    private let fallbackContainer: ModelContainer = {
		let schema = Schema([Item.self, KnownDevice.self, SessionRecord.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try! ModelContainer(for: schema, configurations: [config])
    }()
    
    init() {
        self.modelContainer = initializeContainer()
        if self.modelContainer != nil {
            BLEManager.shared.attach(modelContext: self.modelContainer!.mainContext)
			session.attach(modelContext: self.modelContainer!.mainContext)
        } else {
            BLEManager.shared.attach(modelContext: ModelContext(fallbackContainer))
        }
		session.attachBLEManager(BLEManager.shared)
		//ensureMLTrainingObjectsExist() //loads the ML Trainging Objects
    }

	private func initializeContainer() -> ModelContainer? {
		do {
			// Ensure Application Support directory exists
			let fileManager = FileManager.default
			let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
			if !fileManager.fileExists(atPath: appSupportURL.path) {
				try fileManager.createDirectory(at: appSupportURL, withIntermediateDirectories: true)
			}

			let schema = Schema([Item.self, KnownDevice.self, SessionRecord.self])
			let config = ModelConfiguration(schema: schema)
			return try ModelContainer(for: schema, configurations: [config])
		} catch {
			print("[App] ERROR: \(error)")
			return nil
		}
	}
    
    var body: some Scene {
		WindowGroup {
			Group {
				if showLaunchState {
					LaunchView(isActive: $showLaunchState)
						.onAppear {
							DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
								BLEManager.shared.requestBluetoothPermission()
							}
						}
				} else {
					ContentView(sports: sports)
						.environmentObject(BLEManager.shared)
						.environment(session) // Provide Session via Observation environment
				}
			}
			.onAppear{
				session.attach(modelContext: modelContext)
			}
            .modelContainer(modelContainer ?? fallbackContainer)
            .animation(.easeInOut(duration: 0.25), value: showLaunchState)
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
                BLEManager.shared.stopScan()
            }
        }
    }
}

