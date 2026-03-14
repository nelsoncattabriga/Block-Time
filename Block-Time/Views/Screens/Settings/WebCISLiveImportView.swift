//
//  WebCISLiveImportView.swift
//  Block-Time
//
//  WKWebView sheet for live webCIS logbook extraction.
//  User logs in via SSO, navigates to the logbook history page,
//  then taps "Extract Data". A WKScriptMessageHandler receives
//  the DOM text and passes it back to Swift for parsing.
//

import SwiftUI
import WebKit

// MARK: - View

struct WebCISLiveImportView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(ThemeService.self) private var themeService

    /// Called when extraction succeeds — raw page text ready for parsing
    let onExtracted: (String) -> Void

    @State private var navigator = WebCISNavigator()
    @State private var isLoading = true
    @State private var estimatedProgress: Double = 0
    @State private var currentURL: URL? = nil
    @State private var extractionStatus: ExtractionStatus = .idle

    enum ExtractionStatus {
        case idle
        case extracting
        case success(rowCount: Int)
        case failed(String)
    }

    private let initialURL = URL(string: "https://www.qantas.com.au/cis/operation/aeronauticalrpt")!

    // The logbook report page URL fragment — used to show/hide the Extract button
    private var isOnLogbookPage: Bool {
        guard let url = currentURL else { return false }
        return url.absoluteString.contains("aeronauticalrpt")
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                WebCISWebView(
                    url: initialURL,
                    navigator: navigator,
                    isLoading: $isLoading,
                    estimatedProgress: $estimatedProgress,
                    currentURL: $currentURL,
                    onDataExtracted: handleExtractedData
                )
                .ignoresSafeArea(edges: .bottom)

                if isLoading {
                    ProgressView(value: estimatedProgress)
                        .tint(.accentColor)
                }
            }
            .overlay(alignment: .bottom) {
                extractionBanner
            }
            .navigationTitle("webCIS Logbook")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }

                ToolbarItemGroup(placement: .topBarTrailing) {
                    // Navigation controls
                    Button { navigator.goBack() } label: {
                        Image(systemName: "chevron.left")
                    }
                    Button { navigator.reload() } label: {
                        Image(systemName: "arrow.clockwise")
                    }

                    // Extract button — only visible on the logbook page
                    if isOnLogbookPage {
                        Button {
                            extractionStatus = .extracting
                            navigator.extractData()
                        } label: {
                            Label("Extract Data", systemImage: "tray.and.arrow.down")
                        }
                        .fontWeight(.semibold)
                        .tint(.green)
                        .disabled(isLoading)
                    }
                }
            }
        }
    }

    // MARK: - Bottom banner

    @ViewBuilder
    private var extractionBanner: some View {
        switch extractionStatus {
        case .idle:
            if isOnLogbookPage && !isLoading {
                HStack(spacing: 8) {
                    Image(systemName: "info.circle")
                    Text("Tap **Extract Data** in the toolbar to import your logbook")
                        .font(.caption)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                .padding(.bottom, 8)
            }

        case .extracting:
            HStack(spacing: 8) {
                ProgressView()
                Text("Extracting logbook data…")
                    .font(.caption)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            .padding(.bottom, 8)

        case .success(let rowCount):
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                Text("Extracted \(rowCount) rows — proceeding to import…")
                    .font(.caption)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            .padding(.bottom, 8)

        case .failed(let reason):
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                Text("Extraction failed: \(reason)")
                    .font(.caption)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            .padding(.bottom, 8)
        }
    }

    // MARK: - Handler

    private func handleExtractedData(_ result: Result<String, Error>) {
        switch result {
        case .success(let rawText):
            // Count tab-separated lines — each is one flight row
            let rowCount = rawText.components(separatedBy: "\n")
                .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
                .count

            extractionStatus = .success(rowCount: rowCount)

            // Brief delay so user sees the success state, then hand off.
            // ImportExportView is responsible for dismissing this view and
            // presenting the mapping sheet after the dismiss animation completes.
            Task {
                try? await Task.sleep(for: .seconds(1))
                onExtracted(rawText)
            }

        case .failure(let error):
            print("❌ WebCIS extraction failed: \(error)")
            extractionStatus = .failed(error.localizedDescription)
        }
    }
}

// MARK: - Navigator

@Observable
@MainActor
final class WebCISNavigator {
    private var webView: WKWebView?

    func attach(_ webView: WKWebView) {
        self.webView = webView
    }

    func goBack()  { webView?.goBack() }
    func reload()  { webView?.reload() }

    /// Manually trigger the JS extraction script
    func extractData() {
        guard let webView else { return }
        webView.evaluateJavaScript(WebCISLiveImportView.extractionScript) { result, error in
            // Result is handled via the WKScriptMessageHandler — this call just triggers execution
            if let error {
                print("❌ JS evaluation error: \(error)")
            }
        }
    }
}

// MARK: - JavaScript extraction script

extension WebCISLiveImportView {
    /// Injected into the page to extract the logbook table text and post it back to Swift.
    /// Posts to the "webCISData" message handler.
    static let extractionScript = """
    (function() {
        console.log('[BlockTime] Starting webCIS extraction');

        var tables = document.querySelectorAll('table');
        console.log('[BlockTime] Tables found: ' + tables.length);
        tables.forEach(function(t, i) {
            console.log('[BlockTime] Table[' + i + '] rows=' + t.rows.length + ' classes=' + t.className + ' id=' + t.id);
        });

        // webCIS date format: "11 May 01" — digits followed by a space and 3-letter month
        var datePattern = /^\\d{1,2}\\s+[A-Za-z]{3}\\s+\\d{2}/;

        // Find the table with flight data: largest table whose first data cell matches the date pattern
        var dataTable = null;
        var maxRows = 0;
        for (var t = 0; t < tables.length; t++) {
            var tbl = tables[t];
            if (tbl.rows.length > maxRows) {
                // Check if any cell in the first column matches the date pattern
                for (var r = 0; r < Math.min(tbl.rows.length, 10); r++) {
                    var cell0 = tbl.rows[r].cells[0];
                    if (cell0 && datePattern.test(cell0.innerText.trim())) {
                        maxRows = tbl.rows.length;
                        dataTable = tbl;
                        break;
                    }
                }
            }
        }

        if (!dataTable) {
            // Fallback: just pick the largest table regardless
            for (var t = 0; t < tables.length; t++) {
                if (tables[t].rows.length > maxRows) {
                    maxRows = tables[t].rows.length;
                    dataTable = tables[t];
                }
            }
            console.log('[BlockTime] WARNING: date pattern not matched, using largest table with ' + maxRows + ' rows');
        } else {
            console.log('[BlockTime] Found data table with ' + maxRows + ' rows');
        }

        if (!dataTable) {
            webkit.messageHandlers.webCISData.postMessage('__DEBUG__\\nNo tables found on page.');
            return;
        }

        // Log the first 5 rows with full cell detail for debugging
        console.log('[BlockTime] --- Sample rows (first 5) ---');
        for (var r = 0; r < Math.min(dataTable.rows.length, 5); r++) {
            var cells = Array.from(dataTable.rows[r].cells);
            var cellData = cells.map(function(c, i) { return i + ':' + JSON.stringify(c.innerText.trim()); }).join('  ');
            console.log('[BlockTime] Row[' + r + '] cells=' + cells.length + ' | ' + cellData);
        }
        console.log('[BlockTime] --- Column count in row 0: ' + dataTable.rows[0].cells.length + ' ---');

        // Extract all rows as tab-separated text — one row per line
        var lines = [];
        for (var r = 0; r < dataTable.rows.length; r++) {
            var cells = Array.from(dataTable.rows[r].cells).map(function(c) { return c.innerText.trim(); });
            // Only include rows that look like flight data (first cell matches date pattern)
            if (datePattern.test(cells[0])) {
                lines.push(cells.join('\\t'));
            }
        }

        console.log('[BlockTime] Flight rows extracted: ' + lines.length);

        if (lines.length === 0) {
            webkit.messageHandlers.webCISData.postMessage('__DEBUG__\\nTable found but no rows matched date pattern. Check sample rows above.');
            return;
        }

        var payload = lines.join('\\n');
        webkit.messageHandlers.webCISData.postMessage(payload);
        console.log('[BlockTime] Posted ' + payload.length + ' chars to Swift');
    })();
    """
}

// MARK: - UIViewRepresentable

private struct WebCISWebView: UIViewRepresentable {
    let url: URL
    let navigator: WebCISNavigator
    @Binding var isLoading: Bool
    @Binding var estimatedProgress: Double
    @Binding var currentURL: URL?
    let onDataExtracted: (Result<String, Error>) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()

        // Persistent session so SSO cookies survive across launches
        config.websiteDataStore = .default()

        // Register the message handler that receives extracted data
        config.userContentController.add(context.coordinator, name: "webCISData")

        // Also inject a console.log → print bridge for debugging
        let consoleBridge = WKUserScript(
            source: """
            (function() {
                var origLog = console.log.bind(console);
                console.log = function() {
                    var msg = Array.prototype.slice.call(arguments).join(' ');
                    origLog(msg);
                    try { webkit.messageHandlers.webCISData.postMessage('__LOG__' + msg); } catch(e) {}
                };
            })();
            """,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: false
        )
        config.userContentController.addUserScript(consoleBridge)

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
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "webCISData")
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var parent: WebCISWebView
        private var progressObservation: NSKeyValueObservation?

        init(_ parent: WebCISWebView) {
            self.parent = parent
        }

        func startObserving(_ webView: WKWebView) {
            progressObservation = webView.observe(\.estimatedProgress) { [weak self] wv, _ in
                Task { @MainActor [weak self] in
                    self?.parent.estimatedProgress = wv.estimatedProgress
                }
            }
        }

        func stopObserving() {
            progressObservation = nil
        }

        // MARK: WKNavigationDelegate

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            Task { @MainActor [weak self] in
                self?.parent.isLoading = true
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.parent.isLoading = false
                self.parent.currentURL = webView.url
            }
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            Task { @MainActor [weak self] in
                self?.parent.isLoading = false
            }
            print("❌ WebCIS navigation failed: \(error)")
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            Task { @MainActor [weak self] in
                self?.parent.isLoading = false
            }
            print("❌ WebCIS provisional navigation failed: \(error)")
        }

        // MARK: WKScriptMessageHandler

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.name == "webCISData",
                  let body = message.body as? String else { return }

            // Console log bridge — just print and return
            if body.hasPrefix("__LOG__") {
                print("🌐 JS: \(body.dropFirst(7))")
                return
            }

            let result: Result<String, Error>
            if body.hasPrefix("__DEBUG__") {
                result = .failure(NSError(domain: "WebCIS", code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "No flight table found on this page. Navigate to your logbook and try again."]))
            } else {
                result = .success(body)
            }

            Task { @MainActor [weak self] in
                self?.parent.onDataExtracted(result)
            }
        }
    }
}
