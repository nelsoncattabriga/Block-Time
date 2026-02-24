//
//  LH_NextDutyView.swift
//  Block-Time
//
//  A380/A330/B787 (Long Haul) next duty limits view for the FRMS tab.
//  Extracted from FRMSView.swift.
//

import SwiftUI

struct LH_NextDutyView: View {

    @Bindable var viewModel: FRMSViewModel

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @EnvironmentObject private var appViewModel: FlightTimeExtractorViewModel

    // MARK: - Owned State

    @State private var selectedCrewComplement: CrewComplement = .fourPilot
    @State private var selectedRestFacility: CrewRestFacility = .twoClass1
    @State private var selectedSignOnWindow: SignOnWindow = .w0800_1359
    @State private var expectedDutyHours: Double = 10.0
    @State private var nextDutyIsDeadhead: Bool = false

    @State private var expandCrewRestClassification = false
    @State private var expandDisruptionRest = false

    @State private var disruptionPreviousDutyHours: Double = 12.0
    @State private var disruptionTZDifference: Double = 0.0
    @State private var disruptionNextDutyOver16: Bool = false

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {

            // Crew Complement Picker
            VStack(spacing: 12) {
                Picker("Crew Complement", selection: $selectedCrewComplement) {
                    ForEach([CrewComplement.twoPilot, .threePilot, .fourPilot], id: \.self) { complement in
                        Text(complement.description).tag(complement)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: selectedCrewComplement) { _, newValue in
                    LogManager.shared.debug("LH_NextDutyView: Crew complement changed to \(newValue)")
                    switch newValue {
                    case .twoPilot:   selectedRestFacility = .class1
                    case .threePilot: selectedRestFacility = .class1
                    case .fourPilot:  selectedRestFacility = .twoClass1
                    }
                    updateMaxNextDuty()
                }
            }
            .padding()
            .appCardStyle()

            // Duty & Flight Time Limits
            if let maxDuty = viewModel.maximumNextDuty,
               let signOnLimits = maxDuty.signOnBasedLimits,
               !signOnLimits.isEmpty {

                VStack(alignment: .leading, spacing: 12) {
                    Text("Duty & Flight Time Limits")
                        .font(.headline)
                        .fontWeight(.semibold)

                    // Rest facility picker (3/4-pilot only)
                    if !restFacilityPickerOptions.isEmpty {
                        Picker("Rest Facility", selection: $selectedRestFacility) {
                            ForEach(restFacilityPickerOptions, id: \.facility) { option in
                                Text(option.label).tag(option.facility)
                            }
                        }
                        .pickerStyle(.segmented)

                        crewRestFacilityNoteView
                    }

                    // Sign-on time picker (2-pilot planning only)
                    if selectedCrewComplement == .twoPilot && viewModel.selectedLimitType == .planning {
                        Picker("Sign-On Time", selection: $selectedSignOnWindow) {
                            ForEach(SignOnWindow.allCases, id: \.self) { window in
                                Text(window.rawValue).tag(window)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    VStack(spacing: 10) {
                        let filteredLimits = filteredSignOnLimits(from: signOnLimits)
                        ForEach(filteredLimits.indices, id: \.self) { i in
                            signOnTimeRangeCard(range: filteredLimits[i], limitType: viewModel.selectedLimitType)
                        }
                    }
                }
                .padding()
                .appCardStyle()
            }

            // Rest Requirements
            LHRestRequirementsView(
                crewComplement: selectedCrewComplement,
                limitType: viewModel.selectedLimitType,
                expectedDutyHours: $expectedDutyHours,
                nextDutyIsDeadhead: $nextDutyIsDeadhead
            )

            // Disruption Rest — FD10.2.1
            DisruptionRestSection(
                isExpanded: $expandDisruptionRest,
                previousDutyHours: $disruptionPreviousDutyHours,
                tzDifference: $disruptionTZDifference,
                nextDutyOver16: $disruptionNextDutyOver16,
                crewComplement: selectedCrewComplement
            )

            // Deadheading (planning only)
            if viewModel.selectedLimitType == .planning {
                lhDeadheadingSection
            }

            // Relevant Sectors (A380 & B787 only)
            lhRelevantSectorsSection

            // Cumulative restriction warnings
            if let maxDuty = viewModel.maximumNextDuty, !maxDuty.restrictions.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Restrictions", systemImage: "exclamationmark.triangle")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.orange)

                    ForEach(maxDuty.restrictions, id: \.self) { restriction in
                        Text("• \(restriction)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(.orange.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .onAppear {
            if !viewModel.isLoading, viewModel.cumulativeTotals != nil {
                updateMaxNextDuty()
            }
        }
        .onChange(of: viewModel.isLoading) { _, isLoading in
            if !isLoading {
                updateMaxNextDuty()
            }
        }
        .onChange(of: viewModel.selectedLimitType) { _, newLimitType in
            updateMaxNextDuty()
            // Seats in Passenger Compartment is operational-only; reset when switching to planning
            if newLimitType == .planning && selectedRestFacility == .seatInPassengerCompartment {
                selectedRestFacility = .twoClass1
            }
        }
    }

    // MARK: - Rest Facility Helpers

    /// FD10.2.2 note shown below the rest facility picker (collapsed by default).
    private var crewRestFacilityNoteView: some View {
        DisclosureGroup(
            isExpanded: $expandCrewRestClassification,
            content: {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach([
                        ("Class 1", LH_Operational_FltDuty.class1Aircraft),
                        ("Class 2", LH_Operational_FltDuty.class2Aircraft),
                    ], id: \.0) { label, aircraft in
                        HStack(alignment: .top, spacing: 6) {
                            Text(label)
                                .font(.footnote)
                                .fontWeight(.semibold)
                                .foregroundStyle(.primary)
                                .frame(width: 48, alignment: .leading)
                            VStack(alignment: .leading, spacing: 2) {
                                ForEach(aircraft, id: \.aircraft) { def in
                                    if let config = def.configuration {
                                        Text("\(def.aircraft) — \(config)")
                                    } else {
                                        Text(def.aircraft)
                                    }
                                }
                            }
                            .font(.footnote)
                            .foregroundStyle(.primary)
                        }
                    }
                }
                .padding(.top, 6)
            },
            label: {
                Text("Crew Rest Classification")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
            }
        )
        .padding(10)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var restFacilityPickerOptions: [(facility: CrewRestFacility, label: String)] {
        switch selectedCrewComplement {
        case .twoPilot:
            return []
        case .threePilot:
            return [(.class1, "Class 1"), (.class2, "Class 2")]
        case .fourPilot:
            if viewModel.selectedLimitType == .operational {
                return [
                    (.twoClass1, "2× Class 1"),
                    (.oneClass1OneClass2, "Mixed"),
                    (.twoClass2, "2× Class 2"),
                    (.seatInPassengerCompartment, "PAX Seat"),
                ]
            } else {
                return [(.twoClass1, "2× Class 1"), (.oneClass1OneClass2, "Mixed"), (.twoClass2, "2× Class 2")]
            }
        }
    }

    private func filteredSignOnLimits(from limits: [SignOnTimeRange]) -> [SignOnTimeRange] {
        if selectedCrewComplement == .twoPilot {
            // Planning: filter to the selected sign-on window
            if viewModel.selectedLimitType == .planning {
                return limits.filter { $0.timeRange == selectedSignOnWindow.rawValue }
            }
            // Operational: single "All sign-on times" row, show as-is
            return limits
        }
        // For 4-pilot with 2×Class 1 selected, also show the FD3.4 extension row
        if selectedCrewComplement == .fourPilot && selectedRestFacility == .twoClass1 {
            return limits.filter { $0.restFacility == .twoClass1 || $0.restFacility == .twoClass1FD34 }
        }
        return limits.filter { $0.restFacility == selectedRestFacility }
    }

    private func signOnTimeRangeCard(range: SignOnTimeRange, limitType: FRMSLimitType) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(range.timeRange)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)

            AdaptiveLimitLayout(range: range, limitType: limitType, showTimesInHoursMinutes: appViewModel.showTimesInHoursMinutes)
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - LH Deadheading Section (Planning Only)

    private var lhDeadheadingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Deadheading Limits")
                .font(.headline)
                .fontWeight(.semibold)

            // Duty Limits — one block per duty type
            VStack(alignment: .leading, spacing: 0) {
                ForEach(LH_Planning_FltDuty.deadheadLimits.indices, id: \.self) { i in
                    let limit = LH_Planning_FltDuty.deadheadLimits[i]

                    VStack(alignment: .leading, spacing: 8) {
                        Text(limit.dutyType.rawValue)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .fixedSize(horizontal: false, vertical: true)

                        HStack(alignment: .top, spacing: 24) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Duty Limit")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(formatHoursMinutes(limit.dutyPeriodLimit) + " hrs")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .monospacedDigit()
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Sectors")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(limit.sectorLimit)
                                    .font(.subheadline)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }

                        if let req = limit.requirements {
                            Text(req)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)

                    if i < LH_Planning_FltDuty.deadheadLimits.count - 1 {
                        Divider().padding(.leading, 12)
                    }
                }

                Divider()
                Text(LH_Planning_FltDuty.deadheadPreDutyRestNote)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.secondary.opacity(0.04))
            }
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.secondary.opacity(0.15), lineWidth: 1))

            // Pre-Duty Rest
            lhRestCard(
                title: "Deadhead — Min Pre-Duty Rest",
                rows: LH_Planning_FltDuty.deadheadPreDutyRest.map {
                    (threshold: $0.dutyPeriodThreshold, minRest: "\(Int($0.minimumRestHours)) hrs", condition: $0.requirements)
                },
                footnote: nil
            )

            // Post-Duty Rest
            lhRestCard(
                title: "Deadhead — Min Post-Duty Rest",
                rows: LH_Planning_FltDuty.deadheadPostDutyRest.map {
                    (threshold: $0.dutyPeriodThreshold, minRest: "\(Int($0.minimumRestHours)) hrs", condition: $0.requirements)
                },
                footnote: LH_Planning_FltDuty.deadheadPostDutyRestNote
            )
        }
        .padding()
        .appCardStyle()
    }

    // MARK: - LH Relevant Sectors Section

    private var lhRelevantSectorsSection: some View {
        let sectors = LH_Operational_FltDuty.relevantSectors
        let postDutyRest = LH_Operational_FltDuty.relevantSectorPostDutyRest
        let inboundRest = LH_Operational_FltDuty.relevantSectorInboundAUNZRest
        let preRest = LH_Operational_FltDuty.relevantSectorPreDutyRestHours

        return VStack(alignment: .leading, spacing: 12) {
            Text("Relevant Sectors - Patterns > 18 hrs")
                .font(.headline)
                .fontWeight(.semibold)

            Text("A380 & B787 only")
                .font(.caption)
                .foregroundStyle(.secondary)

            // Named sectors list
            VStack(alignment: .leading, spacing: 0) {
                Text("Relevant Sectors")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.secondary.opacity(0.08))

                ForEach(sectors.indices, id: \.self) { i in
                    HStack(spacing: 8) {
                        Text(sectors[i])
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)

                    if i < sectors.count - 1 {
                        Divider().padding(.leading, 12)
                    }
                }
            }
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.secondary.opacity(0.15), lineWidth: 1))

            // Disruption Rest table
            VStack(alignment: .leading, spacing: 0) {
                Text("Disruption Rest Limits")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.secondary.opacity(0.08))

                // Pre-duty
                HStack(alignment: .top) {
                    Text("Prior to operating")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("\(Int(preRest)) hrs")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 7)

                Divider().padding(.leading, 12)

                Text("After operating a Relevant Sector:")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.top, 8)
                    .padding(.bottom, 4)

                ForEach(postDutyRest.indices, id: \.self) { i in
                    let row = postDutyRest[i]
                    HStack(alignment: .top, spacing: 8) {
                        Text(row.condition)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        if let hrs = row.minimumRestHours {
                            VStack(alignment: .trailing, spacing: 2) {
                                Text("\(Int(hrs)) hrs")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                if let note = row.note {
                                    Text(note)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .multilineTextAlignment(.trailing)
                                }
                            }
                        } else if let note = row.note {
                            Text(note)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .trailing)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)

                    if i < postDutyRest.count - 1 {
                        Divider().padding(.leading, 12)
                    }
                }

                Divider().padding(.leading, 12)

                Text("After Relevant Sector inbound to AU or NZ:")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.top, 8)
                    .padding(.bottom, 4)

                ForEach(inboundRest.indices, id: \.self) { i in
                    let row = inboundRest[i]
                    HStack {
                        Text(row.context.rawValue)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Text("\(Int(row.minimumRestHours)) hrs")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)

                    if i < inboundRest.count - 1 {
                        Divider().padding(.leading, 12)
                    }
                }
            }
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.secondary.opacity(0.15), lineWidth: 1))

            if viewModel.selectedLimitType == .planning {
                VStack(alignment: .leading, spacing: 4) {
                    Text("FD3.4.1")
                        .font(.caption2).fontWeight(.semibold).foregroundStyle(.secondary)
                    Text("Minimum 4 pilot crew for patterns > 18 hrs.")
                        .font(.caption).foregroundStyle(.secondary)

                    Text("FD3.4.2")
                        .font(.caption2).fontWeight(.semibold).foregroundStyle(.secondary)
                        .padding(.top, 4)
                    Text(LH_Planning_FltDuty.relevantSectorMBTTIncrease)
                        .font(.caption).foregroundStyle(.secondary)

                    Text("FD3.4.3")
                        .font(.caption2).fontWeight(.semibold).foregroundStyle(.secondary)
                        .padding(.top, 4)
                    Text(LH_Planning_FltDuty.relevantSectorHomeTransport)
                        .font(.caption).foregroundStyle(.secondary)
                }
                .padding(10)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding()
        .appCardStyle()
    }

    // MARK: - LH Table Helper

    private func lhTableHeader(columns: [String]) -> some View {
        HStack(spacing: 8) {
            ForEach(columns, id: \.self) { col in
                Text(col)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.secondary.opacity(0.08))
    }

    private func formatDecimalHours(_ hours: Double) -> String {
        if hours == Double(Int(hours)) {
            return String(Int(hours))
        }
        return String(format: "%.1f", hours)
    }

    // MARK: - Max Next Duty Calculation

    private func updateMaxNextDuty() {
        let restFacility: RestFacilityClass = selectedCrewComplement == .twoPilot ? .none : .class1
        viewModel.maximumNextDuty = viewModel.calculateMaxNextDuty(
            crewComplement: selectedCrewComplement,
            restFacility: restFacility,
            limitType: viewModel.selectedLimitType
        )
    }
}
