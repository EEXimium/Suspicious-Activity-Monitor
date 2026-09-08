import Foundation
import Combine

final class AuthenticationViewModel: ObservableObject {
    @Published var email = ""
    @Published var password = ""
    @Published var showError = false
    @Published private(set) var errorMessage = ""
    @Published private(set) var isLockedOut = false
    @Published private(set) var isLoading = false
    private var failedAttempts = 0
    private let service: AuthenticationService

    init(service: AuthenticationService = FirebaseAuthenticationService()) { self.service = service }

    func login(onSuccess: @escaping (String) -> Void) {
        authenticate(register: false, onSuccess: onSuccess)
    }

    func register(onSuccess: @escaping (String) -> Void) {
        authenticate(register: true, onSuccess: onSuccess)
    }

    private func authenticate(register: Bool, onSuccess: @escaping (String) -> Void) {
        guard !isLoading, !isLockedOut else { return }
        guard !email.isEmpty, !password.isEmpty else {
            errorMessage = "Please enter email and password."
            showError = true
            return
        }
        isLoading = true
        let submittedEmail = email
        let completion: (Error?) -> Void = { [weak self] error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isLoading = false
                if let error = error {
                    self.errorMessage = error.localizedDescription
                    self.showError = true
                    if !register, let failure = error as? AuthenticationFailure,
                       case .wrongPassword = failure {
                        self.failedAttempts += 1
                        if self.failedAttempts >= 5 {
                            self.isLockedOut = true
                            self.errorMessage = "Too many failed attempts. Please wait 30 seconds."
                            DispatchQueue.main.asyncAfter(deadline: .now() + 30) { [weak self] in
                                self?.isLockedOut = false
                                self?.failedAttempts = 0
                            }
                        }
                    }
                } else {
                    self.failedAttempts = 0
                    self.showError = false
                    self.password = ""
                    onSuccess(submittedEmail)
                }
            }
        }
        if register { service.register(email: submittedEmail, password: password, completion: completion) }
        else { service.signIn(email: submittedEmail, password: password, completion: completion) }
    }
}
