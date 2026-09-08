import Foundation
import FirebaseDatabase

protocol FeedbackRepository {
    func submit(email: String, text: String, completion: @escaping (Error?) -> Void)
}

final class FirebaseFeedbackRepository: FeedbackRepository {
    private let root: DatabaseReference
    init(root: DatabaseReference = Database.database().reference()) { self.root = root }

    func submit(email: String, text: String, completion: @escaping (Error?) -> Void) {
        do {
            let uid = try FirebaseSession.uid()
            let data: [String: Any] = ["feedback": text, "timestamp": ServerValue.timestamp()]
            root.child("feedback").child(uid).child(UUID().uuidString).setValue(data) { error, _ in completion(error) }
        } catch { completion(error) }
    }
}
