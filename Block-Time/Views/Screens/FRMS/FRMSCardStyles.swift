//
//  FRMSCardStyles.swift
//  Block-Time
//
//  Shared card-building helpers for FRMS cumulative limit views.
//  Used by AdaptiveCumulativeLimitsLayout (iPad) and SH_NextDutyView (iPhone).
//

import SwiftUI
import BlockTimeKit

// MARK: - Section Header

func frmsSectionHeader(_ title: String) -> some View {
    HStack(spacing: 10) {
        Text(title.uppercased())
            .iPadScaledFont(.caption, phoneFont: .footnote)
            .fontWeight(.semibold)
            .foregroundStyle(.secondary)
            .kerning(1.2)

        Rectangle()
            .fill(.secondary.opacity(0.2))
            .frame(height: 1)
    }
    .padding(.top, 8)
}

// MARK: - Counter Card

func frmsCounterCard(
    title: String,
    value: Int,
    max: Int,
    unit: String,
    status: FRMSComplianceStatus,
    accentColor: Color
) -> some View {
    HStack(spacing: 0) {
        LinearGradient(
            colors: [accentColor, accentColor.opacity(0.4)],
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(width: 4)

        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)

                Spacer()

                Image(systemName: status.icon)
                    .foregroundStyle(frmsStatusColor(status))
                    .font(.subheadline)
            }

            HStack(alignment: .lastTextBaseline, spacing: 5) {
                Text("\(value)")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundStyle(frmsStatusColor(status))
                    .monospacedDigit()

                Text("/ \(max) \(unit)")
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
            }

            frmsThickGauge(value: Double(value), total: Double(max), color: frmsProgressColor(status))
        }
        .padding(16)
        .background(accentColor.opacity(0.04))
    }
    .appCardStyle()
}

// MARK: - Compact Limit Card (iPhone single-column)

func frmsCompactLimitCard(
    title: String,
    valueText: String,
    limit: Double,
    unit: String,
    current: Double,
    status: FRMSComplianceStatus,
    accentColor: Color,
    note: String? = nil
) -> some View {
    HStack(spacing: 0) {
        LinearGradient(
            colors: [accentColor, accentColor.opacity(0.4)],
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(width: 4)

        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)

                Spacer()

                Image(systemName: status.icon)
                    .foregroundStyle(frmsStatusColor(status))
                    .font(.subheadline)
            }

            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Text(valueText)
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundStyle(.primary)
                    .monospacedDigit()

                Text("/ \(Int(limit)) \(unit)")
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
            }

            frmsThickGauge(value: min(current, limit), total: limit, color: frmsProgressColor(status))

            if let note {
                Text(note)
                    .font(.caption)
                    .foregroundStyle(accentColor.opacity(0.7))
                    .fontWeight(.medium)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(accentColor.opacity(0.04))
    }
    .appCardStyle()
}

// MARK: - Compact Counter Card (iPhone single-column)

func frmsCompactCounterCard(
    title: String,
    value: Int,
    max: Int,
    unit: String,
    status: FRMSComplianceStatus,
    accentColor: Color
) -> some View {
    HStack(spacing: 0) {
        LinearGradient(
            colors: [accentColor, accentColor.opacity(0.4)],
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(width: 4)

        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)

                Spacer()

                Image(systemName: status.icon)
                    .foregroundStyle(frmsStatusColor(status))
                    .font(.subheadline)
            }

            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Text("\(value)")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundStyle(frmsStatusColor(status))
                    .monospacedDigit()

                Text("/ \(max) \(unit)")
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
            }

            frmsThickGauge(value: Double(value), total: Double(max), color: frmsProgressColor(status))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(accentColor.opacity(0.04))
    }
    .appCardStyle()
}

// MARK: - Gauge

func frmsThickGauge(value: Double, total: Double, color: Color) -> some View {
    GeometryReader { geo in
        ZStack(alignment: .leading) {
            Capsule()
                .fill(.quaternary)
                .frame(height: 5)

            Capsule()
                .fill(color)
                .frame(
                    width: total > 0 ? geo.size.width * CGFloat(min(value / total, 1.0)) : 0,
                    height: 5
                )
        }
    }
    .frame(height: 5)
}

// MARK: - Status Colour Helpers

func frmsStatusColor(_ status: FRMSComplianceStatus) -> Color {
    switch status {
    case .compliant:  return .green
    case .warning:    return .orange
    case .violation:  return .red
    }
}

func frmsProgressColor(_ status: FRMSComplianceStatus) -> Color {
    switch status {
    case .compliant:  return .blue
    case .warning:    return .orange
    case .violation:  return .red
    }
}

// MARK: - LNO / BOC Status

func frmsLnoCountStatus(_ count: Int, max: Int) -> FRMSComplianceStatus {
    if count >= max      { return .violation(message: "Maximum LNO periods in 168 hours reached") }
    if count >= max - 1  { return .warning(message: "Approaching LNO limit") }
    return .compliant
}

func frmsBocCountStatus(_ count: Int, max: Int) -> FRMSComplianceStatus {
    if count >= max      { return .violation(message: "Maximum BOC periods in 168 hours reached") }
    if count >= max - 1  { return .warning(message: "Approaching BOC limit") }
    return .compliant
}
