//
//  LimitsReferenceSheet.swift
//  Block-Time
//
//  In-app reference for LH FRMS planning and operational limits.
//  Loads the bundled HTML files and renders them in a WKWebView.
//

import SwiftUI
import WebKit

// MARK: - HTMLReferenceView

private struct HTMLReferenceView: UIViewRepresentable {
    let resourceName: String

    func makeUIView(context: Context) -> WKWebView {
        WKWebView()
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        guard let url = Bundle.main.url(forResource: resourceName, withExtension: "html") else { return }
        webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
    }
}

// MARK: - LimitsReferenceSheet

struct LimitsReferenceSheet: View {
    let planningResource: String
    let operationalResource: String
    @State private var selectedLimitType: FRMSLimitType
    @Environment(\.dismiss) private var dismiss

    init(initialLimitType: FRMSLimitType, planningResource: String, operationalResource: String) {
        _selectedLimitType = State(initialValue: initialLimitType)
        self.planningResource = planningResource
        self.operationalResource = operationalResource
    }

    private var resourceName: String {
        selectedLimitType == .planning ? planningResource : operationalResource
    }

    var body: some View {
        NavigationStack {
            HTMLReferenceView(resourceName: resourceName)
                .ignoresSafeArea(edges: .bottom)
                .navigationTitle("LH Limits Reference")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        Picker("Limit Type", selection: $selectedLimitType) {
                            Text("Planning").tag(FRMSLimitType.planning)
                            Text("Operational").tag(FRMSLimitType.operational)
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 220)
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { dismiss() }
                    }
                }
        }
    }
}
