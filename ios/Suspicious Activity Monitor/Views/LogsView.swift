//
//  LogsView.swift
//  Suspicious Activity Monitor
//
//  Created by Yağız Efe Atasever on 19.12.2024.
//

import SwiftUI

struct LogsView: View {
    @StateObject private var viewModel = LogsViewModel()
    @State private var selectedImage: UIImage? = nil
    @State private var isFullScreen = false

    var body: some View {
        NavigationView {
            VStack {
                if let error = viewModel.errorMessage { Text(error).foregroundColor(.red) }
                if viewModel.isLoading {
                    ProgressView("Loading logs...")
                        .progressViewStyle(CircularProgressViewStyle())
                        .padding()
                } else {
                    List {
                        ForEach(viewModel.logEntries, id: \.identity) { log in
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Camera: \(log.cameraID)").font(.headline)
                                Text("Date: \(log.date)")
                                    .font(.headline)
                                Text("Object: \(log.object)")
                                    .font(.subheadline)
                                Text("Confidence: \(String(format: "%.2f", log.confidence))")
                                    .font(.caption)

                                if let image = decodeImage(from: log.photoBase64) {
                                    Button(action: {
                                        selectedImage = image
                                        isFullScreen = true
                                    }) {
                                        Image(uiImage: image)
                                            .resizable()
                                            .scaledToFit()
                                            .frame(height: 150)
                                            .cornerRadius(10)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                } else {
                                    Text("Image not available")
                                        .foregroundColor(.red)
                                        .font(.caption)
                                }
                            }
                            .padding(.vertical, 10)
                        }
                        .onDelete(perform: viewModel.delete) //Swipe to delete.
                    }
                }
            }
            .onAppear {
                viewModel.fetch()
            }
            .navigationTitle("Activity Logs")
            .sheet(isPresented: $isFullScreen) {
                if let selectedImage = selectedImage {
                    FullScreenImageView(image: selectedImage)
                }
            }
            .toolbar {
                EditButton() // Enable edit mode for deleting
            }
        }
    }

    private func decodeImage(from base64String: String) -> UIImage? {
        guard let imageData = Data(base64Encoded: base64String) else {
            print("Failed to decode Base64 string")
            return nil
        }
        return UIImage(data: imageData)
    }
}
