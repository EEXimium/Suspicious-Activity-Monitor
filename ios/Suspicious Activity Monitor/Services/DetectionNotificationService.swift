import Foundation
import UserNotifications

final class DetectionNotificationService {
    private let logs: LogRepository
    private let center: UNUserNotificationCenter
    private var observation: Observation?
    private var generation = UUID()

    init(logs: LogRepository = FirebaseLogRepository(), center: UNUserNotificationCenter = .current()) {
        self.logs = logs
        self.center = center
    }

    func start() {
        guard observation == nil else { return }
        center.requestAuthorization(options: [.alert, .sound, .badge]) { _, error in
            if let error = error { print("Notification permission error: \(error.localizedDescription)") }
        }
        let currentGeneration = generation
        observation = logs.observe(onEntry: { [weak self] entry in
            guard let self = self, self.generation == currentGeneration else { return }
            self.notify(entry)
        }, onError: {
            print("Notification observer error: \($0.localizedDescription)")
        })
    }

    func stop() {
        generation = UUID()
        observation?.cancel()
        observation = nil
        center.removeAllPendingNotificationRequests()
    }

    private func notify(_ entry: LogEntry) {
        let content = UNMutableNotificationContent()
        content.title = "\(entry.cameraID): \(entry.object) detected!"
        content.body = "Detected on \(entry.date)"
        content.sound = .default
        let request = UNNotificationRequest(identifier: entry.identity, content: content,
                                            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false))
        center.add(request) { error in
            if let error = error { print("Notification error: \(error.localizedDescription)") }
        }
    }

    deinit { observation?.cancel() }
}
