import Foundation

enum DetectionEventPolicy {
    // Legacy entries remain available in Activity Logs but do not replay as alarms.
    static func isNew(timestamp: Double?, since startedAt: Double) -> Bool {
        guard let timestamp = timestamp, timestamp.isFinite else { return false }
        return timestamp >= startedAt
    }
}
