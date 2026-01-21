import Foundation

struct MLTrainingExport: Encodable {
    let sport: String
    let sets: Int
    let duration: Int
    var sessions: [[String: Any]]

    init(from obj: MLTrainingObject) {
        self.sport = obj.type.rawValue
        self.sets = obj.sets
        self.duration = obj.setDuration

        // Flatten all sessions from all locations
        var sessionList: [[String: Any]] = []
        for (_, sessionArray) in obj.sessions {
            for session in sessionArray {
                let points = session.dataPoints.map { point in
                    [
                        "time": point.timestamp,
                        "accX": point.accl.x,
                        "accY": point.accl.y,
                        "accZ": point.accl.z
                    ]
                }
                sessionList.append(["session": points])
            }
        }
        self.sessions = sessionList
    }

    func toJSONData() throws -> Data {
        // Build the required dictionary
        var dict: [String: Any] = [
            "sport": sport,
            "sets": sets,
            "duration": duration
        ]
        for (index, session) in sessions.enumerated() {
            dict["session\(index + 1)"] = session["session"]
        }
        return try JSONSerialization.data(withJSONObject: dict, options: .prettyPrinted)
    }
}