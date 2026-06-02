// Views/Screens/Settings/CustomFieldsView.swift
import SwiftUI

// MARK: - Field Edit Mode

enum FieldEditMode {
    case add
    case edit(CustomCounterDefinition)
}

// MARK: - Inline Custom Fields (embedded in Crew & Ops card)

struct InlineCustomFieldsView: View {
    @State private var showingAddSheet = false
    @State private var editingDefinition: CustomCounterDefinition? = nil

    private var service: CustomCounterService { CustomCounterService.shared }

    // Row height: 44pt content + list row insets (top+bottom = 8pt each = 16pt) = ~52pt per row.
    // Add Field button row uses same height. Extra 2pt per row for separator lines.
    private var listHeight: CGFloat {
        CGFloat(service.definitions.count + 1) * 54
    }

    var body: some View {
        VStack(spacing: 0) {
            List {
                ForEach(service.definitions) { definition in
                    Button {
                        editingDefinition = definition
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: iconFor(definition.type))
                                .foregroundStyle(colorFor(definition.type))
                                .frame(width: 20)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(definition.label)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundStyle(.primary)
                                Text(definition.type.displayName)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(Color(.systemGray6).opacity(0.5))
                    .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
                }
                .onMove { source, destination in
                    service.move(fromOffsets: source, toOffset: destination)
                }

                Button(action: { showingAddSheet = true }) {
                    HStack(spacing: 12) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(.blue)
                            .frame(width: 20)
                        Text("Add Field")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(.blue)
                        Spacer()
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .listRowBackground(Color.blue.opacity(0.06))
                .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .scrollDisabled(true)
            .environment(\.editMode, .constant(.active))
            .frame(height: listHeight)
        }
        .sheet(isPresented: $showingAddSheet) {
            FieldEditSheet(mode: .add) { label, type, showTotal in
                service.add(label: label, type: type, showTotal: showTotal)
            }
        }
        .sheet(item: $editingDefinition) { definition in
            FieldEditSheet(mode: .edit(definition)) { label, type, showTotal in
                service.update(columnIndex: definition.columnIndex, label: label, type: type, showTotal: showTotal)
            } onDelete: {
                service.remove(columnIndex: definition.columnIndex)
            }
        }
    }

    private func iconFor(_ type: CounterType) -> String {
        switch type {
        case .time:    return "clock.fill"
        case .decimal: return "number.circle.fill"
        case .integer: return "number.square.fill"
        case .text:    return "text.alignleft"
        }
    }

    private func colorFor(_ type: CounterType) -> Color {
        switch type {
        case .time:    return .blue
        case .decimal: return .orange
        case .integer: return .teal
        case .text:    return .purple
        }
    }
}

// MARK: - Full-page Custom Fields (iPad split view, kept for future use)

struct CustomFieldsSettingsView: View {
    @Environment(ThemeService.self) private var themeService
    @State private var showingAddSheet = false
    @State private var editingDefinition: CustomCounterDefinition? = nil

    private var service: CustomCounterService { CustomCounterService.shared }

    var body: some View {
        List {
            Section {
                if service.definitions.isEmpty {
                    Text("No fields defined. Tap \"Add Field\" to create one.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(service.definitions) { definition in
                        Button {
                            editingDefinition = definition
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: iconFor(definition.type))
                                    .foregroundStyle(colorFor(definition.type))
                                    .frame(width: 20)

                                Text(definition.label)
                                    .font(.subheadline)
                                    .foregroundStyle(.primary)

                                Spacer()

                                Text(definition.type.displayName)
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(colorFor(definition.type).opacity(0.15))
                                    .foregroundStyle(colorFor(definition.type))
                                    .clipShape(RoundedRectangle(cornerRadius: 5))
                            }
                        }
                        .buttonStyle(.plain)
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                service.remove(columnIndex: definition.columnIndex)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                    .onMove(perform: service.move)
                }
            } footer: {
                Text("Fields appear in the Add/Edit flight form and as selectable Dashboard cards.")
            }

            Section {
                Button("Add Field", systemImage: "plus.circle.fill", action: showAdd)
                    .foregroundStyle(.indigo)
            }
        }
        .background(themeService.getGradient().ignoresSafeArea())
        .scrollContentBackground(.hidden)
        .navigationTitle("Custom Fields")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            EditButton()
        }
        .sheet(isPresented: $showingAddSheet) {
            FieldEditSheet(mode: .add) { label, type, showTotal in
                service.add(label: label, type: type, showTotal: showTotal)
            }
        }
        .sheet(item: $editingDefinition) { definition in
            FieldEditSheet(mode: .edit(definition)) { label, type, showTotal in
                service.update(columnIndex: definition.columnIndex, label: label, type: type, showTotal: showTotal)
            } onDelete: {
                service.remove(columnIndex: definition.columnIndex)
            }
        }
    }

    private func showAdd() {
        showingAddSheet = true
    }

    private func iconFor(_ type: CounterType) -> String {
        switch type {
        case .time:    return "clock.fill"
        case .decimal: return "number.circle.fill"
        case .integer: return "number.square.fill"
        case .text:    return "text.alignleft"
        }
    }

    private func colorFor(_ type: CounterType) -> Color {
        switch type {
        case .time:    return .blue
        case .decimal: return .orange
        case .integer: return .teal
        case .text:    return .purple
        }
    }
}

// MARK: - Field Edit Sheet

struct FieldEditSheet: View {
    let mode: FieldEditMode
    var onSave: (String, CounterType, Bool) -> Void
    var onDelete: (() -> Void)?

    @State private var label: String
    @State private var type: CounterType
    @State private var showTotal: Bool
    @State private var showingDeleteConfirmation = false
    @Environment(\.dismiss) private var dismiss
    @AppStorage("showTimesInHoursMinutes") private var showAsHHMM: Bool = false

    init(mode: FieldEditMode, onSave: @escaping (String, CounterType, Bool) -> Void, onDelete: (() -> Void)? = nil) {
        self.mode = mode
        self.onSave = onSave
        self.onDelete = onDelete
        switch mode {
        case .add:
            _label = State(initialValue: "")
            _type = State(initialValue: .integer)
            _showTotal = State(initialValue: true)
        case .edit(let definition):
            _label = State(initialValue: definition.label)
            _type = State(initialValue: definition.type)
            _showTotal = State(initialValue: definition.showTotal)
        }
    }

    private var title: String {
        switch mode {
        case .add:  return "Add Field"
        case .edit: return "Edit Field"
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // LABEL section
                        VStack(alignment: .leading, spacing: 8) {
                            Text("FIELD LABEL")
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)
                                .padding(.leading, 4)

                            VStack {
                                TextField("Label", text: $label)
                                    .font(.subheadline)
                            }
                            .padding(12)
                            .background(Color(.secondarySystemGroupedBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }

                        // TYPE section
                        VStack(alignment: .leading, spacing: 8) {
                            Text("DATA TYPE")
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)
                                .padding(.leading, 4)

                            VStack(spacing: 0) {
                                ForEach(Array(CounterType.allCases.enumerated()), id: \.element.id) { index, counterType in
                                    Button {
                                        type = counterType
                                    } label: {
                                        HStack(spacing: 14) {
                                            Image(systemName: iconFor(counterType))
                                                .font(.system(size: 20))
                                                .foregroundStyle(colorFor(counterType))
                                                .frame(width: 28)

                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(counterType.displayName)
                                                    .font(.subheadline)
                                                    .fontWeight(.medium)
                                                    .foregroundStyle(.primary)
                                                Text(subtitleFor(counterType))
                                                    .font(.footnote)
                                                    .foregroundStyle(.secondary)
                                            }

                                            Spacer()

                                            if type == counterType {
                                                Image(systemName: "checkmark")
                                                    .font(.subheadline.weight(.semibold))
                                                    .foregroundStyle(.blue)
                                            }
                                        }
                                        .padding(12)
                                        .contentShape(Rectangle())
                                        .background(
                                            type == counterType
                                                ? colorFor(counterType).opacity(0.10)
                                                : Color.clear
                                        )
                                    }
                                    .buttonStyle(.plain)

                                    if index < CounterType.allCases.count - 1 {
                                        Divider()
                                    }
                                }
                            }
                            .background(Color(.secondarySystemGroupedBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }

                        // OPTIONS section
                        if type != .text {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("OPTIONS")
                                    .font(.caption.bold())
                                    .foregroundStyle(.secondary)
                                    .padding(.leading, 4)

                                VStack {
                                    Toggle(isOn: $showTotal) {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("Show Total")
                                                .font(.subheadline)
                                            Text("When off, values aren't summed and no Dashboard card is shown.")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    .tint(.blue)
                                }
                                .padding(12)
                                .background(Color(.systemGray6).opacity(0.75))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }
                    }
                    .padding(16)
                }
            }
            .navigationTitle(title)
            .onChange(of: type) { _, newValue in
                if newValue == .text { showTotal = false }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel", action: cancel)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save", action: save)
                        .fontWeight(.semibold)
                        .disabled(label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .safeAreaInset(edge: .bottom) {
                if case .edit = mode, onDelete != nil {
                    Button(role: .destructive) {
                        showingDeleteConfirmation = true
                    } label: {
                        Text("Delete Field")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                    .padding()
                }
            }
            .confirmationDialog("Delete this field?", isPresented: $showingDeleteConfirmation, titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    onDelete?()
                    dismiss()
                }
            } message: {
                Text("This will delete the field and all its data.")
            }
        }
    }

    private func iconFor(_ type: CounterType) -> String {
        switch type {
        case .time:    return "clock.fill"
        case .decimal: return "number.circle.fill"
        case .integer: return "numbers.rectangle.fill"
        case .text:    return "text.alignleft"
        }
    }

    private func colorFor(_ type: CounterType) -> Color {
        switch type {
        case .time:    return .blue
        case .decimal: return .orange
        case .integer: return .teal
        case .text:    return .purple
        }
    }

    private func subtitleFor(_ type: CounterType) -> String {
        if type == .time {
            return showAsHHMM
                ? "Duration, Shown as 1:30"
                : "Duration, Shown as 1.5"
        }
        return type.subtitle
    }

    private func save() {
        onSave(label.trimmingCharacters(in: .whitespacesAndNewlines), type, showTotal)
        dismiss()
    }

    private func cancel() {
        dismiss()
    }
}
