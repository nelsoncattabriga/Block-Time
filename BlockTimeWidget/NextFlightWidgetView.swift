//
//  NextFlightWidgetView.swift
//  BlockTimeWidget
//
//  Branded Block-Time widget — Sunrise theme, orange accent, light + dark mode.
//  Small:  Route · flight number · departure date + time
//  Medium: Route · STD/STA times · departure date + time
//  Large:  Medium + same-day companion flights
//

import WidgetKit
import SwiftUI
import BlockTimeKit

// MARK: - Design tokens

private enum WT {
    // Orange accent matching AppColors.accentOrange
    static let orange      = Color(red: 1.0, green: 0.62, blue: 0.04).opacity(0.85)
    // Fixed blue — non-adaptive, same value light and dark
    static let blue        = Color(red: 0.20, green: 0.45, blue: 0.90)

    // Backgrounds
    static let darkBG      = Color(red: 0.11, green: 0.11, blue: 0.12)  // #1C1C1E
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
    static func background(style: WidgetStyleOption, dark: Bool) -> some View {
        if style == .gradient {
            gradient(dark: dark).ignoresSafeArea()
        } else {
            (dark ? darkBG : lightBGSolid).ignoresSafeArea()
        }
    }
}

// MARK: - Helpers

private struct TimeFormatHelper {

    private static let utcFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        f.timeZone = TimeZone(secondsFromGMT: 0)
        return f
    }()

    /// Format a UTC Date as "HH:mm" in UTC
    static func utcTime(_ date: Date) -> String {
        utcFormatter.string(from: date)
    }

    /// Returns "Today", "Tomorrow", or "Mon 27th" for a departure date,
    /// evaluated against the device's local calendar.
    static func departureDateLabel(_ date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date)    { return "Today" }
        if cal.isDateInTomorrow(date) { return "Tomorrow" }
        let day     = cal.component(.day, from: date)
        let weekday = weekdayFormatter.string(from: date)
        return "\(weekday) \(day)\(ordinalSuffix(for: day))"
    }

    private static let weekdayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    private static func ordinalSuffix(for day: Int) -> String {
        switch day {
        case 11, 12, 13: return "th"
        default:
            switch day % 10 {
            case 1: return "st"
            case 2: return "nd"
            case 3: return "rd"
            default: return "th"
            }
        }
    }

    /// Format a date as "HH:mmZ" (UTC) or "HH:mm" in the airport's local timezone.
    static func displayTime(_ date: Date, timeZone: WidgetTimeZoneOption, airportICAO: String) -> String {
        switch timeZone {
        case .utc:
            return utcTime(date) + "Z"
        case .local:
            let tz = WidgetAirportCodes.timeZone(for: airportICAO, on: date)
            let f = DateFormatter()
            f.dateFormat = "HH:mm"
            f.timeZone = tz
            return f.string(from: date)
        }
    }

    /// Display airport code — ICAO stored; convert to IATA if useIATACodes.
    static func displayCode(_ icao: String, useIATA: Bool) -> String {
        guard useIATA else { return icao }
        return WidgetAirportCodes.iataFor(icao: icao) ?? icao
    }
}

// MARK: - Root entry point

struct NextFlightWidgetView: View {
    @Environment(\.widgetFamily) var family
    @Environment(\.colorScheme)  var systemScheme
    let entry: NextFlightTimelineEntry

    /// Resolved colour scheme — gradient always follows system; solid respects user override.
    private var scheme: ColorScheme {
        switch entry.configuration.resolvedAppearance {
        case .light:     return .light
        case .dark:      return .dark
        case .automatic: return systemScheme
        }
    }

    var body: some View {
        Group {
            if entry.configuration.displayMode == .countdown {
                switch family {
                case .systemSmall:  CountdownSmallView(entry: entry, scheme: scheme)
                case .systemMedium: CountdownMediumView(entry: entry, scheme: scheme)
                case .systemLarge:  CountdownLargeView(entry: entry, scheme: scheme)
                default:            CountdownSmallView(entry: entry, scheme: scheme)
                }
            } else {
                switch family {
                case .systemSmall:  SmallView(entry: entry, scheme: scheme)
                case .systemMedium: MediumView(entry: entry, scheme: scheme)
                case .systemLarge:  LargeView(entry: entry, scheme: scheme)
                default:            SmallView(entry: entry, scheme: scheme)
                }
            }
        }
        .environment(\.colorScheme, scheme)
    }
}

// MARK: - Small Widget

private struct SmallView: View {
    let entry: NextFlightTimelineEntry
    let scheme: ColorScheme

    private var isDark: Bool { scheme == .dark }
    private var primary: Color { isDark ? WT.primaryDark : WT.primaryLight }

    var body: some View {
        ZStack {
            WT.background(style: entry.configuration.style, dark: isDark)

            if let flight = entry.flight {
                VStack(alignment: .center, spacing: 0) {

                    // Header
                    HStack(spacing: 4) {
                        Image(systemName: "airplane.departure")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(WT.orange)
                        Text("NEXT FLIGHT")
                            .font(.system(size: 10, weight: .semibold))
                            .kerning(0.6)
                            .foregroundStyle(WT.secondary)
                    }

                    Spacer(minLength: 4)

                    // Flight number
                    Text(flight.flightNumber.isEmpty ? "—" : flight.flightNumber)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(WT.secondary)

                    Spacer(minLength: 2)

                    // Route
                    HStack(spacing: 4) {
                        Text(TimeFormatHelper.displayCode(flight.fromAirport, useIATA: flight.useIATACodes))
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundStyle(primary)
                            .minimumScaleFactor(0.6)
                            .lineLimit(1)
                        Image(systemName: "arrow.right")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(WT.orange)
                        Text(TimeFormatHelper.displayCode(flight.toAirport, useIATA: flight.useIATACodes))
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundStyle(primary)
                            .minimumScaleFactor(0.6)
                            .lineLimit(1)
                    }

                    // Divider
                    Rectangle()
                        .fill(WT.orange.opacity(0.25))
                        .frame(height: 1)

                    Spacer(minLength: 6)

                    // Departure date + departure-airport local time
                    if let dep = flight.departureDatetime {
                        VStack(alignment: .center, spacing: 2) {
                            Text(TimeFormatHelper.departureDateLabel(dep))
                                .font(.system(size: 20, weight: .bold, design: .monospaced))
                                .foregroundStyle(WT.orange)
                                .minimumScaleFactor(0.7)
                                .lineLimit(1)
                            Text(TimeFormatHelper.displayTime(dep, timeZone: .local, airportICAO: flight.fromAirport))
                                .font(.system(size: 20, weight: .bold, design: .monospaced))
                                .foregroundStyle(WT.orange)
                                .minimumScaleFactor(0.7)
                        }
                    }
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
    private var primary: Color { isDark ? WT.primaryDark : WT.primaryLight }

    var body: some View {
        ZStack {
            WT.background(style: entry.configuration.style, dark: isDark)

            if let flight = entry.flight {
                VStack(spacing: 0) {

                    // ── Header ───────────────────────────────────────────
                    HStack(spacing: 4) {
                        Image(systemName: "airplane.departure")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(WT.orange)
                        Text("NEXT FLIGHT")
                            .font(.system(size: 10, weight: .semibold))
                            .kerning(0.8)
                            .foregroundStyle(WT.secondary)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)

                    Spacer(minLength: 4)

                    // ── Route + spine ────────────────────────────────────
                    HStack(alignment: .center, spacing: 0) {

                        // Origin
                        VStack(alignment: .leading, spacing: 3) {
                            Text(TimeFormatHelper.displayCode(flight.fromAirport, useIATA: flight.useIATACodes))
                                .font(.system(size: 30, weight: .bold, design: .rounded))
                                .foregroundStyle(primary)
                            Text(flight.departureDatetime.map { TimeFormatHelper.displayTime($0, timeZone: entry.configuration.timeZone, airportICAO: flight.fromAirport) } ?? "–:––")
                                .font(.system(size: 15, weight: .semibold, design: .monospaced))
                                .foregroundStyle(WT.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        // Centre spine
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
                                .font(.system(size: 20, weight: .bold, design: .monospaced))
                                .foregroundStyle(WT.secondary)
                        }
                        .frame(width: 90)

                        // Destination
                        VStack(alignment: .trailing, spacing: 3) {
                            Text(TimeFormatHelper.displayCode(flight.toAirport, useIATA: flight.useIATACodes))
                                .font(.system(size: 30, weight: .bold, design: .rounded))
                                .foregroundStyle(primary)
                            Text(flight.arrivalDatetime.map { TimeFormatHelper.displayTime($0, timeZone: entry.configuration.timeZone, airportICAO: flight.toAirport) } ?? "–:––")
                                .font(.system(size: 15, weight: .semibold, design: .monospaced))
                                .foregroundStyle(WT.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                    .padding(.horizontal, 16)

                    Spacer(minLength: 8)

                    // ── Divider ──────────────────────────────────────────
                    Rectangle()
                        .fill(WT.orange.opacity(0.25))
                        .frame(height: 1)
                        .padding(.horizontal, 16)

                    Spacer(minLength: 6)

                    // ── Departure date + departure-airport local time ─────
                    if let dep = flight.departureDatetime {
                        VStack(alignment: .center, spacing: 1) {
                            Text(TimeFormatHelper.departureDateLabel(dep))
                                .font(.system(size: 20, weight: .bold, design: .monospaced))
                                .foregroundStyle(WT.orange)
                            Text(TimeFormatHelper.displayTime(dep, timeZone: .local, airportICAO: flight.fromAirport))
                                .font(.system(size: 20, weight: .bold, design: .monospaced))
                                .foregroundStyle(WT.orange)
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                    }

                    Spacer(minLength: 8)
                }

            } else {
                NoFlightView(isDark: isDark)
            }
        }
    }
}

// MARK: - Large Widget

private struct LargeView: View {
    let entry: NextFlightTimelineEntry
    let scheme: ColorScheme

    private var isDark: Bool   { scheme == .dark }
    private var primary: Color { isDark ? WT.primaryDark : WT.primaryLight }

    /// Same-day flights that depart after the main card flight, sorted ascending.
    private var otherFlights: [WidgetFlightEntry] {
        guard let next = entry.flight else { return [] }
        let nextDep = next.departureDatetime ?? next.flightDate
        return entry.sameDayFlights
            .filter { ($0.departureDatetime ?? $0.flightDate) > nextDep }
            .sorted { ($0.departureDatetime ?? $0.flightDate) < ($1.departureDatetime ?? $1.flightDate) }
    }

    private var emptyBottomLabel: String {
        "No More Flights"
    }

    var body: some View {
        ZStack {
            WT.background(style: entry.configuration.style, dark: isDark)

            if let flight = entry.flight {
                VStack(spacing: 0) {

                    // ── Header ───────────────────────────────────────────
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
                    .padding(.top, 14)

                    Spacer(minLength: 6)

                    // ── Next flight: route + spine ────────────────────────
                    HStack(alignment: .center, spacing: 0) {

                        // Origin
                        VStack(alignment: .leading, spacing: 3) {
                            Text(TimeFormatHelper.displayCode(flight.fromAirport, useIATA: flight.useIATACodes))
                                .font(.system(size: 36, weight: .bold, design: .rounded))
                                .foregroundStyle(primary)
                            Text(flight.departureDatetime.map { TimeFormatHelper.displayTime($0, timeZone: entry.configuration.timeZone, airportICAO: flight.fromAirport) } ?? "–:––")
                                .font(.system(size: 15, weight: .semibold, design: .monospaced))
                                .foregroundStyle(WT.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        // Centre spine
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
                                .foregroundStyle(WT.secondary)
                        }
                        .frame(width: 90)

                        // Destination
                        VStack(alignment: .trailing, spacing: 3) {
                            Text(TimeFormatHelper.displayCode(flight.toAirport, useIATA: flight.useIATACodes))
                                .font(.system(size: 36, weight: .bold, design: .rounded))
                                .foregroundStyle(primary)
                            Text(flight.arrivalDatetime.map { TimeFormatHelper.displayTime($0, timeZone: entry.configuration.timeZone, airportICAO: flight.toAirport) } ?? "–:––")
                                .font(.system(size: 15, weight: .semibold, design: .monospaced))
                                .foregroundStyle(WT.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                    .padding(.horizontal, 16)

                    Spacer(minLength: 8)

                    // ── Departure date + departure-airport local time ─────
                    if let dep = flight.departureDatetime {
                        VStack(alignment: .center, spacing: 2) {
                            Text(TimeFormatHelper.departureDateLabel(dep))
                                .font(.system(size: 22, weight: .bold, design: .monospaced))
                                .foregroundStyle(WT.orange)
                            Text(TimeFormatHelper.displayTime(dep, timeZone: .local, airportICAO: flight.fromAirport))
                                .font(.system(size: 22, weight: .bold, design: .monospaced))
                                .foregroundStyle(WT.orange)
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                    }

                    Spacer(minLength: 12)

                    // ── Divider ───────────────────────────────────────────
                    Rectangle()
                        .fill(WT.orange.opacity(0.25))
                        .frame(height: 1)
                        .padding(.horizontal, 16)

                    Spacer(minLength: 10)

                    // ── Other flights today ───────────────────────────────
                    if otherFlights.isEmpty {
                        Text(emptyBottomLabel)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(WT.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                    } else {
                        VStack(spacing: 8) {
                            ForEach(otherFlights, id: \.stableID) { f in
                                FlightRowView(flight: f, primary: primary, timeZone: entry.configuration.timeZone)
                            }
                        }
                        .padding(.horizontal, 16)
                    }

                    Spacer(minLength: 14)
                }

            } else {
                NoFlightView(isDark: isDark)
            }
        }
    }
}

// MARK: - Flight row (large widget)

private struct FlightRowView: View {
    let flight: WidgetFlightEntry
    let primary: Color
    let timeZone: WidgetTimeZoneOption

    var body: some View {
        HStack(spacing: 0) {


            // Flight number — fixed size so it never compresses
            Text(flight.flightNumber.isEmpty ? "—" : flight.flightNumber)
                .font(.system(size: 17, weight: .semibold, design: .monospaced))
                .foregroundStyle(primary)
                .fixedSize()
                .padding(.trailing, 12)


            // Route — fixed size so ICAO codes never truncate
            HStack(spacing: 4) {
                Text(TimeFormatHelper.displayCode(flight.fromAirport, useIATA: flight.useIATACodes))
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(primary)
                    .fixedSize()
                Image(systemName: "minus")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(WT.orange)
                Text(TimeFormatHelper.displayCode(flight.toAirport, useIATA: flight.useIATACodes))
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(primary)
                    .fixedSize()
            }

            Spacer(minLength: 8)

            // DEP / ARR times — fixed size so times never wrap
            HStack(spacing: 4) {
                Text(flight.departureDatetime.map { TimeFormatHelper.displayTime($0, timeZone: timeZone, airportICAO: flight.fromAirport) } ?? "–:––")
                    .font(.system(size: 17, weight: .semibold, design: .monospaced))
                    .foregroundStyle(WT.secondary)
                Text("/")
                    .font(.system(size: 17, weight: .light))
                    .foregroundStyle(WT.secondary.opacity(0.5))
                Text(flight.arrivalDatetime.map { TimeFormatHelper.displayTime($0, timeZone: timeZone, airportICAO: flight.toAirport) } ?? "–:––")
                    .font(.system(size: 17, weight: .semibold, design: .monospaced))
                    .foregroundStyle(WT.secondary)
            }
            .fixedSize()
        }
    }
}

// MARK: - Countdown Small Widget

private struct CountdownSmallView: View {
    let entry: NextFlightTimelineEntry
    let scheme: ColorScheme

    private var isDark: Bool { scheme == .dark }
    private var primary: Color { isDark ? WT.primaryDark : WT.primaryLight }

    var body: some View {
        ZStack {
            WT.background(style: entry.configuration.style, dark: isDark)

            if let flight = entry.flight {
                VStack(alignment: .center, spacing: 0) {

                    // Header
                    HStack(spacing: 4) {
                        Image(systemName: "airplane.departure")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(WT.orange)
                        Text("NEXT FLIGHT")
                            .font(.system(size: 10, weight: .semibold))
                            .kerning(0.6)
                            .foregroundStyle(WT.secondary)
                    }

                    Spacer(minLength: 4)

                    // Flight number
                    Text(flight.flightNumber.isEmpty ? "—" : flight.flightNumber)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(WT.secondary)

                    Spacer(minLength: 2)

                    // Route
                    HStack(spacing: 4) {
                        Text(TimeFormatHelper.displayCode(flight.fromAirport, useIATA: flight.useIATACodes))
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundStyle(primary)
                            .minimumScaleFactor(0.6)
                            .lineLimit(1)
                        Image(systemName: "arrow.right")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(WT.orange)
                        Text(TimeFormatHelper.displayCode(flight.toAirport, useIATA: flight.useIATACodes))
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundStyle(primary)
                            .minimumScaleFactor(0.6)
                            .lineLimit(1)
                    }

                    // Divider
                    Rectangle()
                        .fill(WT.orange.opacity(0.25))
                        .frame(height: 1)

                    Spacer(minLength: 6)

                    // Live countdown
                    let depDate = flight.departureDatetime ?? flight.flightDate
                    VStack(spacing: 2) {
                        Text(entry.isPastDeparture ? "PAST STD" : "DEPARTS IN")
                            .font(.system(size: 11, weight: .semibold))
                            .kerning(0.6)
                            .foregroundStyle(WT.secondary)
                        Text(depDate, style: .relative)
                            .font(.system(size: 20, weight: .bold, design: .monospaced))
                            .foregroundStyle(WT.orange)
                            .minimumScaleFactor(0.5)
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(14)

            } else {
                NoFlightView(isDark: isDark)
            }
        }
    }
}

// MARK: - Countdown Medium Widget

private struct CountdownMediumView: View {
    let entry: NextFlightTimelineEntry
    let scheme: ColorScheme

    private var isDark: Bool { scheme == .dark }
    private var primary: Color { isDark ? WT.primaryDark : WT.primaryLight }

    var body: some View {
        ZStack {
            WT.background(style: entry.configuration.style, dark: isDark)

            if let flight = entry.flight {
                VStack(spacing: 0) {

                    // ── Header ───────────────────────────────────────────
                    HStack(spacing: 4) {
                        Image(systemName: "airplane.departure")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(WT.orange)
                        Text("NEXT FLIGHT")
                            .font(.system(size: 10, weight: .semibold))
                            .kerning(0.8)
                            .foregroundStyle(WT.secondary)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)

                    Spacer(minLength: 4)

                    // ── Route + spine (identical to MediumView) ──────────
                    HStack(alignment: .center, spacing: 0) {

                        VStack(alignment: .leading, spacing: 3) {
                            Text(TimeFormatHelper.displayCode(flight.fromAirport, useIATA: flight.useIATACodes))
                                .font(.system(size: 30, weight: .bold, design: .rounded))
                                .foregroundStyle(primary)
                            Text(flight.departureDatetime.map { TimeFormatHelper.displayTime($0, timeZone: entry.configuration.timeZone, airportICAO: flight.fromAirport) } ?? "–:––")
                                .font(.system(size: 15, weight: .semibold, design: .monospaced))
                                .foregroundStyle(WT.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

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
                                .font(.system(size: 20, weight: .bold, design: .monospaced))
                                .foregroundStyle(WT.secondary)
                        }
                        .frame(width: 90)

                        VStack(alignment: .trailing, spacing: 3) {
                            Text(TimeFormatHelper.displayCode(flight.toAirport, useIATA: flight.useIATACodes))
                                .font(.system(size: 30, weight: .bold, design: .rounded))
                                .foregroundStyle(primary)
                            Text(flight.arrivalDatetime.map { TimeFormatHelper.displayTime($0, timeZone: entry.configuration.timeZone, airportICAO: flight.toAirport) } ?? "–:––")
                                .font(.system(size: 15, weight: .semibold, design: .monospaced))
                                .foregroundStyle(WT.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                    .padding(.horizontal, 16)

                    Spacer(minLength: 8)

                    // ── Divider ──────────────────────────────────────────
                    Rectangle()
                        .fill(WT.orange.opacity(0.25))
                        .frame(height: 1)
                        .padding(.horizontal, 16)

                    Spacer(minLength: 6)

                    // ── Countdown (replaces date + time rows) ────────────
                    let depDate = flight.departureDatetime ?? flight.flightDate
                    VStack(spacing: 2) {
                        Text(entry.isPastDeparture ? "PAST STD" : "DEPARTS IN")
                            .font(.system(size: 11, weight: .semibold))
                            .kerning(0.6)
                            .foregroundStyle(WT.secondary)
                        Text(depDate, style: .relative)
                            .font(.system(size: 20, weight: .bold, design: .monospaced))
                            .foregroundStyle(WT.orange)
                            .minimumScaleFactor(0.6)
                            .lineLimit(1)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }

                    Spacer(minLength: 8)
                }

            } else {
                NoFlightView(isDark: isDark)
            }
        }
    }
}

// MARK: - Countdown Large Widget

private struct CountdownLargeView: View {
    let entry: NextFlightTimelineEntry
    let scheme: ColorScheme

    private var isDark: Bool   { scheme == .dark }
    private var primary: Color { isDark ? WT.primaryDark : WT.primaryLight }

    private var otherFlights: [WidgetFlightEntry] {
        guard let next = entry.flight else { return [] }
        let nextDep = next.departureDatetime ?? next.flightDate
        return entry.sameDayFlights
            .filter { ($0.departureDatetime ?? $0.flightDate) > nextDep }
            .sorted { ($0.departureDatetime ?? $0.flightDate) < ($1.departureDatetime ?? $1.flightDate) }
    }

    private var emptyBottomLabel: String {
        "No Other Flights"
    }

    var body: some View {
        ZStack {
            WT.background(style: entry.configuration.style, dark: isDark)

            if let flight = entry.flight {
                VStack(spacing: 0) {

                    // ── Header ───────────────────────────────────────────
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
                    .padding(.top, 14)

                    Spacer(minLength: 6)

                    // ── Route + spine ─────────────────────────────────────
                    HStack(alignment: .center, spacing: 0) {

                        VStack(alignment: .leading, spacing: 3) {
                            Text(TimeFormatHelper.displayCode(flight.fromAirport, useIATA: flight.useIATACodes))
                                .font(.system(size: 36, weight: .bold, design: .rounded))
                                .foregroundStyle(primary)
                            Text(flight.departureDatetime.map { TimeFormatHelper.displayTime($0, timeZone: entry.configuration.timeZone, airportICAO: flight.fromAirport) } ?? "–:––")
                                .font(.system(size: 15, weight: .semibold, design: .monospaced))
                                .foregroundStyle(WT.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

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
                                .foregroundStyle(WT.secondary)
                        }
                        .frame(width: 90)

                        VStack(alignment: .trailing, spacing: 3) {
                            Text(TimeFormatHelper.displayCode(flight.toAirport, useIATA: flight.useIATACodes))
                                .font(.system(size: 36, weight: .bold, design: .rounded))
                                .foregroundStyle(primary)
                            Text(flight.arrivalDatetime.map { TimeFormatHelper.displayTime($0, timeZone: entry.configuration.timeZone, airportICAO: flight.toAirport) } ?? "–:––")
                                .font(.system(size: 15, weight: .semibold, design: .monospaced))
                                .foregroundStyle(WT.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                    .padding(.horizontal, 16)

                    Spacer(minLength: 8)

                    // ── Countdown (replaces date + time rows) ────────────
                    let depDate = flight.departureDatetime ?? flight.flightDate
                    VStack(spacing: 2) {
                        Text(entry.isPastDeparture ? "PAST STD" : "DEPARTS IN")
                            .font(.system(size: 11, weight: .semibold))
                            .kerning(0.6)
                            .foregroundStyle(WT.secondary)
                        Text(depDate, style: .relative)
                            .font(.system(size: 22, weight: .bold, design: .monospaced))
                            .foregroundStyle(WT.orange)
                            .minimumScaleFactor(0.6)
                            .lineLimit(1)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }

                    Spacer(minLength: 12)

                    // ── Divider ───────────────────────────────────────────
                    Rectangle()
                        .fill(WT.orange.opacity(0.25))
                        .frame(height: 1)
                        .padding(.horizontal, 16)

                    Spacer(minLength: 10)

                    // ── Other flights today ───────────────────────────────
                    if otherFlights.isEmpty {
                        Text(emptyBottomLabel)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(WT.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                    } else {
                        VStack(spacing: 8) {
                            ForEach(otherFlights, id: \.stableID) { f in
                                FlightRowView(flight: f, primary: primary, timeZone: entry.configuration.timeZone)
                            }
                        }
                        .padding(.horizontal, 16)
                    }

                    Spacer(minLength: 14)
                }

            } else {
                NoFlightView(isDark: isDark)
            }
        }
    }
}

// MARK: - No flight empty state

private struct NoFlightView: View {
    let isDark: Bool

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
//
// Scenario: 3 flights today, 2 flights tomorrow, then nothing.
//
//  Today
//    F1  BNE → SYD  QF500  dep +0hrs   arr +1.5hrs
//    F2  SYD → MEL  QF400  dep +4hrs   arr +5.25hrs
//    F3  MEL → BNE  QF600  dep +9.5hrs arr +11hrs
//  Tomorrow
//    F4  BNE → PER  QF700  dep +25hrs  arr +27.5hrs
//    F5  PER → BNE  QF701  dep +30hrs  arr +35.5hrs

private let now = Date()

private let f1 = WidgetFlightEntry(
    flightNumber: "QF500", fromAirport: "YBBN", toAirport: "YSSY",
    flightDate: now, departureDatetime: now,
    arrivalDatetime: now.addingTimeInterval(1.5 * 3600),
    useIATACodes: true, snapshotDate: now
)
private let f2 = WidgetFlightEntry(
    flightNumber: "QF400", fromAirport: "YSSY", toAirport: "YMML",
    flightDate: now, departureDatetime: now.addingTimeInterval(4 * 3600),
    arrivalDatetime: now.addingTimeInterval(5.25 * 3600),
    useIATACodes: true, snapshotDate: now
)
private let f3 = WidgetFlightEntry(
    flightNumber: "QF600", fromAirport: "YMML", toAirport: "YBBN",
    flightDate: now, departureDatetime: now.addingTimeInterval(9.5 * 3600),
    arrivalDatetime: now.addingTimeInterval(11 * 3600),
    useIATACodes: true, snapshotDate: now
)
private let f4 = WidgetFlightEntry(
    flightNumber: "QF700", fromAirport: "YBBN", toAirport: "YPPH",
    flightDate: now.addingTimeInterval(24 * 3600),
    departureDatetime: now.addingTimeInterval(25 * 3600),
    arrivalDatetime: now.addingTimeInterval(27.5 * 3600),
    useIATACodes: true, snapshotDate: now
)
private let f5 = WidgetFlightEntry(
    flightNumber: "QF701", fromAirport: "YPPH", toAirport: "YBBN",
    flightDate: now.addingTimeInterval(24 * 3600),
    departureDatetime: now.addingTimeInterval(30 * 3600),
    arrivalDatetime: now.addingTimeInterval(35.5 * 3600),
    useIATACodes: true, snapshotDate: now
)

private let todayFlights    = [f1, f2, f3]
private let tomorrowFlights = [f4, f5]

// State 1 — F1 is next; F2 and F3 in bottom row
private let e1 = NextFlightTimelineEntry(date: now, flight: f1, sameDayFlights: todayFlights)
// State 2 — F1 departed; F2 is next; F3 in bottom row
private let e2 = NextFlightTimelineEntry(date: now.addingTimeInterval(0.5 * 3600), flight: f2, sameDayFlights: todayFlights)
// State 3 — F2 departed; F3 is next; bottom row empty
private let e3 = NextFlightTimelineEntry(date: now.addingTimeInterval(4.5 * 3600), flight: f3, sameDayFlights: todayFlights)
// State 4 — F3 departed; F4 (tomorrow) is main card; "No More Flights Today" in bottom
private let e4 = NextFlightTimelineEntry(date: now.addingTimeInterval(10 * 3600), flight: f4, sameDayFlights: tomorrowFlights, noMoreFlightsToday: true)
// State 5 — F4 departed; F5 is main card; bottom row empty
private let e5 = NextFlightTimelineEntry(date: now.addingTimeInterval(25.5 * 3600), flight: f5, sameDayFlights: tomorrowFlights)
// State 6 — All done
private let e6 = NextFlightTimelineEntry(date: now.addingTimeInterval(36 * 3600), flight: nil)

private let countdownIntent: NextFlightIntent = {
    var intent = NextFlightIntent()
    intent.displayMode = .countdown
    return intent
}()

private let ec1 = NextFlightTimelineEntry(date: now, flight: f4, configuration: countdownIntent)
private let ec2 = NextFlightTimelineEntry(date: now, flight: f1, configuration: countdownIntent)

#Preview("Small — Full scenario", as: .systemSmall) {
    BlockTimeWidget()
} timeline: {
    e1; e2; e3; e4; e5; e6
}

#Preview("Medium — Full scenario", as: .systemMedium) {
    BlockTimeWidget()
} timeline: {
    e1; e2; e3; e4; e5; e6
}

#Preview("Large — Full scenario", as: .systemLarge) {
    BlockTimeWidget()
} timeline: {
    e1; e2; e3; e4; e5; e6
}

#Preview("Countdown Small — days away", as: .systemSmall) {
    BlockTimeWidget()
} timeline: {
    ec1
}

#Preview("Countdown Medium — days away", as: .systemMedium) {
    BlockTimeWidget()
} timeline: {
    ec1
}

#Preview("Countdown Small — imminent", as: .systemSmall) {
    BlockTimeWidget()
} timeline: {
    ec2
}

#Preview("Countdown Medium — imminent", as: .systemMedium) {
    BlockTimeWidget()
} timeline: {
    ec2
}

#Preview("Countdown Large — days away", as: .systemLarge) {
    BlockTimeWidget()
} timeline: {
    NextFlightTimelineEntry(date: now, flight: f4, sameDayFlights: tomorrowFlights, configuration: countdownIntent)
}

#Preview("Countdown Large — imminent", as: .systemLarge) {
    BlockTimeWidget()
} timeline: {
    NextFlightTimelineEntry(date: now, flight: f1, sameDayFlights: todayFlights, configuration: countdownIntent)
}
