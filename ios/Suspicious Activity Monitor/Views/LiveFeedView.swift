//
//  LiveFeedView.swift
//  Suspicious Activity Monitor
//
//  Created by Yağız Efe Atasever on 19.12.2024.
//

import SwiftUI

struct LiveFeedView: View {
    @StateObject private var viewModel = LiveFeedViewModel()
    @State private var showCameraSelection = false
    let email: String // linked cameraları filtrelemek için user emailini passlıyorum

    var body: some View {
        Group {
            if let error = viewModel.errorMessage {
                VStack {
                    Text(error).foregroundColor(.red)
                    Button("Retry") { viewModel.fetch(email: email) }
                }
            } else if viewModel.isLoading {
                VStack {
                    ProgressView("Loading cameras...")
                }
            } else if let streamRequest = viewModel.streamRequest {
                ZStack {
                    // Live feed video
                    WebView(request: streamRequest, onError: viewModel.streamFailed)
                        .edgesIgnoringSafeArea(.all)

                    // Detection yazısı
                    VStack {
                        HStack {
                            Spacer()
                            Text(viewModel.isDetected ? "Detected: \(viewModel.detectedObject)" : "Not Detected")
                                .font(.headline)
                                .fontWeight(.bold)
                                .foregroundColor(viewModel.isDetected ? .red : .green)
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
                    viewModel.startMonitoring()
                }
            } else if viewModel.selectedCameraURL != nil {
                ProgressView("Connecting securely...")
            } else if viewModel.cameraOptions.isEmpty {
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
                    CameraSelectionView(cameraOptions: viewModel.cameraOptions) { cameraID, selectedURL in
                        viewModel.select(cameraID: cameraID, url: selectedURL)
                        self.showCameraSelection = false
                    }
                }
            }
        }
        .onDisappear { viewModel.stopMonitoring() }
        .onAppear {
            viewModel.fetch(email: email)
        }
    }

}
