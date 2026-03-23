//
//  ImportSessionReviewSheet.swift
//  Block-Time
//

import SwiftUI

struct ImportSessionReviewSheet: View {
    @Environment(\.dismiss) private var dismiss
    let result: ImportSessionResult

    // Callback to navigate to logbook filtered to this session
    // This is posted as a notification that FlightsView/FlightsSplitView listens for

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Icon
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.green)
                    .padding(.top, 32)

                // Title
                Text("Import Complete")
                    .font(.title2)
                    .fontWeight(.bold)

                // Stats
                VStack(spacing: 12) {
                    ImportStatRow(icon: "checkmark.circle.fill", color: .green,
                                  label: "Flights added", value: result.successCount)
                    if result.duplicateCount > 0 {
                        ImportStatRow(icon: "minus.circle.fill", color: .secondary,
                                      label: "Duplicates skipped", value: result.duplicateCount)
                    }
                }
                .padding()
                .background(Color(.systemGray6).opacity(0.75))
                .cornerRadius(12)
                .padding(.horizontal)

                Spacer()

                // Review button — posts notification with session ID, FlightsView applies filter
                if result.successCount > 0 {
                    Button {
                        dismiss()
                        // Delay so the sheet dismisses and the tab switch animation completes
                        // before FlightsSplitView receives and applies the session filter
                        let sessionID = result.sessionID
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                            NotificationCenter.default.post(
                                name: .reviewImportSession,
                                object: nil,
                                userInfo: ["sessionID": sessionID]
                            )
                        }
                    } label: {
                        HStack {
                            Image(systemName: "magnifyingglass")
                            Text("Review Imported Flights")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .padding(.horizontal)
                }

                Button("Done") { dismiss() }
                    .foregroundColor(.secondary)
                    .padding(.bottom, 32)
            }
            .navigationTitle("Import Summary")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

private struct ImportStatRow: View {
    let icon: String
    let color: Color
    let label: String
    let value: Int

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text("\(value)")
                .fontWeight(.semibold)
        }
    }
}
