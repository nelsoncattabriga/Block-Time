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
        NavigationView {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "airplane.circle.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.blue)
                        .padding(.top, 20)

                    Text("Multiple Flight Segments Found")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("Select the segment you want to log")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
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
                ToolbarItem(placement: .navigationBarTrailing) {
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
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(Color.blue)
                        .cornerRadius(8)

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
                            .foregroundColor(.blue)

                        Text(segment.origin)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)

                        Text("Departs")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text(segment.departureTime)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                    }
                    .frame(maxWidth: .infinity)

                    // Arrow
                    VStack {
                        Image(systemName: "arrow.right")
                            .font(.title2)
                            .foregroundColor(.secondary)
                    }

                    // Destination
                    VStack(spacing: 4) {
                        Image(systemName: "airplane.arrival")
                            .font(.title3)
                            .foregroundColor(.orange)

                        Text(segment.destination)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)

                        Text("Arrives")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text(segment.arrivalTime)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(.vertical, 20)
                .padding(.horizontal, 16)

                // Date
                HStack {
                    Image(systemName: "calendar")
                        .foregroundColor(.secondary)
                    Text(segment.flightDate)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.bottom, 12)
            }
            .background(.thinMaterial)
            .cornerRadius(12)
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
