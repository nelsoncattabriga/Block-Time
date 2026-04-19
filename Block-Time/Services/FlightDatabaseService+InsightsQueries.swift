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

    /// Returns all analytics for the Insights dashboard on a background context.
    /// All Core Data fetching and computation runs off the main thread; only value types are returned.
    func getInsightsData() async -> NDInsightsData {
        await withCheckedContinuation { continuation in
            persistentContainer.performBackgroundTask { context in
                context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy

                let stats = self.getFlightStatistics(context: context)

                let request: NSFetchRequest<FlightEntity> = FlightEntity.fetchRequest()
                request.predicate = NSPredicate(
                    format: "((blockTime != %@ AND blockTime != %@ AND blockTime != %@) OR (simTime != %@ AND simTime != %@ AND simTime != %@)) AND flightNumber != %@",
                    "0", "0.0", "0.00", "0", "0.0", "0.00", "SUMMARY"
                )
                request.sortDescriptors = [NSSortDescriptor(key: "date", ascending: true)]

                let flights: [FlightEntity]
                do {
                    flights = try context.fetch(request)
                } catch {
                    continuation.resume(returning: NDInsightsData(
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
                    ))
                    return
                }

                let result = NDInsightsData(
                    flightStatistics: stats,
                    monthlyActivity: self.computeMonthlyActivity(flights),
                    dailyActivity: self.computeDailyActivity(flights),
                    fleetHours: self.computeFleetHours(flights),
                    pfRatioByMonth: self.computePFRatioByMonth(flights),
                    monthlyNight: self.computeMonthlyNight(flights),
                    topRoutes: self.computeTopRoutes(flights),
                    topRegistrations: self.computeTopRegistrations(flights),
                    approachTypes: self.computeApproachTypes(flights),
                    tlStats: self.computeTLStats(flights),
                    careerStats: self.computeCareerStats(flights),
                    frmsStrip: self.computeFRMSStrip(flights),
                    projectedFRMS: self.computeProjectedFRMS(context: context),
                    frmsRolling: self.computeFRMSRolling(context: context)
                )
                continuation.resume(returning: result)
            }
        }
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
        let countSimInTotal = UserDefaults.standard.object(forKey: "countSimInTotal") as? Bool ?? true
        var hours: [String: Double] = [:]
        var sectors: [String: Int] = [:]

        for f in flights {
            let t = f.aircraftType ?? ""
            guard !t.isEmpty else { continue }
            let blockTime = hrs(f.blockTime)
            let simTime = isSpInsOnly(f) ? 0 : hrs(f.simTime)
            hours[t, default: 0] += blockTime > 0 ? blockTime : (countSimInTotal ? simTime : 0)
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
        var airports = Set<String>()
        for f in flights {
            if let a = f.fromAirport, !a.isEmpty { airports.insert(a) }
            if let a = f.toAirport,   !a.isEmpty { airports.insert(a) }
        }
        return NDCareerStats(
            totalBlockHours: block,
            totalSIMHours: sim,
            totalSectors: flights.count,
            totalAircraftTypes: aircraftTypes.count,
            totalAirports: airports.count,
            firstFlightDate: flights.compactMap { $0.date }.min()
        )
    }

    // MARK: - FRMS Rolling Time Series

    /// Builds per-day rolling totals for each FRMS limit over the past 90 days
    /// plus all future rostered duty days, suitable for line/bar chart rendering.
    ///
    /// Past points use actual completed flights; future points use STD/STA scheduled times.
    /// Each point's `total` is the rolling sum for its window (e.g. 28 days) ending on that day.
    func computeFRMSRolling(context: NSManagedObjectContext? = nil) -> NDFRMSRollingData {
        let ctx = context ?? viewContext

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
        do { histEntities = try ctx.fetch(histRequest) } catch { return .empty }

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
        do { futureEntities = try ctx.fetch(futureRequest) } catch { return .empty }

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

            // Build a day-by-day sorted array of all values so we can use a sliding window
            // rather than iterating the full dict on every point (O(n) total vs O(n²)).
            let allDays: [(date: Date, value: Double, isFuture: Bool)] = {
                var result: [(Date, Double, Bool)] = []
                for (d, v) in actualDict where v > 0 { result.append((d, v, false)) }
                for (d, v) in futureDict  where v > 0 { result.append((d, v, true)) }
                return result.sorted { $0.0 < $1.0 }
            }()

            var points: [NDFRMSRollingPoint] = []
            var runningTotal = 0.0
            // addTail: next index to be consumed into runningTotal (entries with date <= cursor)
            // evictHead: next index to be evicted when it falls outside the window floor
            var addTail   = 0
            var evictHead = 0
            var cursor = seriesStart

            while cursor <= seriesEnd {
                let isFuture = cursor > today

                // Add entries whose date falls on or before cursor
                while addTail < allDays.count && allDays[addTail].date <= cursor {
                    let entry = allDays[addTail]
                    // Past cursor: only count actual (non-projected) values.
                    // Future cursor: count everything (actual history + projected future).
                    let shouldCount = isFuture ? true : !entry.isFuture
                    if shouldCount { runningTotal += entry.value }
                    addTail += 1
                }

                // Evict entries that have fallen outside the rolling window floor
                guard let windowFloor = cal.date(byAdding: .day, value: -(windowDays - 1), to: cursor) else {
                    cursor = cal.date(byAdding: .day, value: 1, to: cursor) ?? cursor
                    continue
                }
                while evictHead < addTail && allDays[evictHead].date < windowFloor {
                    let entry = allDays[evictHead]
                    let wasCounted = isFuture ? true : !entry.isFuture
                    if wasCounted { runningTotal -= entry.value }
                    evictHead += 1
                }

                points.append(NDFRMSRollingPoint(date: cursor, total: max(runningTotal, 0), isProjected: isFuture))
                cursor = cal.date(byAdding: .day, value: 1, to: cursor) ?? cursor
            }

            return NDFRMSRollingSeries(
                limitLabel: label,
                limit: limit,
                warnAt: warnAt,
                points: points,
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
    func computeProjectedFRMS(context: NSManagedObjectContext? = nil) -> NDProjectedFRMSData {
        let ctx = context ?? viewContext

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
            historicalEntities = try ctx.fetch(historicalRequest)
        } catch {
            return .empty
        }

        // Aggregate actual flight hours per calendar day.
        // For duty, track the span per day using first STD (duty start anchor) and last actual IN
        // (duty end anchor), matching the FRMS calculation: duty = (firstSTD - signOn) → (lastIN + signOff).
        // Multi-sector days receive only one set of sign-on/off margins.
        var actualFlightByDay: [Date: Double] = [:]
        var actualDutySpanByDay: [Date: (firstSTD: Int, lastIN: Int)] = [:]

        for entity in historicalEntities {
            guard let entityDate = entity.date else { continue }
            let day = cal.startOfDay(for: entityDate)
            actualFlightByDay[day, default: 0] += hrs(entity.blockTime)

            // Duty start: STD (always used as sign-on anchor per FRMS rules)
            // Duty end: actual IN time; fall back to STA if IN not recorded
            let inStr  = (entity.inTime?.isEmpty  == false) ? entity.inTime  : entity.scheduledArrival
            guard let stdMins = hhmm(entity.scheduledDeparture), let inMins = hhmm(inStr) else { continue }

            if var span = actualDutySpanByDay[day] {
                span.firstSTD = min(span.firstSTD, stdMins)
                span.lastIN   = max(span.lastIN,   inMins)
                actualDutySpanByDay[day] = span
            } else {
                actualDutySpanByDay[day] = (firstSTD: stdMins, lastIN: inMins)
            }
        }

        // Convert spans → duty hours: (lastIN - firstSTD) + signOn + signOff, once per day
        var actualDutyByDay: [Date: Double] = [:]
        for (day, span) in actualDutySpanByDay {
            let rawMins = span.lastIN >= span.firstSTD
                ? span.lastIN - span.firstSTD
                : (1440 - span.firstSTD) + span.lastIN
            actualDutyByDay[day] = Double(rawMins + signOnMins + signOffMins) / 60.0
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
            futureEntities = try ctx.fetch(futureRequest)
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

        // Build per-day aggregates for future duties.
        // Sectors are sorted chronologically. When the gap between the previous sector's STA
        // and the next sector's STD exceeds 10 hours (600 mins), treat as a separate duty period.
        // This handles days with an early-morning arrival followed by a separate evening departure.
        let minRestMins = 600 // 10 hours minimum rest between duties

        // Store multiple duty segments per calendar day: [(firstSTD, lastSTA, flightHours)]
        var futureByDay: [Date: [(firstSTD: Int, lastSTA: Int, flight: Double)]] = [:]

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


            if var segments = futureByDay[day] {
                // Check gap from last segment's STA to this sector's STD
                let lastSTA = segments[segments.count - 1].lastSTA
                // Gap calculation handles overnight (STD next day > STA same day)
                let gap = stdMins >= lastSTA
                    ? stdMins - lastSTA
                    : (1440 - lastSTA) + stdMins

                if gap >= minRestMins {
                    // Rest period — start a new duty segment
                    segments.append((firstSTD: stdMins, lastSTA: staMins, flight: bh))
                } else {
                    // Same duty — extend the last segment
                    var last = segments[segments.count - 1]
                    last.lastSTA = staMins
                    last.flight += bh
                    segments[segments.count - 1] = last
                }
                futureByDay[day] = segments
            } else {
                futureByDay[day] = [(firstSTD: stdMins, lastSTA: staMins, flight: bh)]
            }
        }

        // Calculate duty hours per future day — sum across all duty segments on that day
        var futureDays: [FutureDayData] = []
        for (day, segments) in futureByDay {
            var totalFlight = 0.0
            var totalDuty   = 0.0
            for seg in segments {
                let rawMins = seg.lastSTA >= seg.firstSTD
                    ? seg.lastSTA - seg.firstSTD
                    : (1440 - seg.firstSTD) + seg.lastSTA
                totalDuty   += Double(rawMins + signOnMins + signOffMins) / 60.0
                totalFlight += seg.flight
            }
            futureDays.append(FutureDayData(date: day, flightHours: totalFlight, dutyHours: totalDuty))
        }
        futureDays.sort { $0.date < $1.date }

        // MARK: Rolling peak calculation
        // Evaluate every calendar day from tomorrow through the last rostered day so that
        // windows ending on gap days (no duty) are also checked. The peak rolling total
        // can occur on a day between roster entries as flights drop off the back of the window.

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

        guard let lastRosteredDay = futureDays.last?.date,
              let tomorrow = cal.date(byAdding: .day, value: 1, to: today) else {
            return NDProjectedFRMSData(
                flightHours7d: peakFlight7d, flightHours28d: peakFlight28d,
                flightHours365d: peakFlight365d, dutyHours7d: peakDuty7d, dutyHours14d: peakDuty14d
            )
        }

        var D = tomorrow
        while D <= lastRosteredDay {
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

            D = cal.date(byAdding: .day, value: 1, to: D) ?? lastRosteredDay
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
