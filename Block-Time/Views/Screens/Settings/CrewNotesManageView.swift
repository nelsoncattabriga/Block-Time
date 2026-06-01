// Views/Screens/Settings/CrewNotesManageView.swift
import SwiftUI

// MARK: - CrewNotesManageView

@MainActor
struct CrewNotesManageView: View {
    @State private var contacts: [CrewContactEntity] = []
    @State private var selectedContact: CrewContactEntity?
    @State private var showingAddSheet = false
    @State private var searchText = ""

    private var filteredContacts: [CrewContactEntity] {
        guard !searchText.isEmpty else { return contacts }
        return contacts.filter {
            ($0.name ?? "").localizedCaseInsensitiveContains(searchText) ||
            ($0.notes ?? "").localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        Group {
            if contacts.isEmpty {
                VStack {
                    Spacer()
                    Text("No crew notes saved.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            } else if filteredContacts.isEmpty {
                VStack {
                    Spacer()
                    Text("No results for \"\(searchText)\"")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            } else {
                List(filteredContacts, id: \.self) { contact in
                    Button {
                        selectedContact = contact
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(contact.name ?? "")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundStyle(.primary)

                            Text(String((contact.notes ?? "").prefix(60)))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                    }
                    .foregroundStyle(.primary)
                }
            }
        }
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search crew notes")
        .navigationTitle("Crew Notes")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Add crew note", systemImage: "plus") {
                    showingAddSheet = true
                }
            }
        }
        .navigationDestination(isPresented: Binding(
            get: { selectedContact != nil },
            set: { if !$0 { selectedContact = nil } }
        )) {
            if let contact = selectedContact {
                CrewNoteEditView(contact: contact) {
                    contacts = CrewContactService.shared.fetchAll()
                }
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            CrewNoteAddSheet {
                contacts = CrewContactService.shared.fetchAll()
            }
        }
        .onAppear {
            contacts = CrewContactService.shared.fetchAll()
        }
    }
}

// MARK: - CrewNoteAddSheet

@MainActor
struct CrewNoteAddSheet: View {
    let onSave: () -> Void

    @State private var name = ""
    @State private var notes = ""
    @State private var showingSuggestions = false
    @Environment(\.dismiss) private var dismiss

    private let userDefaultsService = UserDefaultsService()

    private var existingNames: [String] {
        userDefaultsService.loadSettings().savedCrewNames
    }

    private var filteredSuggestions: [String] {
        guard !name.isEmpty else { return [] }
        return existingNames.filter { $0.localizedCaseInsensitiveContains(name) && $0 != name }
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("Full name", text: $name)
                        .autocorrectionDisabled()
                    if !filteredSuggestions.isEmpty {
                        ForEach(filteredSuggestions, id: \.self) { suggestion in
                            Button(suggestion) {
                                name = suggestion
            }
                            .foregroundStyle(.secondary)
                            .font(.subheadline)
                        }
                    }
                }
                Section("Notes") {
                    TextEditor(text: $notes)
                        .font(.body)
                        .frame(minHeight: 120)
                }
            }
            .navigationTitle("New Crew Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
                        CrewContactService.shared.upsert(name: trimmed, notes: notes)
                        _ = userDefaultsService.addCrewName(trimmed)
                        onSave()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(!canSave)
                }
            }
        }
    }
}

// MARK: - CrewNoteEditView

@MainActor
struct CrewNoteEditView: View {
    let contact: CrewContactEntity
    let onDone: () -> Void

    @State private var notesText: String
    @State private var showDeleteConfirm = false
    @State private var deleted = false
    @Environment(\.dismiss) private var dismiss

    init(contact: CrewContactEntity, onDone: @escaping () -> Void) {
        self.contact = contact
        self.onDone = onDone
        _notesText = State(initialValue: contact.notes ?? "")
    }

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section(header: Text("Name")) {
                    Text(contact.name ?? "")
                        .font(.subheadline)
                }

                Section(header: Text("Notes")) {
                    TextEditor(text: $notesText)
                        .font(.body)
                        .frame(minHeight: 120)
                }
            }

            Button("Delete Note") {
                showDeleteConfirm = true
            }
            .foregroundStyle(.red)
            .padding()
            .confirmationDialog("Delete this note?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
                Button("Delete Note", role: .destructive) {
                    deleted = true
                    CrewContactService.shared.delete(name: contact.name ?? "")
                    onDone()
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            }
        }
        .navigationTitle(contact.name ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear {
            guard !deleted else { return }
            CrewContactService.shared.upsert(name: contact.name ?? "", notes: notesText)
            onDone()
        }
    }
}
