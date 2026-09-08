import XCTest
@testable import Suspicious_Activity_Monitor

final class ViewModelTests: XCTestCase {
    private let log = LogEntry(id: "test", date: "2026-01-01", object: "Knife",
                               confidence: 0.9, photoBase64: "anBlZw==")

    // ViewModels deliver results to the main queue. Queue this after their callbacks.
    private func drainMainQueue() {
        let delivered = expectation(description: "Main queue callback delivered")
        DispatchQueue.main.async { delivered.fulfill() }
        wait(for: [delivered], timeout: 2)
    }

    func testFailedDeleteKeepsLogAndReportsError() {
        let repository = FakeLogRepository()
        repository.entries = [log]
        let model = LogsViewModel(repository: repository)
        model.fetch()
        drainMainQueue()
        repository.deleteError = TestError.failed
        model.delete(at: IndexSet(integer: 0))
        drainMainQueue()
        XCTAssertEqual(model.logEntries.count, 1)
        XCTAssertNotNil(model.errorMessage)
    }

    func testSuccessfulDeleteRemovesOnlyAcknowledgedLog() {
        let repository = FakeLogRepository()
        repository.entries = [log]
        let model = LogsViewModel(repository: repository)
        model.fetch()
        drainMainQueue()
        model.delete(at: IndexSet(integer: 0))
        XCTAssertEqual(model.logEntries.count, 1)
        drainMainQueue()
        XCTAssertTrue(model.logEntries.isEmpty)
    }

    func testFailedFetchLeavesLoadingState() {
        let repository = FakeLogRepository()
        repository.fetchError = TestError.failed
        let model = LogsViewModel(repository: repository)
        model.fetch()
        drainMainQueue()
        XCTAssertFalse(model.isLoading)
        XCTAssertNotNil(model.errorMessage)
    }

    func testMonitoringIsIdempotentAndCancelsOnStop() {
        let repository = FakeLogRepository()
        let model = LiveFeedViewModel(cameras: FakeCameraRepository(), logs: repository)
        model.startMonitoring()
        model.startMonitoring()
        XCTAssertEqual(repository.observeCount, 1)
        repository.onEntry?(log)
        drainMainQueue()
        XCTAssertTrue(model.isDetected)
        model.stopMonitoring()
        XCTAssertTrue(repository.token.cancelled)
        XCTAssertFalse(model.isDetected)
        // A queued callback from a cancelled subscription must not restore the banner.
        repository.onEntry?(log)
        drainMainQueue()
        XCTAssertFalse(model.isDetected)
    }

    func testLogoutUsesAuthenticationServiceAndPreservesSessionOnFailure() {
        let authentication = FakeAuthenticationService()
        let model = AccountViewModel(cameras: FakeCameraRepository(), authentication: authentication)
        authentication.signOutError = TestError.failed
        XCTAssertFalse(model.logout())
        XCTAssertTrue(model.showError)
        authentication.signOutError = nil
        XCTAssertTrue(model.logout())
        XCTAssertEqual(authentication.signOutCount, 2)
    }

    func testEmptyFeedbackIsNotSubmitted() {
        let repository = FakeFeedbackRepository()
        let model = FeedbackViewModel(repository: repository)
        model.feedbackText = "  \n "
        model.send(email: "user@example.com")
        XCTAssertTrue(model.showErrorMessage)
        XCTAssertEqual(repository.submitCount, 0)
    }

    func testLiveBannerIgnoresOtherCameras() {
        let repository = FakeLogRepository()
        let model = LiveFeedViewModel(cameras: FakeCameraRepository(), logs: repository,
                                      streamAccess: FakeStreamAccessService())
        model.select(cameraID: "front", url: URL(string: "https://front.example.com/video_feed")!)
        var other = log
        other.cameraID = "back"
        repository.onEntry?(other)
        drainMainQueue()
        XCTAssertFalse(model.isDetected)
        other.cameraID = "front"
        repository.onEntry?(other)
        drainMainQueue()
        XCTAssertTrue(model.isDetected)
        model.stopMonitoring()
    }

    func testCancelledScreenIgnoresLateStreamCredential() {
        let streamAccess = FakeStreamAccessService()
        streamAccess.delayed = true
        let model = LiveFeedViewModel(cameras: FakeCameraRepository(), logs: FakeLogRepository(),
                                      streamAccess: streamAccess)
        let url = URL(string: "https://front.example.com/video_feed")!
        model.select(cameraID: "front", url: url)
        model.stopMonitoring()
        streamAccess.completion?(.success(URLRequest(url: url)))
        drainMainQueue()
        XCTAssertNil(model.streamRequest)
    }

    func testDeletingOneCameraDoesNotRemoveMatchingRecordInAnother() {
        let repository = FakeLogRepository()
        var front = log
        front.cameraID = "front"
        var back = log
        back.cameraID = "back"
        repository.entries = [front, back]
        let model = LogsViewModel(repository: repository)
        model.fetch()
        drainMainQueue()
        model.delete(at: IndexSet(integer: 0))
        drainMainQueue()
        XCTAssertEqual(model.logEntries.map(\.cameraID), ["back"])
    }

    func testInsecureStreamFailsBeforeFetchingCredentials() {
        let service = FirebaseStreamAccessService()
        var rejected = false
        service.request(for: URL(string: "http://camera.example.com/video_feed")!) { result in
            if case .failure = result { rejected = true }
        }
        XCTAssertTrue(rejected)
    }
}

private enum TestError: Error { case failed }

private final class FakeObservation: Observation {
    var cancelled = false
    func cancel() { cancelled = true }
}

private final class FakeLogRepository: LogRepository {
    var entries: [LogEntry] = []
    var deleteError: Error?
    var fetchError: Error?
    var observeCount = 0
    var onEntry: ((LogEntry) -> Void)?
    let token = FakeObservation()

    func fetch(completion: @escaping (Result<[LogEntry], Error>) -> Void) {
        if let error = fetchError { completion(.failure(error)) }
        else { completion(.success(entries)) }
    }
    func delete(_ log: LogEntry, completion: @escaping (Error?) -> Void) { completion(deleteError) }
    func observe(onEntry: @escaping (LogEntry) -> Void, onError: @escaping (Error) -> Void) -> Observation {
        observeCount += 1
        self.onEntry = onEntry
        return token
    }
}

private final class FakeCameraRepository: CameraRepository {
    func fetch(email: String, completion: @escaping (Result<[String: String], Error>) -> Void) {
        completion(.success([:]))
    }
    func link(email: String, id: String, completion: @escaping (Error?) -> Void) { completion(nil) }
    func unlink(email: String, id: String, completion: @escaping (Error?) -> Void) { completion(nil) }
}

private final class FakeAuthenticationService: AuthenticationService {
    var signOutCount = 0
    var signOutError: Error?
    func signIn(email: String, password: String, completion: @escaping (Error?) -> Void) { completion(nil) }
    func register(email: String, password: String, completion: @escaping (Error?) -> Void) { completion(nil) }
    func signOut() throws {
        signOutCount += 1
        if let error = signOutError { throw error }
    }
}

private final class FakeFeedbackRepository: FeedbackRepository {
    var submitCount = 0
    func submit(email: String, text: String, completion: @escaping (Error?) -> Void) {
        submitCount += 1
        completion(nil)
    }
}

private final class FakeStreamAccessService: StreamAccessService {
    var delayed = false
    var completion: ((Result<URLRequest, Error>) -> Void)?
    func request(for url: URL, completion: @escaping (Result<URLRequest, Error>) -> Void) {
        self.completion = completion
        if !delayed { completion(.success(URLRequest(url: url))) }
    }
}
