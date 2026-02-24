//
//  DisruptionRestSection.swift
//  Block-Time
//
//  FD10.2.1 Disruption Rest calculator for the FRMS LH tab section.
//  Extracted from FRMSView.swift.
//

import SwiftUI

// MARK: - Disruption Rest — FD10.2.1

struct DisruptionRestSection: View {
    @Binding var isExpanded: Bool
    @Binding var previousDutyHours: Double
    @Binding var tzDifference: Double
    @Binding var nextDutyOver16: Bool
    let crewComplement: CrewComplement

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    // MARK: Clause calculations

    private var clauseI: Double {
        switch crewComplement {
        case .twoPilot:
            return previousDutyHours > 11.0 ? 12.0 : 10.0
        case .threePilot, .fourPilot:
            return previousDutyHours > 16.0 ? 24.0 : 12.0
        }
    }

    private var clauseII: Double? {
        guard previousDutyHours > 12.0 else { return nil }
        return 12.0 + 1.5 * (previousDutyHours - 12.0)
    }

    private var clauseIII: Double? {
        guard nextDutyOver16 else { return nil }
        switch crewComplement {
        case .twoPilot:   return nil
        case .threePilot: return 24.0
        case .fourPilot:  return 24.0
        }
    }

    private var effectiveRest: Double {
        let base = max(clauseI, clauseII ?? 0.0, clauseIII ?? 0.0)
        return base + max(0, tzDifference - 3)
    }

    // MARK: Body

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: 0) {

                Text("Applies when a disruption occurs after commencement of a pattern. Uses crew complement and operating/deadheading selection from Rest Requirements above.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, 16)

                if horizontalSizeClass == .compact {
                    // iPhone: stacked layout
                    inputRows
                        .padding(.bottom, 12)
                    clauseRows
                    effectiveRestRow
                } else {
                    // iPad: inputs on left, clause results on right
                    HStack(alignment: .top, spacing: 24) {
                        inputRows
                            .frame(maxWidth: .infinity)
                        Divider()
                        VStack(alignment: .leading, spacing: 0) {
                            clauseRows
                            effectiveRestRow
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            .padding(.top, 12)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "bolt.circle.fill")
                    .foregroundStyle(.orange)
                Text("Disruption Rest Calculator")
            }
            .font(.headline)
            .fontWeight(.semibold)
        }
        .padding()
        .appCardStyle()
    }

    // MARK: Sub-views

    @ViewBuilder
    private var inputRows: some View {
        VStack(spacing: 0) {
            // Previous Duty
            HStack {
                Text("Previous Duty")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                HStack(spacing: 0) {
                    Text(formatHoursMinutes(previousDutyHours))
                        .font(.subheadline)
                        .monospacedDigit()
                        .frame(minWidth: 44, alignment: .trailing)
                    Divider()
                        .frame(height: 20)
                        .padding(.horizontal, 8)
                    Button {
                        if previousDutyHours > 12.0 { previousDutyHours -= 0.25 }
                    } label: {
                        Image(systemName: "minus")
                            .font(.subheadline)
                            .frame(width: 28, height: 28)
                    }
                    Divider()
                        .frame(height: 20)
                    Button {
                        if previousDutyHours < 24.0 { previousDutyHours += 0.25 }
                    } label: {
                        Image(systemName: "plus")
                            .font(.subheadline)
                            .frame(width: 28, height: 28)
                    }
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.roundedRectangle(radius: 6))
                .padding(.trailing, 6)
            }
            .padding(.vertical, 10)

            Divider()

            // TZ Difference
            HStack {
                Text("TZ Difference")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                HStack(spacing: 0) {
                    Text(tzDifference == 0 ? "None" : formatHoursMinutes(tzDifference))
                        .font(.subheadline)
                        .monospacedDigit()
                        .frame(minWidth: 64, alignment: .trailing)
                    Divider()
                        .frame(height: 20)
                        .padding(.horizontal, 8)
                    Button {
                        if tzDifference > 0 { tzDifference -= 0.5 }
                    } label: {
                        Image(systemName: "minus")
                            .font(.subheadline)
                            .frame(width: 28, height: 28)
                    }
                    Divider()
                        .frame(height: 20)
                    Button {
                        if tzDifference < 12 { tzDifference += 0.5 }
                    } label: {
                        Image(systemName: "plus")
                            .font(.subheadline)
                            .frame(width: 28, height: 28)
                    }
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.roundedRectangle(radius: 6))
                .padding(.trailing, 6)
            }
            .padding(.vertical, 10)

            Divider()

            // Next Duty Planned > 16 hrs
            HStack {
                Text("Next Duty Planned > 16 hrs")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Toggle("", isOn: $nextDutyOver16)
                    .labelsHidden()
                    .scaleEffect(0.8)
                    .padding(.trailing, 6)
            }
            .padding(.vertical, 10)
        }
    }

    @ViewBuilder
    private var clauseRows: some View {
        let ci   = clauseI
        let cii  = clauseII
        let ciii = clauseIII
        VStack(spacing: 0) {
            clauseRow(
                label: "Clause (i)",
                subtitle: "Standard FD10.1",
                value: ci,
                isBold: ci >= (cii ?? 0) && ci >= (ciii ?? 0)
            )

            Divider()

            if let ciiVal = cii {
                clauseRow(
                    label: "Clause (ii)",
                    subtitle: "12:00 + 1.5×\(formatHoursMinutes(previousDutyHours - 12.0))",
                    value: ciiVal,
                    isBold: ciiVal >= ci && ciiVal >= (ciii ?? 0)
                )
            } else {
                naRow(label: "Clause (ii)", subtitle: "Duty ≤ 12 hrs")
            }

            Divider()

            if let ciiiVal = ciii {
                clauseRow(
                    label: "Clause (iii)",
                    subtitle: "Planned > 16 hrs",
                    value: ciiiVal,
                    isBold: ciiiVal >= ci && ciiiVal >= (cii ?? 0)
                )
            } else {
                naRow(label: "Clause (iii)", subtitle: "Planned > 16 hrs")
            }
        }
    }

    private var effectiveRestRow: some View {
        HStack {
            Label("Minimum Rest", systemImage: "bed.double.fill")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.blue)
            Spacer()
            Text(formatHoursMinutes(effectiveRest))
                .font(.title3)
                .fontWeight(.bold)
                .foregroundStyle(.blue)
                .monospacedDigit()
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .background(Color.blue.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .padding(.top, 4)
    }

    // MARK: Row helpers

    private func clauseRow(label: String, subtitle: String, value: Double, isBold: Bool) -> some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.subheadline)
                    .fontWeight(isBold ? .semibold : .regular)
                    .foregroundStyle(isBold ? .primary : .secondary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(formatHoursMinutes(value))
                .font(.subheadline)
                .fontWeight(isBold ? .semibold : .regular)
                .foregroundStyle(isBold ? AppColors.accentOrange : .secondary)
                .monospacedDigit()
        }
        .padding(.vertical, 10)
    }

    private func naRow(label: String, subtitle: String) -> some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            Spacer()
            Text("N/A")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .padding(.vertical, 10)
    }
}
