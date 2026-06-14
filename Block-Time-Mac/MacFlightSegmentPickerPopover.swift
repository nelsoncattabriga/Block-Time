//
//  MacFlightSegmentPickerPopover.swift
//  Block-Time-Mac
//

import BlockTimeKit
import SwiftUI

struct MacFlightSegmentPickerPopover: View {
    let segments: [FlightAwareData]
    let onSelect: (FlightAwareData) -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Multiple Segments Found")
                    .font(.headline)
                Spacer()
                Button("Cancel", action: onDismiss)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)
            .padding(.bottom, 8)

            Divider()

            ScrollView {
                VStack(spacing: 8) {
                    ForEach(Array(segments.enumerated()), id: \.offset) { idx, seg in
                        Button {
                            onSelect(seg)
                        } label: {
                            HStack(spacing: 12) {
                                Text("Seg \(idx + 1)")
                                    .font(.caption.bold())
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.blue)
                                    .clipShape(RoundedRectangle(cornerRadius: 4))

                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 4) {
                                        Text(seg.origin)
                                            .font(.system(.body, design: .monospaced).bold())
                                        Image(systemName: "arrow.right")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                        Text(seg.destination)
                                            .font(.system(.body, design: .monospaced).bold())
                                    }
                                    HStack(spacing: 8) {
                                        Text("OUT \(seg.departureTime)")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        Text("IN \(seg.arrivalTime)")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.secondary.opacity(0.07))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(10)
            }
        }
        .frame(width: 300, height: min(CGFloat(segments.count) * 72 + 70, 400))
    }
}
