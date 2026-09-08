import Foundation
import FirebaseDatabase

protocol CameraRepository {
    func fetch(email: String, completion: @escaping (Result<[String: String], Error>) -> Void)
    func link(email: String, id: String, completion: @escaping (Error?) -> Void)
    func unlink(email: String, id: String, completion: @escaping (Error?) -> Void)
}

final class FirebaseCameraRepository: CameraRepository {
    private let root: DatabaseReference

    init(root: DatabaseReference = Database.database().reference()) { self.root = root }

    // The UI email is display-only. Authorization always uses the authenticated UID.
    private func cameras() throws -> DatabaseReference {
        root.child("users").child(try FirebaseSession.uid()).child("linked_cameras")
    }

    func fetch(email: String, completion: @escaping (Result<[String: String], Error>) -> Void) {
        do {
            try cameras().observeSingleEvent(of: .value) { snapshot in
                completion(.success(snapshot.value as? [String: String] ?? [:]))
            } withCancel: { completion(.failure($0)) }
        } catch { completion(.failure(error)) }
    }

    func link(email: String, id: String, completion: @escaping (Error?) -> Void) {
        guard id.range(of: "^[A-Za-z0-9_-]{1,128}$", options: .regularExpression) != nil else {
            completion(AccessError.invalidCamera)
            return
        }
        do {
            let destination = try cameras().child(id)
            // Database rules permit this metadata read only for an administrator-granted member.
            root.child("cameras").child(id).observeSingleEvent(of: .value) { snapshot in
                guard let data = snapshot.value as? [String: Any],
                      let address = data["url"] as? String, let url = URL(string: address),
                      url.scheme?.lowercased() == "https", url.host != nil,
                      url.user == nil, url.password == nil else {
                    completion(AccessError.invalidCamera)
                    return
                }
                // Rules validate membership again and require the exact registered URL.
                destination.setValue(address) { error, _ in completion(error) }
            } withCancel: { _ in completion(AccessError.invalidCamera) }
        } catch { completion(error) }
    }

    func unlink(email: String, id: String, completion: @escaping (Error?) -> Void) {
        do {
            try cameras().child(id).removeValue { error, _ in completion(error) }
        } catch { completion(error) }
    }
}
