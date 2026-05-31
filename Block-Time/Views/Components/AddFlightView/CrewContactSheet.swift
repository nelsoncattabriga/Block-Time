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
                notes = CrewContactService.shared.fetchContact(name: name)?.notes ?? ""
            }
        }
    }
}

#Preview {
    CrewContactSheet(name: "John Smith", onDismiss: {})
}
