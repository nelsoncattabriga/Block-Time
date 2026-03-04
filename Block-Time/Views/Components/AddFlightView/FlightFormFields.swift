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
    @State private var selectedDate: Date
    @State private var showingPicker = false

    // Storage format used for reading/writing dateString.
    // Static so it is accessible in init before self is fully initialised.
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yyyy"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.locale = Locale(identifier: "en_AU")
        return formatter
    }()

    // Display format shown on the button label ("10 Mar 2026").
    private static let displayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM yyyy"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.locale = Locale(identifier: "en_AU")
        return formatter
    }()

    init(label: String, dateString: Binding<String>, icon: String,
         airportCode: String = "", timeString: String = "",
         showLocalDate: Bool = false, useIATACodes: Bool = false) {
        self.label = label
        self._dateString = dateString
        self.icon = icon
        self.airportCode = airportCode
        self.timeString = timeString
        self.showLocalDate = showLocalDate
        self.useIATACodes = useIATACodes
        self._showingPicker = State(initialValue: false)
        let initial = Self.dateFormatter.date(from: dateString.wrappedValue) ?? Date()
        self._selectedDate = State(initialValue: initial)
    }

    // Calculate local date for display
    private var localDate: Date? {
        guard showLocalDate,
              !dateString.isEmpty,
              !airportCode.isEmpty else { return nil }
        let timeToUse = !timeString.isEmpty ? timeString : "01:00"
        let localDateString = AirportService.shared.convertToLocalDate(
            utcDateString: dateString,
            utcTimeString: timeToUse,
            airportICAO: airportCode
        )
        return Self.dateFormatter.date(from: localDateString)
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption.bold())
                    .foregroundColor(.secondary)

                // Custom button so we fully control the date label text.
                // The compact DatePicker renders its own button label using an
                // internal iOS locale format we cannot override (inconsistent on iOS 26).
                Button {
                    showingPicker = true
                } label: {
                    Text(Self.displayFormatter.string(from: selectedDate))
                        .font(.subheadline.bold())
                        .foregroundColor(.primary)
                }
                .buttonStyle(.plain)
            }

            Spacer()

            // Local Date read-only display
            if let localDateValue = localDate {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Local Date")
                        .font(.caption.bold())
                        .foregroundColor(.secondary)
                    Text(Self.displayFormatter.string(from: localDateValue))
                        .font(.subheadline.bold())
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(12)
        .background(Color(.systemGray6).opacity(0.75))
        .cornerRadius(8)
        .sheet(isPresented: $showingPicker) {
            VStack(spacing: 0) {
                DatePicker("", selection: $selectedDate, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .environment(\.locale, Locale(identifier: "en_AU"))
                    .environment(\.timeZone, .gmt)
                    .padding(.horizontal)
                    .onChange(of: selectedDate) { _, newDate in
                        dateString = Self.dateFormatter.string(from: newDate)
                        showingPicker = false
                    }
            }
            .presentationDetents([.height(420)])
            .presentationDragIndicator(.visible)
        }
        .onAppear {
            if dateString.isEmpty {
                selectedDate = Date()
                dateString = Self.dateFormatter.string(from: Date())
            }
        }
        .onChange(of: dateString) { _, newDateString in
            // Keep selectedDate in sync when dateString changes externally (e.g. ACARS)
            if let date = Self.dateFormatter.date(from: newDateString) {
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
                HapticManager.shared.impact(.medium)
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
                            HapticManager.shared.impact(.medium)
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
