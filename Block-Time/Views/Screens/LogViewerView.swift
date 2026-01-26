//
//  LogViewerView.swift
//  Block-Time
//
//  UI for viewing, filtering, and sharing app logs
//

import SwiftUI
import UniformTypeIdentifiers

// Wrapper to hold shareable log file URL
struct ShareableLogFile: Identifiable {
    let id = UUID()
    let url: URL
}

struct LogViewerView: View {
    @ObservedObject private var themeService = ThemeService.shared
    @Environment(\.dismiss) private var dismiss

    @State private var logContent: String = ""
    @State private var filteredLines: [String] = []
    @State private var totalLineCount: Int = 0
    @State private var selectedFilter: LogLevel? = nil
    @State private var searchText: String = ""
    @State private var isLoading: Bool = true
    @State private var isFiltering: Bool = false
    @State private var showingClearConfirmation: Bool = false
    @State private var logFileSize: String = ""
    @State private var shareableFile: ShareableLogFile?
    @State private var searchTask: Task<Void, Never>?

    var body: some View {
        VStack(spacing: 0) {
            // Header Stats
            VStack(spacing: 8) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Log File Size")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(logFileSize)
                            .font(.headline)
                            .foregroundColor(.primary)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Total Lines")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(totalLineCount)")
                            .font(.headline)
                            .foregroundColor(.primary)
                    }
                }
                .padding()
                .background(Color(.systemGray6).opacity(0.5))
                .cornerRadius(8)
            }
            .padding(.horizontal)
            .padding(.top, 8)

            // Filter Dropdown
            HStack {
                Text("Filter:")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Menu {
                    Button {
                        HapticManager.shared.impact(.light)
                        selectedFilter = nil
                        applyFilters()
                    } label: {
                        if selectedFilter == nil {
                            Label("All Levels", systemImage: "checkmark")
                        } else {
                            Text("All Levels")
                        }
                    }

                    Divider()

                    ForEach(LogLevel.allCases, id: \.self) { level in
                        Button {
                            HapticManager.shared.impact(.light)
                            selectedFilter = level
                            applyFilters()
                        } label: {
                            if selectedFilter == level {
                                Label("\(level.emoji) \(level.displayName)", systemImage: "checkmark")
                            } else {
                                Text("\(level.emoji) \(level.displayName)")
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        if let filter = selectedFilter {
                            Text("\(filter.emoji) \(filter.displayName)")
                        } else {
                            Text("All Levels")
                        }
                        Image(systemName: "chevron.down")
                            .font(.caption)
                    }
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(selectedFilter != nil ? colorForLevel(selectedFilter!) : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }

                Spacer()
            }
            .padding(.horizontal)
            .padding(.vertical, 8)

            // Search Bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)

                TextField("Search logs...", text: $searchText)
                    .textFieldStyle(PlainTextFieldStyle())
                    .autocapitalization(.none)
                    .onChange(of: searchText) { _, newValue in
                        // Debounce search - wait 300ms after user stops typing
                        searchTask?.cancel()
                        searchTask = Task {
                            try? await Task.sleep(nanoseconds: 300_000_000) // 300ms
                            if !Task.isCancelled {
                                applyFilters()
                            }
                        }
                    }

                if !searchText.isEmpty {
                    Button(action: {
                        searchText = ""
                        searchTask?.cancel()
                        applyFilters()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(12)
            .background(Color(.systemGray6).opacity(0.5))
            .cornerRadius(8)
            .padding(.horizontal)
            .padding(.bottom, 8)

            // Log Content
            if isLoading {
                Spacer()
                ProgressView("Loading logs...")
                Spacer()
            } else if isFiltering {
                Spacer()
                ProgressView("Filtering logs...")
                Spacer()
            } else if filteredLines.isEmpty {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 60))
                        .foregroundColor(.gray)

                    Text("No logs found")
                        .font(.headline)
                        .foregroundColor(.secondary)

                    if selectedFilter != nil || !searchText.isEmpty {
                        Text("Try adjusting your filters")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
            } else {
                ScrollView {
                    ScrollViewReader { proxy in
                        LazyVStack(alignment: .leading, spacing: 0, pinnedViews: []) {
                            ForEach(Array(filteredLines.enumerated()), id: \.offset) { index, line in
                                Text(line)
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundColor(.primary)
                                    .textSelection(.enabled)
                                    .padding(.horizontal)
                                    .padding(.vertical, 1)
                                    .id(index)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical)
                        .onAppear {
                            // Scroll to bottom on appear
                            if !filteredLines.isEmpty {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    withAnimation {
                                        proxy.scrollTo(filteredLines.count - 1, anchor: .bottom)
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Action Buttons
            HStack(spacing: 10) {
                Button(action: {
                    refreshLogs()
                }) {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text("Refresh")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }

                Button(action: {
                    prepareFileForSharing()
                }) {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                        Text("Share")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }

                Button(action: {
                    showingClearConfirmation = true
                }) {
                    HStack {
                        Image(systemName: "trash")
                        Text("Clear")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
            }
            .padding()
        }
        .background(
            themeService.getGradient()
                .ignoresSafeArea()
        )
        .navigationTitle("Debug Log")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadLogs()
        }
        .sheet(item: $shareableFile) { shareableLog in
            LogViewerShareSheet(items: [shareableLog.url])
        }
        .alert("Clear All Logs?", isPresented: $showingClearConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Clear", role: .destructive) {
                clearLogs()
            }
        } message: {
            Text("This will delete the log file. This action cannot be undone.")
        }
    }

    // MARK: - Helper Functions

    private func loadLogs() {
        isLoading = true
        DispatchQueue.global(qos: .userInitiated).async {
            let content = LogManager.shared.getCurrentLogContent() ?? "No logs available"
            let size = LogManager.shared.getLogFileSize()
            let lineCount = content.components(separatedBy: "\n").count

            DispatchQueue.main.async {
                self.logContent = content
                self.logFileSize = size
                self.totalLineCount = lineCount
                self.applyFilters()
                self.isLoading = false
            }
        }
    }

    private func refreshLogs() {
        HapticManager.shared.impact(.light)
        loadLogs()
    }

    private func clearLogs() {
        HapticManager.shared.notification(.warning)
        LogManager.shared.clearAllLogs {
            self.loadLogs()
        }
    }

    private func applyFilters() {
        // Cancel any existing search task
        searchTask?.cancel()

        isFiltering = true

        // Capture current filter values
        let currentFilter = selectedFilter
        let currentSearch = searchText
        let currentContent = logContent

        // Create a new task for filtering
        searchTask = Task {
            let filtered = await Task.detached(priority: .userInitiated) {
                var lines = currentContent.components(separatedBy: "\n")

                // Apply level filter
                if let level = currentFilter {
                    lines = lines.filter { line in
                        line.contains("[\(level.rawValue)]")
                    }
                }

                // Apply search filter
                if !currentSearch.isEmpty {
                    lines = lines.filter { line in
                        line.localizedCaseInsensitiveContains(currentSearch)
                    }
                }

                return lines
            }.value

            // Only update if this task wasn't cancelled
            if !Task.isCancelled {
                await MainActor.run {
                    self.filteredLines = filtered
                    self.isFiltering = false
                }
            }
        }
    }

    private func colorForLevel(_ level: LogLevel) -> Color {
        switch level {
        case .debug: return .gray
        case .info: return .blue
        case .warning: return .orange
        case .error: return .red
        }
    }

    private func prepareFileForSharing() {
        HapticManager.shared.impact(.light)

        // Copy log file to Documents directory for sharing (same approach as backups)
        let sourceURL = LogManager.shared.getCurrentLogURL()
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let destinationURL = documentsPath.appendingPathComponent("BlockTime_Log.txt")

        do {
            // Remove existing file if it exists
            try? FileManager.default.removeItem(at: destinationURL)

            // Copy the log file
            try FileManager.default.copyItem(at: sourceURL, to: destinationURL)

            shareableFile = ShareableLogFile(url: destinationURL)
        } catch {
            LogManager.shared.error("Failed to prepare log file for sharing: \(error.localizedDescription)")
        }
    }
}

// MARK: - Share Sheet

private struct LogViewerShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    NavigationStack {
        LogViewerView()
    }
}
