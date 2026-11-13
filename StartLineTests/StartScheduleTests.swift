import XCTest
@testable import StartLine

final class StartScheduleTests: XCTestCase {
    private var calendar: Calendar!

    override func setUp() {
        super.setUp()
        calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    }

    func testNextCandidateUsesFollowingFiveMinuteBoundary() {
        let schedule = StartSchedule.make(
            now: date(hour: 10, minute: 1, second: 0),
            calendar: calendar
        )

        XCTAssertEqual(schedule.suggested.displayText, "10:05")
    }

    func testExactBoundaryAdvancesToNextSlot() {
        let schedule = StartSchedule.make(
            now: date(hour: 10, minute: 5, second: 0),
            calendar: calendar
        )

        XCTAssertEqual(schedule.suggested.displayText, "10:10")
    }

    func testHourBoundaryAdvancesToNextHour() {
        let schedule = StartSchedule.make(
            now: date(hour: 10, minute: 59, second: 59),
            calendar: calendar
        )

        XCTAssertEqual(schedule.suggested.displayText, "11:00")
    }

    func testScheduleContainsNineFiveMinuteCandidates() {
        let schedule = StartSchedule.make(
            now: date(hour: 10, minute: 1, second: 0),
            calendar: calendar
        )

        XCTAssertEqual(schedule.timelineCandidates.count, 9)
        XCTAssertEqual(schedule.timelineCandidates.first?.displayText, "10:05")
        XCTAssertEqual(schedule.timelineCandidates.last?.displayText, "10:45")
    }

    func testRemainingSecondsRoundsUpAndStopsAtZero() {
        let now = date(hour: 10, minute: 0, second: 0)

        XCTAssertEqual(
            StartSchedule.remainingSeconds(from: now, to: now.addingTimeInterval(3.1)),
            4
        )
        XCTAssertEqual(
            StartSchedule.remainingSeconds(from: now, to: now.addingTimeInterval(-1)),
            0
        )
    }

    func testRemainingTimeTextUsesVersionTwoFormat() {
        XCTAssertEqual(StartSchedule.remainingTimeText(remainingSeconds: 0), "0m 00s")
        XCTAssertEqual(StartSchedule.remainingTimeText(remainingSeconds: 65), "1m 05s")
        XCTAssertEqual(StartSchedule.remainingTimeText(remainingSeconds: 3_600), "60m 00s")
    }

    func testScheduledRingPhaseBoundaries() {
        XCTAssertEqual(ScheduledRingPhase(remainingSeconds: 60), .normal)
        XCTAssertEqual(ScheduledRingPhase(remainingSeconds: 59), .warning)
        XCTAssertEqual(ScheduledRingPhase(remainingSeconds: 10), .warning)
        XCTAssertEqual(ScheduledRingPhase(remainingSeconds: 9), .imminent)
        XCTAssertEqual(ScheduledRingPhase(remainingSeconds: 0), .imminent)
    }

    func testProductionDurationFallbacksRemainUnchanged() {
        let overrides = CountdownDurationOverrides.disabled

        XCTAssertNil(overrides.duration(for: .scheduled))
        XCTAssertEqual(overrides.duration(for: .pomodoro, productionMinutes: 25), 1_500)
        XCTAssertEqual(overrides.duration(for: .breakTime, productionMinutes: 5), 300)
    }

    private func date(hour: Int, minute: Int, second: Int) -> Date {
        calendar.date(
            from: DateComponents(
                year: 2026,
                month: 7,
                day: 30,
                hour: hour,
                minute: minute,
                second: second
            )
        )!
    }
}
