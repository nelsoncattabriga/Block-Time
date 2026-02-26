//
//  UserGuideView.swift
//  Block-Time
//

import SwiftUI
import WebKit

// MARK: - Web Navigator

@Observable
@MainActor
final class WebNavigator {
    private var webView: WKWebView?

    func attach(_ webView: WKWebView) {
        self.webView = webView
    }

    func goBack() { webView?.goBack() }
    func goForward() { webView?.goForward() }
    func reload() { webView?.reload() }
    func load(_ url: URL) { webView?.load(URLRequest(url: url)) }
}

// MARK: - User Guide View

struct UserGuideView: View {
    @Environment(ThemeService.self) private var themeService
    @State private var navigator = WebNavigator()
    @State private var isLoading = true
    @State private var loadError: Error?
    @State private var canGoBack = false
    @State private var canGoForward = false
    @State private var estimatedProgress: Double = 0

    private let guideURL = URL(string: "https://block-time.app/guide/")!

    var body: some View {
        ZStack(alignment: .top) {
            GuideWebView(
                url: guideURL,
                navigator: navigator,
                isLoading: $isLoading,
                canGoBack: $canGoBack,
                canGoForward: $canGoForward,
                estimatedProgress: $estimatedProgress,
                loadError: $loadError
            )
            .ignoresSafeArea(edges: .bottom)

            if isLoading {
                ProgressView(value: estimatedProgress)
                    .tint(.accentColor)
            }
        }
        .overlay {
            if loadError != nil {
                offlineOverlay
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Button { navigator.goBack() } label: {
                    Image(systemName: "chevron.left")
                }
                .disabled(!canGoBack)

                Button { navigator.goForward() } label: {
                    Image(systemName: "chevron.right")
                }
                .disabled(!canGoForward)

                Button { navigator.reload() } label: {
                    Image(systemName: "arrow.clockwise")
                }
            }
        }
        .navigationTitle("User Guide")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var offlineOverlay: some View {
        VStack(spacing: 20) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 60))
                .foregroundColor(.secondary)

            Text("Unable to Load Guide")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Check your internet connection and try again.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Button("Try Again") {
                loadError = nil
                navigator.load(guideURL)
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(themeService.getGradient().ignoresSafeArea())
    }
}

// MARK: - WKWebView Representable

private struct GuideWebView: UIViewRepresentable {
    let url: URL
    let navigator: WebNavigator
    @Binding var isLoading: Bool
    @Binding var canGoBack: Bool
    @Binding var canGoForward: Bool
    @Binding var estimatedProgress: Double
    @Binding var loadError: Error?

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default() // persistent disk cache across launches

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true

        context.coordinator.startObserving(webView)
        navigator.attach(webView)

        webView.load(URLRequest(url: url))
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        context.coordinator.parent = self
    }

    static func dismantleUIView(_ webView: WKWebView, coordinator: Coordinator) {
        coordinator.stopObserving()
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, WKNavigationDelegate {
        var parent: GuideWebView
        private var progressObservation: NSKeyValueObservation?

        init(_ parent: GuideWebView) {
            self.parent = parent
        }

        func startObserving(_ webView: WKWebView) {
            progressObservation = webView.observe(\.estimatedProgress, options: [.new]) { [weak self] webView, _ in
                let progress = webView.estimatedProgress
                Task { @MainActor [weak self] in
                    self?.parent.estimatedProgress = progress
                }
            }
        }

        func stopObserving() {
            progressObservation = nil
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            parent.isLoading = true
            parent.loadError = nil
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            parent.isLoading = false
            parent.canGoBack = webView.canGoBack
            parent.canGoForward = webView.canGoForward
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            parent.isLoading = false
            parent.loadError = error
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            parent.isLoading = false
            parent.loadError = error
        }
    }
}

#Preview {
    NavigationStack {
        UserGuideView()
    }
    .environment(ThemeService.shared)
}
