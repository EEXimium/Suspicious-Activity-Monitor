//
//  AccountPage.swift
//  Suspicious Activity Monitor
//
//  Created by Yağız Efe Atasever on 4.01.2025.
//

import SwiftUI

struct AccountPage: View {
    @Binding var isLoggedIn: Bool
    var email: String
    @StateObject private var viewModel = AccountViewModel()

    var body: some View {
        VStack(spacing: 20) {
            Text("Account Settings")
                .font(.largeTitle)
                .bold()

            Text("Logged in as: \(email)")
                .font(.headline)

            Divider()

            TextField("Camera ID", text: $viewModel.cameraID)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .autocapitalization(.none)

            Text("Your administrator must grant camera access to your account before linking.")
                .font(.caption)

            Button(action: { viewModel.link(email: email) }) {
                Text("Link Camera")
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.green)
                    .cornerRadius(10)
            }

            List {
                ForEach(viewModel.linkedCameras.keys.sorted(), id: \.self) { cameraID in
                    HStack {
                        Text(cameraID)
                        Spacer()
                        Button(action: { viewModel.unlink(email: email, id: cameraID) }) {
                            Text("Unlink")
                                .foregroundColor(.red)
                        }
                    }
                }
            }

            Divider()

            Button(action: { if viewModel.logout() { isLoggedIn = false } }) {
                Text("Log Out")
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.red)
                    .cornerRadius(10)
            }

            if viewModel.showError {
                Text(viewModel.errorMessage)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
        .onAppear {
            viewModel.fetch(email: email)
        }
    }

}
