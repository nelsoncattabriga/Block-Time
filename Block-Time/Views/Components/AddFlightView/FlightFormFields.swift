import SwiftUI

// MARK: - Modern Date Picker Field
struct ModernDatePickerField: View {
    let label: String
    @Binding var dateString: String
    let icon: String
    var airportCode: String = ""
    var timeString: String = ""
    var showLocalDate: Bool = false
    var useIATACodes: Bool = false
    @State private var selectedDate = Date()

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yyyy"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)  // UTC timezone
        formatter.locale = Locale(identifier: "en_AU")
        return formatter
    }()

    // Calculate local date for display
    private var localDate: Date? {
        guard showLocalDate,
              !dateString.isEmpty,
              !airportCode.isEmpty else {
            return nil
        }

        // Use the provided time, or a time near midnight to show potential date changes
        // Using 01:00 instead of 12:00 to better show date differences across timezones
        let timeToUse = !timeString.isEmpty ? timeString : "01:00"

        let localDateString = AirportService.shared.convertToLocalDate(
            utcDateString: dateString,
            utcTimeString: timeToUse,
            airportICAO: airportCode
        )

        return dateFormatter.date(from: localDateString)
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 20)

            // UTC Date
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption.bold())
                    .foregroundColor(.secondary)

                DatePicker("", selection: $selectedDate, displayedComponents: .date)
                    .labelsHidden()
                    .datePickerStyle(.compact)
                    .environment(\.locale, Locale(identifier: "en_AU"))
                    .environment(\.timeZone, .gmt)
                    .onChange(of: selectedDate) { _, newDate in
                        dateString = dateFormatter.string(from: newDate)
                    }
            }

            Spacer()

            // Local Date (side by side) - read-only display
            if let localDateValue = localDate {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Local Date")
                        .font(.caption.bold())
                        .foregroundColor(.secondary)

                    DatePicker("", selection: .constant(localDateValue), displayedComponents: .date)
                        .labelsHidden()
                        .datePickerStyle(.compact)
                        .environment(\.locale, Locale(identifier: "en_AU"))
                        .disabled(true)
                }
            }
        }
        .padding(12)
        .background(Color(.systemGray6).opacity(0.75))
        .cornerRadius(8)
        .onAppear {
            if !dateString.isEmpty, let date = dateFormatter.date(from: dateString) {
                selectedDate = date
            } else {
                // Set to today's UTC date if empty
                let utcDateFormatter = DateFormatter()
                utcDateFormatter.dateFormat = "dd/MM/yyyy"
                utcDateFormatter.timeZone = TimeZone(abbreviation: "UTC")
                let utcDate = Date()
                selectedDate = utcDate
                dateString = utcDateFormatter.string(from: utcDate)
            }
        }
        .onChange(of: dateString) { _, newDateString in
            // Sync selectedDate when dateString changes externally (e.g., from ACARS)
            if let date = dateFormatter.date(from: newDateString) {
                selectedDate = date
            }
        }
    }
}

// MARK: - Modern Aircraft Reg Field
struct ModernAircraftRegField: View {
    @ObservedObject var viewModel: FlightTimeExtractorViewModel
    @State private var showingPicker = false
    var isDisabled: Bool = false

    var body: some View {
        Button(action: {
            if !isDisabled {
                showingPicker = true
            }
        }) {
            HStack {
                Image(systemName: "airplane")
                    .foregroundColor(isDisabled ? .gray : .blue)
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 2) {
                    Text("A/C REGISTRATION")
                        .font(.caption.bold())
                        .foregroundColor(.secondary)

                    HStack(alignment: .bottom, spacing: 8) {
                        Text(viewModel.aircraftReg.isEmpty ? "Select aircraft" : viewModel.aircraftReg)
                            .font(.subheadline.bold())
                            .foregroundColor(viewModel.aircraftReg.isEmpty ? .secondary : .primary)

                        if !viewModel.aircraftReg.isEmpty && !viewModel.aircraftType.isEmpty {
                            Text(viewModel.aircraftType)
                                .font(.caption.bold())
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Spacer()

                if isDisabled {
                    Image(systemName: "lock.fill")
                        .font(.caption)
                        .foregroundColor(.gray)
                } else {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(12)
            .background(Color(.systemGray6).opacity(0.75))
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(isDisabled)
        .sheet(isPresented: $showingPicker) {
            AircraftRegPickerSheet(
                selectedReg: Binding(
                    get: { viewModel.aircraftReg },
                    set: { viewModel.updateAircraftReg($0) }
                ),
                selectedType: Binding(
                    get: { viewModel.aircraftType },
                    set: { viewModel.updateAircraftType($0) }
                ),
                showFullReg: viewModel.showFullAircraftReg,
                recentAircraftRegs: viewModel.recentAircraftRegs,
                onDismiss: { showingPicker = false }
            )
        }
    }
}

// MARK: - Modern Airport Field
struct ModernAirportField: View {
    let label: String
    @Binding var value: String
    let icon: String
    let useIATACodes: Bool
    let recentAirports: [String]
    let onAirportSelected: (String) -> Void
    @State private var showingPicker = false
    @State private var searchText = ""

    private var displayCode: String {
        guard !value.isEmpty else { return "" }
        if useIATACodes, let iataCode = AirportService.shared.convertToIATA(value) {
            return iataCode
        }
        return value
    }

    private var placeholderText: String {
        if useIATACodes {
            return "IATA"
        } else {
            return "ICAO"
        }
    }

    var body: some View {
        Button(action: { showingPicker = true }) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.blue)
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(.caption.bold())
                        .foregroundColor(.secondary)

                    Text(displayCode.isEmpty ? placeholderText : displayCode)
                        .font(.subheadline.bold())
                        .foregroundColor(displayCode.isEmpty ? .secondary.opacity(0.5) : .primary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(12)
            .background(Color(.systemGray6).opacity(0.75))
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
        .sheet(isPresented: $showingPicker) {
            AirportPickerSheet(
                title: "\(label) Airport",
                selectedAirport: Binding(
                    get: { value },
                    set: { newValue in
                        value = newValue
                        if !newValue.isEmpty {
                            onAirportSelected(newValue)
                        }
                    }
                ),
                searchText: $searchText,
                recentAirports: recentAirports,
                onDismiss: {
                    showingPicker = false
                    searchText = ""
                }
            )
        }
    }
}

// MARK: - Modern Crew Field
struct ModernCrewField: View {
    let label: String
    @Binding var value: String
    let savedNames: [String]
    var recentNames: [String] = []
    let onNameAdded: (String) -> Void
    let onNameRemoved: ((String) -> Void)?
    let icon: String
    var isDisabled: Bool = false
    @State private var showingPicker = false
    @State private var searchText = ""

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(isDisabled ? .gray : .blue)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption.bold())
                    .foregroundColor(.secondary)

                Text(value.isEmpty ? "Select crew" : value)
                    .font(.subheadline.bold())
                    .foregroundColor(value.isEmpty ? .secondary : .primary)
            }

            Spacer()

            if isDisabled {
                Image(systemName: "lock.fill")
                    .font(.caption)
                    .foregroundColor(.gray)
            } else {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(12)
        .background(Color(.systemGray6).opacity(0.75))
        .cornerRadius(8)
        .contentShape(Rectangle())
        .onTapGesture {
            if !isDisabled {
                searchText = value  // Pre-populate with current value
                showingPicker = true
            }
        }
        .sheet(isPresented: $showingPicker) {
            CrewNamePickerSheet(
                title: label,
                selectedName: $value,
                searchText: $searchText,
                savedNames: savedNames,
                recentNames: recentNames,
                onNameAdded: onNameAdded,
                onNameRemoved: onNameRemoved,
                onDismiss: {
                    showingPicker = false
                    searchText = ""  // Clear after dismissing
                }
            )
        }
    }
}

// MARK: - Modern Flight Number Field
struct ModernFlightNumberField: View {
    let label: String
    @Binding var value: String
    let placeholder: String
    let icon: String
    var isUppercase: Bool = false
    var keyboardType: UIKeyboardType = .default
    var canSearch: Bool = false
    var onSearch: (() -> Void)? = nil
    var onCommit: (() -> Void)? = nil
    var onFocus: (() -> Void)? = nil
    @FocusState private var textFieldFocused: Bool
    @State private var useAlphanumericKeyboard: Bool = false

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption.bold())
                    .foregroundColor(.secondary)

                TextField(placeholder, text: $value)
                    .font(.subheadline.bold())
                    .textInputAutocapitalization(isUppercase ? .characters : .words)
                    .autocorrectionDisabled(true)
                    .keyboardType(useAlphanumericKeyboard ? .default : keyboardType)
                    .focused($textFieldFocused)
                    .onChange(of: value) { _, newValue in
                        if isUppercase {
                            value = newValue.uppercased()
                        }
                    }
                    .onChange(of: textFieldFocused) { _, isFocused in
                        if isFocused {
                            onFocus?()
                        }
                    }
                    .submitLabel(.done)
                    .onSubmit {
                        onCommit?()
                    }
            }

            // Search button with FlightAware logo
            Button(action: {
                textFieldFocused = false  // Dismiss keyboard
                onSearch?()
                HapticManager.shared.impact(.light)
            }) {
                ZStack {
                    VStack{

                        Image(systemName: "airplane.path.dotted")
                            .font(.system(size: 25))
                            .foregroundColor(.blue)
                            .opacity(canSearch ? 1.0 : 0.4)

                        Text("Online Search")
                            .font(.caption.bold())
                            .foregroundColor(.blue)
                            .opacity(canSearch ? 1.0 : 0.4)
                    }
                }
            }
            .disabled(!canSearch)
        }
        .padding(12)
        .background(Color(.systemGray6).opacity(0.75))
        .cornerRadius(8)
        .contentShape(Rectangle())
        .onTapGesture {
            textFieldFocused = true
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                if textFieldFocused {
                    // Keyboard switcher button - only show on iPhone when number pad is the base keyboard
                    if UIDevice.current.userInterfaceIdiom == .phone && keyboardType == .numbersAndPunctuation {
                        Button(action: {
                            useAlphanumericKeyboard.toggle()
                            HapticManager.shared.impact(.light)
                            // Refocus to apply keyboard change
                            textFieldFocused = false
                            Task { @MainActor in
                                try await Task.sleep(for: .seconds(0.1))
                                textFieldFocused = true
                            }
                        }) {
                            HStack(spacing: 4) {
                                Text(useAlphanumericKeyboard ? "123" : "abc")
                            }
                            .fontWeight(.semibold)
                        }
                    }

                    Spacer()

                    Button("Done") {
                        textFieldFocused = false
                    }
                    .font(.subheadline.bold())
                }
            }
        }
    }
}

// MARK: - Modern Editable Field
struct ModernEditableField: View {
    let label: String
    @Binding var value: String
    let placeholder: String
    let icon: String
    var isUppercase: Bool = false
    var keyboardType: UIKeyboardType = .default
    var onCommit: (() -> Void)? = nil
    var onFocus: (() -> Void)? = nil
    @FocusState private var textFieldFocused: Bool

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption.bold())
                    .foregroundColor(.secondary)

                TextField(placeholder, text: $value)
                    .font(.subheadline.bold())
                    .textInputAutocapitalization(isUppercase ? .characters : .words)
                    .autocorrectionDisabled(true)
                    .keyboardType(keyboardType)
                    .focused($textFieldFocused)
                    .onChange(of: value) { _, newValue in
                        if isUppercase {
                            value = newValue.uppercased()
                        }
                    }
                    .onChange(of: textFieldFocused) { _, isFocused in
                        if isFocused {
                            onFocus?()
                        }
                    }
                    .submitLabel(.done)
                    .onSubmit {
                        onCommit?()
                    }
            }
        }
        .padding(12)
        .background(Color(.systemGray6).opacity(0.75))
        .cornerRadius(8)
        .contentShape(Rectangle())
        .onTapGesture {
            textFieldFocused = true
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                if textFieldFocused && keyboardType == .numberPad {
                    Spacer()
                    Button("Done") {
                        textFieldFocused = false
                    }
                    .font(.subheadline.bold())
                }
            }
        }
    }
}
