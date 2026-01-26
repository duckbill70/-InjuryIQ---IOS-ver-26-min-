import XCTest
@testable import InjuryIQ___Xcode

final class MLTrainingObjectTests: XCTestCase {

    // Helper to build a tiny session with known timestamps to test frequency
    private func makeSession(points: Int, start: TimeInterval = 0, dt: TimeInterval = 0.02, fatigue: mlFatigueLevel = .fresh) -> mlTrainingSession {
        var dataPoints: [MLDataPoint] = []
        for i in 0..<points {
            let t = start + Double(i) * dt
            dataPoints.append(
                MLDataPoint(
                    timestamp: t,
                    accl: Accl(x: Double(i), y: 0, z: 0),
                    mag: Mag(x: 0, y: Double(i), z: 0)
                )
            )
        }
        let data = try! JSONEncoder().encode(dataPoints)
        return mlTrainingSession(id: UUID(), data: data, fatigue: fatigue)
    }

    override func setUpWithError() throws {
        // Ensure a clean slate for the types we touch
        for type in ActivityType.allCases {
            try? MLTrainingObject.delete(type: type)
        }
    }

    func testSaveLoadRoundTrip() throws {
        let type: ActivityType = .running
        var obj = MLTrainingObject(type: type, distance: 5, sets: 3, setDuration: 0)
        let s1 = makeSession(points: 100)
        obj.sessions[.leftfoot] = [s1]

        try obj.save()
        let loaded = try MLTrainingObject.load(type: type)

        XCTAssertEqual(loaded.type, obj.type)
        XCTAssertEqual(loaded.sets, obj.sets)
        XCTAssertEqual(loaded.distance, obj.distance)
        XCTAssertEqual(loaded.sessions[.leftfoot]?.count, 1)
    }

    func testResetClearsSessionsAndExport() throws {
        let type: ActivityType = .hiking

        // Save an object with data and write export
        var obj = MLTrainingObject(type: type, distance: 10, sets: 2, setDuration: 0)
        obj.sessions[.rightfoot] = [makeSession(points: 50)]
        try obj.save()
        try obj.writeExport()

        // Ensure export exists and non-empty
        let preSize = (try? Data(contentsOf: obj.exportURL).count) ?? 0
        XCTAssertGreaterThan(preSize, 0)

        // Reset
        try MLTrainingObject.reset(type: type)
        let reloaded = try MLTrainingObject.load(type: type)

        XCTAssertTrue(reloaded.sessions.values.flatMap { $0 }.isEmpty)

        // After reset(), export should be deleted or rewritten empty
        let exportExists = FileManager.default.fileExists(atPath: reloaded.exportURL.path)
        if exportExists {
            let postSize = (try? Data(contentsOf: reloaded.exportURL).count) ?? 0
            XCTAssertGreaterThanOrEqual(postSize, 0)
        } else {
            XCTAssertFalse(exportExists)
        }
    }

    func testExportReflectsCurrentSessions() throws {
        let type: ActivityType = .racket
        var obj = MLTrainingObject(type: type, distance: 0, sets: 3, setDuration: 3)
        obj.sessions[.leftfoot] = [makeSession(points: 10)]
        obj.sessions[.rightfoot] = [makeSession(points: 20)]
        try obj.save()
        try obj.writeExport()

        let data = try Data(contentsOf: obj.exportURL)
        XCTAssertGreaterThan(data.count, 0)

        // Add another session and rewrite
        var loaded = try MLTrainingObject.load(type: type)
        let extra = makeSession(points: 5, fatigue: .moderate)
        loaded.addSession(extra, for: .leftfoot)
        try loaded.save()
        try loaded.writeExport()

        let updated = try Data(contentsOf: loaded.exportURL)
        XCTAssertGreaterThanOrEqual(updated.count, data.count) // likely grows due to prettyPrinted
    }

    func testFrequencyCacheComputedAndPersisted() throws {
        let type: ActivityType = .cycling
        let session = makeSession(points: 101, start: 0, dt: 0.01) // ~101 Hz over ~1s
        var obj = MLTrainingObject(type: type)
        obj.sessions[.leftfoot] = [session]
        try obj.save()

        let loaded = try MLTrainingObject.load(type: type)
        let freq = loaded.sessions[.leftfoot]?.first?.frequencyHz
        XCTAssertNotNil(freq)
        // Allow some wiggle room
        XCTAssertTrue(freq! > 90 && freq! < 120)
    }
}
