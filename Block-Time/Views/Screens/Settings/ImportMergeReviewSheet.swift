//
//  ImportMergeReviewSheet.swift
//  Block-Time
//

import SwiftUI

struct ImportMergeReviewSheet: View {
    let proposals: [MergeProposal]
    /// Called with the user-approved subset (may be empty if all rejected)
    let onConfirm: ([MergeProposal]) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var approved: Set<UUID>

    init(proposals: [MergeProposal], onConfirm: @escaping ([MergeProposal]) -> Void) {
        self.proposals = proposals
        self.onConfirm = onConfirm
        // Default: all approved
        _approved = State(initialValue: Set(proposals.map { $0.id }))
    }

    private var approvedCount: Int { approved.count }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("The import found \(proposals.count) field update\(proposals.count == 1 ? "" : "s") for existing flights.")
                            .font(.subheadline)
                        Text("Review and deselect any changes you don't want applied. Deselected rows will be left unchanged.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }

                Section(header: Text("Proposed Changes")) {
                    ForEach(proposals) { proposal in
                        MergeProposalRow(
                            proposal: proposal,
                            isApproved: approved.contains(proposal.id)
                        ) { isOn in
                            if isOn {
                                approved.insert(proposal.id)
                            } else {
                                approved.remove(proposal.id)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Review Updates")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Select All") {
                        approved = Set(proposals.map { $0.id })
                    }
                    .disabled(approved.count == proposals.count)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        let selected = proposals.filter { approved.contains($0.id) }
                        onConfirm(selected)
                        dismiss()
                    } label: {
                        Text(approvedCount > 0 ? "Apply \(approvedCount)" : "Skip Updates")
                            .fontWeight(.semibold)
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                if approvedCount > 0 {
                    Button(role: .destructive) {
                        onConfirm([])
                        dismiss()
                    } label: {
                        Text("Skip Updates")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.bordered)
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                }
            }
        }
    }
}

// MARK: - Row

private struct MergeProposalRow: View {
    let proposal: MergeProposal
    let isApproved: Bool
    let onToggle: (Bool) -> Void

    var body: some View {
        Button {
            onToggle(!isApproved)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: isApproved ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isApproved ? Color.accentColor : Color.secondary)
                    .font(.title3)

                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text(proposal.flightDate)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Text(proposal.route)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    HStack(spacing: 4) {
                        Text(proposal.fieldName + ":")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if proposal.oldValue.isEmpty {
                            Text("(empty)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .italic()
                        } else {
                            Text(proposal.oldValue)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .strikethrough(!isApproved)
                        }
                        Image(systemName: "arrow.right")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(proposal.newValue)
                            .font(.caption)
                            .foregroundStyle(isApproved ? .primary : .secondary)
                    }
                }
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
