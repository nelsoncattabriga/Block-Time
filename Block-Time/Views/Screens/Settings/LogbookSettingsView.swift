import SwiftUI
import UniformTypeIdentifiers

// MARK: - Logbook Settings View (iOS Home Screen Style)
struct LogbookSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var settings = LogbookSettings.shared
    @State private var isEditMode = false
    @State private var showAddSheet = false
    @State private var draggedCard: StatCardType?

    private var availableCards: [StatCardType] {
        StatCardType.allCases.filter { !settings.selectedCards.contains($0) }
    }

    let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]

    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Instructions
                        if !isEditMode {
                            Text("Long press cards to rearrange")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .padding(.top)
                        }

                        // Dashboard Preview Grid
                        LazyVGrid(columns: columns, spacing: 16) {
                            ForEach(settings.selectedCards) { cardType in
                                DashboardPreviewCard(
                                    cardType: cardType,
                                    isEditMode: $isEditMode,
                                    onRemove: {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                            settings.removeCard(cardType)
                                        }
                                    }
                                )
                                .onDrag {
                                    self.draggedCard = cardType
                                    return NSItemProvider(object: cardType.rawValue as NSString)
                                }
                                .onDrop(of: [.text], delegate: CardDropDelegate(
                                    draggedCard: $draggedCard,
                                    cards: $settings.selectedCards,
                                    targetCard: cardType
                                ))
                            }

                            // Add Card Button - only show if there are cards available to add
                            if !availableCards.isEmpty {
                                Button {
                                    showAddSheet = true
                                } label: {
                                    VStack(spacing: 12) {
                                        Image(systemName: "plus.circle.fill")
                                            .font(.system(size: 40))
                                            .foregroundColor(.blue)

                                        Text("Add Card")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 120)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [5]))
                                            .foregroundColor(Color.blue.opacity(0.3))
                                    )
                                }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 20)

                        // Card count
                        Text("\(settings.selectedCards.count) cards")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Dashboard Layout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if isEditMode {
                        Button("Done") {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                isEditMode = false
                            }
                        }
                        .fontWeight(.semibold)
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showAddSheet) {
                AddCardSheet(availableCards: availableCards)
            }
        }
    }
}

// MARK: - Dashboard Preview Card
struct DashboardPreviewCard: View {
    let cardType: StatCardType
    @Binding var isEditMode: Bool
    let onRemove: () -> Void

    @State private var isPressed = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            // Card Content
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: cardType.icon)
                        .font(.headline)
                        .foregroundColor(cardType.color)

                    Spacer()
                }

                Spacer()

                Text(cardType.displayName)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                    .lineLimit(2)
            }
            .padding(12)
            .frame(maxWidth: .infinity)
            .frame(height: 120)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
                    .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(cardType.color.opacity(0.3), lineWidth: 1)
            )
            .scaleEffect(isEditMode ? 0.95 : 1.0)
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .rotationEffect(.degrees(isEditMode ? (Double.random(in: -1...1)) : 0))
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isEditMode)

            // Remove Button (X)
            if isEditMode {
                Button {
                    onRemove()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundColor(.red)
                        .background(
                            Circle()
                                .fill(Color(.systemBackground))
                                .frame(width: 20, height: 20)
                        )
                }
                .offset(x: 8, y: -8)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isEditMode)
        .onLongPressGesture(minimumDuration: 0.5) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isEditMode = true
            }

            // Haptic feedback
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
        } onPressingChanged: { pressing in
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = pressing
            }
        }
    }
}

// MARK: - Add Card Sheet
struct AddCardSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var settings = LogbookSettings.shared
    let availableCards: [StatCardType]

    let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]

    var body: some View {
        NavigationView {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(availableCards) { cardType in
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                settings.addCard(cardType)
                            }

                            // Haptic feedback
                            let generator = UIImpactFeedbackGenerator(style: .light)
                            generator.impactOccurred()

                            // Dismiss if no more cards available to add
                            if availableCards.count == 1 {
                                dismiss()
                            }
                        } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: cardType.icon)
                                        .font(.headline)
                                        .foregroundColor(cardType.color)

                                    Spacer()

                                    Image(systemName: "plus.circle.fill")
                                        .font(.title3)
                                        .foregroundColor(.green)
                                }

                                Spacer()

                                Text(cardType.displayName)
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.primary)
                                    .lineLimit(2)
                            }
                            .padding(12)
                            .frame(maxWidth: .infinity)
                            .frame(height: 120)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(.systemBackground))
                                    .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(cardType.color.opacity(0.3), lineWidth: 1)
                            )
                        }
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Add Card")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Drag and Drop Delegate
struct CardDropDelegate: DropDelegate {
    @Binding var draggedCard: StatCardType?
    @Binding var cards: [StatCardType]
    let targetCard: StatCardType

    func performDrop(info: DropInfo) -> Bool {
        draggedCard = nil
        return true
    }

    func dropEntered(info: DropInfo) {
        guard let draggedCard = draggedCard,
              draggedCard != targetCard,
              let fromIndex = cards.firstIndex(of: draggedCard),
              let toIndex = cards.firstIndex(of: targetCard) else {
            return
        }

        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            cards.move(fromOffsets: IndexSet(integer: fromIndex), toOffset: toIndex > fromIndex ? toIndex + 1 : toIndex)
            LogbookSettings.shared.selectedCards = cards
            LogbookSettings.shared.saveSettings()
        }
    }
}
