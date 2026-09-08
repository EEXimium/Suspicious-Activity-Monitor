# Project analysis

The current design is documented in [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).
Setup and run commands are maintained in [README.md](README.md).

The repository contains a SwiftUI iOS client and a Python YOLO camera server.
The client uses MVVM with protocol-based services; the server separates detection
policy from camera, model, persistence and HTTP adapters.

Validation includes Python unit tests and iOS ViewModel tests. Hardware, Firebase
integration and an Xcode build require their respective runtime environments.
