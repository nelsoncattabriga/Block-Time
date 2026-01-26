//
//  SimpleFieldComponents.swift
//  Block-Time
//
//  Created by Nelson on 3/9/2025.
//

import SwiftUI

// MARK: - Flight Detail Field (Read-only)
struct FlightDetailField: View {
    let label: String
    @Binding var text: String
    let placeholder: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.primary)
                .frame(width: 80, alignment: .leading)
            TextField(placeholder, text: $text)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .disabled(true)
        }
    }
}

// MARK: - Manual Entry Field
struct ManualEntryField: View {
    let label: String
    @Binding var text: String
    let placeholder: String
    var isUppercase: Bool = false
    
    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.primary)
                .frame(width: 80, alignment: .leading)
            TextField(placeholder, text: $text)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .textCase(isUppercase ? .uppercase : nil)
                .onChange(of: text) { _, newValue in
                    if isUppercase {
                        text = newValue.uppercased()
                    }
                }
        }
    }
}

// MARK: - Date Picker Field
struct DatePickerField: View {
    let label: String
    @Binding var dateString: String
    @State private var selectedDate = Date()
    @State private var showingDatePicker = false
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yyyy"
        return formatter
    }()
    
    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.primary)
                .frame(width: 80, alignment: .leading)
            
            Button(action: {
                showingDatePicker = true
            }) {
                HStack {
                    Text(dateString.isEmpty ? "" : dateString)
                        .foregroundColor(dateString.isEmpty ? .secondary : .primary)
                    Spacer()
                    Image(systemName: "calendar")
                        .foregroundColor(.blue)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(Color(.systemGray6).opacity(0.75))
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color(.systemGray4), lineWidth: 1)
                )
            }
            .buttonStyle(PlainButtonStyle())
        }
        .sheet(isPresented: $showingDatePicker) {
            DatePickerSheet(
                selectedDate: $selectedDate,
                dateString: $dateString,
                dateFormatter: dateFormatter,
                onDismiss: {
                    showingDatePicker = false
                }
            )
        }
        .onAppear {
            if !dateString.isEmpty, let date = dateFormatter.date(from: dateString) {
                selectedDate = date
            }
        }
        .onChange(of: dateString) { _, newValue in
            if !newValue.isEmpty, let date = dateFormatter.date(from: newValue) {
                selectedDate = date
            }
        }
    }
}

// MARK: - Date Picker Sheet
private struct DatePickerSheet: View {
    @Binding var selectedDate: Date
    @Binding var dateString: String
    let dateFormatter: DateFormatter
    let onDismiss: () -> Void
    
    var body: some View {
        NavigationView {
            DatePicker("Select Date", selection: $selectedDate, displayedComponents: .date)
                .datePickerStyle(WheelDatePickerStyle())
                .labelsHidden()
                .navigationTitle("Flight Date")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Cancel") {
                            onDismiss()
                        }
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            dateString = dateFormatter.string(from: selectedDate)
                            onDismiss()
                        }
                    }
                }
        }
        .presentationDetents([.medium])
    }
}
