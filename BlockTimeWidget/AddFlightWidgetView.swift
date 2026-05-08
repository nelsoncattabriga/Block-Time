//
//  AddFlightWidgetView.swift
//  BlockTimeWidget
//
//  Add Flight widget — small and medium sizes.
//  Small:  single tap target → opens AddFlightView.
//  Medium: two tap targets — Add Flight and Capture ACARS (supported fleets only).
//          When fleet does not support capture, shows full-width Add Flight.
//

import WidgetKit
import SwiftUI

// MARK: - Design tokens (mirrors NextFlightWidgetView.swift WT)

private enum WT {
    // Orange accent matching AppColors.accentOrange
    static let orange       = Color(red: 1.0, green: 0.62, blue: 0.04).opacity(0.85)
    // Fixed blue — non-adaptive, same value light and dark
    static let blue         = Color(red: 0.20, green: 0.45, blue: 0.90)

    // Backgrounds
    static let darkBG       = Color(red: 0.11, green: 0.11, blue: 0.12)  // #1C1C1E
    static let lightBGSolid = Color(red: 0.98, green: 0.96, blue: 0.93)

    // Text
    static let primaryDark  = Color(white: 0.75)
    static let primaryLight = Color(red: 0.1, green: 0.1, blue: 0.12)
    static let secondary    = Color(white: 0.55)

    // Gradient — mirrors defaultTheme in ThemeService (blue→orange, topLeading→bottomTrailing)
    static func gradient(dark: Bool) -> LinearGradient {
        if dark {
            return LinearGradient(
                colors: [darkBG, blue.opacity(0.25), Color.orange.opacity(0.18)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        } else {
            return LinearGradient(
                colors: [blue.opacity(0.18), Color(red: 0.98, green: 0.96, blue: 0.93), Color.orange.opacity(0.15)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        }
    }

    @ViewBuilder
    static func background(dark: Bool) -> some View {
        gradient(dark: dark).ignoresSafeArea()
    }
}

// MARK: - Fleet support

private let captureSupportedFleets: Set<String> = ["B737", "A330", "B787", "A320", "A380"]

// MARK: - Timeline entry + provider

struct AddFlightEntry: TimelineEntry {
    let date: Date
    let captureSupported: Bool
}

struct AddFlightProvider: TimelineProvider {
    func placeholder(in context: Context) -> AddFlightEntry {
        AddFlightEntry(date: Date(), captureSupported: true)
    }

    func getSnapshot(in context: Context, completion: @escaping (AddFlightEntry) -> Void) {
        let fleetID = UserDefaults(suiteName: "group.com.thezoolab.blocktime")?.string(forKey: "selectedFleetID") ?? "B737"
        let supported = captureSupportedFleets.contains(fleetID)
        completion(AddFlightEntry(date: Date(), captureSupported: supported))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<AddFlightEntry>) -> Void) {
        getSnapshot(in: context) { entry in
            completion(Timeline(entries: [entry], policy: .never))
        }
    }
}

// MARK: - Widget

struct AddFlightWidget: Widget {
    let kind = "AddFlightWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: AddFlightProvider()) { entry in
            AddFlightWidgetView(entry: entry)
                .containerBackground(for: .widget) { Color.clear }
        }
        .configurationDisplayName("Add Flight")
        .description("Quickly log a new sector.")
        .supportedFamilies([.systemSmall, .systemMedium])
        .contentMarginsDisabled()
    }
}

// MARK: - Root view

struct AddFlightWidgetView: View {
    @Environment(\.widgetFamily) private var widgetFamily
    @Environment(\.colorScheme)  private var systemScheme

    let entry: AddFlightEntry

    private var isDark: Bool { systemScheme == .dark }
    private var primary: Color { isDark ? WT.primaryDark : WT.primaryLight }

    var body: some View {
        ZStack {
            WT.background(dark: isDark)

            switch widgetFamily {
            case .systemSmall:
                SmallAddFlightView(isDark: isDark, primary: primary)
            case .systemMedium:
                MediumAddFlightView(isDark: isDark, primary: primary, captureSupported: entry.captureSupported)
            default:
                SmallAddFlightView(isDark: isDark, primary: primary)
            }
        }
    }
}

// MARK: - Small view

private struct SmallAddFlightView: View {
    let isDark: Bool
    let primary: Color

    var body: some View {
        Link(destination: URL(string: "blocktime://add-flight")!) {
            VStack(spacing: 8) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 36, weight: .semibold))
                    .foregroundStyle(WT.orange)

                Text("Add Flight")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(primary)

                Rectangle()
                    .fill(WT.orange.opacity(0.25))
                    .frame(height: 1)
                    .padding(.horizontal, 20)

                Text("BLOCK-TIME")
                    .font(.system(size: 9, weight: .semibold))
                    .kerning(0.8)
                    .foregroundStyle(WT.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(14)
        }
    }
}

// MARK: - Medium view

private struct MediumAddFlightView: View {
    let isDark: Bool
    let primary: Color
    let captureSupported: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 4) {
                Image(systemName: "airplane.departure")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(WT.orange)
                Text("BLOCK-TIME")
                    .font(.system(size: 10, weight: .semibold))
                    .kerning(0.8)
                    .foregroundStyle(WT.secondary)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)

            Spacer(minLength: 6)

            if captureSupported {
                HStack(spacing: 0) {
                    // Left: Add Flight
                    Link(destination: URL(string: "blocktime://add-flight")!) {
                        TileView(
                            icon: "plus.circle.fill",
                            label: "Add Flight",
                            isDark: isDark,
                            primary: primary
                        )
                    }

                    // Divider
                    Rectangle()
                        .fill(WT.orange.opacity(0.2))
                        .frame(width: 1)
                        .padding(.vertical, 16)

                    // Right: Capture ACARS
                    Link(destination: URL(string: "blocktime://add-flight?capture=true")!) {
                        TileView(
                            icon: "camera.fill",
                            label: "Capture ACARS",
                            isDark: isDark,
                            primary: primary
                        )
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // Full-width Add Flight when capture not supported
                Link(destination: URL(string: "blocktime://add-flight")!) {
                    HStack(spacing: 12) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 34, weight: .semibold))
                            .foregroundStyle(WT.orange)
                        Text("Add Flight")
                            .font(.system(size: 20, weight: .semibold, design: .rounded))
                            .foregroundStyle(primary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }

            Spacer(minLength: 10)
        }
    }
}

// MARK: - Tile (medium, two-up)

private struct TileView: View {
    let icon: String
    let label: String
    let isDark: Bool
    let primary: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(WT.orange)
            Text(label)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(primary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 8)
    }
}

// MARK: - Previews

#Preview("Small — Add Flight", as: .systemSmall) {
    AddFlightWidget()
} timeline: {
    AddFlightEntry(date: Date(), captureSupported: true)
}

#Preview("Medium — Capture Supported", as: .systemMedium) {
    AddFlightWidget()
} timeline: {
    AddFlightEntry(date: Date(), captureSupported: true)
}

#Preview("Medium — Capture Not Supported", as: .systemMedium) {
    AddFlightWidget()
} timeline: {
    AddFlightEntry(date: Date(), captureSupported: false)
}
