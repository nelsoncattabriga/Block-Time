//
//  NextFlightWidgetView.swift
//  BlockTimeWidget
//
//  Branded Block-Time widget — Sunrise theme, orange accent, light + dark mode.
//  Small:  Route · flight number · countdown
//  Medium: Route · STD/STA times (local + UTC) · countdown
//

import WidgetKit
import SwiftUI

// MARK: - Design tokens

private enum WT {
    // Orange accent matching AppColors.accentOrange
    static let orange      = Color(red: 1.0, green: 0.62, blue: 0.04)   // ~orange.opacity(0.85)
    static let orangeDim   = Color(red: 1.0, green: 0.62, blue: 0.04).opacity(0.18)

    // Backgrounds
    static let darkBG      = Color(red: 0.11, green: 0.11, blue: 0.12)  // #1C1C1E
    static let lightBG     = Color(white: 0.97)

    // Text
    static let primaryDark = Color.white
    static let primaryLight = Color(red: 0.1, green: 0.1, blue: 0.12)
    static let secondary   = Color(white: 0.55)
}

// MARK: - Helpers

private struct TimeFormatHelper {

    static let utcCal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(secondsFromGMT: 0)!
        return c
    }()


    /// Format a UTC Date as "HH:MM" in device local time
    static func localTime(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        f.timeZone = TimeZone.current
        return f.string(from: date)
    }

    /// Format a UTC Date as "HH:mm" in UTC
    static func utcTime(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        f.timeZone = TimeZone(secondsFromGMT: 0)
        return f.string(from: date)
    }

    /// Display airport code — ICAO stored; convert to IATA if useIATACodes.
    /// Falls back to stored code if conversion not available.
    static func displayCode(_ icao: String, useIATA: Bool) -> String {
        guard useIATA else { return icao }
        // Basic ICAO→IATA map for common airports.
        // The widget runs out-of-process so it can't call AirportService.
        // The full map is embedded in AirportData.swift (generated file added to widget target).
        return WidgetAirportCodes.iataFor(icao: icao) ?? icao
    }
}

// MARK: - Root entry point

struct NextFlightWidgetView: View {
    @Environment(\.widgetFamily) var family
    @Environment(\.colorScheme)  var colorScheme
    let entry: NextFlightTimelineEntry

    var body: some View {
        switch family {
        case .systemSmall:  SmallView(entry: entry, scheme: colorScheme)
        case .systemMedium: MediumView(entry: entry, scheme: colorScheme)
        default:            SmallView(entry: entry, scheme: colorScheme)
        }
    }
}

// MARK: - Small Widget

private struct SmallView: View {
    let entry: NextFlightTimelineEntry
    let scheme: ColorScheme

    private var isDark: Bool { scheme == .dark }
    private var bg: Color    { isDark ? WT.darkBG : WT.lightBG }
    private var primary: Color { isDark ? WT.primaryDark : WT.primaryLight }

    var body: some View {
        ZStack {
            bg.ignoresSafeArea()

            if let flight = entry.flight {
                VStack(alignment: .center, spacing: 0) {

                    // Header label
                    HStack(spacing: 4) {
                        Image(systemName: "airplane.departure")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(WT.orange)
                        Text("NEXT FLIGHT")
                            .font(.system(size: 9, weight: .semibold))
                            .kerning(0.8)
                            .foregroundStyle(WT.secondary)
                    }

                    Spacer(minLength: 4)

                    // Flight number
                    Text(flight.flightNumber.isEmpty ? "—" : flight.flightNumber)
                        .font(.system(size: 16, weight: .semibold, design: .monospaced))
                        .foregroundStyle(WT.secondary)

                    Spacer(minLength: 2)

                    // Route
                    HStack(spacing: 4) {
                        Text(TimeFormatHelper.displayCode(flight.fromAirport, useIATA: flight.useIATACodes))
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundStyle(primary)
                        Image(systemName: "arrow.right")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(WT.orange)
                        Text(TimeFormatHelper.displayCode(flight.toAirport, useIATA: flight.useIATACodes))
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundStyle(primary)
                    }

                    // STD
                    if let dep = flight.departureDatetime {
                        Text("STD: \(TimeFormatHelper.utcTime(dep))Z / \(TimeFormatHelper.localTime(dep))")
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundStyle(WT.secondary)
                            .minimumScaleFactor(0.7)
                            .lineLimit(1)
                            .padding(.top, 1)
                    }

                    Spacer(minLength: 8)

                    // Divider
                    Rectangle()
                        .fill(WT.orange.opacity(0.25))
                        .frame(height: 1)

                    Spacer(minLength: 6)

                    // Countdown
                    CountdownView(label: entry.countdownLabel, large: true)
                }
                .padding(14)

            } else {
                NoFlightView(isDark: isDark)
            }
        }
    }
}

// MARK: - Medium Widget

private struct MediumView: View {
    let entry: NextFlightTimelineEntry
    let scheme: ColorScheme

    private var isDark: Bool   { scheme == .dark }
    private var bg: Color      { isDark ? WT.darkBG : WT.lightBG }
    private var primary: Color { isDark ? WT.primaryDark : WT.primaryLight }

    var body: some View {
        ZStack {
            bg.ignoresSafeArea()

            if let flight = entry.flight {
                VStack(spacing: 0) {

                    // ── Top section: route + spine ──────────────────────
                    HStack(alignment: .center, spacing: 0) {

                        // Origin
                        VStack(alignment: .leading, spacing: 3) {
                            Text(TimeFormatHelper.displayCode(flight.fromAirport, useIATA: flight.useIATACodes))
                                .font(.system(size: 30, weight: .bold, design: .rounded))
                                .foregroundStyle(primary)
                            Text("STD \(flight.departureDatetime.map { TimeFormatHelper.localTime($0) } ?? "–:––")")
                                .font(.system(size: 12, weight: .medium, design: .monospaced))
                                .foregroundStyle(WT.secondary)
                            Text(flight.departureDatetime.map { TimeFormatHelper.utcTime($0) + "Z" } ?? "–:––")
                                .font(.system(size: 12, weight: .medium, design: .monospaced))
                                .foregroundStyle(WT.secondary.opacity(0.7))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        // Centre spine: dashes + arrow + flight number
                        VStack(spacing: 2) {
                            HStack(spacing: 2) {
                                ForEach(0..<4, id: \.self) { _ in
                                    Rectangle()
                                        .fill(WT.orange.opacity(0.4))
                                        .frame(width: 5, height: 1.5)
                                }
                                Image(systemName: "airplane")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(WT.orange)
                                ForEach(0..<4, id: \.self) { _ in
                                    Rectangle()
                                        .fill(WT.orange.opacity(0.4))
                                        .frame(width: 5, height: 1.5)
                                }
                            }
                            Text(flight.flightNumber.isEmpty ? "—" : flight.flightNumber)
                                .font(.system(size: 18, weight: .bold, design: .monospaced))
                                .foregroundStyle(WT.orange)
                        }
                        .frame(width: 90)

                        // Destination
                        VStack(alignment: .trailing, spacing: 3) {
                            Text(TimeFormatHelper.displayCode(flight.toAirport, useIATA: flight.useIATACodes))
                                .font(.system(size: 30, weight: .bold, design: .rounded))
                                .foregroundStyle(primary)
                            Text("STA \(flight.arrivalDatetime.map { TimeFormatHelper.localTime($0) } ?? "–:––")")
                                .font(.system(size: 12, weight: .medium, design: .monospaced))
                                .foregroundStyle(WT.secondary)
                            Text(flight.arrivalDatetime.map { TimeFormatHelper.utcTime($0) + "Z" } ?? "–:––")
                                .font(.system(size: 12, weight: .medium, design: .monospaced))
                                .foregroundStyle(WT.secondary.opacity(0.7))
                        }
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 14)

                    Spacer(minLength: 8)

                    // ── Divider ─────────────────────────────────────────
                    Rectangle()
                        .fill(WT.orange.opacity(0.25))
                        .frame(height: 1)
                        .padding(.horizontal, 16)

                    Spacer(minLength: 6)

                    // ── Bottom strip: header label + countdown ───────────
                    HStack(alignment: .center) {
                        HStack(spacing: 4) {
                            Image(systemName: "airplane.departure")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(WT.orange)
                            Text("NEXT FLIGHT")
                                .font(.system(size: 9, weight: .semibold))
                                .kerning(0.8)
                                .foregroundStyle(WT.secondary)
                        }

                        Spacer()

                        CountdownView(label: entry.countdownLabel, large: false)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
                }

            } else {
                NoFlightView(isDark: isDark)
            }
        }
    }
}

// MARK: - Countdown subview

private struct CountdownView: View {
    let label: String
    let large: Bool

    private var isDeparted: Bool { label == "Departed" }

    var body: some View {
        VStack(alignment: large ? .center : .trailing, spacing: 1) {
            if !isDeparted {
                Text("Departure within")
                    .font(.system(size: large ? 10 : 9, weight: .medium))
                    .foregroundStyle(WT.secondary)
            }

            Text(label)
                .font(.system(size: large ? 26 : 15, weight: .bold, design: .monospaced))
                .foregroundStyle(isDeparted ? WT.secondary : Color.orange)
                .monospacedDigit()
                .minimumScaleFactor(0.7)
                .lineLimit(1)
        }
    }
}

// MARK: - No flight empty state

private struct NoFlightView: View {
    let isDark: Bool
    private var primary: Color { isDark ? WT.primaryDark : WT.primaryLight }

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "airplane")
                .font(.system(size: 22, weight: .light))
                .foregroundStyle(WT.secondary)
            Text("No Upcoming\nFlights")
                .font(.system(size: 12, weight: .medium))
                .multilineTextAlignment(.center)
                .foregroundStyle(WT.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Previews

private let previewEntry = NextFlightTimelineEntry(
    date: .now,
    flight: WidgetFlightEntry(
        flightNumber: "QF063",
        fromAirport: "FAOR",
        toAirport: "YSSY",
        flightDate: Date().addingTimeInterval(3600 * 6),
        departureDatetime: Date().addingTimeInterval(3600 * 6),
        arrivalDatetime: Date().addingTimeInterval(3600 * 17),
        useIATACodes: true,
        snapshotDate: .now
    ),
    countdownLabel: "6 Hrs"
)

private let emptyEntry = NextFlightTimelineEntry(date: .now, flight: nil, countdownLabel: "")

#Preview("Small — Flight", as: .systemSmall) {
    BlockTimeWidget()
} timeline: {
    previewEntry
    emptyEntry
}

#Preview("Medium — Flight", as: .systemMedium) {
    BlockTimeWidget()
} timeline: {
    previewEntry
    emptyEntry
}
