
import SwiftData
import CoreBluetooth

@Model
final class KnownDevice {
    @Attribute(.unique) var uuid: UUID
    var name: String
    var lastConnectedAt: Date

    init(uuid: UUID, name: String, lastConnectedAt: Date) {
        self.uuid = uuid
        self.name = name
        self.lastConnectedAt = lastConnectedAt
    }
}
