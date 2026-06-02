// Views/Screens/Settings/PersonalCrewSettingsView.swift
import SwiftUI

// MARK: - Personal & Crew Settings Detail View

struct PersonalCrewSettingsView: View {
    @ObservedObject var viewModel: FlightTimeExtractorViewModel
    @Environment(ThemeService.self) private var themeService

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                ModernDefaultCrewNamesCard(viewModel: viewModel)
                ModernOpsDataCard(viewModel: viewModel)
                ModernCrewNotesCard()
                ModernCustomFieldsCard()

                Spacer(minLength: 20)
            }
            .frame(maxWidth: 800)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
        .background(
            ZStack {
                themeService.getGradient()
                    .ignoresSafeArea()
            }
        )
        .navigationTitle("Crew & Ops Data")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Default Crew Names Card

struct ModernDefaultCrewNamesCard: View {
    @ObservedObject var viewModel: FlightTimeExtractorViewModel

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "person.2.fill")
                    .foregroundColor(.blue)
                    .font(.title3)

                Text("Crew Info")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)

                Spacer()
            }

            VStack(spacing: 12) {
                // Flight Time Position Picker
                HStack(spacing: 12) {
                    Image(systemName: "clock.badge.checkmark")
                        .foregroundColor(.blue)
                        .frame(width: 20)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Log Flight Time As")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                    }

                    Spacer()

                    Picker("", selection: Binding(
                        get: { viewModel.flightTimePosition },
                        set: { viewModel.updateFlightTimePosition($0) }
                    )) {
                        ForEach(FlightTimePosition.allCases, id: \.self) { position in
                            Text(position.rawValue).tag(position)
                        }
                    }
                    .pickerStyle(.menu)
                }
                .padding(12)
                .background(Color(.systemGray6).opacity(0.5))
                .cornerRadius(8)

                // F/O PF Time Credit Picker (only show when F/O is selected)
                if viewModel.flightTimePosition == .firstOfficer {
                    HStack(spacing: 12) {
                        Image(systemName: "airplane.circle")
                            .foregroundColor(.blue)
                            .frame(width: 20)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Log PF time as")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                        }

                        Spacer()

                        Picker("", selection: Binding(
                            get: { viewModel.foPilotFlyingCredit },
                            set: { viewModel.updateFOPilotFlyingCredit($0) }
                        )) {
                            Text("ICUS").tag(TimeCreditType.p1us)
                            Text("P2").tag(TimeCreditType.p2)
                        }
                        .pickerStyle(.menu)
                    }
                    .padding(12)
                    .background(Color(.systemGray6).opacity(0.5))
                    .cornerRadius(8)
                }

                // Default Name Field
                switch viewModel.flightTimePosition {
                case .captain:
                    ModernTextFieldRow(
                        label: "Default Captain Name",
                        text: Binding(
                            get: { viewModel.defaultCaptainName },
                            set: { viewModel.updateDefaultCaptainName($0) }
                        ),
                        placeholder: "Enter default captain name",
                        icon: "person"
                    )

                case .firstOfficer:
                    ModernTextFieldRow(
                        label: "Default F/O Name",
                        text: Binding(
                            get: { viewModel.defaultCoPilotName },
                            set: { viewModel.updateDefaultCoPilotName($0) }
                        ),
                        placeholder: "Enter default F/O name",
                        icon: "person"
                    )

                case .secondOfficer:
                    ModernTextFieldRow(
                        label: "Default S/O Name",
                        text: Binding(
                            get: { viewModel.defaultSOName },
                            set: { viewModel.updateDefaultSOName($0) }
                        ),
                        placeholder: "Enter default S/O name",
                        icon: "person"
                    )
                }

                Divider()
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)

                ModernToggleRow(
                    title: "Log S/O Names",
                    subtitle: "Show S/O Name Fields",
                    isOn: Binding(
                        get: { viewModel.showSONameFields },
                        set: { viewModel.updateShowSONameFields($0) }
                    ),
                    color: .blue,
                    icon: "person.2"
                )


                Divider()
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)

                ModernToggleRow(
                    title: "Log Instructor Time",
                    subtitle: "Log Trainer / Instructor Time",
                    isOn: Binding(
                        get: { viewModel.showSpInsSelector },
                        set: { viewModel.updateShowSpInsSelector($0) }
                    ),
                    color: .blue,
                    icon: "person.wave.2"
                )

                if viewModel.showSpInsSelector {
                    instructionEnvironmentPicker
                }
            }
        }
        .padding(16)
        .background(.thinMaterial)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.blue.opacity(0.2), lineWidth: 1)
        )
    }

    @ViewBuilder
    private var instructionEnvironmentPicker: some View {
        let caption: String = viewModel.defaultInstructionEnvironment == .simulator
            ? "Sim instruction hours counted separately from SIM time."
            : "Aircraft instruction hours counted as P1 time by default."
        VStack(alignment: .leading, spacing: 6) {
            Text("Default instruction environment")
                .font(.footnote)
                .foregroundColor(.secondary)
                .padding(.horizontal, 4)

            HStack(spacing: 0) {
                ForEach([InstructionEnvironment.aircraft, .simulator], id: \.self) { env in
                    instructionEnvButton(env: env)
                }
            }
            .padding(3)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color(.separator).opacity(0.5), lineWidth: 0.5)
            )

            Text(caption)
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal, 4)
        }
        .padding(.horizontal, 4)
        .padding(.top, 2)
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    private func instructionEnvButton(env: InstructionEnvironment) -> some View {
        let isSelected = viewModel.defaultInstructionEnvironment == env
        let icon = env == .simulator ? "desktopcomputer" : "airplane"
        let label = env == .simulator ? "Simulator" : "Aircraft"
        let activeColor: Color = env == .simulator ? .purple : .blue
        return Button {
            viewModel.updateDefaultInstructionEnvironment(env)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.caption)
                Text(label).font(.footnote.bold())
            }
            .foregroundColor(isSelected ? .white : .secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(isSelected ? activeColor : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Ops Data Card

struct ModernOpsDataCard: View {
    @ObservedObject var viewModel: FlightTimeExtractorViewModel

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "slider.horizontal.3")
                    .foregroundColor(.blue)
                    .font(.title3)

                Text("Operations")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)

                Spacer()
            }

            VStack(spacing: 12) {

                // Instrument Time when PF
                HStack {
                    Image(systemName: "gauge.with.dots.needle.67percent")
                        .foregroundColor(.blue)
                        .frame(width: 20)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Inst Time when PF")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)

                        Text("\(viewModel.pfAutoInstrumentMinutes) minutes")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Picker("", selection: Binding(
                        get: { viewModel.pfAutoInstrumentMinutes },
                        set: { viewModel.updatePFAutoInstrumentMinutes($0) }
                    )) {
                        Text("None").tag(0)
                        Text("15 min").tag(15)
                        Text("30 min").tag(30)
                        Text("45 min").tag(45)
                        Text("60 min").tag(60)
                    }
                    .pickerStyle(.menu)
                }
                .padding(12)
                .background(Color(.systemGray6).opacity(0.5))
                .cornerRadius(8)

                Divider()
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)

                // Log Approaches Toggle
                ModernToggleRow(
                    title: "Log Approaches",
                    subtitle: "ILS, GLS, AIII...",
                    isOn: Binding(
                        get: { viewModel.logApproaches },
                        set: { viewModel.updateLogApproaches($0) }
                    ),
                    color: .blue,
                    icon: "airplane.arrival"
                )

                // Default Approach Type Picker (only show when Log Approaches is enabled)
                if viewModel.logApproaches {
                    HStack {
                        Image(systemName: "location.north.line")
                            .foregroundColor(.blue)
                            .frame(width: 20)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Default Approach")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)

                            Text(viewModel.defaultApproachType ?? "Nil")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Picker("", selection: Binding(
                            get: { viewModel.defaultApproachType },
                            set: { viewModel.updateDefaultApproachType($0) }
                        )) {
                            Text("Nil").tag(nil as String?)
                            Text("ILS").tag("ILS" as String?)
                            Text("GLS").tag("GLS" as String?)
                            Text("RNP").tag("RNP" as String?)
                            Text("AIII").tag("AIII" as String?)
                            Text("NPA").tag("NPA" as String?)
                        }
                        .pickerStyle(.menu)
                    }
                    .padding(12)
                    .background(Color(.systemGray6).opacity(0.5))
                    .cornerRadius(8)
                }
            }
        }
        .padding(16)
        .background(.thinMaterial)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.blue.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Custom Fields Card

struct ModernCustomFieldsCard: View {
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "list.bullet.rectangle.portrait")
                    .foregroundColor(.blue)
                    .font(.title3)

                Text("Custom Fields")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)

                Spacer()
            }

            InlineCustomFieldsView()
        }
        .padding(16)
        .background(.thinMaterial)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.blue.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Crew Notes Card

struct ModernCrewNotesCard: View {
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "note.text")
                    .foregroundStyle(.blue)
                    .font(.title3)

                Text("Crew Notes")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)

                Spacer()
            }

            NavigationLink(destination: CrewNotesManageView()) {
                HStack(spacing: 12) {
                    Image(systemName: "person.text.rectangle")
                        .foregroundStyle(.blue)
                        .frame(width: 20)

                    Text("Edit Notes")
                        .font(.subheadline)
                        .foregroundStyle(.primary)

                    Spacer()
                }
                .padding(12)
                .background(Color(.systemGray6).opacity(0.5))
                .clipShape(.rect(cornerRadius: 8))
            }
        }
        .padding(16)
        .background(.thinMaterial)
        .clipShape(.rect(cornerRadius: 12))
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.blue.opacity(0.2), lineWidth: 1)
        )
    }
}
