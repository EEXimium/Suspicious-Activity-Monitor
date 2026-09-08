import Foundation
import Combine

final class LogsViewModel: ObservableObject {
    @Published private(set) var logEntries: [LogEntry] = []
    @Published private(set) var isLoading = true
    @Published private(set) var errorMessage: String?
    private let repository: LogRepository

    init(repository: LogRepository = FirebaseLogRepository()) { self.repository = repository }

    func fetch() {
        isLoading = true
        errorMessage = nil
        repository.fetch { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false
                switch result {
                case .success(let logs): self?.logEntries = logs
                case .failure(let error): self?.errorMessage = error.localizedDescription
                }
            }
        }
    }

    func delete(at offsets: IndexSet) {
        let selected = offsets.compactMap { logEntries.indices.contains($0) ? logEntries[$0] : nil }
        for log in selected {
            repository.delete(log) { [weak self] error in
                DispatchQueue.main.async {
                    if let error = error { self?.errorMessage = error.localizedDescription }
                    else { self?.logEntries.removeAll { $0.identity == log.identity } }
                }
            }
        }
    }
}
