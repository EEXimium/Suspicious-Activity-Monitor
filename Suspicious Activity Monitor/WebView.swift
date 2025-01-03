//
//  WebView.swift
//  Suspicious Activity Monitor
//
//  Created by Yağız Efe Atasever on 20.12.2024.
//


import SwiftUI
import WebKit

struct WebView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        let request = URLRequest(url: url)
        webView.load(request)
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        //update yok
    }
}
