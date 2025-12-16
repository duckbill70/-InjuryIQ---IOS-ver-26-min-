
import SwiftData
import CoreBluetooth

@Model
final class KnownDevice {
    @Attribute(.unique) var uuid: UUID
    var name: String
    var lastConnectedAt: Date
    var isConnected: Bool = false

    init(uuid: UUID, name: String, lastConnectedAt: Date, isConnected: Bool = false) {
        self.uuid = uuid
        self.name = name
        self.lastConnectedAt = lastConnectedAt
        self.isConnected = isConnected
    }
}
