//
//  ColumnManagerPopover.swift
//  Block-Time-Mac
//
//  Popover for reordering and hiding logbook columns.
//

import SwiftUI

struct ColumnManagerPopover: View {
    @Bindable var prefs: ColumnPreferences

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            pinnedSection
            Divider()
            columnList
            Divider()
            footer
        }
        .frame(width: 260)
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text("Columns")
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
            Spacer()
            Button("Reset") { prefs.reset() }
                .buttonStyle(.plain)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.blue)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - Pinned (always visible)

    private var pinnedSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Always visible")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 12)
                .padding(.top, 6)
                .padding(.bottom, 2)

            ForEach(LogbookColumn.frozenColumns(localTime: false)) { col in
                HStack(spacing: 8) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                        .frame(width: 16)
                    Text(col.title)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
            }
        }
        .padding(.bottom, 4)
    }

    // MARK: - Scrolling columns list

    private var columnList: some View {
        List {
            ForEach(prefs.order, id: \.self) { id in
                if let col = LogbookColumn.scrollingColumns(hhmm: true, rounding: "standard", localTime: false).first(where: { $0.id == id }) {
                    ColumnRow(col: col, isHidden: prefs.hidden.contains(id)) {
                        prefs.toggleVisibility(id)
                    }
                    .listRowInsets(EdgeInsets(top: 0, leading: 8, bottom: 0, trailing: 8))
                    .listRowSeparator(.hidden)
                }
            }
            .onMove { prefs.move(fromOffsets: $0, toOffset: $1) }
        }
        .listStyle(.plain)
        .frame(height: min(CGFloat(prefs.order.count) * 28, 320))
    }

    // MARK: - Footer

    private var footer: some View {
        let visible = prefs.order.count - prefs.hidden.count
        return Text("\(visible) of \(prefs.order.count) visible")
            .font(.system(size: 11, design: .monospaced))
            .foregroundStyle(.tertiary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 7)
    }
}

// MARK: - Column Row

private struct ColumnRow: View {
    let col: LogbookColumn
    let isHidden: Bool
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
                .frame(width: 16)

            Text(col.title)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(isHidden ? .tertiary : .primary)

            Spacer()

            Toggle("", isOn: Binding(
                get: { !isHidden },
                set: { _ in onToggle() }
            ))
            .toggleStyle(.switch)
            .controlSize(.mini)
            .labelsHidden()
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}
