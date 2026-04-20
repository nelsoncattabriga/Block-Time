//
//  MacLogbookView.swift
//  Block-Time-Mac
//
//  Spreadsheet-style logbook table using SwiftUI Table.
//

import SwiftUI

struct MacLogbookView: View {
    @StateObject private var viewModel = MacLogbookViewModel()
    @Binding var selection: Set<UUID>

    var body: some View {
        VStack(spacing: 0) {
            tableContent
            footerBar
        }
        .task { await viewModel.load() }
        .searchable(text: $viewModel.searchText, placement: .toolbar, prompt: "Search flights…")
        .toolbar { tableToolbar }
    }

    // MARK: - Table

    private var tableContent: some View {
        Group {
            if viewModel.isLoading {
                ProgressView("Loading logbook…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.displayedFlights.isEmpty {
                ContentUnavailableView(
                    viewModel.searchText.isEmpty ? "No Flights" : "No Results",
                    systemImage: "book.closed",
                    description: Text(viewModel.searchText.isEmpty
                        ? "Flights sync automatically from your iPhone."
                        : "Try a different search term.")
                )
            } else {
                MacLogbookTableView(rows: viewModel.displayedFlights, selection: $selection)
            }
        }
    }

    // MARK: - Footer

    private var footerBar: some View {
        HStack(spacing: 16) {
            Text("\(viewModel.displayedFlights.count) entries")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.secondary)

            if !selection.isEmpty {
                Text("Selected: \(selection.count)")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            let totalBlock = MacFlightRow.hhmmDisplay(viewModel.totalBlockHours)
            Text("Total Block: \(totalBlock)")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.bar)
        .overlay(alignment: .top) {
            Divider()
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var tableToolbar: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button {
                NotificationCenter.default.post(name: .macNewFlight, object: nil)
            } label: {
                Label("New Flight", systemImage: "plus")
            }
            .keyboardShortcut("n", modifiers: .command)
        }

        ToolbarItem(placement: .automatic) {
            Button {
                Task { await viewModel.reload() }
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            .keyboardShortcut("r", modifiers: .command)
        }
    }
}

