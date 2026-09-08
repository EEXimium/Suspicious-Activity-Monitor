import Foundation
import Combine

final class AccountViewModel: ObservableObject {
    @Published var cameraID = ""
    @Published private(set) var linkedCameras: [String: String] = [:]
    @Published private(set) var errorMessage = ""
    @Published private(set) var showError = false
    private let cameras: CameraRepository
    private let authentication: AuthenticationService

    init(cameras: CameraRepository = FirebaseCameraRepository(),
         authentication: AuthenticationService = FirebaseAuthenticationService()) {
        self.cameras = cameras
        self.authentication = authentication
    }

    func fetch(email: String) {
        cameras.fetch(email: email) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let cameras): self?.linkedCameras = cameras; self?.showError = false
                case .failure(let error): self?.report(error)
                }
            }
        }
    }

    func link(email: String) {
        guard !cameraID.isEmpty else {
            errorMessage = "Please enter the Camera ID provided by your administrator."
            showError = true
            return
        }
        cameras.link(email: email, id: cameraID) { [weak self] error in
            DispatchQueue.main.async {
                if let error = error { self?.report(error) }
                else { self?.fetch(email: email) }
            }
        }
    }

    func unlink(email: String, id: String) {
        cameras.unlink(email: email, id: id) { [weak self] error in
            DispatchQueue.main.async {
                if let error = error { self?.report(error) }
                else { self?.fetch(email: email) }
            }
        }
    }

    func logout() -> Bool {
        do { try authentication.signOut(); return true }
        catch { report(error); return false }
    }

    private func report(_ error: Error) { errorMessage = error.localizedDescription; showError = true }
}
