# Architecture

## iOS: MVVM with injected services

All iOS source, the Xcode project, test targets and Info.plist live under `ios/`.
Open `ios/Suspicious Activity Monitor.xcodeproj`. Their relative paths are
preserved, so the Xcode target configuration does not require path changes.

`Views` render SwiftUI controls and keep presentation state such as the selected
image or an open sheet. SwiftUI views and data models remain value types; reference
types own mutable application state and external resources.

`ViewModels` are final `ObservableObject` classes. They validate input, publish
loading/error/result state on the main queue, and depend on service protocols.
Tests inject fake implementations without accessing Firebase.

`Services` implement authentication, camera linking, log storage, feedback and
notifications. Firebase types and database paths are confined to this layer.
`DatabaseObservation` owns observer handles and removes them on cancellation or
deallocation. `LiveFeedViewModel` starts one subscription and cancels it when the
screen disappears; its reset timer is replaced when a newer detection arrives.

`App` configures Firebase before any default service is constructed, owns the
notification service, and selects the login or main screen. ViewModels have
default production dependencies and initializer injection for tests.

Log deletion updates the screen only after the server acknowledges success.
Logout calls Firebase Auth's sign-out operation before changing screen state.

## Python: composition and adapters

| Module | Responsibility |
| --- | --- |
| `monitor/config.py` | Immutable environment configuration and validation |
| `monitor/domain.py` | Detection value object, storage/encoding contracts, confidence and cooldown policy |
| `monitor/adapters.py` | OpenCV camera/JPEG, YOLO inference, Firebase persistence |
| `monitor/streaming.py` | Frame processing and multipart stream generation |
| `monitor/web.py` | Flask application factory and HTTP routes |
| `monitor/security.py` | Verified identity, expiry and camera access policy |
| `GoingLiveYOLO.py` | Composition root and resource lifetime |

Imports do not load model weights, open a camera, start training, or connect to
Firebase. Entry points perform those operations explicitly. The server closes
resources through `ExitStack`, including when startup fails after acquiring a
resource. One process owns a camera; a lock serializes frame capture, inference
and cooldown updates across concurrent stream clients. Each client requests its
own frames; this is not a shared-frame broadcast service.

The logger accepts only known threat classes with confidence **greater than 0.7**
and saves each object type at most once per **10 seconds**, matching the original
server. A failed write does not consume the cooldown. Storage errors are logged
without including image payloads and do not interrupt the video stream.

## UID and camera-scoped data contract

```text
cameraLogs/{cameraID}/{objectType}/{logID}: {cameraID, date, timestamp, confidence, photoBase64}
cameras/{cameraID}: {url}
cameraMembers/{cameraID}/{uid}: true
users/{uid}/linked_cameras/{cameraID}: url
feedback/{uid}/{feedbackID}: {feedback, timestamp}
```

The Python server and iOS observers recognize `Knife`, `Pistol`, `Rifle` and
`Stick-Rod`. New logs include a Unix timestamp in seconds and a UTC ISO date.
Observers ignore records older than subscription startup and legacy records
without a timestamp. Legacy global records are inaccessible until an administrator
can establish ownership and migrate them; deploy the database rules, updated
Python server and updated app together. Keep server
and phone clocks synchronized. Notifications start only while signed in and stop
on logout; the app restores an existing Firebase session at launch. Only cameras
with an administrator-granted membership can be linked. Rules restrict reads and
event deletion to members with an active link, deny client evidence creation,
and deny all client membership changes. Log subscriptions track the user's linked
cameras; the live banner filters events to the selected camera.

Detection still runs while a stream is being consumed. Notifications are local
iOS notifications, not a remote push delivery service; background execution is
subject to iOS restrictions. The training dataset must be supplied separately;
the included `data.yaml` references image directories not shipped here.

The app declares local-network usage and requires trusted HTTPS. A stream access
service obtains a Firebase ID token and adds it to the Authorization header,
never to the URL. WKWebView uses nonpersistent storage, rejects navigation away
from the registered stream URL, and refreshes its request before token expiry.
Waitress accepts traffic only from the local TLS proxy; the endpoint checks
token validity/revocation, membership and linking before yielding video and
rechecks authorization during long-lived streams. Failures deny access.

## Deployment work requiring an actual environment

- Apply the provided Firebase rules and explicitly provision camera membership.
  Configure DNS and TLS on the target host using the proxy template. Follow
  [SECURITY_SETUP.md](SECURITY_SETUP.md) for deployment and legacy-data migration.
- Remote push notifications and continuous detection without a video consumer
  are separate features; local notifications cannot guarantee background alerts.
- Real camera inference, Firebase permissions and an iOS build still require
  hardware, credentials and macOS/Xcode. Unit tests do not validate those systems.

## Verification

From `pythonProject`, install `requirements-test.txt`, then run
`python -m unittest discover -s tests -v` for the
hardware-independent policy, cooldown, payload and stream tests.
From `firebase`, run `npm ci --ignore-scripts` and `npm test` for database isolation
and privilege-escalation tests using the local emulator.

In Xcode, run the `Suspicious Activity MonitorTests` target for ViewModel tests
covering failed/successful deletion, fetch errors, subscription cancellation,
logout and feedback validation. iOS builds require macOS/Xcode and Firebase
configuration. Real camera, model and Firebase integration must be checked with
your own hardware and credentials.
