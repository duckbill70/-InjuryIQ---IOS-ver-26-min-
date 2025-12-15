
//___FILEHEADER___

import SwiftUI
import SwiftData
import CoreBluetooth

@main
struct InjuryIQApp: App {
    private var modelContainer: ModelContainer?
    private var showLaunch: Bool = true
    @State private var showLaunchState: Bool = true
    
    private let fallbackContainer: ModelContainer = {
        let schema = Schema([Item.self, KnownDevice.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try! ModelContainer(for: schema, configurations: [config])
    }()
    
    init() {
        self.modelContainer = initializeContainer()
        if self.modelContainer != nil {
            BLEManager.shared.attach(modelContext: self.modelContainer!.mainContext)
        } else {
            BLEManager.shared.attach(modelContext: ModelContext(fallbackContainer))
        }
    }
    
    private func initializeContainer() -> ModelContainer? {
        do {
            let schema = Schema([Item.self, KnownDevice.self])
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
                    ContentView()
                        .environmentObject(BLEManager.shared)
                }
            }
            .modelContainer(modelContainer ?? fallbackContainer)
            .animation(.easeInOut(duration: 0.25), value: showLaunchState)
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
                BLEManager.shared.stopScan()
            }
        }
    }
}
