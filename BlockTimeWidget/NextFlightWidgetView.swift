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

    /// "28:15 hrs" style for ≥ 1h,  "HH:MM" live timer is handled by Text(.timer) in the view
    static func countdownLabel(until date: Date) -> String {
        let interval = date.timeIntervalSinceNow
        guard interval > 0 else { return "Departed" }

        let totalMinutes = Int(interval / 60)
        let hours = totalMinutes / 60
        let mins  = totalMinutes % 60

        if interval >= 86400 {
            // More than 24 h — show total hours
            return String(format: "%d:%02d hrs", hours, mins)
        }
        // Under 24 h — caller uses Text(.timer) for live tick; this is the fallback label
        return String(format: "%d:%02d", hours, mins)
    }

    /// Returns true when departure is under 24 h away — use live Text(.timer)
    static func useLiveTicker(for date: Date) -> Bool {
        let interval = date.timeIntervalSinceNow
        return interval > 0 && interval < 86400
    }

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
        ZStack(alignment: .topLeading) {
            bg.ignoresSafeArea()

            if let flight = entry.flight {
                VStack(alignment: .leading, spacing: 0) {

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

                    Spacer(minLength: 6)

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

                    // Flight number
                    Text(flight.flightNumber.isEmpty ? "—" : flight.flightNumber)
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundStyle(WT.secondary)
                        .padding(.top, 2)

                    Spacer(minLength: 8)

                    // Divider
                    Rectangle()
                        .fill(WT.orange.opacity(0.25))
                        .frame(height: 1)

                    Spacer(minLength: 6)

                    // Countdown
                    CountdownView(departureDatetime: flight.departureDatetime,
                                  flightDate: flight.flightDate,
                                  large: true)
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
        ZStack(alignment: .topLeading) {
            bg.ignoresSafeArea()

            if let flight = entry.flight {
                VStack(alignment: .leading, spacing: 0) {

                    // Top row: label + countdown
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

                        CountdownView(departureDatetime: flight.departureDatetime,
                                      flightDate: flight.flightDate,
                                      large: false)
                    }

                    Spacer(minLength: 8)

                    // Route row
                    HStack(alignment: .center, spacing: 0) {
                        // Origin
                        VStack(alignment: .leading, spacing: 1) {
                            Text(TimeFormatHelper.displayCode(flight.fromAirport, useIATA: flight.useIATACodes))
                                .font(.system(size: 26, weight: .bold, design: .rounded))
                                .foregroundStyle(primary)
                            if let dep = flight.departureDatetime {
                                Text("\(TimeFormatHelper.localTime(dep))L / \(TimeFormatHelper.utcTime(dep))Z")
                                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                                    .foregroundStyle(WT.secondary)
                            } else {
                                Text("STD –:––")
                                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                                    .foregroundStyle(WT.secondary)
                            }
                        }

                        Spacer()

                        // Arrow + flight number
                        VStack(spacing: 2) {
                            Image(systemName: "arrow.right")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(WT.orange)
                            Text(flight.flightNumber.isEmpty ? "—" : flight.flightNumber)
                                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                .foregroundStyle(WT.orange)
                        }

                        Spacer()

                        // Destination
                        VStack(alignment: .trailing, spacing: 1) {
                            Text(TimeFormatHelper.displayCode(flight.toAirport, useIATA: flight.useIATACodes))
                                .font(.system(size: 26, weight: .bold, design: .rounded))
                                .foregroundStyle(primary)
                            if let arr = flight.arrivalDatetime {
                                Text("\(TimeFormatHelper.localTime(arr))L / \(TimeFormatHelper.utcTime(arr))Z")
                                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                                    .foregroundStyle(WT.secondary)
                            } else {
                                Text("STA –:––")
                                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                                    .foregroundStyle(WT.secondary)
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)

            } else {
                NoFlightView(isDark: isDark)
            }
        }
    }
}

// MARK: - Countdown subview

private struct CountdownView: View {
    let departureDatetime: Date?
    let flightDate: Date
    let large: Bool

    private var effectiveDate: Date { departureDatetime ?? flightDate }

    var body: some View {
        VStack(alignment: large ? .leading : .trailing, spacing: 1) {
            if TimeFormatHelper.useLiveTicker(for: effectiveDate) {
                // Live ticking timer (WidgetKit renders this without extra timeline entries)
                Text(effectiveDate, style: .timer)
                    .font(.system(size: large ? 28 : 15, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color.orange)
                    .monospacedDigit()
            } else if effectiveDate.timeIntervalSinceNow > 0 {
                Text(TimeFormatHelper.countdownLabel(until: effectiveDate))
                    .font(.system(size: large ? 26 : 14, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color.orange)
                    .monospacedDigit()
            } else {
                Text("Departed")
                    .font(.system(size: large ? 18 : 12, weight: .semibold))
                    .foregroundStyle(WT.secondary)
            }

            if departureDatetime != nil {
                Text("to departure")
                    .font(.system(size: large ? 10 : 9, weight: .medium))
                    .foregroundStyle(WT.secondary)
            } else {
                // No time available — showing day-level countdown
                Text("days to go")
                    .font(.system(size: large ? 10 : 9, weight: .medium))
                    .foregroundStyle(WT.secondary)
            }
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
