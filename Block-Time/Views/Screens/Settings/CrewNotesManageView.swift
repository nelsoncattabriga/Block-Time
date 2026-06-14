// Views/Screens/Settings/CrewNotesManageView.swift
import SwiftUI
import BlockTimeKit

// MARK: - CrewNotesManageView

@MainActor
struct CrewNotesManageView: View {
    @State private var contacts: [CrewContactEntity] = []
    @State private var selectedContact: CrewContactEntity?
    @State private var showingAddSheet = false
    @State private var searchText = ""
    @Environment(ThemeService.self) private var themeService

    private var filteredContacts: [CrewContactEntity] {
        guard !searchText.isEmpty else { return contacts }
        return contacts.filter {
            ($0.name ?? "").localizedCaseInsensitiveContains(searchText) ||
            ($0.notes ?? "").localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                crewNotesCard
                Spacer(minLength: 20)
            }
            .frame(maxWidth: 800)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
        .background(
            themeService.getGradient()
                .ignoresSafeArea()
        )
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
        .sheet(item: $selectedContact) { contact in
            CrewNoteEditView(contact: contact) {
                contacts = CrewContactService.shared.fetchAll()
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

    // MARK: - Crew Notes Card

    private var crewNotesCard: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "person.text.rectangle")
                    .foregroundStyle(.blue)
                    .font(.title3)

                Text("Saved Notes")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)

                Spacer()

                if !contacts.isEmpty {
                    Text("\(contacts.count)")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(.systemGray5))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }

            if contacts.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "person.text.rectangle")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                    Text("No crew notes saved")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Text("Tap + to add your first crew note")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else if filteredContacts.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                    Text("No results for \"\(searchText)\"")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(filteredContacts.enumerated()), id: \.element) { index, contact in
                        Button {
                            selectedContact = contact
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "person.fill")
                                    .foregroundStyle(.blue)
                                    .font(.title3)
                                    .frame(width: 24)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(contact.name ?? "")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundStyle(.primary)

                                    if let notes = contact.notes, !notes.isEmpty {
                                        Text(String(notes.prefix(60)))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                            .minimumScaleFactor(0.7)
                                    }
                                }

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 10)
                            .padding(.horizontal, 12)
                            .background(Color(.systemGray6).opacity(0.5))
                        }
                        .buttonStyle(.plain)

                        if index < filteredContacts.count - 1 {
                            Divider()
                                .padding(.leading, 48)
                        }
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
        .padding(16)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.blue.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - CrewNoteAddSheet

@MainActor
struct CrewNoteAddSheet: View {
    let onSave: () -> Void

    @State private var name = ""
    @State private var notes = ""
    @Environment(\.dismiss) private var dismiss

    private let userDefaultsService = UserDefaultsService()

    private var existingNames: [String] {
        let settings = userDefaultsService.loadSettings()
        let db = FlightDatabaseService.shared
        let fromUserDefaults = Set(settings.savedCrewNames)
        let fromDB = Set(db.getAllCaptainNames())
            .union(db.getAllFONames())
            .union(db.getAllSONames())
        return Array(fromUserDefaults.union(fromDB)).sorted()
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
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // NAME section
                        VStack(alignment: .leading, spacing: 8) {
                            Text("NAME")
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)
                                .padding(.leading, 4)

                            Text(contact.name ?? "")
                                .font(.subheadline)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(12)
                                .background(Color(.secondarySystemGroupedBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }

                        // NOTES section
                        VStack(alignment: .leading, spacing: 8) {
                            Text("NOTES")
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)
                                .padding(.leading, 4)

                            TextEditor(text: $notesText)
                                .font(.subheadline)
                                .frame(minHeight: 160)
                                .padding(12)
                                .background(Color(.secondarySystemGroupedBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }

                        // Delete button
                        Button(role: .destructive) {
                            showDeleteConfirm = true
                        } label: {
                            Label("Delete Note", systemImage: "trash")
                                .frame(maxWidth: .infinity)
                                .padding(12)
                                .background(Color.red.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                    }
                    .padding(16)
                }
            }
            .navigationTitle(contact.name ?? "Edit Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        guard !deleted else { return }
                        CrewContactService.shared.upsert(name: contact.name ?? "", notes: notesText)
                        onDone()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .alert("Delete this crew note?", isPresented: $showDeleteConfirm) {
                Button("Delete", role: .destructive) {
                    deleted = true
                    CrewContactService.shared.delete(name: contact.name ?? "")
                    onDone()
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This cannot be undone.")
            }
        }
    }
}
