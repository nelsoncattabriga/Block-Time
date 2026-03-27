//
//  FlightDatabaseService+InsightsQueries.swift
//  Block-Time
//
//  Consolidated analytics computations for the Insights dashboard.
//  Single source of truth — all ND* analytics flow through here.
//

import Foundation
import CoreData
import SwiftUI

// MARK: - Aggregate insights payload

struct NDInsightsData {
    let flightStatistics: FlightStatistics
    let monthlyActivity: [NDMonthlyActivity]
    let dailyActivity: [NDDailyActivity]
    let fleetHours: [NDFleetHours]
    let pfRatioByMonth: [NDMonthlyPFRatio]
    let monthlyNight: [NDMonthlyNight]
    let topRoutes: [NDRouteFrequency]
    let topRegistrations: [NDRegistrationHours]
    let approachTypes: [NDApproachTypeStat]
    let tlStats: NDTakeoffLandingStats
    let careerStats: NDCareerStats
    let frmsStrip: NDFRMSStripData
    let projectedFRMS: NDProjectedFRMSData
    let frmsRolling: NDFRMSRollingData
}

// MARK: - Extension

extension FlightDatabaseService {

    /// Returns all analytics for the Insights dashboard.
    /// Calls the proven `getFlightStatistics()` for aggregate totals, then
    /// performs one additional Core Data fetch for analytics computations.
    func getInsightsData() -> NDInsightsData {
        let stats = getFlightStatistics()

        let request: NSFetchRequest<FlightEntity> = FlightEntity.fetchRequest()
        request.predicate = NSPredicate(
            format: "(blockTime != %@ AND blockTime != %@ AND blockTime != %@) OR (simTime != %@ AND simTime != %@ AND simTime != %@)",
            "0", "0.0", "0.00", "0", "0.0", "0.00"
        )
        request.sortDescriptors = [NSSortDescriptor(key: "date", ascending: true)]

        let flights: [FlightEntity]
        do {
            flights = try viewContext.fetch(request)
        } catch {
            return NDInsightsData(
                flightStatistics: stats,
                monthlyActivity: [],
                dailyActivity: [],
                fleetHours: [],
                pfRatioByMonth: [],
                monthlyNight: [],
                topRoutes: [],
                topRegistrations: [],
                approachTypes: [],
                tlStats: .empty,
                careerStats: .empty,
                frmsStrip: .empty,
                projectedFRMS: .empty,
                frmsRolling: .empty
            )
        }

        return NDInsightsData(
            flightStatistics: stats,
            monthlyActivity: computeMonthlyActivity(flights),
            dailyActivity: computeDailyActivity(flights),
            fleetHours: computeFleetHours(flights),
            pfRatioByMonth: computePFRatioByMonth(flights),
            monthlyNight: computeMonthlyNight(flights),
            topRoutes: computeTopRoutes(flights),
            topRegistrations: computeTopRegistrations(flights),
            approachTypes: computeApproachTypes(flights),
            tlStats: computeTLStats(flights),
            careerStats: computeCareerStats(flights),
            frmsStrip: computeFRMSStrip(flights),
            projectedFRMS: computeProjectedFRMS(),
            frmsRolling: computeFRMSRolling()
        )
    }

    // MARK: - Private helpers

    private func hrs(_ s: String?) -> Double { Double(s ?? "0") ?? 0 }

    /// True when the entity is a Sp/Ins-only flight (simTime == spInsTime > 0)
    private func isSpInsOnly(_ f: FlightEntity) -> Bool {
        let spVal = hrs(f.spInsTime)
        guard spVal > 0 else { return false }
        return abs(hrs(f.simTime) - spVal) < 0.01
    }

    private func monthStart(for date: Date) -> Date {
        let cal = Calendar.current
        return cal.date(from: cal.dateComponents([.year, .month], from: date)) ?? date
    }

    // MARK: - Compute methods

    private func computeMonthlyActivity(_ flights: [FlightEntity]) -> [NDMonthlyActivity] {
        var block: [Date: Double] = [:]
        var sim: [Date: Double] = [:]
        var night: [Date: Double] = [:]
        var sectors: [Date: Int] = [:]

        for f in flights {
            guard let date = f.date else { continue }
            let m = monthStart(for: date)
            let blockHrs = hrs(f.blockTime)
            block[m, default: 0] += blockHrs
            sim[m, default: 0]   += isSpInsOnly(f) ? 0 : hrs(f.simTime)
            night[m, default: 0] += hrs(f.nightTime)
            if blockHrs > 0 {
                sectors[m, default: 0] += 1
            }
        }

        let months = Set(block.keys).union(sim.keys).union(night.keys)
        return months.sorted().map {
            NDMonthlyActivity(month: $0, blockHours: block[$0] ?? 0, simHours: sim[$0] ?? 0, nightHours: night[$0] ?? 0, sectorCount: sectors[$0] ?? 0)
        }
    }

    private func computeDailyActivity(_ flights: [FlightEntity]) -> [NDDailyActivity] {
        let cal = Calendar.current
        let now = Date()
        guard let cutoff = cal.date(byAdding: .day, value: -35, to: now) else { return [] }

        var block: [Date: Double] = [:]
        var sim: [Date: Double] = [:]

        for f in flights {
            guard let date = f.date, date >= cutoff else { continue }
            let d = cal.startOfDay(for: date)
            block[d, default: 0] += hrs(f.blockTime)
            sim[d, default: 0]   += isSpInsOnly(f) ? 0 : hrs(f.simTime)
        }

        let days = Set(block.keys).union(sim.keys)
        return days.sorted().map {
            NDDailyActivity(day: $0, blockHours: block[$0] ?? 0, simHours: sim[$0] ?? 0)
        }
    }

    private func computeFleetHours(_ flights: [FlightEntity]) -> [NDFleetHours] {
        var hours: [String: Double] = [:]
        var sectors: [String: Int] = [:]

        for f in flights {
            let t = f.aircraftType ?? ""
            guard !t.isEmpty else { continue }
            hours[t, default: 0]   += hrs(f.blockTime)
            sectors[t, default: 0] += 1
        }

        return hours.map { NDFleetHours(aircraftType: $0.key, hours: $0.value, sectors: sectors[$0.key] ?? 0) }
            .sorted { $0.hours > $1.hours }
    }

    private func computePFRatioByMonth(_ flights: [FlightEntity]) -> [NDMonthlyPFRatio] {
        var pf: [Date: Int] = [:]
        var total: [Date: Int] = [:]

        for f in flights {
            guard let date = f.date else { continue }
            let m = monthStart(for: date)
            total[m, default: 0] += 1
            if f.isPilotFlying { pf[m, default: 0] += 1 }
        }

        return total.keys.sorted().map { m in
            NDMonthlyPFRatio(
                month: m,
                pfRatio: Double(pf[m] ?? 0) / Double(total[m] ?? 1),
                totalSectors: total[m] ?? 0
            )
        }
    }

    private func computeMonthlyNight(_ flights: [FlightEntity]) -> [NDMonthlyNight] {
        var night: [Date: Double] = [:]
        for f in flights {
            guard let date = f.date else { continue }
            night[monthStart(for: date), default: 0] += hrs(f.nightTime)
        }
        return night.keys.sorted().map { NDMonthlyNight(month: $0, nightHours: night[$0] ?? 0) }
    }

    private func computeTopRoutes(_ flights: [FlightEntity]) -> [NDRouteFrequency] {
        var counts: [String: (from: String, to: String, n: Int)] = [:]
        for f in flights {
            let from = f.fromAirport ?? ""; let to = f.toAirport ?? ""
            guard !from.isEmpty, !to.isEmpty else { continue }
            let key = "\(from)-\(to)"
            counts[key] = (from, to, (counts[key]?.n ?? 0) + 1)
        }
        return counts.values.sorted { $0.n > $1.n }.prefix(10)
            .map { NDRouteFrequency(from: $0.from, to: $0.to, sectors: $0.n) }
    }

    private func computeTopRegistrations(_ flights: [FlightEntity]) -> [NDRegistrationHours] {
        var data: [String: (reg: String, type: String, hours: Double, sectors: Int)] = [:]
        for f in flights {
            let reg = f.aircraftReg ?? ""; guard !reg.isEmpty else { continue }
            let current = data[reg]
            data[reg] = (reg, f.aircraftType ?? "", (current?.hours ?? 0) + hrs(f.blockTime), (current?.sectors ?? 0) + 1)
        }
        return data.values.sorted { $0.hours > $1.hours }.prefix(10)
            .map { NDRegistrationHours(registration: $0.reg, aircraftType: $0.type, hours: $0.hours, sectors: $0.sectors) }
    }

    private func computeApproachTypes(_ flights: [FlightEntity]) -> [NDApproachTypeStat] {
        var aiii = 0, ils = 0, rnp = 0, gls = 0, npa = 0, total = 0
        for f in flights {
            guard (f.dayLandings + f.nightLandings) > 0 else { continue }
            total += 1
            if f.isAIII { aiii += 1 }
            if f.isILS  { ils  += 1 }
            if f.isRNP  { rnp  += 1 }
            if f.isGLS  { gls  += 1 }
            if f.isNPA  { npa  += 1 }
        }
        guard total > 0 else { return [] }

        let d = Double(total)
        let raw: [(String, Int, Color)] = [
            ("AIII", aiii, .blue),
            ("ILS",  ils,  .green),
            ("RNP",  rnp,  .orange),
            ("GLS",  gls,  .purple),
            ("NPA",  npa,  .red)
        ]
        return raw.filter { $0.1 > 0 }
            .map { NDApproachTypeStat(typeName: $0.0, count: $0.1, percentage: Double($0.1) / d * 100, color: $0.2) }
            .sorted { $0.count > $1.count }
    }

    private func computeTLStats(_ flights: [FlightEntity]) -> NDTakeoffLandingStats {
        var dTO = 0, nTO = 0, dLDG = 0, nLDG = 0
        for f in flights {
            dTO  += Int(f.dayTakeoffs);  nTO  += Int(f.nightTakeoffs)
            dLDG += Int(f.dayLandings);  nLDG += Int(f.nightLandings)
        }
        return NDTakeoffLandingStats(dayTakeoffs: dTO, nightTakeoffs: nTO, dayLandings: dLDG, nightLandings: nLDG)
    }

    private func computeCareerStats(_ flights: [FlightEntity]) -> NDCareerStats {
        let block = flights.reduce(0.0) { $0 + hrs($1.blockTime) }
        let sim   = flights.reduce(0.0) { $0 + (isSpInsOnly($1) ? 0 : hrs($1.simTime)) }
        let aircraftTypes = Set(flights.compactMap { $0.aircraftType }.filter { !$0.isEmpty })
        return NDCareerStats(
            totalHours: block + sim,
            totalSectors: flights.count,
            totalAircraftTypes: aircraftTypes.count,
            firstFlightDate: flights.compactMap { $0.date }.min()
        )
    }

    // MARK: - FRMS Rolling Time Series

    /// Builds per-day rolling totals for each FRMS limit over the past 90 days
    /// plus all future rostered duty days, suitable for line/bar chart rendering.
    ///
    /// Past points use actual completed flights; future points use STD/STA scheduled times.
    /// Each point's `total` is the rolling sum for its window (e.g. 28 days) ending on that day.
    func computeFRMSRolling() -> NDFRMSRollingData {

        // MARK: Config
        let config: FRMSConfiguration
        if let data = UserDefaults.standard.data(forKey: "FRMSConfiguration"),
           let decoded = try? JSONDecoder().decode(FRMSConfiguration.self, from: data) {
            config = decoded
        } else {
            config = FRMSConfiguration(fleet: .a320B737, homeBase: "YSSY")
        }

        let fleet       = config.fleet
        let signOnMins  = config.signOnMinutesBeforeSTD
        let signOffMins = config.signOffMinutesAfterIN
        let periodDays  = fleet.flightTimePeriodDays

        let cal   = Calendar.current
        let today = cal.startOfDay(for: Date())

        // MARK: Fetch actual flights — go back far enough to feed all rolling windows
        // For the 365d chart we show seriesStart = today-365, and each point on that series
        // needs the full preceding 365-day window, so we must fetch back 365+365 = 730 days.
        guard let historyStart = cal.date(byAdding: .day, value: -730, to: today) else { return .empty }

        let histRequest: NSFetchRequest<FlightEntity> = FlightEntity.fetchRequest()
        histRequest.predicate = NSPredicate(
            format: "date >= %@ AND date <= %@",
            historyStart as NSDate, today as NSDate
        )
        histRequest.sortDescriptors = [NSSortDescriptor(key: "date", ascending: true)]

        let histEntities: [FlightEntity]
        do { histEntities = try viewContext.fetch(histRequest) } catch { return .empty }

        // Build [Date: (flightHours, dutyHours)] per calendar day from actual flights
        var actualFlight: [Date: Double] = [:]
        var actualDuty:   [Date: Double] = [:]

        for entity in histEntities {
            guard let entityDate = entity.date else { continue }
            let day = cal.startOfDay(for: entityDate)
            let bt  = hrs(entity.blockTime)
            let st  = isSpInsOnly(entity) ? 0.0 : hrs(entity.simTime)
            let fh  = bt + st
            actualFlight[day, default: 0] += fh
            // Duty per sector: flight time + margins (approximate; FRMSViewModel does exact grouping)
            if fh > 0 {
                actualDuty[day, default: 0] += fh + Double(signOnMins + signOffMins) / 60.0
            }
        }

        // MARK: Fetch future rostered flights
        let futureRequest: NSFetchRequest<FlightEntity> = FlightEntity.fetchRequest()
        futureRequest.predicate = NSPredicate(
            format: "date > %@ AND scheduledDeparture != %@ AND scheduledDeparture != nil AND (outTime == %@ OR outTime == nil)",
            today as NSDate, "", ""
        )
        futureRequest.sortDescriptors = [NSSortDescriptor(key: "date", ascending: true)]

        let futureEntities: [FlightEntity]
        do { futureEntities = try viewContext.fetch(futureRequest) } catch { return .empty }

        // Parse "HH:MM" or "HHMM" → minutes from midnight
        func hhmm(_ s: String?) -> Int? {
            guard let s = s else { return nil }
            let clean = s.replacingOccurrences(of: ":", with: "")
            guard clean.count == 4, let v = Int(clean) else { return nil }
            return (v / 100) * 60 + (v % 100)
        }

        func blockFromSTDSTA(std: String, sta: String) -> Double {
            guard let d = hhmm(std), let a = hhmm(sta) else { return 0 }
            let diff = a >= d ? a - d : (1440 - d) + a
            return Double(diff) / 60.0
        }

        // Group future sectors by day → (flightHours, dutyHours)
        var futureFlight: [Date: Double] = [:]
        var futureDuty:   [Date: Double] = [:]
        var futureFirstSTD: [Date: Int]  = [:]
        var futureLastSTA:  [Date: Int]  = [:]

        for entity in futureEntities {
            guard let entityDate = entity.date,
                  let std = entity.scheduledDeparture, !std.isEmpty,
                  let sta = entity.scheduledArrival, !sta.isEmpty,
                  let stdMins = hhmm(std), let staMins = hhmm(sta)
            else { continue }

            let day = cal.startOfDay(for: entityDate)
            let bh  = blockFromSTDSTA(std: std, sta: sta)
            guard bh > 0 else { continue }

            futureFlight[day, default: 0] += bh
            futureFirstSTD[day] = min(futureFirstSTD[day] ?? stdMins, stdMins)
            futureLastSTA[day]  = max(futureLastSTA[day]  ?? staMins, staMins)
        }

        // Compute duty hours per future day
        for day in futureFlight.keys {
            guard let firstSTD = futureFirstSTD[day], let lastSTA = futureLastSTA[day] else { continue }
            let raw = lastSTA >= firstSTD ? lastSTA - firstSTD : (1440 - firstSTD) + lastSTA
            futureDuty[day] = Double(raw + signOnMins + signOffMins) / 60.0
        }

        let lastFutureDay = futureFlight.keys.max() ?? today

        // MARK: Build rolling series for each limit
        //
        // Chart range per series: today - windowDays ... today + windowDays
        // (capped at lastFutureDay so 365d chart doesn't show a year of empty future)
        // Today sits in the centre; past half = history that built up the current total,
        // future half = where the roster takes it.

        func rollingSum(
            day D: Date,
            windowDays: Int,
            actualDict: [Date: Double],
            futureDict: [Date: Double]
        ) -> Double {
            guard let windowStart = cal.date(byAdding: .day, value: -(windowDays - 1), to: D) else { return 0 }
            var total = 0.0
            for (date, val) in actualDict where date >= windowStart && date <= min(D, today) {
                total += val
            }
            for (date, val) in futureDict where date > today && date >= windowStart && date <= D {
                total += val
            }
            return total
        }

        func buildSeries(
            label: String,
            limit: Double,
            warnAt: Double,
            windowDays: Int,
            actualDict: [Date: Double],
            futureDict: [Date: Double]
        ) -> NDFRMSRollingSeries {
            guard let seriesStart = cal.date(byAdding: .day, value: -windowDays, to: today),
                  let idealEnd    = cal.date(byAdding: .day, value:  windowDays, to: today) else {
                return NDFRMSRollingSeries(limitLabel: label, limit: limit, warnAt: warnAt,
                                           points: [], fleet: fleet, chartStart: today, chartEnd: today)
            }
            // Cap future end at last rostered duty (no point showing empty future beyond roster)
            let seriesEnd = min(idealEnd, max(lastFutureDay, today))

            var points: [NDFRMSRollingPoint] = []
            var cursor = seriesStart
            var sevenDayCounter = 0

            while cursor <= seriesEnd {
                let isPast      = cursor <= today
                let isFuture    = cursor > today
                let hasActivity = isPast
                    ? (actualDict[cursor] ?? 0) > 0
                    : (futureDict[cursor] ?? 0) > 0

                // Emit: any active day, every-7-days anchor in past, and today always
                let isToday     = cal.isDate(cursor, inSameDayAs: today)
                let shouldEmit  = hasActivity
                    || isToday
                    || (isPast && sevenDayCounter % 7 == 0)
                    || (isFuture && hasActivity)

                if shouldEmit {
                    let total = rollingSum(day: cursor, windowDays: windowDays,
                                           actualDict: actualDict, futureDict: futureDict)
                    points.append(NDFRMSRollingPoint(date: cursor, total: total, isProjected: isFuture))
                }

                cursor = cal.date(byAdding: .day, value: 1, to: cursor) ?? cursor
                if isPast { sevenDayCounter += 1 }
            }

            return NDFRMSRollingSeries(
                limitLabel: label,
                limit: limit,
                warnAt: warnAt,
                points: points.sorted { $0.date < $1.date },
                fleet: fleet,
                chartStart: seriesStart,
                chartEnd: seriesEnd
            )
        }

        let warnFrac = config.showWarningsAtPercentage

        let flight28 = buildSeries(
            label: "\(periodDays)-Day Flight",
            limit: fleet.maxFlightTime28Days,
            warnAt: fleet.maxFlightTime28Days * warnFrac,
            windowDays: periodDays,
            actualDict: actualFlight,
            futureDict: futureFlight
        )

        let flight365 = buildSeries(
            label: "365-Day Flight",
            limit: fleet.maxFlightTime365Days,
            warnAt: fleet.maxFlightTime365Days * warnFrac,
            windowDays: 365,
            actualDict: actualFlight,
            futureDict: futureFlight
        )

        let duty7 = buildSeries(
            label: "7-Day Duty",
            limit: fleet.maxDutyTime7Days,
            warnAt: fleet.maxDutyTime7Days * warnFrac,
            windowDays: 7,
            actualDict: actualDuty,
            futureDict: futureDuty
        )

        let limit14 = fleet.maxDutyTime14DaysInitial ?? fleet.maxDutyTime14Days
        let duty14 = buildSeries(
            label: "14-Day Duty",
            limit: limit14,
            warnAt: limit14 * warnFrac,
            windowDays: 14,
            actualDict: actualDuty,
            futureDict: futureDuty
        )

        var flight7: NDFRMSRollingSeries? = nil
        if let max7d = fleet.maxFlightTime7Days {
            flight7 = buildSeries(
                label: "7-Day Flight",
                limit: max7d,
                warnAt: max7d * warnFrac,
                windowDays: 7,
                actualDict: actualFlight,
                futureDict: futureFlight
            )
        }

        return NDFRMSRollingData(
            flight28d:  flight28,
            flight365d: flight365,
            duty7d:     duty7,
            duty14d:    duty14,
            flight7d:   flight7
        )
    }

    // MARK: - Projected FRMS (accurate rolling-window peak)

    /// Computes the PEAK rolling total for each FRMS limit across all future duty days.
    ///
    /// For each future duty day D, the rolling total on that day is:
    ///   actual hours in [D - (window-1), today]  +  projected hours in (today, D]
    ///
    /// We report max(rolling total) across all D — the highest your total will reach
    /// if all rostered duties are flown. This is what gets overlaid on the gauge bar.
    func computeProjectedFRMS() -> NDProjectedFRMSData {

        // MARK: Config
        let config: FRMSConfiguration
        if let data = UserDefaults.standard.data(forKey: "FRMSConfiguration"),
           let decoded = try? JSONDecoder().decode(FRMSConfiguration.self, from: data) {
            config = decoded
        } else {
            config = FRMSConfiguration(fleet: .a320B737, homeBase: "YSSY")
        }

        let signOnMins  = config.signOnMinutesBeforeSTD
        let signOffMins = config.signOffMinutesAfterIN
        let fleet       = config.fleet
        let periodDays  = fleet.flightTimePeriodDays   // 28 (SH) or 30 (LH)

        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())

        // MARK: Helpers

        // Parse "HH:MM" or "HHMM" → minutes from midnight
        func hhmm(_ s: String?) -> Int? {
            guard let s = s else { return nil }
            let clean = s.replacingOccurrences(of: ":", with: "")
            guard clean.count == 4, let v = Int(clean) else { return nil }
            return (v / 100) * 60 + (v % 100)
        }

        func blockHours(std: String, sta: String) -> Double {
            guard let d = hhmm(std), let a = hhmm(sta) else { return 0 }
            let diff = a >= d ? a - d : (1440 - d) + a
            return Double(diff) / 60.0
        }

        // MARK: Fetch historical actual flights (up to 365 days back)
        // Build [Date: (flightHours, dutyHours)] keyed by start-of-day
        // We need actual data going back (periodDays - 1) days before the last future duty.
        // Using 365 days covers all windows.

        let historicalRequest: NSFetchRequest<FlightEntity> = FlightEntity.fetchRequest()
        guard let lookbackStart = cal.date(byAdding: .day, value: -365, to: today) else { return .empty }
        historicalRequest.predicate = NSPredicate(
            format: "date >= %@ AND date <= %@ AND (blockTime != %@ OR outTime != %@)",
            lookbackStart as NSDate, today as NSDate, "", ""
        )
        historicalRequest.sortDescriptors = [NSSortDescriptor(key: "date", ascending: true)]

        let historicalEntities: [FlightEntity]
        do {
            historicalEntities = try viewContext.fetch(historicalRequest)
        } catch {
            return .empty
        }

        // Aggregate actual flight hours per calendar day
        var actualFlightByDay: [Date: Double] = [:]
        var actualDutyByDay:   [Date: Double] = [:]

        for entity in historicalEntities {
            guard let entityDate = entity.date else { continue }
            let day = cal.startOfDay(for: entityDate)
            actualFlightByDay[day, default: 0] += hrs(entity.blockTime)
            // Duty: approximate from sign-on/off offsets around actual OUT/IN
            // For simplicity use block time + margins as duty contribution per sector
            // (FRMSViewModel does the accurate grouping; we just need relative daily totals here)
            let bt = hrs(entity.blockTime) + hrs(entity.simTime)
            actualDutyByDay[day, default: 0] += bt > 0 ? bt + Double(signOnMins + signOffMins) / 60.0 : 0
        }

        // MARK: Fetch future rostered flights (no OUT time, STD set, date > today)
        let futureRequest: NSFetchRequest<FlightEntity> = FlightEntity.fetchRequest()
        futureRequest.predicate = NSPredicate(
            format: "date > %@ AND scheduledDeparture != %@ AND scheduledDeparture != nil AND (outTime == %@ OR outTime == nil)",
            today as NSDate, "", ""
        )
        futureRequest.sortDescriptors = [NSSortDescriptor(key: "date", ascending: true)]

        let futureEntities: [FlightEntity]
        do {
            futureEntities = try viewContext.fetch(futureRequest)
        } catch {
            return .empty
        }

        guard !futureEntities.isEmpty else { return .empty }

        // Group future sectors by day
        struct FutureDayData {
            let date: Date          // start-of-day
            let flightHours: Double
            let dutyHours: Double
        }

        // Build per-day aggregates for future duties
        var futureByDay: [Date: (flight: Double, duty: Double, firstSTD: Int, lastSTA: Int)] = [:]

        for entity in futureEntities {
            guard let entityDate = entity.date,
                  let std = entity.scheduledDeparture, !std.isEmpty,
                  let sta = entity.scheduledArrival, !sta.isEmpty,
                  let stdMins = hhmm(std),
                  let staMins = hhmm(sta)
            else { continue }

            let day = cal.startOfDay(for: entityDate)
            let bh  = blockHours(std: std, sta: sta)
            guard bh > 0 else { continue }

            if var existing = futureByDay[day] {
                existing = (
                    flight:   existing.flight + bh,
                    duty:     existing.duty,            // recalculated below
                    firstSTD: min(existing.firstSTD, stdMins),
                    lastSTA:  max(existing.lastSTA, staMins)
                )
                futureByDay[day] = existing
            } else {
                futureByDay[day] = (flight: bh, duty: 0, firstSTD: stdMins, lastSTA: staMins)
            }
        }

        // Calculate duty hours per future day from first STD → last STA + margins
        var futureDays: [FutureDayData] = []
        for (day, data) in futureByDay {
            let rawMins = data.lastSTA >= data.firstSTD
                ? data.lastSTA - data.firstSTD
                : (1440 - data.firstSTD) + data.lastSTA
            let dutyHours = Double(rawMins + signOnMins + signOffMins) / 60.0
            futureDays.append(FutureDayData(date: day, flightHours: data.flight, dutyHours: dutyHours))
        }
        futureDays.sort { $0.date < $1.date }

        // MARK: Rolling peak calculation
        // For each future duty day D, compute rolling totals ending on D and track the peak.

        var peakFlight7d:   Double = 0
        var peakFlight28d:  Double = 0
        var peakFlight365d: Double = 0
        var peakDuty7d:     Double = 0
        var peakDuty14d:    Double = 0

        // Helper: sum actual hours in [windowStart, today]
        func actualFlightSum(windowStart: Date) -> Double {
            actualFlightByDay.filter { $0.key >= windowStart && $0.key <= today }.values.reduce(0, +)
        }
        func actualDutySum(windowStart: Date) -> Double {
            actualDutyByDay.filter { $0.key >= windowStart && $0.key <= today }.values.reduce(0, +)
        }

        // Helper: sum future projected hours in (today, throughDay] that are within windowStart
        func projectedFlightSum(windowStart: Date, throughDay: Date) -> Double {
            futureDays.filter { $0.date > today && $0.date >= windowStart && $0.date <= throughDay }
                      .reduce(0) { $0 + $1.flightHours }
        }
        func projectedDutySum(windowStart: Date, throughDay: Date) -> Double {
            futureDays.filter { $0.date > today && $0.date >= windowStart && $0.date <= throughDay }
                      .reduce(0) { $0 + $1.dutyHours }
        }

        for day in futureDays {
            let D = day.date

            // Flight 7-day window ending on D (LH fleet only)
            if fleet.maxFlightTime7Days != nil {
                let ws = cal.date(byAdding: .day, value: -6, to: D) ?? D
                let rolling = actualFlightSum(windowStart: ws) + projectedFlightSum(windowStart: ws, throughDay: D)
                peakFlight7d = max(peakFlight7d, rolling)
            }

            // Flight 28/30-day window ending on D
            let ws28 = cal.date(byAdding: .day, value: -(periodDays - 1), to: D) ?? D
            let rolling28 = actualFlightSum(windowStart: ws28) + projectedFlightSum(windowStart: ws28, throughDay: D)
            peakFlight28d = max(peakFlight28d, rolling28)

            // Flight 365-day window ending on D
            let ws365 = cal.date(byAdding: .day, value: -364, to: D) ?? D
            let rolling365 = actualFlightSum(windowStart: ws365) + projectedFlightSum(windowStart: ws365, throughDay: D)
            peakFlight365d = max(peakFlight365d, rolling365)

            // Duty 7-day window ending on D
            let ws7d = cal.date(byAdding: .day, value: -6, to: D) ?? D
            let rollingDuty7 = actualDutySum(windowStart: ws7d) + projectedDutySum(windowStart: ws7d, throughDay: D)
            peakDuty7d = max(peakDuty7d, rollingDuty7)

            // Duty 14-day window ending on D
            let ws14 = cal.date(byAdding: .day, value: -13, to: D) ?? D
            let rollingDuty14 = actualDutySum(windowStart: ws14) + projectedDutySum(windowStart: ws14, throughDay: D)
            peakDuty14d = max(peakDuty14d, rollingDuty14)
        }

        return NDProjectedFRMSData(
            flightHours7d:   peakFlight7d,
            flightHours28d:  peakFlight28d,
            flightHours365d: peakFlight365d,
            dutyHours7d:     peakDuty7d,
            dutyHours14d:    peakDuty14d
        )
    }

    private func computeFRMSStrip(_ flights: [FlightEntity]) -> NDFRMSStripData {
        let cal = Calendar.current
        let now = Date()
        guard let ago7   = cal.date(byAdding: .day, value: -7,   to: now),
              let ago28  = cal.date(byAdding: .day, value: -28,  to: now),
              let ago365 = cal.date(byAdding: .day, value: -365, to: now) else { return .empty }

        var h7 = 0.0, h28 = 0.0, h365 = 0.0
        for f in flights {
            guard let date = f.date else { continue }
            let total = hrs(f.blockTime) + (isSpInsOnly(f) ? 0 : hrs(f.simTime))
            if date >= ago7   { h7   += total }
            if date >= ago28  { h28  += total }
            if date >= ago365 { h365 += total }
        }

        let fleet: FRMSFleet
        if let data   = UserDefaults.standard.data(forKey: "FRMSConfiguration"),
           let config = try? JSONDecoder().decode(FRMSConfiguration.self, from: data) {
            fleet = config.fleet
        } else {
            fleet = .a320B737
        }

        return NDFRMSStripData(hours7d: h7, hours28d: h28, hours365d: h365, fleet: fleet)
    }
}
