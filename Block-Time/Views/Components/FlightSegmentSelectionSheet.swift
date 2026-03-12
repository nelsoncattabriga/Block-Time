//
//  FlightSegmentSelectionSheet.swift
//  Block-Time
//
//  Created by Nelson
//

import SwiftUI

struct FlightSegmentSelectionSheet: View {
    let flightSegments: [FlightAwareData]
    let onSelect: (FlightAwareData) -> Void
    let onDismiss: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "airplane.circle.fill")
                        .font(.system(size: 50))
                        .foregroundStyle(.blue)
                        .padding(.top, 20)

                    Text("Multiple Flight Segments Found")
                        .font(.title2)
                        .bold()

                    Text("Select the segment you want to log")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.bottom, 20)
                }
                .padding(.horizontal)

                Divider()

                // Flight segments list
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(Array(flightSegments.enumerated()), id: \.offset) { index, segment in
                            FlightSegmentCard(
                                segment: segment,
                                index: index + 1,
                                totalSegments: flightSegments.count,
                                onSelect: {
                                    onSelect(segment)
                                    onDismiss()
                                }
                            )
                        }
                    }
                    .padding()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") {
                        onDismiss()
                    }
                }
            }
        }
    }
}

struct FlightSegmentCard: View {
    let segment: FlightAwareData
    let index: Int
    let totalSegments: Int
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 0) {
                // Segment number badge
                HStack {
                    Text("Segment \(index) of \(totalSegments)")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(Color.blue)
                        .clipShape(.rect(cornerRadius: 8))

                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)

                // Flight details
                HStack(spacing: 16) {
                    // Origin
                    VStack(spacing: 4) {
                        Image(systemName: "airplane.departure")
                            .font(.title3)
                            .foregroundStyle(.blue)

                        Text(segment.origin)
                            .font(.title2)
                            .bold()
                            .foregroundStyle(.primary)

                        Text("Departs")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Text(segment.departureTime)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.primary)
                    }
                    .frame(maxWidth: .infinity)

                    // Arrow
                    VStack {
                        Image(systemName: "arrow.right")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                    }

                    // Destination
                    VStack(spacing: 4) {
                        Image(systemName: "airplane.arrival")
                            .font(.title3)
                            .foregroundStyle(.orange)

                        Text(segment.destination)
                            .font(.title2)
                            .bold()
                            .foregroundStyle(.primary)

                        Text("Arrives")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Text(segment.arrivalTime)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.primary)
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(.vertical, 20)
                .padding(.horizontal, 16)

                // Date
                HStack {
                    Image(systemName: "calendar")
                        .foregroundStyle(.secondary)
                    Text(segment.flightDate)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.bottom, 12)
            }
            .background(.thinMaterial)
            .clipShape(.rect(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.blue.opacity(0.3), lineWidth: 2)
            )
            .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Preview
#Preview {
    FlightSegmentSelectionSheet(
        flightSegments: [
            FlightAwareData(
                origin: "YSSY",
                destination: "WSSS",
                departureTime: "08:30",
                arrivalTime: "14:00",
                scheduledDepartureTime: nil,
                scheduledArrivalTime: nil,
                flightDate: "28/10/2025"
            ),
            FlightAwareData(
                origin: "WSSS",
                destination: "EGLL",
                departureTime: "16:45",
                arrivalTime: "23:15",
                scheduledDepartureTime: nil,
                scheduledArrivalTime: nil,
                flightDate: "28/10/2025"
            )
        ],
        onSelect: { _ in },
        onDismiss: { }
    )
}
