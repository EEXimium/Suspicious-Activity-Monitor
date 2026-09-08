//
//  LoginView.swift
//  Suspicious Activity Monitor
//
//  Created by Yağız Efe Atasever on 4.01.2025.
//

import SwiftUI

struct LoginView: View {
    @StateObject private var viewModel = AuthenticationViewModel()
    @Binding var isLoggedIn: Bool
    @Binding var userEmail: String

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Login")
                    .font(.largeTitle)
                    .bold()

                TextField("Email", text: $viewModel.email)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)

                SecureField("Password", text: $viewModel.password)
                    .textFieldStyle(RoundedBorderTextFieldStyle())

                Button(action: login) {
                    Text("Login")
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(viewModel.isLockedOut ? Color.gray : Color.blue)
                        .cornerRadius(10)
                }
                .disabled(viewModel.isLockedOut || viewModel.isLoading)

                NavigationLink(
                    destination: RegistrationView(isLoggedIn: $isLoggedIn, userEmail: $userEmail)
                ) {
                    Text("Don't have an account? Register")
                        .foregroundColor(.blue)
                }

                if viewModel.showError {
                    Text(viewModel.errorMessage)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                }
            }
            .padding()
            .navigationTitle("Login")
        }
    }

    private func login() {
        viewModel.login { email in
            userEmail = email
            isLoggedIn = true
        }
    }
}
