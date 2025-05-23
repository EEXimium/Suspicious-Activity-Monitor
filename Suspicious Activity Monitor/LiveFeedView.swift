//
//  LiveFeedView.swift
//  Suspicious Activity Monitor
//
//  Created by Yağız Efe Atasever on 19.12.2024.
//

import SwiftUI
import FirebaseDatabase

struct LiveFeedView: View {
    @State private var selectedCameraURL: URL? = nil
    @State private var cameraOptions: [String: String] = [:] // Camera Name -> Camera URL
    @State private var showCameraSelection = false
    @State private var isDetected: Bool = false
    @State private var detectedObject: String = "None"
    @State private var isLoading = true // kameralar fetchlenirken load state göstermek için, ama fetch çok kısa sürüyor
    let email: String // linked cameraları filtrelemek için user emailini passlıyorum

    var body: some View {
        Group {
            if isLoading {
                VStack {
                    ProgressView("Loading cameras...")
                }
            } else if let selectedCameraURL = selectedCameraURL {
                ZStack {
                    // Live feed video
                    WebView(url: selectedCameraURL)
                        .edgesIgnoringSafeArea(.all)

                    // Detection yazısı
                    VStack {
                        HStack {
                            Spacer()
                            Text(isDetected ? "Detected: \(detectedObject)" : "Not Detected")
                                .font(.headline)
                                .fontWeight(.bold)
                                .foregroundColor(isDetected ? .red : .green)
                                .padding()
                                .background(Color.black.opacity(0.7))
                                .cornerRadius(10)
                                .padding(.top, 150)
                            Spacer()
                        }
                        Spacer()
                    }
                }
                .onAppear {
                    startMonitoringDetections()
                }
            } else if cameraOptions.isEmpty {
                VStack {
                    Text("No linked cameras found.")
                        .font(.largeTitle)
                        .padding()
                }
            } else {
                VStack {
                    Text("Select a Camera")
                        .font(.largeTitle)
                        .padding()

                    Button("Choose Camera") {
                        showCameraSelection = true
                    }
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .sheet(isPresented: $showCameraSelection) {
                    CameraSelectionView(cameraOptions: cameraOptions) { selectedURL in
                        self.selectedCameraURL = selectedURL
                        self.showCameraSelection = false
                    }
                }
            }
        }
        .onAppear {
            fetchLinkedCameras()
        }
    }

    private func fetchLinkedCameras() {
        let databaseRef = Database.database().reference()
        let sanitizedEmail = email.replacingOccurrences(of: ".", with: ",")
        
        databaseRef.child("users").child(sanitizedEmail).child("linked_cameras").observeSingleEvent(of: .value) { snapshot in
            DispatchQueue.main.async {
                isLoading = false
                if let cameras = snapshot.value as? [String: String] {
                    cameraOptions = cameras
                } else {
                    cameraOptions = [:]
                }
            }
        }
    }

    private func startMonitoringDetections() {
        let databaseRef = Database.database().reference().child("logs")

        ["Knife", "Pistol"].forEach { objectType in
            databaseRef.child(objectType).observe(.childAdded) { snapshot in
                if let data = snapshot.value as? [String: Any],
                   let confidence = data["confidence"] as? Double,
                   confidence >= 0.7 {
                    DispatchQueue.main.async {
                        detectedObject = objectType
                        isDetected = true
                        //neden +9 çünkü objeler 10 saniyede bir db'ye loglanıyor,
                        //eğer loglara göre değil detectiona göre yaparsam
                        //notif spamı yiyorum
                        DispatchQueue.main.asyncAfter(deadline: .now() + 9) {
                            isDetected = false
                            detectedObject = "None"
                        }
                    }
                }
            }
        }
    }
}
