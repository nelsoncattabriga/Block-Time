import SwiftUI
import CoreData

// MARK: - Raw Database Viewer

struct RawDatabaseView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(
        entity: FlightEntity.entity(),
        sortDescriptors: [NSSortDescriptor(key: "date", ascending: false)],
        predicate: nil,
        animation: .default
    )
    private var flights: FetchedResults<FlightEntity>

    @State private var selectedObjectID: NSManagedObjectID?
    @State private var searchText = ""

    private var filtered: [FlightEntity] {
        guard !searchText.isEmpty else { return Array(flights) }
        let q = searchText.lowercased()
        return flights.filter {
            ($0.flightNumber ?? "").lowercased().contains(q) ||
            ($0.fromAirport ?? "").lowercased().contains(q) ||
            ($0.toAirport ?? "").lowercased().contains(q) ||
            ($0.aircraftReg ?? "").lowercased().contains(q)
        }
    }

    var body: some View {
        List(filtered, id: \.objectID) { flight in
            Button {
                selectedObjectID = flight.objectID
            } label: {
                RawFlightRow(flight: flight)
            }
            .buttonStyle(.plain)
        }
        .searchable(text: $searchText, prompt: "Flight, route, registration")
        .navigationTitle("Raw Database (\(flights.count))")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: Binding(
            get: { selectedObjectID != nil },
            set: { if !$0 { selectedObjectID = nil } }
        )) {
            if let oid = selectedObjectID,
               let flight = try? viewContext.existingObject(with: oid) as? FlightEntity {
                RawFlightDetailSheet(flight: flight, onDeleted: {
                    selectedObjectID = nil
                })
                .environment(\.managedObjectContext, viewContext)
            }
        }
    }
}

// MARK: - Row

private struct RawFlightRow: View {
    let flight: FlightEntity

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "dd MMM yyyy"
        return f
    }()

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(flight.date.map { Self.dateFormatter.string(from: $0) } ?? "No date")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    if let fn = flight.flightNumber, !fn.isEmpty {
                        Text(fn)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                Text("\(flight.fromAirport ?? "???") → \(flight.toAirport ?? "???")")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(flight.blockTime ?? "—")
                    .font(.subheadline.monospacedDigit())
                    .fontWeight(.medium)
                if let sim = flight.simTime, sim != "0.0", sim != "0.00", sim != "0", !sim.isEmpty {
                    Text("SIM")
                        .font(.footnote)
                        .foregroundColor(.purple)
                }
            }
            Image(systemName: "chevron.right")
                .font(.footnote)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Detail Sheet

struct RawFlightDetailSheet: View {
    let flight: FlightEntity
    let onDeleted: () -> Void

    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @State private var showDeleteConfirm = false

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()

    var body: some View {
        NavigationStack {
            List {
                rawSection("Identity") {
                    rawRow("id", flight.id?.uuidString)
                    rawRow("importSessionID", flight.importSessionID?.uuidString)
                    rawRow("createdAt", flight.createdAt.map { Self.dateFormatter.string(from: $0) })
                    rawRow("modifiedAt", flight.modifiedAt.map { Self.dateFormatter.string(from: $0) })
                    rawRow("importedAt", flight.importedAt.map { Self.dateFormatter.string(from: $0) })
                }

                rawSection("Flight") {
                    rawRow("date", flight.date.map { Self.dateFormatter.string(from: $0) })
                    rawRow("flightNumber", flight.flightNumber)
                    rawRow("fromAirport", flight.fromAirport)
                    rawRow("toAirport", flight.toAirport)
                    rawRow("aircraftType", flight.aircraftType)
                    rawRow("aircraftReg", flight.aircraftReg)
                    rawRow("outTime", flight.outTime)
                    rawRow("inTime", flight.inTime)
                    rawRow("scheduledDeparture", flight.scheduledDeparture)
                    rawRow("scheduledArrival", flight.scheduledArrival)
                    rawRow("isPositioning", String(flight.isPositioning))
                    rawRow("isPilotFlying", String(flight.isPilotFlying))
                }

                rawSection("Times") {
                    rawRow("blockTime", flight.blockTime)
                    rawRow("simTime", flight.simTime)
                    rawRow("nightTime", flight.nightTime)
                    rawRow("instrumentTime", flight.instrumentTime)
                    rawRow("p1Time", flight.p1Time)
                    rawRow("p1usTime", flight.p1usTime)
                    rawRow("p2Time", flight.p2Time)
                    rawRow("spInsTime", flight.spInsTime)
                }

                rawSection("T/O & Ldg") {
                    rawRow("dayTakeoffs", String(flight.dayTakeoffs))
                    rawRow("nightTakeoffs", String(flight.nightTakeoffs))
                    rawRow("dayLandings", String(flight.dayLandings))
                    rawRow("nightLandings", String(flight.nightLandings))
                    rawRow("isILS", String(flight.isILS))
                    rawRow("isGLS", String(flight.isGLS))
                    rawRow("isRNP", String(flight.isRNP))
                    rawRow("isNPA", String(flight.isNPA))
                    rawRow("isAIII", String(flight.isAIII))
                }

                rawSection("Crew") {
                    rawRow("captainName", flight.captainName)
                    rawRow("foName", flight.foName)
                    rawRow("so1Name", flight.so1Name)
                    rawRow("so2Name", flight.so2Name)
                }

                rawSection("Other") {
                    rawRow("customCount", String(flight.customCount))
                    rawRow("remarks", flight.remarks)
                }

                Section {
                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        Label("Delete This Record", systemImage: "trash")
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
            }
            .navigationTitle("Raw Record")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .alert("Delete Record?", isPresented: $showDeleteConfirm) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    viewContext.delete(flight)
                    try? viewContext.save()
                    NotificationCenter.default.post(name: .flightDataChanged, object: nil)
                    onDeleted()
                    dismiss()
                }
            } message: {
                Text("This permanently deletes the Core Data record. This cannot be undone.")
            }
        }
    }

    @ViewBuilder
    private func rawSection(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        Section(title) {
            content()
        }
    }

    private func rawRow(_ key: String, _ value: String?) -> some View {
        HStack(alignment: .top) {
            Text(key)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 140, alignment: .leading)
            Text(value ?? "nil")
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(value == nil ? .secondary : .primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
        }
        .padding(.vertical, 1)
    }
}
