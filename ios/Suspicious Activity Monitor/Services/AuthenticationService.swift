import Foundation
import FirebaseAuth

protocol AuthenticationService {
    func signIn(email: String, password: String, completion: @escaping (Error?) -> Void)
    func register(email: String, password: String, completion: @escaping (Error?) -> Void)
    func signOut() throws
}

enum AuthenticationFailure: LocalizedError {
    case wrongPassword

    var errorDescription: String? { "Incorrect password." }
}

final class FirebaseAuthenticationService: AuthenticationService {
    var currentEmail: String? { Auth.auth().currentUser?.email }

    func signIn(email: String, password: String, completion: @escaping (Error?) -> Void) {
        Auth.auth().signIn(withEmail: email, password: password) { _, error in
            if let error = error, (error as NSError).code == AuthErrorCode.wrongPassword.rawValue {
                completion(AuthenticationFailure.wrongPassword)
            } else {
                completion(error)
            }
        }
    }

    func register(email: String, password: String, completion: @escaping (Error?) -> Void) {
        Auth.auth().createUser(withEmail: email, password: password) { _, error in completion(error) }
    }

    func signOut() throws { try Auth.auth().signOut() }
}
