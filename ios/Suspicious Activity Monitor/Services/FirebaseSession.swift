import Foundation
import FirebaseAuth

enum AccessError: LocalizedError {
    case signedOut, invalidCamera, secureURLRequired

    var errorDescription: String? {
        switch self {
        case .signedOut: return "Please sign in again."
        case .invalidCamera: return "Camera unavailable. Ask the administrator to grant access to your account."
        case .secureURLRequired: return "The camera must use a trusted HTTPS address."
        }
    }
}

enum FirebaseSession {
    static func uid() throws -> String {
        guard let uid = Auth.auth().currentUser?.uid else { throw AccessError.signedOut }
        return uid
    }
}

protocol StreamAccessService {
    func request(for url: URL, completion: @escaping (Result<URLRequest, Error>) -> Void)
}

final class FirebaseStreamAccessService: StreamAccessService {
    func request(for url: URL, completion: @escaping (Result<URLRequest, Error>) -> Void) {
        guard url.scheme?.lowercased() == "https", url.host != nil,
              url.user == nil, url.password == nil, url.path == "/video_feed",
              url.query == nil, url.fragment == nil else {
            completion(.failure(AccessError.secureURLRequired))
            return
        }
        guard let user = Auth.auth().currentUser else {
            completion(.failure(AccessError.signedOut))
            return
        }
        user.getIDTokenForcingRefresh(true) { token, error in
            if let error = error { completion(.failure(error)); return }
            guard Auth.auth().currentUser?.uid == user.uid, let token = token else {
                completion(.failure(AccessError.signedOut))
                return
            }
            var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData)
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            completion(.success(request))
        }
    }
}
