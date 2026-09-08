import Foundation
import FirebaseDatabase

protocol Observation: AnyObject { func cancel() }

final class DatabaseObservation: Observation {
    private var registrations: [(DatabaseQuery, DatabaseHandle)] = []
    private var children: [String: DatabaseObservation] = [:]
    private(set) var cancelled = false

    func add(_ query: DatabaseQuery, _ handle: DatabaseHandle) {
        if cancelled { query.removeObserver(withHandle: handle) }
        else { registrations.append((query, handle)) }
    }

    func synchronize(cameraIDs: Set<String>, subscribe: (String) -> DatabaseObservation) {
        guard !cancelled else { return }
        for id in Array(children.keys) where !cameraIDs.contains(id) {
            children.removeValue(forKey: id)?.cancel()
        }
        for id in cameraIDs where children[id] == nil { children[id] = subscribe(id) }
    }

    func cancel() {
        cancelled = true
        registrations.forEach { $0.0.removeObserver(withHandle: $0.1) }
        registrations.removeAll()
        children.values.forEach { $0.cancel() }
        children.removeAll()
    }
    deinit { cancel() }
}

protocol LogRepository {
    func fetch(completion: @escaping (Result<[LogEntry], Error>) -> Void)
    func delete(_ log: LogEntry, completion: @escaping (Error?) -> Void)
    func observe(onEntry: @escaping (LogEntry) -> Void, onError: @escaping (Error) -> Void) -> Observation
}

final class FirebaseLogRepository: LogRepository {
    private let root: DatabaseReference
    init(root: DatabaseReference = Database.database().reference()) { self.root = root }

    private func linkedCameras() throws -> DatabaseReference {
        root.child("users").child(try FirebaseSession.uid()).child("linked_cameras")
    }

    private static func entry(_ snapshot: DataSnapshot, camera: String, object: String) -> LogEntry? {
        guard let data = snapshot.value as? [String: Any],
              let date = data["date"] as? String,
              let confidence = data["confidence"] as? Double,
              let photo = data["photoBase64"] as? String else { return nil }
        return LogEntry(id: snapshot.key, date: date, object: object,
                        confidence: confidence, photoBase64: photo, cameraID: camera)
    }

    func fetch(completion: @escaping (Result<[LogEntry], Error>) -> Void) {
        do {
            try linkedCameras().observeSingleEvent(of: .value) { [self] snapshot in
                let cameras = snapshot.value as? [String: String] ?? [:]
                guard !cameras.isEmpty else { completion(.success([])); return }
                let group = DispatchGroup()
                var entries: [LogEntry] = []
                var failure: Error?
                // Firebase callbacks run on main; serialize result aggregation there too.
                for camera in cameras.keys {
                    group.enter()
                    root.child("cameraLogs").child(camera).observeSingleEvent(of: .value) { snapshot in
                        DispatchQueue.main.async {
                            for case let objects as DataSnapshot in snapshot.children {
                                for case let child as DataSnapshot in objects.children {
                                    if let entry = Self.entry(child, camera: camera, object: objects.key) {
                                        entries.append(entry)
                                    }
                                }
                            }
                            group.leave()
                        }
                    } withCancel: { error in
                        DispatchQueue.main.async { failure = error; group.leave() }
                    }
                }
                group.notify(queue: .main) {
                    if let error = failure { completion(.failure(error)) }
                    else { completion(.success(entries.sorted { $0.date > $1.date })) }
                }
            } withCancel: { completion(.failure($0)) }
        } catch { completion(.failure(error)) }
    }

    func delete(_ log: LogEntry, completion: @escaping (Error?) -> Void) {
        guard !log.cameraID.isEmpty else { completion(AccessError.invalidCamera); return }
        root.child("cameraLogs").child(log.cameraID).child(log.object).child(log.id)
            .removeValue { error, _ in completion(error) }
    }

    func observe(onEntry: @escaping (LogEntry) -> Void, onError: @escaping (Error) -> Void) -> Observation {
        let observation = DatabaseObservation()
        do {
            let links = try linkedCameras()
            let startedAt = Date().timeIntervalSince1970
            let handle = links.observe(.value, with: { [weak observation, self] snapshot in
                guard let observation = observation, !observation.cancelled else { return }
                let cameraIDs = Set((snapshot.value as? [String: String] ?? [:]).keys)
                observation.synchronize(cameraIDs: cameraIDs) { camera in
                    let childObservation = DatabaseObservation()
                    for object in ["Knife", "Pistol", "Rifle", "Stick-Rod"] {
                        let query = root.child("cameraLogs").child(camera).child(object)
                            .queryOrdered(byChild: "timestamp").queryStarting(atValue: startedAt)
                        let handle = query.observe(.childAdded, with: { [weak childObservation] snapshot in
                            guard let childObservation = childObservation, !childObservation.cancelled,
                                  let data = snapshot.value as? [String: Any],
                                  DetectionEventPolicy.isNew(timestamp: data["timestamp"] as? Double, since: startedAt),
                                  let entry = Self.entry(snapshot, camera: camera, object: object) else { return }
                            onEntry(entry)
                        }, withCancel: { [weak childObservation] error in
                            childObservation?.cancel()
                            onError(error)
                        })
                        childObservation.add(query, handle)
                    }
                    return childObservation
                }
            }, withCancel: { [weak observation] error in observation?.cancel(); onError(error) })
            observation.add(links, handle)
        } catch { onError(error) }
        return observation
    }
}
