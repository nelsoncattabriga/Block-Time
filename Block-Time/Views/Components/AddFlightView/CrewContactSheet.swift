//
//  CrewContactSheet.swift
//  Block-Time
//
//  Sheet for viewing and editing notes for a crew member.
//  Name is read-only; notes are editable via a scrolling TextEditor.
//

import SwiftUI

struct CrewContactSheet: View {
    let name: String
    let onDismiss: () -> Void

    @State private var notes: String = ""
    @State private var contactExists = false
    @State private var showDeleteConfirm = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Crew Member") {
                    LabeledContent("Name", value: name)
                }
                Section("Notes") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 120)
                        .font(.body)
                }
                if contactExists {
                    Section {
                        Button("Delete Note", role: .destructive) {
                            showDeleteConfirm = true
                        }
                    }
                }
            }
            .navigationTitle("Crew Contact")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { onDismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        CrewContactService.shared.upsert(name: name, notes: notes)
                        onDismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                let contact = CrewContactService.shared.fetchContact(name: name)
                notes = contact?.notes ?? ""
                contactExists = contact != nil
            }
            .confirmationDialog("Delete note for \(name)?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    CrewContactService.shared.delete(name: name)
                    onDismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This cannot be undone.")
            }
        }
    }
}

#Preview {
    CrewContactSheet(name: "John Smith", onDismiss: {})
}
