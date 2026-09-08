//
//  RegistrationView.swift
//  Suspicious Activity Monitor
//
//  Created by Yağız Efe Atasever on 4.01.2025.
//

import SwiftUI

struct RegistrationView: View {
    @StateObject private var viewModel = AuthenticationViewModel()
    @Binding var isLoggedIn: Bool
    @Binding var userEmail: String

    var body: some View {
        VStack(spacing: 20) {
            Text("Register")
                .font(.largeTitle)
                .bold()

            TextField("Email", text: $viewModel.email)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .keyboardType(.emailAddress)
                .autocapitalization(.none)

            SecureField("Password", text: $viewModel.password)
                .textFieldStyle(RoundedBorderTextFieldStyle())

            Button(action: register) {
                Text("Register")
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.green)
                    .cornerRadius(10)
            }
            .disabled(viewModel.isLoading)

            if viewModel.showError {
                Text(viewModel.errorMessage)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
        .navigationTitle("Register")
    }

    private func register() {
        viewModel.register { email in
            userEmail = email
            isLoggedIn = true
        }
    }
}
