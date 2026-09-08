import SwiftUI
import WebKit

struct WebView: UIViewRepresentable {
    let request: URLRequest
    let onError: (String) -> Void

    final class Coordinator: NSObject, WKNavigationDelegate {
        var request: URLRequest?
        var onError: (String) -> Void
        init(onError: @escaping (String) -> Void) { self.onError = onError }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            // Never forward the Firebase bearer credential to a redirected host or path.
            guard navigationAction.request.url == request?.url else {
                decisionHandler(.cancel)
                onError("The camera tried to redirect the secure stream.")
                return
            }
            decisionHandler(.allow)
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse,
                     decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
            if let response = navigationResponse.response as? HTTPURLResponse, response.statusCode >= 400 {
                decisionHandler(.cancel)
                onError("Camera connection denied or unavailable. Check your access and retry.")
            } else { decisionHandler(.allow) }
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            report(error)
        }
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            report(error)
        }
        private func report(_ error: Error) {
            if (error as NSError).code != NSURLErrorCancelled { onError(error.localizedDescription) }
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(onError: onError) }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        let view = WKWebView(frame: .zero, configuration: configuration)
        view.navigationDelegate = context.coordinator
        context.coordinator.request = request
        view.load(request)
        return view
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        context.coordinator.onError = onError
        if context.coordinator.request != request {
            context.coordinator.request = request
            uiView.load(request)
        }
    }

    static func dismantleUIView(_ uiView: WKWebView, coordinator: Coordinator) {
        uiView.navigationDelegate = nil
        uiView.stopLoading()
    }
}
