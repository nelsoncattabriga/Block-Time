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

                    // Live import option
                    WebCISLiveImportCard {
                        dismiss()
                        Task { @MainActor in
                            try? await Task.sleep(for: .seconds(0.2))
                            onLiveImport()
                        }
                    }
                    .padding(.horizontal)

                    // Divider with label
                    HStack(spacing: 12) {
                        Rectangle()
                            .fill(Color(.separator).opacity(0.5))
                            .frame(height: 1)
                        Text("or import from file")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize()
                        Rectangle()
                            .fill(Color(.separator).opacity(0.5))
                            .frame(height: 1)
                    }
                    .padding(.horizontal)

                    // Notice banner
//                    WebCISNoticeBanner()
//                        .padding(.horizontal)

                    // Instruction card
                    WebCISInstructionCard {
                        Divider()
                        Button {
                            dismiss()
                            Task { @MainActor in
                                try? await Task.sleep(for: .seconds(0.2))
                                onSelectFile()
                            }
                        } label: {
                            HStack {
                                Image(systemName: "doc.badge.plus")
                                Text("Select webCIS File")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .foregroundStyle(.orange)
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
                        .fill(Color.green.opacity(0.12))
                        .frame(width: 44, height: 44)
                    Image(systemName: "globe")
                        .font(.title3)
                        .foregroundStyle(.green)
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
            .background(Color(.secondarySystemBackground).overlay(Color.green.opacity(0.05)))
            .clipShape(.rect(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.green.opacity(0.35), lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
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

// MARK: - Instruction Card

private struct WebCISInstructionCard<Action: View>: View {
    let action: Action

    init(@ViewBuilder action: () -> Action) {
        self.action = action()
    }

    private let steps: [String] = [
        "Search Workday for the 'Manager Crew Systems' email address",
        "Email them requesting a copy of your webCIS Flying Record",
        "Once you receive the file, save it and tap Select webCIS File below"
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.orange.opacity(0.12))
                        .frame(width: 36, height: 36)
                    Image(systemName: "envelope.fill")
                        .font(.headline)
                        .foregroundStyle(.orange)
                }

                Text("Import From File")
                    .font(.subheadline)
                    .fontWeight(.bold)
            }

            // Steps
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                    HStack(alignment: .top, spacing: 10) {
                        Text("\(index + 1)")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.orange)
                            .frame(width: 20, height: 20)
                            .background(Color.orange.opacity(0.12))
                            .clipShape(Circle())

                        Text(step)
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                            .fixedSize(horizontal: false, vertical: true)

                        Spacer(minLength: 0)
                    }
                }
            }

            action
        }
        .padding()
        .background(Color(.secondarySystemBackground).overlay(Color.orange.opacity(0.05)))
        .clipShape(.rect(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color(.separator).opacity(0.4), lineWidth: 1.5)
        )
    }
}

#Preview {
    WebCISImportInstructionsView { } onLiveImport: { }
}
