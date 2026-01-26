import SwiftUI

// MARK: - Aircraft Type Picker View
struct AircraftTypePickerView: View {
    let availableTypes: [String]
    @Binding var selectedType: String
    let onSelectionChanged: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            List {
                ForEach(availableTypes, id: \.self) { aircraftType in
                    Button {
                        onSelectionChanged(aircraftType)
                    } label: {
                        HStack {
                            Text(aircraftType)
                                .foregroundColor(.primary)
                            Spacer()
                            if aircraftType == selectedType {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.accentColor)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Select Aircraft Type")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
