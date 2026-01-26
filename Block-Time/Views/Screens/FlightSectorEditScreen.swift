import SwiftUI
import CoreData

// MARK: - Flight Sector Edit Screen
// MARK: - FlightSectorEditScreen: Replacement for FlightSectorDetailView with editing capability
struct FlightSectorEditScreen: View {
    let sector: FlightSector
    let onDelete: (FlightSector) -> Void
    let onSave: (FlightSector) -> Void
    var useIATACodes: Bool = false

    @Environment(\.dismiss) private var dismiss

    @State private var date: String
    @State private var flightNumber: String
    @State private var aircraftReg: String
    @State private var aircraftType: String
    @State private var fromAirport: String
    @State private var toAirport: String
    @State private var captainName: String
    @State private var foName: String
    @State private var so1Name: String
    @State private var so2Name: String
    @State private var blockTime: String
    @State private var nightTime: String
    @State private var p1Time: String
    @State private var p1usTime: String
    @State private var instrumentTime: String
    @State private var simTime: String
    @State private var isPilotFlying: Bool
    @State private var isAIII: Bool
    @State private var remarks: String
    
    @State private var showingDeleteAlert = false
    @State private var saveErrorMessage: String?
    
    private let databaseService = FlightDatabaseService.shared
    
    init(sector: FlightSector, useIATACodes: Bool = false, onDelete: @escaping (FlightSector) -> Void, onSave: @escaping (FlightSector) -> Void) {
        self.sector = sector
        self.useIATACodes = useIATACodes
        self.onDelete = onDelete
        self.onSave = onSave

        _date = State(initialValue: sector.date)
        _flightNumber = State(initialValue: sector.flightNumber)
        _aircraftReg = State(initialValue: sector.aircraftReg)
        _aircraftType = State(initialValue: sector.aircraftType)
        // Display airport codes in user's preferred format
        _fromAirport = State(initialValue: AirportService.shared.getDisplayCode(sector.fromAirport, useIATA: useIATACodes))
        _toAirport = State(initialValue: AirportService.shared.getDisplayCode(sector.toAirport, useIATA: useIATACodes))
        _captainName = State(initialValue: sector.captainName)
        _foName = State(initialValue: sector.foName)
        _so1Name = State(initialValue: sector.so1Name ?? "")
        _so2Name = State(initialValue: sector.so2Name ?? "")
        _blockTime = State(initialValue: sector.blockTime)
        _nightTime = State(initialValue: sector.nightTime)
        _p1Time = State(initialValue: sector.p1Time)
        _p1usTime = State(initialValue: sector.p1usTime)
        _instrumentTime = State(initialValue: sector.instrumentTime)
        _simTime = State(initialValue: sector.simTime)
        _isPilotFlying = State(initialValue: sector.isPilotFlying)
        _isAIII = State(initialValue: sector.isAIII)
        _remarks = State(initialValue: sector.remarks)
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                
                // Date
                EditableCard(title: "Date") {
                    TextField("DD/MM/YYYY", text: $date)
                        .keyboardType(.numbersAndPunctuation)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                        .font(.body)
                        .padding(8)
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(6)
                }
                
                // Flight Number
                EditableCard(title: "Flight Number") {
                    TextField("Flight Number", text: $flightNumber)
                        .textInputAutocapitalization(.characters)
                        .disableAutocorrection(true)
                        .font(.body)
                        .padding(8)
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(6)
                }
                
                // Aircraft Registration
                EditableCard(title: "Aircraft Reg") {
                    TextField("Aircraft Registration", text: $aircraftReg)
                        .textInputAutocapitalization(.characters)
                        .disableAutocorrection(true)
                        .font(.body)
                        .padding(8)
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(6)
                }
                
                // Aircraft Type
                EditableCard(title: "Aircraft Type") {
                    TextField("Aircraft Type", text: $aircraftType)
                        .textInputAutocapitalization(.characters)
                        .disableAutocorrection(true)
                        .font(.body)
                        .padding(8)
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(6)
                }
                
                // From Airport
                EditableCard(title: "From Airport") {
                    TextField("From Airport", text: $fromAirport)
                        .textInputAutocapitalization(.characters)
                        .disableAutocorrection(true)
                        .font(.body)
                        .padding(8)
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(6)
                }
                
                // To Airport
                EditableCard(title: "To Airport") {
                    TextField("To Airport", text: $toAirport)
                        .textInputAutocapitalization(.characters)
                        .disableAutocorrection(true)
                        .font(.body)
                        .padding(8)
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(6)
                }
                
                // Captain Name
                EditableCard(title: "Captain") {
                    TextField("Captain Name", text: $captainName)
                        .textInputAutocapitalization(.words)
                        .disableAutocorrection(false)
                        .font(.body)
                        .padding(8)
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(6)
                }
                
                // First Officer Name
                EditableCard(title: "F/O") {
                    TextField("F/O Name", text: $foName)
                        .textInputAutocapitalization(.words)
                        .disableAutocorrection(false)
                        .font(.body)
                        .padding(8)
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(6)
                }
                
                // Second Officer 1 Name
                EditableCard(title: "SO1") {
                    TextField("Second Officer 1", text: $so1Name)
                        .textInputAutocapitalization(.words)
                        .disableAutocorrection(false)
                        .font(.body)
                        .padding(8)
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(6)
                }
                
                // Second Officer 2 Name
                EditableCard(title: "SO2") {
                    TextField("Second Officer 2", text: $so2Name)
                        .textInputAutocapitalization(.words)
                        .disableAutocorrection(false)
                        .font(.body)
                        .padding(8)
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(6)
                }
                
                // Block Time
                EditableCard(title: "Block Time (hrs)") {
                    TextField("Block Time", text: $blockTime)
                        .keyboardType(UIDevice.current.userInterfaceIdiom == .pad ? .numbersAndPunctuation : .decimalPad)
                        .font(.body)
                        .padding(8)
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(6)
                }

                // Night Time
                EditableCard(title: "Night Time (hrs)") {
                    TextField("Night Time", text: $nightTime)
                        .keyboardType(UIDevice.current.userInterfaceIdiom == .pad ? .numbersAndPunctuation : .decimalPad)
                        .font(.body)
                        .padding(8)
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(6)
                }

                // P1 Time
                EditableCard(title: "P1 Time (hrs)") {
                    TextField("P1 Time", text: $p1Time)
                        .keyboardType(UIDevice.current.userInterfaceIdiom == .pad ? .numbersAndPunctuation : .decimalPad)
                        .font(.body)
                        .padding(8)
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(6)
                }

                // P1US Time
                EditableCard(title: "P1US Time (hrs)") {
                    TextField("P1US Time", text: $p1usTime)
                        .keyboardType(UIDevice.current.userInterfaceIdiom == .pad ? .numbersAndPunctuation : .decimalPad)
                        .font(.body)
                        .padding(8)
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(6)
                }

                // Instrument Time
                EditableCard(title: "Instrument Time (hrs)") {
                    TextField("Instrument Time", text: $instrumentTime)
                        .keyboardType(UIDevice.current.userInterfaceIdiom == .pad ? .numbersAndPunctuation : .decimalPad)
                        .font(.body)
                        .padding(8)
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(6)
                }

                // SIM Time
                EditableCard(title: "SIM Time (hrs)") {
                    TextField("SIM Time", text: $simTime)
                        .keyboardType(UIDevice.current.userInterfaceIdiom == .pad ? .numbersAndPunctuation : .decimalPad)
                        .font(.body)
                        .padding(8)
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(6)
                }
                
                // Pilot Flying Toggle
                EditableCard(title: "Pilot Flying (PF)") {
                    Toggle("Is Pilot Flying?", isOn: $isPilotFlying)
                        .toggleStyle(SwitchToggleStyle(tint: .green))
                        .font(.body)
                }
                
                // AIII Toggle
                EditableCard(title: "AIII") {
                    Toggle("Is AIII?", isOn: $isAIII)
                        .toggleStyle(SwitchToggleStyle(tint: .green))
                        .font(.body)
                }
                
                // Remarks (multiline)
                EditableCard(title: "Remarks") {
                    TextEditor(text: $remarks)
                        .frame(minHeight: 80)
                        .padding(8)
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(6)
                }
                
                if let errorMessage = saveErrorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.footnote)
                        .padding(.horizontal, 16)
                }
                
                VStack(spacing: 16) {
                    /*
                    Button(action: saveFlight) {
                        Text("Save")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green)
                            .cornerRadius(12)
                    }
                    */
                    
                    Button(action: {
                        showingDeleteAlert = true
                    }) {
                        Text("Delete")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.red)
                            .cornerRadius(12)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 20)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("Edit Flight")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") {
                    saveFlight()
                }
            }
        }
        .alert("Delete Flight?", isPresented: $showingDeleteAlert) {
            Button("Delete", role: .destructive) {
                onDelete(sector)
                print("Dismiss called after delete for sector: \(sector.id) \(sector.flightNumber)")
                dismiss()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This action cannot be undone.")
        }
        .onAppear {
            print("FlightSectorEditScreen appeared for sector: \(sector.id) \(sector.flightNumber)")
        }
    }
    
    private func saveFlight() {
        saveErrorMessage = nil
        
        // Basic validation could be enhanced as needed
        guard !date.isEmpty,
              !flightNumber.isEmpty,
              !aircraftReg.isEmpty,
              !fromAirport.isEmpty,
              !toAirport.isEmpty else {
            saveErrorMessage = "Please fill in all required fields: Date, Flight Number, Aircraft Reg, From and To airports."
            return
        }
        
        let updatedSector = FlightSector(
            id: sector.id,
            date: date,
            flightNumber: flightNumber,
            aircraftReg: aircraftReg,
            aircraftType: aircraftType,
            // Normalize airport codes to ICAO before saving
            fromAirport: AirportService.shared.convertToICAO(fromAirport),
            toAirport: AirportService.shared.convertToICAO(toAirport),
            captainName: captainName,
            foName: foName,
            so1Name: so1Name.isEmpty ? nil : so1Name,
            so2Name: so2Name.isEmpty ? nil : so2Name,
            blockTime: blockTime,
            nightTime: nightTime,
            p1Time: p1Time,
            p1usTime: p1usTime,
            instrumentTime: instrumentTime,
            simTime: simTime,
            isPilotFlying: isPilotFlying,
            isAIII: isAIII,
            remarks: remarks
        )
        
        if databaseService.updateFlight(updatedSector) {
            onSave(updatedSector)
            print("Dismiss called after successful save for sector: \(sector.id) \(sector.flightNumber)")
            dismiss()
        } else {
            saveErrorMessage = "Failed to save flight. Please try again."
        }
    }
}

