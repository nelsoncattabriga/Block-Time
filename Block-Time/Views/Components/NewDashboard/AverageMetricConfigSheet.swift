import SwiftUI

// MARK: - Average Metric Config Sheet
struct AverageMetricConfigSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedAircraftType: String
    @Binding var selectedTimePeriod: String
    @Binding var selectedComparisonPeriod: String
    let availableAircraftTypes: [String]
    let timePeriodOptions: [String: String]
    let comparisonPeriodOptions: [String: String]
    let onSave: () -> Void

    private var summaryText: String {
        let aircraft = selectedAircraftType.isEmpty ? "all aircraft" : "the \(selectedAircraftType)"
        let period = timePeriodOptions[selectedTimePeriod] ?? "\(selectedTimePeriod) days"
        let timeframe = comparisonPeriodOptions[selectedComparisonPeriod] ?? "all time"

        if selectedComparisonPeriod.isEmpty {
            // All Time - no timeframe mention
            return "Show the average hours and sectors per \(period) on \(aircraft)."
        } else {
            // Last X - include "over the last..."
            return "Show the average hours and sectors per \(period) on \(aircraft) over the \(timeframe.lowercased())."
        }
    }

    var body: some View {
        NavigationView {
            Form {
                Section {
                    Picker("Aircraft", selection: $selectedAircraftType) {
                        Text("All Aircraft").tag("")
                        ForEach(availableAircraftTypes, id: \.self) { type in
                            Text(type).tag(type)
                        }
                    }
                }

                Section {
                    Picker("Average Per", selection: $selectedTimePeriod) {
                        ForEach(timePeriodOptions.keys.sorted(by: { Int($0) ?? 0 < Int($1) ?? 0 }), id: \.self) { key in
                            Text(timePeriodOptions[key] ?? key).tag(key)
                        }
                    }
                    .pickerStyle(.menu)
                }

                Section {
                    Picker("Timeframe", selection: $selectedComparisonPeriod) {
                        ForEach(comparisonPeriodOptions.keys.sorted(by: {
                            let val1 = $0.isEmpty ? Int.max : (Int($0) ?? 0)
                            let val2 = $1.isEmpty ? Int.max : (Int($1) ?? 0)
                            return val1 < val2
                        }), id: \.self) { key in
                            Text(comparisonPeriodOptions[key] ?? key).tag(key)
                        }
                    }
                    .pickerStyle(.menu)
                }

                Section {
                    Text(summaryText)
                        .font(.headline)
                        .foregroundColor(.primary)
                }
            }
            .navigationTitle("Average Stats Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        onSave()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}
