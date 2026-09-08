//
//  LogEntry.swift
//  Suspicious Activity Monitor
//
//  Created by Yağız Efe Atasever on 21.12.2024.
//


import Foundation
//burası loglarla alakalı. db'ye kaydedeceğimiz obje loglarının attributeları nelerdir onlar bunlar.
struct LogEntry: Identifiable, Codable {
    let id: String          // Random ID
    let date: String        // Timestamp
    let object: String      // Object type ("Knife", "Pistol")
    let confidence: Double  // Confidence
    let photoBase64: String // Base64-encoded resim
    var cameraID: String = ""

    var identity: String { "\(cameraID)/\(object)/\(id)" }
}
