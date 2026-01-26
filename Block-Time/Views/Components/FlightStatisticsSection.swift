import SwiftUI
import UniformTypeIdentifiers

// MARK: - View Extension for Conditional Modifiers
extension View {
    @ViewBuilder func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }

    // Scale font size for iPad
    func iPadScaledFont(_ font: Font) -> some View {
        modifier(IPadFontScaling(font: font))
    }
}

// MARK: - iPad Font Scaling Modifier
struct IPadFontScaling: ViewModifier {
    let font: Font
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var settings = LogbookSettings.shared

    func body(content: Content) -> some View {
        if shouldScaleFont {
            // iPad OR iPhone with wide layout - use larger font
            content.font(scaledFont)
        } else {
            // iPhone with compact layout - use original font
            content.font(font)
        }
    }

    private var shouldScaleFont: Bool {
        // Scale fonts if:
        // 1. On iPad (horizontalSizeClass == .regular), OR
        // 2. On iPhone with compact view (single column = wider cards)
        horizontalSizeClass == .regular || settings.isCompactView
    }

    private var scaledFont: Font {
        // Scale fonts by approximately 1.3x for iPad
        switch font {
        case .largeTitle: return .largeTitle
        case .title: return .largeTitle
        case .title2: return .title
        case .title3: return .title2
        case .headline: return .title3
        case .subheadline: return .headline
        case .body: return .title3
        case .callout: return .subheadline
        case .caption: return .callout
        case .caption2: return .caption
        case .footnote: return .caption
        default: return font
        }
    }
}

// MARK: - Flight Statistics Section
struct FlightStatisticsSection: View {
    let statistics: FlightStatistics
    @Binding var isEditMode: Bool
    @State private var settings = LogbookSettings.shared
    @State private var draggedCard: StatCardType?
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var showTimesInHoursMinutes: Bool = UserDefaults.standard.bool(forKey: "showTimesInHoursMinutes")

    // Dynamic column count based on device and user preference
    private var gridColumns: [GridItem] {
        let isPhone = horizontalSizeClass == .compact

        // On iPhone: use user's compact view preference
        // On iPad: always use 2 columns
        if isPhone && settings.isCompactView {
            return [GridItem(.flexible(), spacing: 12)]
        } else {
            return [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ]
        }
    }

    var body: some View {
        VStack(spacing: 16) {
            // Statistics Cards - Dynamic based on user settings
            LazyVGrid(columns: gridColumns, spacing: 12) {
                ForEach(settings.selectedCards, id: \.self) { cardType in
                    EditableCardWrapper(
                        cardType: cardType,
                        isEditMode: $isEditMode,
                        onRemove: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                settings.removeCard(cardType)
                            }
                        }
                    ) {
                        cardView(for: cardType)
                    }
                    .if(isEditMode) { view in
                        view
                            .onDrag {
                                self.draggedCard = cardType
                                return NSItemProvider(object: cardType.rawValue as NSString)
                            } preview: {
                                cardView(for: cardType)
                                    .frame(width: 160, height: 110)
                                    .compositingGroup()
                                    .shadow(color: Color.black.opacity(0.3), radius: 8, x: 0, y: 4)
                            }
                            .onDrop(of: [.text], delegate: CardDropDelegate(
                                draggedCard: $draggedCard,
                                cards: $settings.selectedCards,
                                targetCard: cardType
                            ))
                    }
                }
            }
        }
        .padding(16)
        .onReceive(NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)) { _ in
            showTimesInHoursMinutes = UserDefaults.standard.bool(forKey: "showTimesInHoursMinutes")
        }
    }

    @ViewBuilder
    private func cardView(for cardType: StatCardType) -> some View {
        switch cardType {
        case .totalTime:
            StatCard(
                title: "Total Time",
                value: statistics.formattedTotalFlightTime(asHoursMinutes: showTimesInHoursMinutes),
                subtitle: "\(statistics.totalSectors) sectors",
                color: .blue,
                icon: "clock.fill"
            )

        case .picTime:
            StatCard(
                title: "PIC Time",
                value: statistics.formattedP1Time(asHoursMinutes: showTimesInHoursMinutes),
                subtitle: "In Command",
                color: .green,
                icon: "person.badge.shield.checkmark.fill"
            )

        case .p1usTime:
            StatCard(
                title: "ICUS Time",
                value: statistics.formattedP1USTime(asHoursMinutes: showTimesInHoursMinutes),
                subtitle: "Under Supervision",
                color: .orange,
                icon: "person.2.fill"
            )

        case .nightTime:
            StatCard(
                title: "Night Time",
                value: statistics.formattedNightTime(asHoursMinutes: showTimesInHoursMinutes),
                subtitle: "Night flying",
                color: .indigo,
                icon: "moon.fill"
            )

        case .simTime:
            StatCard(
                title: "SIM Time",
                value: statistics.formattedSIMTime(asHoursMinutes: showTimesInHoursMinutes),
                subtitle: "Simulator training",
                color: .cyan,
                icon: "desktopcomputer"
            )

        case .pfRatio:
            StatCard(
                title: "PF Ratio",
                value: String(format: "%.0f%%", statistics.pfPercentage),
                subtitle: "\(statistics.pfSectors) of \(statistics.totalSectors)",
                color: .green,
                icon: "chart.pie.fill"
            )

        case .recentActivity7:
            RecentActivityCard(statistics: statistics, days: 7)

        case .recentActivity28:
            RecentActivityCard(statistics: statistics, days: 28, maxHours: 100)

        case .recentActivity30:
            RecentActivityCard(statistics: statistics, days: 30, maxHours: 100)

        case .recentActivity365:
            RecentActivityCard(statistics: statistics, days: 365, maxHours: 1000)

        case .pfRecency:
            RecencyCard(statistics: statistics, recencyType: .pf)

        case .aiiiRecency:
            RecencyCard(statistics: statistics, recencyType: .aiii)

        case .takeoffRecency:
            RecencyCard(statistics: statistics, recencyType: .takeoff)
            
        case .landingRecency:
            RecencyCard(statistics: statistics, recencyType: .landing)
            
        case .aircraftTypeTime:
            AircraftTypeTimeCard(statistics: statistics, isEditMode: isEditMode)

        case .averageMetric:
            AverageMetricCard(statistics: statistics, isEditMode: isEditMode)
        }
    }
}

// MARK: - Editable Card Wrapper
struct EditableCardWrapper<Content: View>: View {
    let cardType: StatCardType
    @Binding var isEditMode: Bool
    let onRemove: () -> Void
    let content: () -> Content

    var body: some View {
        ZStack(alignment: .topTrailing) {
            content()

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
    }
}

