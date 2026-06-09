//
//  WebCISImportInstructionsView.swift
//  Block-Time
//
//  Created by Nelson on 26/02/2026.
//

import SwiftUI

struct WebCISImportInstructionsView: View {
    @Environment(\.dismiss) private var dismiss
    let onSelectFile: () -> Void
    let onLiveImport: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    VStack(spacing: 10) {
                        Image(systemName: "doc.text.fill")
                            .font(.system(size: 52))
                            .foregroundStyle(.orange)

                        Text("webCIS Flying Record")
                            .font(.title2)
                            .fontWeight(.bold)

                        Text("ARMS Flying Experience Report")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top)

                    // Notes / callouts
                    WebCISNotesSection()
                        .padding(.horizontal)

                    // Live import option
                    WebCISLiveImportCard {
                        dismiss()
                        Task { @MainActor in
                            try? await Task.sleep(for: .seconds(0.2))
                            onLiveImport()
                        }
                    }
                    .padding(.horizontal)

                    // File import option
                    WebCISFileImportCard {
                        dismiss()
                        Task { @MainActor in
                            try? await Task.sleep(for: .seconds(0.2))
                            onSelectFile()
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.bottom, 24)
            }
            .navigationTitle("Import webCIS History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Live Import Card

private struct WebCISLiveImportCard: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Color.orange.opacity(0.12))
                        .frame(width: 44, height: 44)
                    Image(systemName: "globe")
                        .font(.title3)
                        .foregroundStyle(.orange)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("Import Directly from webCIS")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                    Text("Login to webCIS to import flying history")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(Color(.secondarySystemBackground).overlay(Color.orange.opacity(0.05)))
            .clipShape(.rect(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.orange.opacity(0.35), lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Notes Section

private struct WebCISNotesSection: View {
    var body: some View {
        VStack(spacing: 10) {
            // iOS 26 iPad known issue — iPad only
            if UIDevice.current.userInterfaceIdiom == .pad {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .font(.subheadline)
                    .padding(.top, 1)

                VStack(alignment: .leading, spacing: 4) {
                    Text("iPAD — iOS 26 KNOWN ISSUE")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(.orange)

                    Text("The authentication loop may not complete correctly in full-screen mode. Switch to windowed mode before logging in. Alternatively, choose **receive a text message** as your authentication method, or authenticate using another device.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding()
            .background(Color.orange.opacity(0.08))
            .clipShape(.rect(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.orange.opacity(0.35), lineWidth: 1)
            )
            } // end iPad-only

        }
    }
}

// MARK: - Notice Banner

//private struct WebCISNoticeBanner: View {
//    var body: some View {
//        HStack(alignment: .top, spacing: 12) {
//            Image(systemName: "envelope.badge.fill")
//                .foregroundStyle(.orange)
//                .font(.subheadline)
//                .padding(.top, 1)
//
//            VStack(alignment: .leading, spacing: 4) {
//                Text("File Must Be Requested")
//                    .font(.subheadline)
//                    .fontWeight(.bold)
//
//                Text("The webCIS Flying Experience Report is **not** available for self-service download. You must request it by email from Qantas.")
//                    .font(.subheadline)
//                    .foregroundStyle(.secondary)
//                    .fixedSize(horizontal: false, vertical: true)
//            }
//        }
//        .padding()
//        .background(Color.orange.opacity(0.1))
//        .clipShape(.rect(cornerRadius: 12))
//        .overlay(
//            RoundedRectangle(cornerRadius: 12)
//                .stroke(Color.orange.opacity(0.45), lineWidth: 1)
//        )
//    }
//}

// MARK: - File Import Card

private struct WebCISFileImportCard: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Color.orange.opacity(0.12))
                        .frame(width: 44, height: 44)
                    Image(systemName: "doc.badge.plus")
                        .font(.title3)
                        .foregroundStyle(.orange)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("Select webCIS File")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                    Text("Import from a saved webCIS history file")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(Color(.secondarySystemBackground).overlay(Color.orange.opacity(0.05)))
            .clipShape(.rect(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.orange.opacity(0.35), lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    WebCISImportInstructionsView { } onLiveImport: { }
}
