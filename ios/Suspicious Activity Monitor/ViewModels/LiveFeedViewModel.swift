import Foundation
import Combine

final class LiveFeedViewModel: ObservableObject {
    @Published private(set) var selectedCameraURL: URL?
    @Published private(set) var selectedCameraID: String?
    @Published private(set) var streamRequest: URLRequest?
    @Published private(set) var cameraOptions: [String: String] = [:]
    @Published private(set) var isDetected = false
    @Published private(set) var detectedObject = "None"
    @Published private(set) var isLoading = true
    @Published private(set) var errorMessage: String?
    private let cameras: CameraRepository
    private let logs: LogRepository
    private let streamAccess: StreamAccessService
    private var observation: Observation?
    private var resetDetection: DispatchWorkItem?
    private var generation = UUID()
    private var requestGeneration = UUID()
    private var refreshStream: DispatchWorkItem?

    init(cameras: CameraRepository = FirebaseCameraRepository(), logs: LogRepository = FirebaseLogRepository(),
         streamAccess: StreamAccessService = FirebaseStreamAccessService()) {
        self.cameras = cameras
        self.logs = logs
        self.streamAccess = streamAccess
    }

    func fetch(email: String) {
        isLoading = true
        errorMessage = nil
        cameras.fetch(email: email) { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false
                switch result {
                case .success(let cameras):
                    self?.cameraOptions = cameras
                    if let id = self?.selectedCameraID, let address = cameras[id], let url = URL(string: address) {
                        self?.select(cameraID: id, url: url)
                    } else {
                        self?.selectedCameraID = nil
                        self?.selectedCameraURL = nil
                        self?.streamRequest = nil
                    }
                case .failure(let error): self?.errorMessage = error.localizedDescription
                }
            }
        }
    }

    func select(cameraID: String, url: URL) {
        stopMonitoring()
        selectedCameraID = cameraID
        selectedCameraURL = url
        prepareStream()
        startMonitoring()
    }

    func prepareStream() {
        guard let url = selectedCameraURL else { return }
        refreshStream?.cancel()
        errorMessage = nil
        let requestID = UUID()
        requestGeneration = requestID
        streamAccess.request(for: url) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self, self.requestGeneration == requestID else { return }
                switch result {
                case .failure(let error): self.streamRequest = nil; self.errorMessage = error.localizedDescription
                case .success(let request):
                    self.streamRequest = request
                    // Firebase ID tokens last one hour; refresh before the server closes the stream.
                    let refresh = DispatchWorkItem { [weak self] in self?.prepareStream() }
                    self.refreshStream = refresh
                    DispatchQueue.main.asyncAfter(deadline: .now() + 50 * 60, execute: refresh)
                }
            }
        }
    }

    func streamFailed(_ message: String) {
        errorMessage = message
        streamRequest = nil
    }

    func startMonitoring() {
        guard observation == nil else { return }
        let currentGeneration = generation
        observation = logs.observe(onEntry: { [weak self] entry in
            DispatchQueue.main.async {
                guard let self = self, self.generation == currentGeneration, entry.confidence >= 0.7,
                      entry.cameraID == (self.selectedCameraID ?? "") else { return }
                self.resetDetection?.cancel()
                self.detectedObject = entry.object
                self.isDetected = true
                let reset = DispatchWorkItem { [weak self] in
                    self?.isDetected = false
                    self?.detectedObject = "None"
                }
                self.resetDetection = reset
                DispatchQueue.main.asyncAfter(deadline: .now() + 9, execute: reset)
            }
        }, onError: { [weak self] error in
            DispatchQueue.main.async {
                guard let self = self, self.generation == currentGeneration else { return }
                self.errorMessage = error.localizedDescription
            }
        })
    }

    func stopMonitoring() {
        requestGeneration = UUID()
        refreshStream?.cancel()
        refreshStream = nil
        streamRequest = nil
        generation = UUID()
        observation?.cancel()
        observation = nil
        resetDetection?.cancel()
        resetDetection = nil
        isDetected = false
        detectedObject = "None"
    }

    deinit { observation?.cancel(); resetDetection?.cancel(); refreshStream?.cancel() }
}
