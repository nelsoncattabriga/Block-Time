import SwiftUI

// MARK: - Modern Manual Entry Data Card
struct ModernManualEntryDataCard: View {
    @ObservedObject var viewModel: FlightTimeExtractorViewModel

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "person.2.fill")
                    .foregroundStyle(.purple)
                    .font(.title3)

                Text("Crew & Ops Data")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)

                Spacer()
            }

            VStack(spacing: 12) {

                // Aircraft registration field - disabled for positioning flights
                ModernAircraftRegField(viewModel: viewModel, isDisabled: viewModel.isPositioning)

                // All crew fields on separate lines - disabled for positioning flights
                VStack(spacing: 8) {
                    ModernCrewField(
                        label: "CAPTAIN",
                        value: Binding(
                            get: { viewModel.captainName },
                            set: { viewModel.updateCaptainName($0) }
                        ),
                        savedNames: viewModel.savedCaptainNames,
                        recentNames: viewModel.recentCaptainNames,
                        onNameAdded: viewModel.addCaptainName,
                        onNameRemoved: viewModel.removeCaptainName,
                        icon: "person.badge.shield.checkmark",
                        isDisabled: viewModel.isPositioning
                    )

                    ModernCrewField(
                        label: "F/O",
                        value: Binding(
                            get: { viewModel.coPilotName },
                            set: { viewModel.updateCoPilotName($0) }
                        ),
                        savedNames: viewModel.savedCoPilotNames,
                        recentNames: viewModel.recentCoPilotNames,
                        onNameAdded: viewModel.addCoPilotName,
                        onNameRemoved: viewModel.removeCoPilotName,
                        icon: "person.badge.clock",
                        isDisabled: viewModel.isPositioning
                    )

                    // Conditionally show SO fields
                    if viewModel.showSONameFields {
                        ModernCrewField(
                            label: "S/O 1",
                            value: Binding(
                                get: { viewModel.so1Name },
                                set: { viewModel.updateSO1Name($0) }
                            ),
                            savedNames: viewModel.savedSONames,
                            recentNames: viewModel.recentSONames,
                            onNameAdded: viewModel.addSOName,
                            onNameRemoved: viewModel.removeSOName,
                            icon: "person.badge.key",
                            isDisabled: viewModel.isPositioning
                        )

                        ModernCrewField(
                            label: "S/O 2",
                            value: Binding(
                                get: { viewModel.so2Name },
                                set: { viewModel.updateSO2Name($0) }
                            ),
                            savedNames: viewModel.savedSONames,
                            recentNames: viewModel.recentSONames,
                            onNameAdded: viewModel.addSOName,
                            onNameRemoved: viewModel.removeSOName,
                            icon: "person.badge.key.fill",
                            isDisabled: viewModel.isPositioning
                        )
                    }
                }
                // Toggles section
                ModernTogglesSection(viewModel: viewModel)

                // Remarks section
                ModernRemarksField(
                    label: "REMARKS",
                    value: Binding(
                        get: { viewModel.remarks },
                        set: { viewModel.remarks = $0 }
                    ),
                    icon: "note.text"
                )
            }
        }
        .padding(16)
        .background(.thinMaterial)
        .clipShape(.rect(cornerRadius: 12))
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.purple.opacity(0.2), lineWidth: 1)
        )
    }
}
