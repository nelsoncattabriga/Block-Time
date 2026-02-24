//
//  LHRestRequirementsView.swift
//  Block-Time
//
//  LH rest requirements calculator for the FRMS tab.
//  Extracted from FRMSView.swift.
//

import SwiftUI

// MARK: - Shared LH Helpers

struct DutyBand: Identifiable {
    let id: String
    let label: String
    let value: Double   // representative value that unambiguously falls in this threshold band
}

// Row data: (threshold, minRest, condition)
typealias LHRestRow = (threshold: String, minRest: String, condition: String?)

func lhRestCard(title: String, rows: [LHRestRow], footnote: String?) -> some View {
    VStack(alignment: .leading, spacing: 0) {
        Text(title)
            .font(.subheadline)
            .fontWeight(.semibold)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.secondary.opacity(0.08))

        ForEach(rows.indices, id: \.self) { i in
            let row = rows[i]
            HStack(alignment: .top, spacing: 8) {
                Text(row.threshold == "—" ? row.threshold : "\(row.threshold) hrs")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 80, alignment: .leading)

                Text(row.minRest)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .frame(width: 70, alignment: .leading)

                if let condition = row.condition {
                    Text(condition)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Spacer()
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)

            if i < rows.count - 1 {
                Divider().padding(.leading, 12)
            }
        }

        if let note = footnote, !note.isEmpty {
            Divider()
            Text(note)
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.secondary.opacity(0.04))
        }
    }
    .background(.ultraThinMaterial)
    .clipShape(RoundedRectangle(cornerRadius: 10))
    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.secondary.opacity(0.15), lineWidth: 1))
}

// MARK: - LH Rest Requirements View

struct LHRestRequirementsView: View {
    let crewComplement: CrewComplement
    let limitType: FRMSLimitType
    @Binding var expectedDutyHours: Double
    @Binding var nextDutyIsDeadhead: Bool

    private var dutyBandOptions: [DutyBand] {
        if nextDutyIsDeadhead {
            return [
                DutyBand(id: "dh_le12", label: "≤ 12 hrs", value: 10.0),
                DutyBand(id: "dh_gt12", label: "> 12 hrs", value: 14.0),
            ]
        }
        switch (crewComplement, limitType) {
        case (.twoPilot, .operational):
            return [
                DutyBand(id: "op2p_le11", label: "≤ 11 hrs",    value: 10.0),
                DutyBand(id: "op2p_1115", label: "11:15 hrs",   value: 11.25),
                DutyBand(id: "op2p_1130", label: "11:30 hrs",   value: 11.5),
                DutyBand(id: "op2p_1145", label: "11:45 hrs",   value: 11.75),
                DutyBand(id: "op2p_1200", label: "12:00 hrs",   value: 12.0),
                DutyBand(id: "op2p_gt12", label: "> 12 hrs",    value: 13.0),
            ]
        case (.twoPilot, .planning):
            return [
                DutyBand(id: "pl2p_le11", label: "≤ 11 hrs", value: 10.0),
                DutyBand(id: "pl2p_gt11", label: "> 11 hrs",  value: 12.0),
            ]
        case (.threePilot, .operational):
            return [
                DutyBand(id: "op3p_le16", label: "≤ 16 hrs", value: 14.0),
                DutyBand(id: "op3p_gt16", label: "> 16 hrs",  value: 18.0),
            ]
        case (.threePilot, .planning):
            return [
                DutyBand(id: "pl3p_le12", label: "≤ 12 hrs", value: 10.0),
                DutyBand(id: "pl3p_gt12", label: "> 12 hrs",  value: 14.0),
            ]
        case (.fourPilot, .operational):
            return [
                DutyBand(id: "op4p_le16", label: "≤ 16 hrs",         value: 14.0),
                DutyBand(id: "op4p_gt16", label: "> 16 hrs",          value: 17.0),
                DutyBand(id: "op4p_gt18", label: "> 18 hrs (FD3.4)", value: 20.0),
            ]
        case (.fourPilot, .planning):
            return [
                DutyBand(id: "pl4p_le12", label: "≤ 12 hrs", value: 10.0),
                DutyBand(id: "pl4p_gt12", label: "> 12 hrs",  value: 13.0),
                DutyBand(id: "pl4p_gt14", label: "> 14 hrs",  value: 15.0),
                DutyBand(id: "pl4p_gt16", label: "> 16 hrs",  value: 17.0),
            ]
        }
    }

    private func calculatePreDutyRestRows(dutyHours: Double) -> [LHRestRow] {
        if nextDutyIsDeadhead {
            let threshold = dutyHours <= 12 ? "≤ 12" : "> 12"
            return LH_Planning_FltDuty.deadheadPreDutyRest
                .filter { $0.dutyPeriodThreshold == threshold }
                .map { (threshold: $0.dutyPeriodThreshold, minRest: "\(Int($0.minimumRestHours)) hrs", condition: $0.requirements) }
        }

        switch (crewComplement, limitType) {
        case (.twoPilot, .operational):
            let threshold = dutyHours <= 11 ? "≤ 11" : "> 11"
            return LH_Operational_FltDuty.twoPilotPreDutyRest
                .filter { $0.dutyPeriodThreshold == threshold && $0.minimumRestHours != nil }
                .map { (threshold: $0.dutyPeriodThreshold, minRest: "\(Int($0.minimumRestHours!)) hrs", condition: $0.requirements) }

        case (.twoPilot, .planning):
            let threshold = dutyHours <= 11 ? "≤ 11" : "> 11"
            return LH_Planning_FltDuty.twoPilotPreDutyRest
                .filter { $0.dutyPeriodThreshold == threshold }
                .map { (threshold: $0.dutyPeriodThreshold, minRest: "\(Int($0.minimumRestHours)) hrs", condition: $0.requirements) }

        case (.threePilot, .operational):
            return LH_Operational_FltDuty.threePilotPreDutyRest
                .filter { $0.minimumRestHours != nil }
                .map { (threshold: "—", minRest: "\(Int($0.minimumRestHours!)) hrs", condition: $0.requirements) }

        case (.threePilot, .planning):
            let threshold = dutyHours <= 12 ? "≤ 12" : "> 12"
            return LH_Planning_FltDuty.threePilotPreDutyRest
                .filter { $0.dutyPeriodThreshold == threshold }
                .map { (threshold: $0.dutyPeriodThreshold, minRest: "\(Int($0.minimumRestHours)) hrs", condition: $0.requirements) }

        case (.fourPilot, .operational):
            if dutyHours > 18 {
                return [("—", "22+ hrs", "Relevant Sector disruption limits apply — see below")]
            }
            return LH_Operational_FltDuty.fourPilotPreDutyRest
                .filter { $0.dutyPeriodThreshold == "—" && $0.minimumRestHours != nil }
                .map { (threshold: "—", minRest: "\(Int($0.minimumRestHours!)) hrs", condition: $0.requirements) }

        case (.fourPilot, .planning):
            if dutyHours <= 14 {
                return LH_Planning_FltDuty.fourPilotPreDutyRest
                    .filter { $0.dutyPeriodThreshold == "≤ 14" }
                    .map { (threshold: $0.dutyPeriodThreshold, minRest: "\(Int($0.minimumRestHours)) hrs", condition: $0.requirements) }
            } else if dutyHours <= 16 {
                return LH_Planning_FltDuty.fourPilotPreDutyRest
                    .filter { $0.dutyPeriodThreshold == "> 14 ≤ 16" }
                    .map { (threshold: $0.dutyPeriodThreshold, minRest: "\(Int($0.minimumRestHours)) hrs", condition: $0.requirements) }
            } else {
                return LH_Planning_FltDuty.fourPilotPreDutyRest
                    .filter { $0.dutyPeriodThreshold == "> 16" }
                    .map { (threshold: $0.dutyPeriodThreshold, minRest: "\(Int($0.minimumRestHours)) hrs", condition: $0.requirements) }
            }
        }
    }

    private func calculatePostDutyRestRows(dutyHours: Double, isDeadhead: Bool) -> [LHRestRow] {
        if isDeadhead {
            let threshold = dutyHours <= 12 ? "≤ 12" : "> 12"
            return LH_Planning_FltDuty.deadheadPostDutyRest
                .filter { $0.dutyPeriodThreshold == threshold }
                .map { (threshold: $0.dutyPeriodThreshold, minRest: "\(Int($0.minimumRestHours)) hrs", condition: $0.requirements) }
        }

        switch (crewComplement, limitType) {
        case (.twoPilot, .operational):
            if dutyHours <= 11 {
                return [("≤11 hrs", "10 hrs", nil)]
            } else if dutyHours <= 12 {
                let excessMin = (dutyHours - 11.0) * 60.0
                let addHrs = Int(ceil(excessMin / 15.0))
                let total = 10 + addHrs
                return [(">11 hrs", "\(total) hrs", "10 + \(addHrs)h (duty exceeded 11h by \(Int(excessMin))m)")]
            } else {
                return [(">12 hrs", "24 hrs", nil)]
            }

        case (.twoPilot, .planning):
            let threshold = dutyHours <= 11 ? "≤ 11" : "> 11"
            return LH_Planning_FltDuty.twoPilotPostDutyRest
                .filter { $0.dutyPeriodThreshold == threshold }
                .map { (threshold: $0.dutyPeriodThreshold, minRest: "\(Int($0.minimumRestHours)) hrs", condition: $0.requirements) }

        case (.threePilot, .operational):
            if dutyHours <= 16 {
                return [("≤16 hrs", "12 hrs", nil)]
            } else {
                return [(">16 hrs", "24 hrs", nil)]
            }

        case (.fourPilot, .operational):
            if dutyHours <= 16 {
                return [("≤16 hrs", "12 hrs", nil)]
            } else if dutyHours <= 18 {
                return [(">16 hrs", "24 hrs", nil)]
            } else {
                return [(">18 hrs (FD3.4)", "Refer to Relevant Sector disruption limits", nil)]
            }

        case (.threePilot, .planning):
            let threshold = dutyHours <= 12 ? "≤ 12" : "> 12"
            return LH_Planning_FltDuty.threePilotPostDutyRest
                .filter { $0.dutyPeriodThreshold == threshold }
                .map { (threshold: $0.dutyPeriodThreshold, minRest: "\(Int($0.minimumRestHours)) hrs", condition: $0.requirements) }

        case (.fourPilot, .planning):
            if dutyHours <= 12 {
                return LH_Planning_FltDuty.fourPilotPostDutyRest
                    .filter { $0.dutyPeriodThreshold == "≤ 12" }
                    .map { (threshold: $0.dutyPeriodThreshold, minRest: "\(Int($0.minimumRestHours)) hrs", condition: $0.requirements) }
            } else if dutyHours <= 14 {
                return LH_Planning_FltDuty.fourPilotPostDutyRest
                    .filter { $0.dutyPeriodThreshold == "> 12" }
                    .map { (threshold: $0.dutyPeriodThreshold, minRest: "\(Int($0.minimumRestHours)) hrs", condition: $0.requirements) }
            } else if dutyHours <= 16 {
                return LH_Planning_FltDuty.fourPilotPostDutyRest
                    .filter { $0.dutyPeriodThreshold == "> 14" }
                    .map { (threshold: $0.dutyPeriodThreshold, minRest: "\(Int($0.minimumRestHours)) hrs", condition: $0.requirements) }
            } else {
                return LH_Planning_FltDuty.fourPilotPostDutyRest
                    .filter { $0.dutyPeriodThreshold == "> 16" }
                    .map { (threshold: $0.dutyPeriodThreshold, minRest: "\(Int($0.minimumRestHours)) hrs", condition: $0.requirements) }
            }
        }
    }

    private var lhPreDutyRestFootnote: String? {
        switch crewComplement {
        case .twoPilot:
            return limitType == .operational
                ? LH_Operational_FltDuty.twoPilotConsecutiveDutyNote.text
                : nil
        case .threePilot, .fourPilot:
            return nil
        }
    }

    private var lhPostDutyRestFootnote: String? {
        switch crewComplement {
        case .twoPilot:
            return limitType == .planning
                ? LH_Planning_FltDuty.twoPilotPostDutyDeadheadNote
                : nil
        case .threePilot:
            return limitType == .operational
                ? LH_Operational_FltDuty.augmentedPostDutyDeadheadNote
                : LH_Planning_FltDuty.threePilotPostDutyDeadheadNote
        case .fourPilot:
            return limitType == .operational
                ? LH_Operational_FltDuty.augmentedPostDutyDeadheadNote
                : LH_Planning_FltDuty.fourPilotPostDutyDeadheadNote
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Rest Requirements")
                .font(.headline)
                .fontWeight(.semibold)

            // Calculator controls
            VStack(alignment: .leading, spacing: 8) {
                Text("Expected Next Duty")
                    .font(.subheadline)
                    .foregroundStyle(.primary.opacity(0.8))

                Picker("Next Duty", selection: $nextDutyIsDeadhead) {
                    Text("Operating").tag(false)
                    Text("Deadheading").tag(true)
                }
                .pickerStyle(.segmented)

                Picker("Expected Duty", selection: $expectedDutyHours) {
                    ForEach(dutyBandOptions) { band in
                        Text(band.label).tag(band.value)
                    }
                }
                .pickerStyle(.segmented)
            }
            .padding()
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .onAppear {
                expectedDutyHours = dutyBandOptions.first?.value ?? 10.0
            }
            .onChange(of: nextDutyIsDeadhead) { _, _ in
                expectedDutyHours = dutyBandOptions.first?.value ?? 10.0
            }
            .onChange(of: crewComplement) { _, _ in
                expectedDutyHours = dutyBandOptions.first?.value ?? 10.0
            }
            .onChange(of: limitType) { _, _ in
                expectedDutyHours = dutyBandOptions.first?.value ?? 10.0
            }

            // Pre-Duty Rest
            lhRestCard(
                title: "Minimum Pre-Duty Rest",
                rows: calculatePreDutyRestRows(dutyHours: expectedDutyHours),
                footnote: nextDutyIsDeadhead ? LH_Planning_FltDuty.deadheadPreDutyRestNote : lhPreDutyRestFootnote
            )

            // Post-Duty Rest
            lhRestCard(
                title: "Minimum Post-Duty Rest",
                rows: calculatePostDutyRestRows(dutyHours: expectedDutyHours, isDeadhead: nextDutyIsDeadhead),
                footnote: nextDutyIsDeadhead ? LH_Planning_FltDuty.deadheadPostDutyRestNote : lhPostDutyRestFootnote
            )
        }
        .padding()
        .appCardStyle()
    }
}
