//
//  ContentView.swift
//  Suspicious Activity Monitor
//
//  Created by Yağız Efe Atasever on 19.12.2024.
//

import SwiftUI

struct ContentView: View {
    @Binding var isLoggedIn: Bool
    @Binding var userEmail: String
    @State private var showFeedbackSheet = false // To show the feedback sheet

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                NavigationLink(destination: LogsView()) {
                    
                    //DB deki tehlike obje loglarına bakıp silebiliyorum
                    Text("Activity Logs")
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.green)
                        .cornerRadius(10)
                }
                //hesabıma linklenmiş kameraları istediğim gibi izleyebiliyorum (tabi kamera live'sa o sırada)
                NavigationLink(destination: LiveFeedView(email: userEmail)) {
                    Text("Live Feed")
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue)
                        .cornerRadius(10)
                }

                NavigationLink(
                    destination: AccountPage(isLoggedIn: $isLoggedIn, email: userEmail)
                ) {
                    //hesap ayarları, kamera linkleme ve log out
                    Text("Account Settings")
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.orange)
                        .cornerRadius(10)
                }

                Button(action: {
                    callEmergencyNumber()
                }) {
                    Text("Call Emergency 112")
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.red)
                        .cornerRadius(10)
                }

                Button(action: {
                    showFeedbackSheet = true
                }) {
                    Text("Send Feedback")
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.purple)
                        .cornerRadius(10)
                }
            }
            .padding()
            .navigationTitle("S.A.M. Main Menu") //S.A.M. -> Suspicious Activity Monitor. Kısaltması isim gibi oldu böyle kalsın dedik.
            .sheet(isPresented: $showFeedbackSheet) {
                FeedbackView(email: userEmail)
            }
        }
    }
    //telefon numaralarını url olarak giriyoruz. böyle olunca iOS otomatik olarak bir numara aramak istediğimizi varsayıyor
    //ve tuşa bastığımızda "ara 112?" diye bir onay tuşu çıkarıyor.
    private func callEmergencyNumber() {
        let phoneNumber = "tel://112"
        if let url = URL(string: phoneNumber), UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        } else {
            print("Cannot make a phone call on this device.")
        }
    }
}
