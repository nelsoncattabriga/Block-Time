// Views/Screens/Settings/CrewNotesManageView.swift
import SwiftUI

// MARK: - CrewNotesManageView

@MainActor
struct CrewNotesManageView: View {
    @State private var contacts: [CrewContactEntity] = []
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if contacts.isEmpty {
                    VStack {
                        Spacer()
                        Text("No crew notes saved.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                } else {
                    List(contacts, id: \.self) { contact in
                        NavigationLink(value: contact) {
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
                    }
                }
            }
            .navigationTitle("Crew Notes")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: CrewContactEntity.self) { contact in
                CrewNoteEditView(contact: contact) {
                    contacts = CrewContactService.shared.fetchAll()
                }
            }
            .onAppear {
                contacts = CrewContactService.shared.fetchAll()
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
                    CrewContactService.shared.delete(name: contact.name ?? "")
                    onDone()
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            }
        }
        .navigationTitle(contact.name ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Cancel") {
                    dismiss()
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save") {
                    CrewContactService.shared.upsert(name: contact.name ?? "", notes: notesText)
                    onDone()
                    dismiss()
                }
            }
        }
    }
}
