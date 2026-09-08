import XCTest
@testable import Suspicious_Activity_Monitor

final class DetectionEventPolicyTests: XCTestCase {
    func testHistoricalAndLegacyLogsDoNotTriggerAlarms() {
        XCTAssertFalse(DetectionEventPolicy.isNew(timestamp: 99, since: 100))
        XCTAssertFalse(DetectionEventPolicy.isNew(timestamp: nil, since: 100))
        XCTAssertFalse(DetectionEventPolicy.isNew(timestamp: .nan, since: 100))
    }

    func testNewEventsAreAcceptedAtSubscriptionBoundary() {
        XCTAssertTrue(DetectionEventPolicy.isNew(timestamp: 100, since: 100))
        XCTAssertTrue(DetectionEventPolicy.isNew(timestamp: 101, since: 100))
    }
}
