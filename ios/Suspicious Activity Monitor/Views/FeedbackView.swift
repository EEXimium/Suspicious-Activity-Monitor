//
//  FeedbackView.swift
//  Suspicious Activity Monitor
//
//  Created by Yağız Efe Atasever on 4.01.2025.
//


import SwiftUI

struct FeedbackView: View {
    @Environment(\.dismiss) private var dismiss
    let email: String
    @StateObject private var viewModel = FeedbackViewModel()

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Send Feedback")
                    .font(.largeTitle)
                    .bold()
                //texfieldimiz var, kullanıcı istediği feedbacki giriyor buraya
                TextField("Enter your feedback here", text: $viewModel.feedbackText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(height: 100)
                    .padding()

                Button(action: { viewModel.send(email: email) }) {
                    Text("Submit Feedback")
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.green)
                        .cornerRadius(10)
                }
                .disabled(viewModel.isSending)

                if viewModel.showSuccessMessage {
                    Text("Feedback submitted successfully!")
                        .foregroundColor(.green)
                        .font(.subheadline)
                }

                if viewModel.showErrorMessage {
                    Text("Failed to submit feedback. Please try again.")
                        .foregroundColor(.red)
                        .font(.subheadline)
                }
            }
            .padding()
            .navigationTitle("Feedback")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        hideKeyboard()
                        viewModel.showSuccessMessage = false
                        viewModel.showErrorMessage = false
                        viewModel.feedbackText = ""
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
