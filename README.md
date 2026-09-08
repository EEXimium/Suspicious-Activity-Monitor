# Suspicious Activity Monitor

A SwiftUI iOS application and Python camera server for live video, weapon detection,
Firebase activity logs and local notifications.

## Repository layout

```text
ios/
  Suspicious Activity Monitor/
    App/                Application startup
    Models/             Data models
    Views/              SwiftUI screens and reusable UI
    ViewModels/         Screen state and business operations
    Services/           Protocols and Firebase/notification implementations
  Suspicious Activity Monitor.xcodeproj/
  Suspicious Activity MonitorTests/
  Suspicious Activity MonitorUITests/
  Suspicious-Activity-Monitor-Info.plist
pythonProject/
  monitor/              Configuration, domain, adapters, streaming and HTTP
  models/               Preserved trained model checkpoints
  tests/                Hardware-independent unit tests
  GoingLiveYOLO.py       Camera server entry point
  trainYolo.py           Training CLI
  test.py               Local preview CLI
  requirements.txt
  .env.example
firebase/               Realtime Database rules and emulator tests
deploy/                 HTTPS reverse-proxy configuration
docs/
  ARCHITECTURE.md
  SECURITY_SETUP.md
```

See [architecture and data contracts](docs/ARCHITECTURE.md) for class responsibilities,
dependency injection, preserved behavior and current limitations.

## Firebase setup

1. Create a Firebase project with **Realtime Database** and **Authentication**.
2. Enable Email/Password authentication.
3. Register the iOS app, download `GoogleService-Info.plist`, and add it to the app
   target in Xcode.
4. Generate a Firebase Admin service-account JSON for the Python server and keep
   it outside version control.
5. Follow [secure deployment and migration](docs/SECURITY_SETUP.md) to deploy the
   database rules, configure HTTPS, register cameras and grant access by user UID.
   Shared camera passwords and email-based authorization are no longer used.

This implementation uses Realtime Database, with JPEG evidence stored as Base64
inside log entries. It does not use Firestore or Storage for those entries.

## Run the camera server

Python 3.10+ is required; Python 3.11 is a suitable development environment.

```powershell
cd pythonProject
python -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install -r requirements.txt

$env:FIREBASE_DATABASE_URL = "https://YOUR-PROJECT-default-rtdb.REGION.firebasedatabase.app/"
$env:GOOGLE_APPLICATION_CREDENTIALS = "C:\path\to\serviceAccount.json"
$env:CAMERA_SOURCE = "0"
$env:CAMERA_ID = "front-door"
python GoingLiveYOLO.py
```

On macOS/Linux, activate with `source .venv/bin/activate` and set environment
variables using `export NAME=value`.

The default model is `models/best.pt`, resolved relative to
`pythonProject`. Override it with `MODEL_PATH`. Camera source defaults to device
index `1`; use `0` for the first camera or supply a stream URL. Other settings
are listed in [.env.example](pythonProject/.env.example); this file is a template
and is not loaded automatically.

The server listens only on `127.0.0.1:5000` behind the HTTPS proxy described in
[SECURITY_SETUP.md](docs/SECURITY_SETUP.md). The iOS app supplies a Firebase ID
token; anonymous browser access to video is denied. Detection runs while an
authorized client consumes video. Run one server process per camera.

## Run the iOS app

Open `ios/Suspicious Activity Monitor.xcodeproj` in Xcode 16 or newer on macOS,
resolve Swift packages, configure signing and Firebase, then build and run.
The app deployment target is iOS 16.6; the unit-test target currently uses iOS 18.1.

The project uses Xcode's synchronized folders, so the reorganized Swift source
directories are automatically included in the existing app target.

Update the database rules, Python server and app together. Old global logs are
not visible under the new access model; follow the reviewed migration procedure
in the security guide. Keep the phone and server clocks synchronized.

Sign in or register, ask the administrator to grant your account camera access,
link the provided camera ID under Account Settings, and select it under
Live Feed. Activity Logs shows recorded images and supports deletion. The main
screen also includes feedback submission and an emergency-call shortcut to 112.

## Training and local preview

Training requires your own valid dataset YAML and image/label files. The bundled
`data.yaml` references training directories that are not included.

```powershell
python trainYolo.py --data "C:\datasets\weapons\data.yaml" --epochs 100
python trainYolo.py --data "C:\datasets\weapons\data.yaml" --device cpu
python test.py --camera 0
```

Use `--device mps` on supported Apple hardware, or a CUDA device index when
available. Preview runs without Firebase; press **q** to exit.

## Tests

From `pythonProject`:

```powershell
python -m pip install -r requirements-test.txt
python -m unittest discover -s tests -v
```

These tests use Flask's test client with fake authentication/storage, without a
camera, model download or Firebase credentials. Run the iOS ViewModel tests with **Product > Test** in
Xcode. See the architecture document for integration checks and known limitations.
GitHub Actions runs Python tests on Windows/Linux and database-rule tests in the
Firebase emulator. See the security guide for running the emulator locally.

## Authors and license

- Efe Atasever — [EEXimium](https://github.com/EEXimium)
- Tolga Değirmenci — [QuietLess](https://github.com/QuietLess)

Licensed under [MIT](LICENSE). Built with SwiftUI, Firebase, Flask, OpenCV and
Ultralytics YOLO.
