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
    static let orange      = Color(red: 1.0, green: 0.62, blue: 0.04).opacity(0.85)
    static let orangeDim   = Color(red: 1.0, green: 0.62, blue: 0.04).opacity(0.18)

    // Backgrounds
    static let darkBG      = Color(red: 0.11, green: 0.11, blue: 0.12)  // #1C1C1E
    // 1. Warm off-white
//     static let lightBG = Color(red: 0.96, green: 0.95, blue: 0.93)
    // 2. Cool light grey
    // static let lightBG = Color(red: 0.93, green: 0.93, blue: 0.95)
    // 3. Soft warm sand
//    static let lightBG     = Color(red: 0.95, green: 0.92, blue: 0.87)
    // 4. System adaptive
//     static let lightBG = Color(.systemBackground)
    // 5. Orange tint
//     static let lightBG = Color(red: 0.98, green: 0.96, blue: 0.93)
    // 6. Light slate
    // static let lightBG = Color(red: 0.90, green: 0.91, blue: 0.93)
    // 7. Blue tint
//     static let lightBG = Color(red: 0.91, green: 0.94, blue: 0.98)

    // Text
    static let primaryDark = Color(white: 0.75)
    static let primaryLight = Color(red: 0.1, green: 0.1, blue: 0.12)
    static let secondary   = Color(white: 0.55)

    // Gradient — mirrors defaultTheme in ThemeService (blue→orange, topLeading→bottomTrailing)
    static func gradient(dark: Bool) -> LinearGradient {
        if dark {
            return LinearGradient(
                colors: [
                    darkBG,
                    Color.blue.opacity(0.25),
                    Color.orange.opacity(0.18)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            return LinearGradient(
                colors: [
                    Color.blue.opacity(0.18),
                    Color(red: 0.98, green: 0.96, blue: 0.93),
                    Color.orange.opacity(0.15)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
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

    /// Returns "Today", "Tomorrow", or "Mon 27th" for a UTC departure date,
    /// evaluated against the device's local calendar.
    static func departureDateLabel(_ date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date)    { return "Today" }
        if cal.isDateInTomorrow(date) { return "Tomorrow" }
        let day      = cal.component(.day, from: date)
        let ordinal  = ordinalSuffix(for: day)
        let weekday  = weekdayFormatter.string(from: date)   // "Mon", "Tue" …
        return "\(weekday) \(day)\(ordinal)"
    }

    private static let weekdayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE"          // locale-independent 3-letter abbreviation
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
        case .systemLarge:  LargeView(entry: entry, scheme: colorScheme)
        default:            SmallView(entry: entry, scheme: colorScheme)
        }
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
            WT.gradient(dark: isDark).ignoresSafeArea()

            if let flight = entry.flight {
                VStack(alignment: .center, spacing: 0) {

                    // Header label
                    HStack(spacing: 4) {
                        Image(systemName: "airplane.departure")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(WT.orange)
                        Text("NEXT FLIGHT")
                            .font(.system(size: 10, weight: .semibold))
                            .kerning(0.6)
                            .foregroundStyle(WT.secondary)
//                        Spacer()
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
                        Image(systemName: "arrow.right")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(WT.orange)
                        Text(TimeFormatHelper.displayCode(flight.toAirport, useIATA: flight.useIATACodes))
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundStyle(primary)
                    }

//                    // STD / STA
//                    HStack(alignment: .top, spacing: 0) {
//                        VStack(alignment: .leading, spacing: 1) {
//                            Text("DEP")
//                                .font(.system(size: 10, weight: .semibold))
//                                .foregroundStyle(WT.secondary)
//                            Text(flight.departureDatetime.map { TimeFormatHelper.utcTime($0) + "Z" } ?? "–:––")
//                                .font(.system(size: 14, weight: .bold, design: .monospaced))
//                                .foregroundStyle(WT.secondary)
//                        }
//                        .frame(maxWidth: .infinity, alignment: .leading)
//
//                        VStack(alignment: .trailing, spacing: 1) {
//                            Text("ARR")
//                                .font(.system(size: 10, weight: .semibold))
//                                .foregroundStyle(WT.secondary)
//                            Text(flight.arrivalDatetime.map { TimeFormatHelper.utcTime($0) + "Z" } ?? "–:––")
//                                .font(.system(size: 14, weight: .bold, design: .monospaced))
//                                .foregroundStyle(WT.secondary)
//                        }
//                        .frame(maxWidth: .infinity, alignment: .trailing)
//                    }
//                    .padding(.top, 2)
//
//                    Spacer(minLength: 8)

                    // Divider
                    Rectangle()
                        .fill(WT.orange.opacity(0.25))
                        .frame(height: 1)

                    Spacer(minLength: 6)

                    // Departure date + local time
                    if let dep = flight.departureDatetime {
                        
                        VStack(alignment: .center, spacing: 2) {
                            Text(TimeFormatHelper.departureDateLabel(dep))
                                .font(.system(size: 20, weight: .bold, design: .monospaced))
                                .foregroundStyle(Color.orange)
                                .minimumScaleFactor(0.7)
                                .lineLimit(1)
                            Text(TimeFormatHelper.localTime(dep))
                                .font(.system(size: 20, weight: .bold, design: .monospaced))
                                .foregroundStyle(Color.orange)
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
            WT.gradient(dark: isDark).ignoresSafeArea()

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

                    // ── Top section: route + spine ──────────────────────
                    HStack(alignment: .center, spacing: 0) {

                        // Origin
                        VStack(alignment: .leading, spacing: 3) {
                            Text(TimeFormatHelper.displayCode(flight.fromAirport, useIATA: flight.useIATACodes))
                                .font(.system(size: 30, weight: .bold, design: .rounded))
                                .foregroundStyle(primary)
                            Text("\(flight.departureDatetime.map { TimeFormatHelper.utcTime($0) + "Z" } ?? "–:––")")
                                .font(.system(size: 15, weight: .semibold, design: .monospaced))
                                .foregroundStyle(WT.secondary)
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
                                .font(.system(size: 20, weight: .bold, design: .monospaced))
                                .foregroundStyle(WT.secondary)
                        }
                        .frame(width: 90)

                        // Destination
                        VStack(alignment: .trailing, spacing: 3) {
                            Text(TimeFormatHelper.displayCode(flight.toAirport, useIATA: flight.useIATACodes))
                                .font(.system(size: 30, weight: .bold, design: .rounded))
                                .foregroundStyle(primary)
                            Text("\(flight.arrivalDatetime.map { TimeFormatHelper.utcTime($0) + "Z" } ?? "–:––")")
                                .font(.system(size: 15, weight: .semibold, design: .monospaced))
                                .foregroundStyle(WT.secondary)

                        }
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                    .padding(.horizontal, 16)

                    Spacer(minLength: 8)

                    // ── Divider ─────────────────────────────────────────
                    Rectangle()
                        .fill(WT.orange.opacity(0.25))
                        .frame(height: 1)
                        .padding(.horizontal, 16)

                    Spacer(minLength: 6)

                    // ── Bottom strip: centred departure date + time ──────
                    if let dep = flight.departureDatetime {
                        VStack(alignment: .center, spacing: 1) {
                            Text(TimeFormatHelper.departureDateLabel(dep))
                                .font(.system(size: 20, weight: .bold, design: .monospaced))
                                .foregroundStyle(Color.orange)
                            Text(TimeFormatHelper.localTime(dep))
                                .font(.system(size: 20, weight: .bold, design: .monospaced))
                                .foregroundStyle(Color.orange)
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

    /// Same-day flights excluding the current next flight
    private var otherFlights: [WidgetFlightEntry] {
        guard let next = entry.flight else { return [] }
        let nextDep = next.departureDatetime ?? next.flightDate
        return entry.sameDayFlights.filter { f in
            let fDep = f.departureDatetime ?? f.flightDate
            return fDep != nextDep
        }
    }

    var body: some View {
        ZStack {
            WT.gradient(dark: isDark).ignoresSafeArea()

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
                            Text(flight.departureDatetime.map { TimeFormatHelper.utcTime($0) + "Z" } ?? "–:––")
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
                            Text(flight.arrivalDatetime.map { TimeFormatHelper.utcTime($0) + "Z" } ?? "–:––")
                                .font(.system(size: 15, weight: .semibold, design: .monospaced))
                                .foregroundStyle(WT.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                    .padding(.horizontal, 16)

                    Spacer(minLength: 8)

                    // ── Departure date + time ─────────────────────────────
                    if let dep = flight.departureDatetime {
                        VStack(alignment: .center, spacing: 2) {
                            Text(TimeFormatHelper.departureDateLabel(dep))
                                .font(.system(size: 22, weight: .bold, design: .monospaced))
                                .foregroundStyle(Color.orange)
                            Text(TimeFormatHelper.localTime(dep))
                                .font(.system(size: 22, weight: .bold, design: .monospaced))
                                .foregroundStyle(Color.orange)
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
                        Text("No other flights today")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(WT.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                    } else {
                        VStack(spacing: 8) {
                            ForEach(otherFlights, id: \.flightNumber) { f in
                                FlightRowView(flight: f, primary: primary)
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

    var body: some View {
        HStack(spacing: 0) {
            // Route
            HStack(spacing: 4) {
                Text(TimeFormatHelper.displayCode(flight.fromAirport, useIATA: flight.useIATACodes))
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(primary)
                Image(systemName: "arrow.right")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(WT.orange)
                Text(TimeFormatHelper.displayCode(flight.toAirport, useIATA: flight.useIATACodes))
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(primary)
            }

            Spacer()

            // Flight number
            Text(flight.flightNumber.isEmpty ? "—" : flight.flightNumber)
                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                .foregroundStyle(WT.secondary)

            Spacer()

            // DEP / ARR times
            HStack(spacing: 12) {
                VStack(alignment: .trailing, spacing: 1) {
                    Text("DEP")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(WT.secondary.opacity(0.7))
                    Text(flight.departureDatetime.map { TimeFormatHelper.utcTime($0) + "Z" } ?? "–:––")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundStyle(WT.secondary)
                }
                VStack(alignment: .trailing, spacing: 1) {
                    Text("ARR")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(WT.secondary.opacity(0.7))
                    Text(flight.arrivalDatetime.map { TimeFormatHelper.utcTime($0) + "Z" } ?? "–:––")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundStyle(WT.secondary)
                }
            }
        }
    }
}

// MARK: - Countdown subview

//private struct CountdownView: View {
//    let label: String
//    let large: Bool
//
//    private var isDeparted: Bool { label == "Departed" }
//
//    var body: some View {
//        VStack(alignment: large ? .center : .trailing, spacing: 1) {
//            if !isDeparted {
//                Text("Departure within")
//                    .font(.system(size: large ? 10 : 9, weight: .medium))
//                    .foregroundStyle(WT.secondary)
//            }
//
//            Text(label)
//                .font(.system(size: large ? 26 : 15, weight: .bold, design: .monospaced))
//                .foregroundStyle(isDeparted ? WT.secondary : Color.orange)
//                .monospacedDigit()
//                .minimumScaleFactor(0.7)
//                .lineLimit(1)
//        }
//    }
//}

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
        departureDatetime: Date().addingTimeInterval(3600 * 35),
        arrivalDatetime: Date().addingTimeInterval(3600 * 47),
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

#Preview("Large — Flight", as: .systemLarge) {
    BlockTimeWidget()
} timeline: {
    previewEntry
    emptyEntry
}
