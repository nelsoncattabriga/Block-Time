import SwiftUI

// MARK: - Custom Counter Input Field

struct CustomCountField: View {
    let label: String
    @Binding var count: Int
    var keyboardToolbar: KeyboardToolbarState? = nil

    @State private var text: String = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "person.2.badge.plus")
                    .foregroundColor(.blue)
                    .frame(width: 20)
                Text(label.uppercased())
                    .font(.caption.bold())
                    .foregroundColor(.secondary)
            }

            TextField("0", text: $text)
                .keyboardType(.numberPad)
                .font(.subheadline)
                .focused($isFocused)
                .onChange(of: text) { _, newValue in
                    let filtered = newValue.filter { $0.isNumber }
                    if filtered != newValue {
                        text = filtered
                    }
                    if let parsed = Int(filtered), parsed >= 0 {
                        count = min(parsed, 9999)
                        if parsed > 9999 { text = "9999" }
                    } else if filtered.isEmpty {
                        count = 0
                    }
                }
                .onChange(of: isFocused) { _, focused in
                    if focused {
                        keyboardToolbar?.fieldDidFocus(clear: {
                            text = ""
                            count = 0
                        })
                    }
                }
                .onAppear {
                    text = count > 0 ? "\(count)" : ""
                }
        }
        .padding(12)
        .background(Color(.systemGray6).opacity(0.75))
        .cornerRadius(8)
    }
}

// MARK: - Modern Manual Entry Data Card
struct ModernManualEntryDataCard: View {
    @ObservedObject var viewModel: FlightTimeExtractorViewModel
    var keyboardToolbar: KeyboardToolbarState? = nil

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "person.2.fill")
                    .foregroundColor(.purple)
                    .font(.title3)

                Text("Crew & Ops Data")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)

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
                        icon: "person",
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
                        icon: "person",
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
                            icon: "person",
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
                            icon: "person",
                            isDisabled: viewModel.isPositioning
                        )
                    }
                }
                // Toggles section
                ModernTogglesSection(viewModel: viewModel, keyboardToolbar: keyboardToolbar)

                // Custom counter field (e.g. PAX)
                if viewModel.logCustomCount && !viewModel.isPositioning {
                    CustomCountField(
                        label: viewModel.customCountLabel,
                        count: Binding(
                            get: { viewModel.customCount },
                            set: { viewModel.customCount = $0 }
                        ),
                        keyboardToolbar: keyboardToolbar
                    )
                }
                
                // Remarks section
                ModernRemarksField(
                    label: "REMARKS",
                    value: Binding(
                        get: { viewModel.remarks },
                        set: { viewModel.remarks = $0 }
                    ),
                    icon: "note.text",
                    keyboardToolbar: keyboardToolbar
                )
            }
        }
        .padding(16)
        .background(.thinMaterial)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.purple.opacity(0.2), lineWidth: 1)
        )
    }
}
