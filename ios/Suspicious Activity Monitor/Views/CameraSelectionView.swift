//
//  CameraSelectionView.swift
//  Suspicious Activity Monitor
//
//  Created by Yağız Efe Atasever on 4.01.2025.
//

import SwiftUI

struct CameraSelectionView: View {
    let cameraOptions: [String: String]
    let onSelect: (String, URL) -> Void
    //kullanıcının hesabına birden çok cam linklenmişse, livefeed'de istediğini seçebilir
    var body: some View {
        NavigationView {
            List(cameraOptions.keys.sorted(), id: \.self) { cameraName in
                if let urlString = cameraOptions[cameraName], let url = URL(string: urlString) {
                    Button(action: {
                        onSelect(cameraName, url)
                    }) {
                        Text(cameraName)
                    }
                }
            }
            .navigationTitle("Select a Camera")
        }
    }
}
