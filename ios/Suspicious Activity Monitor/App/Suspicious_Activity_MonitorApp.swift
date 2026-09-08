import SwiftUI
import FirebaseCore

@main
struct Suspicious_Activity_MonitorApp: App {
    @State private var isLoggedIn = false
    @State private var userEmail = ""
    private let notifications: DetectionNotificationService

    init() {
        FirebaseApp.configure()
        let email = FirebaseAuthenticationService().currentEmail
        _isLoggedIn = State(initialValue: email != nil)
        _userEmail = State(initialValue: email ?? "")
        notifications = DetectionNotificationService()
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if isLoggedIn {
                    ContentView(isLoggedIn: $isLoggedIn, userEmail: $userEmail)
                } else {
                    LoginView(isLoggedIn: $isLoggedIn, userEmail: $userEmail)
                }
            }
            .onAppear { updateNotifications() }
            .onChange(of: isLoggedIn) { _ in updateNotifications() }
        }
    }

    private func updateNotifications() {
        if isLoggedIn { notifications.start() }
        else { notifications.stop(); userEmail = "" }
    }
}
