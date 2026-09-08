import Foundation
import Combine

final class FeedbackViewModel: ObservableObject {
    @Published var feedbackText = ""
    @Published var showSuccessMessage = false
    @Published var showErrorMessage = false
    @Published private(set) var isSending = false
    private let repository: FeedbackRepository

    init(repository: FeedbackRepository = FirebaseFeedbackRepository()) { self.repository = repository }

    func send(email: String) {
        guard !isSending else { return }
        showSuccessMessage = false
        showErrorMessage = false
        let text = feedbackText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, text.utf16.count <= 5000 else { showErrorMessage = true; return }
        isSending = true
        repository.submit(email: email, text: text) { [weak self] error in
            DispatchQueue.main.async {
                self?.isSending = false
                self?.showErrorMessage = error != nil
                self?.showSuccessMessage = error == nil
                if error == nil { self?.feedbackText = "" }
            }
        }
    }
}
