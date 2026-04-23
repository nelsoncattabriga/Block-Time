//
//  FrozenColumnSpreadsheetView.swift
//  Block-Time
//

import SwiftUI
import UIKit

// MARK: - SwiftUI wrapper

struct FrozenColumnSpreadsheetView: UIViewRepresentable {

    let flights: [FlightSector]
    let highlightedFlightID: UUID?
    let displayConfig: SpreadsheetDisplayConfig
    var onTap: (FlightSector) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> SpreadsheetContainerView {
        let view = SpreadsheetContainerView()
        view.coordinator = context.coordinator
        context.coordinator.container = view
        view.configure(flights: flights, config: displayConfig, highlightedID: highlightedFlightID)
        return view
    }

    func updateUIView(_ uiView: SpreadsheetContainerView, context: Context) {
        context.coordinator.parent = self
        uiView.update(flights: flights, config: displayConfig, highlightedID: highlightedFlightID)
    }
}

// MARK: - Display config

struct SpreadsheetDisplayConfig: Equatable {
    let useLocalTime: Bool
    let useIATA: Bool
    let showHHMM: Bool
    let roundingMode: RoundingMode
}

// MARK: - Coordinator

extension FrozenColumnSpreadsheetView {

    final class Coordinator: NSObject, UITableViewDataSource, UITableViewDelegate, UIScrollViewDelegate {

        var parent: FrozenColumnSpreadsheetView
        weak var container: SpreadsheetContainerView?
        private var isSyncing = false

        init(_ parent: FrozenColumnSpreadsheetView) {
            self.parent = parent
        }

        // MARK: UITableViewDataSource

        func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
            parent.flights.count
        }

        func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
            guard let container else { return UITableViewCell() }
            let flight = parent.flights[indexPath.row]
            let highlighted = flight.id == parent.highlightedFlightID
            let config = parent.displayConfig

            if tableView === container.leftTable {
                let cell = tableView.dequeueReusableCell(withIdentifier: LeftCell.reuseID, for: indexPath) as! LeftCell
                cell.configure(flight: flight, index: indexPath.row, highlighted: highlighted, config: config)
                return cell
            } else {
                let cell = tableView.dequeueReusableCell(withIdentifier: RightCell.reuseID, for: indexPath) as! RightCell
                cell.configure(flight: flight, index: indexPath.row, highlighted: highlighted, config: config)
                return cell
            }
        }

        // MARK: UITableViewDelegate

        func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
            Col.rowHeight
        }

        func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
            tableView.deselectRow(at: indexPath, animated: false)
            let flight = parent.flights[indexPath.row]
            parent.onTap(flight)
        }

        // MARK: Scroll sync

        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            guard !isSyncing, let container else { return }
            isSyncing = true

            // Vertical sync between the two tables
            let y = scrollView.contentOffset.y
            if scrollView === container.leftTable {
                if abs(container.rightTable.contentOffset.y - y) > 0.5 {
                    container.rightTable.setContentOffset(CGPoint(x: container.rightTable.contentOffset.x, y: y), animated: false)
                }
            } else if scrollView === container.rightTable {
                if abs(container.leftTable.contentOffset.y - y) > 0.5 {
                    container.leftTable.setContentOffset(CGPoint(x: 0, y: y), animated: false)
                }
            }

            // Horizontal sync: pan the right header content to match rightHScroll's horizontal offset
            if scrollView === container.rightHScroll || scrollView === container.rightTable {
                let x = container.rightHScroll.contentOffset.x
                container.rightHeaderView?.subviews.first?.frame.origin.x = -x
            }

            isSyncing = false
        }
    }
}

// MARK: - Column constants (shared by container + cells)

enum Col {
    static let date:      CGFloat = 92
    static let flight:    CGFloat = 72
    static let reg:       CGFloat = 72
    static let type:      CGFloat = 72
    static let airport:   CGFloat = 52
    static let crew:      CGFloat = 120
    static let std:       CGFloat = 52
    static let sta:       CGFloat = 52
    static let out:       CGFloat = 52
    static let inn:       CGFloat = 52
    static let block:     CGFloat = 84
    static let night:     CGFloat = 84
    static let p1:        CGFloat = 84
    static let p1us:      CGFloat = 84
    static let p2:        CGFloat = 84
    static let instr:     CGFloat = 84
    static let sim:       CGFloat = 76
    static let spIns:     CGFloat = 84
    static let pax:       CGFloat = 48
    static let pf:        CGFloat = 84
    static let aiii:      CGFloat = 48
    static let rnp:       CGFloat = 44
    static let ils:       CGFloat = 40
    static let gls:       CGFloat = 44
    static let npa:       CGFloat = 44
    static let dayTO:     CGFloat = 68
    static let dayLdg:    CGFloat = 68
    static let nightTO:   CGFloat = 76
    static let nightLdg:  CGFloat = 76
    static let custom:    CGFloat = 100
    static let remarks:   CGFloat = 500

    static let frozenWidth: CGFloat  = date + flight
    static let headerHeight: CGFloat = 36
    static let rowHeight: CGFloat    = 44

    static let rightWidth: CGFloat =
        reg + type + airport * 2 + std + sta + out + inn +
        block + night + crew * 4 +
        p1 + p1us + p2 + instr + sim + spIns +
        pax + pf + aiii + rnp + ils + gls + npa +
        dayTO + dayLdg + nightTO + nightLdg + custom + remarks
}

// MARK: - Container UIView

final class SpreadsheetContainerView: UIView {

    weak var coordinator: FrozenColumnSpreadsheetView.Coordinator?

    let leftTable  = UITableView(frame: .zero, style: .plain)
    let rightTable = UITableView(frame: .zero, style: .plain)

    // The right table lives inside a horizontal scroll view
    let rightHScroll = UIScrollView()

    // Frozen header views (rebuilt when config/flights change)
    private var leftHeaderView: UIView?
    var rightHeaderView: UIView?

    private var flights: [FlightSector] = []
    private var config   = SpreadsheetDisplayConfig(useLocalTime: false, useIATA: false, showHHMM: true, roundingMode: .standard)
    private var highlightedID: UUID?

    // MARK: Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: Setup

    private func setupViews() {
        // Left table
        leftTable.register(LeftCell.self, forCellReuseIdentifier: LeftCell.reuseID)
        leftTable.separatorStyle = .singleLine
        leftTable.separatorInset = .zero
        leftTable.rowHeight = Col.rowHeight
        leftTable.showsVerticalScrollIndicator = false
        leftTable.translatesAutoresizingMaskIntoConstraints = false

        // Right horizontal scroll view
        rightHScroll.showsHorizontalScrollIndicator = true
        rightHScroll.showsVerticalScrollIndicator   = false
        rightHScroll.alwaysBounceVertical = false
        rightHScroll.translatesAutoresizingMaskIntoConstraints = false

        // Right table (inside rightHScroll)
        rightTable.register(RightCell.self, forCellReuseIdentifier: RightCell.reuseID)
        rightTable.separatorStyle = .singleLine
        rightTable.separatorInset = .zero
        rightTable.rowHeight = Col.rowHeight
        rightTable.showsVerticalScrollIndicator = true
        rightTable.showsHorizontalScrollIndicator = false
        rightTable.translatesAutoresizingMaskIntoConstraints = false

        rightHScroll.addSubview(rightTable)
        addSubview(leftTable)
        addSubview(rightHScroll)

        // Frozen-pane shadow
        leftTable.layer.shadowColor   = UIColor.black.cgColor
        leftTable.layer.shadowOpacity = 0.12
        leftTable.layer.shadowOffset  = CGSize(width: 3, height: 0)
        leftTable.layer.shadowRadius  = 4
        leftTable.clipsToBounds       = false

        NSLayoutConstraint.activate([
            // Left table sits below the frozen header
            leftTable.topAnchor.constraint(equalTo: topAnchor, constant: Col.headerHeight * 2),
            leftTable.leadingAnchor.constraint(equalTo: leadingAnchor),
            leftTable.bottomAnchor.constraint(equalTo: bottomAnchor),
            leftTable.widthAnchor.constraint(equalToConstant: Col.frozenWidth),

            // Right hscroll sits below the frozen header
            rightHScroll.topAnchor.constraint(equalTo: topAnchor, constant: Col.headerHeight * 2),
            rightHScroll.leadingAnchor.constraint(equalTo: leftTable.trailingAnchor),
            rightHScroll.trailingAnchor.constraint(equalTo: trailingAnchor),
            rightHScroll.bottomAnchor.constraint(equalTo: bottomAnchor),

            // Right table: pinned to frame guide for position + height (vertical scroll is the table's job)
            // Width anchored to content guide to drive horizontal scroll content size
            rightTable.topAnchor.constraint(equalTo: rightHScroll.frameLayoutGuide.topAnchor),
            rightTable.leadingAnchor.constraint(equalTo: rightHScroll.contentLayoutGuide.leadingAnchor),
            rightTable.heightAnchor.constraint(equalTo: rightHScroll.frameLayoutGuide.heightAnchor),
            rightTable.widthAnchor.constraint(equalToConstant: Col.rightWidth),
            // This makes the content guide as wide as the table, enabling horizontal scroll
            rightHScroll.contentLayoutGuide.widthAnchor.constraint(equalToConstant: Col.rightWidth),
        ])
    }

    // MARK: Wire delegate after coordinator is set

    override func didMoveToWindow() {
        super.didMoveToWindow()
        guard let coordinator else { return }
        leftTable.dataSource  = coordinator
        leftTable.delegate    = coordinator
        rightTable.dataSource = coordinator
        rightTable.delegate   = coordinator
        rightHScroll.delegate = coordinator
        buildHeaders()
    }

    // MARK: Configure / Update

    func configure(flights: [FlightSector], config: SpreadsheetDisplayConfig, highlightedID: UUID?) {
        self.flights       = flights
        self.config        = config
        self.highlightedID = highlightedID
        // Headers built in didMoveToWindow once tables are ready
    }

    func update(flights: [FlightSector], config: SpreadsheetDisplayConfig, highlightedID: UUID?) {
        let flightsChanged   = flights.map(\.id) != self.flights.map(\.id)
        let configChanged    = config != self.config
        let highlightChanged = highlightedID != self.highlightedID

        let previousHighlightedID = self.highlightedID

        self.flights       = flights
        self.config        = config
        self.highlightedID = highlightedID

        if flightsChanged || configChanged {
            buildHeaders()
            leftTable.reloadData()
            rightTable.reloadData()
        } else if highlightChanged {
            let ids = Set([highlightedID, previousHighlightedID].compactMap { $0 })
            let rows = flights.enumerated()
                .filter { ids.contains($0.element.id) }
                .map    { IndexPath(row: $0.offset, section: 0) }
            leftTable.reloadRows(at: rows, with: .none)
            rightTable.reloadRows(at: rows, with: .none)
        }
    }

    // MARK: Frozen headers (pinned as subviews above the scroll areas, never scroll vertically)

    private func buildHeaders() {
        leftHeaderView?.removeFromSuperview()
        rightHeaderView?.removeFromSuperview()

        // Left header: above the left table, fixed
        let lh = makeLeftHeader()
        lh.translatesAutoresizingMaskIntoConstraints = false
        addSubview(lh)
        NSLayoutConstraint.activate([
            lh.topAnchor.constraint(equalTo: topAnchor),
            lh.leadingAnchor.constraint(equalTo: leadingAnchor),
            lh.widthAnchor.constraint(equalToConstant: Col.frozenWidth),
            lh.heightAnchor.constraint(equalToConstant: Col.headerHeight * 2),
        ])
        leftHeaderView = lh

        // Right header: full content width, clipped to the visible scroll area.
        // bounds.origin.x is shifted in scrollViewDidScroll to pan it horizontally.
        let rh = makeRightHeader()
        rh.clipsToBounds = true
        // Use a plain frame-positioned container that is Col.rightWidth wide
        // but masked by a clipping wrapper pinned to rightHScroll's visible frame.
        let rhClip = UIView()
        rhClip.clipsToBounds = true
        rhClip.translatesAutoresizingMaskIntoConstraints = false
        addSubview(rhClip)
        NSLayoutConstraint.activate([
            rhClip.topAnchor.constraint(equalTo: topAnchor),
            rhClip.leadingAnchor.constraint(equalTo: rightHScroll.leadingAnchor),
            rhClip.trailingAnchor.constraint(equalTo: rightHScroll.trailingAnchor),
            rhClip.heightAnchor.constraint(equalToConstant: Col.headerHeight * 2),
        ])
        rh.frame = CGRect(x: 0, y: 0, width: Col.rightWidth, height: Col.headerHeight * 2)
        rhClip.addSubview(rh)
        rightHeaderView = rhClip
    }

    private func makeLeftHeader() -> UIView {
        let container = UIView(frame: CGRect(x: 0, y: 0, width: Col.frozenWidth, height: Col.headerHeight * 2))
        container.backgroundColor = barColor

        // Row 1 — column labels
        let headerRow = rowView(width: Col.frozenWidth, height: Col.headerHeight, y: 0)
        var x: CGFloat = 0
        addHeaderLabel("Date",   width: Col.date,   to: headerRow, x: &x, alignment: .center)
        addHeaderLabel("Flt No", width: Col.flight, to: headerRow, x: &x, alignment: .center)
        container.addSubview(headerRow)

        // Row 2 — totals label + blank
        let footerRow = rowView(width: Col.frozenWidth, height: Col.headerHeight, y: Col.headerHeight)
        x = 0
        addTotalLabelCell("Totals -->", width: Col.date,   to: footerRow, x: &x)
        addDivider(to: footerRow, x: x, height: Col.headerHeight)   // trailing divider for Flt No col
        container.addSubview(footerRow)

        // Top separator on footer row
        addTopSeparator(to: footerRow, width: Col.frozenWidth)
        // Bottom border on entire header block
        addBottomBorder(to: container, width: Col.frozenWidth)

        return container
    }

    private func makeRightHeader() -> UIView {
        let container = UIView(frame: CGRect(x: 0, y: 0, width: Col.rightWidth, height: Col.headerHeight * 2))
        container.backgroundColor = barColor

        // Row 1 — column labels
        let headerRow = rowView(width: Col.rightWidth, height: Col.headerHeight, y: 0)
        var x: CGFloat = 0
        addHeaderLabel("Reg",          width: Col.reg,      to: headerRow, x: &x)
        addHeaderLabel("Type",         width: Col.type,     to: headerRow, x: &x)
        addHeaderLabel("From",         width: Col.airport,  to: headerRow, x: &x)
        addHeaderLabel("To",           width: Col.airport,  to: headerRow, x: &x)
        addHeaderLabel("STD",          width: Col.std,      to: headerRow, x: &x)
        addHeaderLabel("STA",          width: Col.sta,      to: headerRow, x: &x)
        addHeaderLabel("OUT",          width: Col.out,      to: headerRow, x: &x)
        addHeaderLabel("IN",           width: Col.inn,      to: headerRow, x: &x)
        addHeaderLabel("Block Time",   width: Col.block,    to: headerRow, x: &x, alignment: .center)
        addHeaderLabel("Night Time",   width: Col.night,    to: headerRow, x: &x, alignment: .center)
        addHeaderLabel("Captain",      width: Col.crew,     to: headerRow, x: &x)
        addHeaderLabel("F/O",          width: Col.crew,     to: headerRow, x: &x)
        addHeaderLabel("S/O1",         width: Col.crew,     to: headerRow, x: &x)
        addHeaderLabel("S/O2",         width: Col.crew,     to: headerRow, x: &x)
        addHeaderLabel("P1 Time",      width: Col.p1,       to: headerRow, x: &x, alignment: .center)
        addHeaderLabel("P1US Time",    width: Col.p1us,     to: headerRow, x: &x, alignment: .center)
        addHeaderLabel("P2 Time",      width: Col.p2,       to: headerRow, x: &x, alignment: .center)
        addHeaderLabel("Instrument",   width: Col.instr,    to: headerRow, x: &x, alignment: .center)
        addHeaderLabel("SIM Time",     width: Col.sim,      to: headerRow, x: &x, alignment: .center)
        addHeaderLabel("Sp/Ins Time",  width: Col.spIns,    to: headerRow, x: &x, alignment: .center)
        addHeaderLabel("PAX",          width: Col.pax,      to: headerRow, x: &x)
        addHeaderLabel("Pilot Flying", width: Col.pf,       to: headerRow, x: &x)
        addHeaderLabel("AIII",         width: Col.aiii,     to: headerRow, x: &x)
        addHeaderLabel("RNP",          width: Col.rnp,      to: headerRow, x: &x)
        addHeaderLabel("ILS",          width: Col.ils,      to: headerRow, x: &x)
        addHeaderLabel("GLS",          width: Col.gls,      to: headerRow, x: &x)
        addHeaderLabel("NPA",          width: Col.npa,      to: headerRow, x: &x)
        addHeaderLabel("Day T/O",      width: Col.dayTO,    to: headerRow, x: &x)
        addHeaderLabel("Day Ldg",      width: Col.dayLdg,   to: headerRow, x: &x)
        addHeaderLabel("Night T/O",    width: Col.nightTO,  to: headerRow, x: &x)
        addHeaderLabel("Night Ldg",    width: Col.nightLdg, to: headerRow, x: &x)
        addHeaderLabel("Custom Count", width: Col.custom,   to: headerRow, x: &x)
        addHeaderLabel("Remarks",      width: Col.remarks,  to: headerRow, x: &x)
        container.addSubview(headerRow)

        // Row 2 — totals
        let footerRow = rowView(width: Col.rightWidth, height: Col.headerHeight, y: Col.headerHeight)
        x = 0
        addEmptyCell(width: Col.reg,      to: footerRow, x: &x)
        addEmptyCell(width: Col.type,     to: footerRow, x: &x)
        addEmptyCell(width: Col.airport,  to: footerRow, x: &x)
        addEmptyCell(width: Col.airport,  to: footerRow, x: &x)
        addEmptyCell(width: Col.std,      to: footerRow, x: &x)
        addEmptyCell(width: Col.sta,      to: footerRow, x: &x)
        addEmptyCell(width: Col.out,      to: footerRow, x: &x)
        addEmptyCell(width: Col.inn,      to: footerRow, x: &x)
        addTotalTimeLabel(sumTime(\.blockTime),    width: Col.block,    to: footerRow, x: &x)
        addTotalTimeLabel(sumTime(\.nightTime),    width: Col.night,    to: footerRow, x: &x)
        addEmptyCell(width: Col.crew,     to: footerRow, x: &x)
        addEmptyCell(width: Col.crew,     to: footerRow, x: &x)
        addEmptyCell(width: Col.crew,     to: footerRow, x: &x)
        addEmptyCell(width: Col.crew,     to: footerRow, x: &x)
        addTotalTimeLabel(sumTime(\.p1Time),       width: Col.p1,       to: footerRow, x: &x)
        addTotalTimeLabel(sumTime(\.p1usTime),     width: Col.p1us,     to: footerRow, x: &x)
        addTotalTimeLabel(sumTime(\.p2Time),       width: Col.p2,       to: footerRow, x: &x)
        addTotalTimeLabel(sumTime(\.instrumentTime), width: Col.instr,  to: footerRow, x: &x)
        addTotalTimeLabel(sumTime(\.simTime),      width: Col.sim,      to: footerRow, x: &x)
        addTotalTimeLabel(sumTime(\.spInsTime),    width: Col.spIns,    to: footerRow, x: &x)
        addEmptyCell(width: Col.pax,      to: footerRow, x: &x)
        addEmptyCell(width: Col.pf,       to: footerRow, x: &x)
        addEmptyCell(width: Col.aiii,     to: footerRow, x: &x)
        addEmptyCell(width: Col.rnp,      to: footerRow, x: &x)
        addEmptyCell(width: Col.ils,      to: footerRow, x: &x)
        addEmptyCell(width: Col.gls,      to: footerRow, x: &x)
        addEmptyCell(width: Col.npa,      to: footerRow, x: &x)
        addTotalCountLabel(sumInt(\.dayTakeoffs),  width: Col.dayTO,    to: footerRow, x: &x)
        addTotalCountLabel(sumInt(\.dayLandings),  width: Col.dayLdg,   to: footerRow, x: &x)
        addTotalCountLabel(sumInt(\.nightTakeoffs),width: Col.nightTO,  to: footerRow, x: &x)
        addTotalCountLabel(sumInt(\.nightLandings),width: Col.nightLdg, to: footerRow, x: &x)
        addTotalCountLabel(sumInt(\.customCount),  width: Col.custom,   to: footerRow, x: &x)
        addEmptyCell(width: Col.remarks,  to: footerRow, x: &x)
        container.addSubview(footerRow)

        addTopSeparator(to: footerRow, width: Col.rightWidth)
        addBottomBorder(to: container, width: Col.rightWidth)

        return container
    }

    // MARK: Header cell helpers

    private func rowView(width: CGFloat, height: CGFloat, y: CGFloat) -> UIView {
        let v = UIView(frame: CGRect(x: 0, y: y, width: width, height: height))
        v.backgroundColor = barColor
        return v
    }

    private func addHeaderLabel(_ title: String, width: CGFloat, to parent: UIView, x: inout CGFloat, alignment: NSTextAlignment = .center) {
        let label = UILabel(frame: CGRect(x: x + 6, y: 0, width: width - 12, height: Col.headerHeight))
        label.text = title
        label.font = .preferredFont(forTextStyle: .caption1).withWeight(.semibold)
        label.textColor = .secondaryLabel
        label.textAlignment = alignment
        label.numberOfLines = 1
        parent.addSubview(label)
        addDivider(to: parent, x: x + width, height: Col.headerHeight)
        x += width
    }

    private func addTotalLabelCell(_ title: String, width: CGFloat, to parent: UIView, x: inout CGFloat) {
        let label = UILabel(frame: CGRect(x: x + 6, y: 0, width: width - 12, height: Col.headerHeight))
        label.text = title
        label.font = .preferredFont(forTextStyle: .caption1).withWeight(.semibold)
        label.textColor = .secondaryLabel
        label.numberOfLines = 1
        parent.addSubview(label)
        addDivider(to: parent, x: x + width, height: Col.headerHeight)
        x += width
    }

    private func addEmptyCell(width: CGFloat, to parent: UIView, x: inout CGFloat) {
        addDivider(to: parent, x: x + width, height: Col.headerHeight)
        x += width
    }

    private func addTotalTimeLabel(_ value: String, width: CGFloat, to parent: UIView, x: inout CGFloat) {
        let label = UILabel(frame: CGRect(x: x + 6, y: 0, width: width - 12, height: Col.headerHeight))
        label.text = value
        label.font = UIFont.monospacedDigitSystemFont(ofSize: UIFont.preferredFont(forTextStyle: .caption1).pointSize, weight: .semibold)
        label.textColor = value.isEmpty ? .tertiaryLabel : .label
        label.textAlignment = .center
        label.numberOfLines = 1
        parent.addSubview(label)
        addDivider(to: parent, x: x + width, height: Col.headerHeight)
        x += width
    }

    private func addTotalCountLabel(_ value: Int, width: CGFloat, to parent: UIView, x: inout CGFloat) {
        let label = UILabel(frame: CGRect(x: x + 6, y: 0, width: width - 12, height: Col.headerHeight))
        label.text = value == 0 ? "" : String(value)
        label.font = UIFont.monospacedDigitSystemFont(ofSize: UIFont.preferredFont(forTextStyle: .caption1).pointSize, weight: .semibold)
        label.textColor = value == 0 ? .tertiaryLabel : .label
        label.textAlignment = .center
        label.numberOfLines = 1
        parent.addSubview(label)
        addDivider(to: parent, x: x + width, height: Col.headerHeight)
        x += width
    }

    private func addDivider(to parent: UIView, x: CGFloat, height: CGFloat) {
        let div = UIView(frame: CGRect(x: x - 0.5, y: 0, width: 0.5, height: height))
        div.backgroundColor = UIColor.label.withAlphaComponent(0.25)
        parent.addSubview(div)
    }

    private func addTopSeparator(to view: UIView, width: CGFloat) {
        let sep = UIView(frame: CGRect(x: 0, y: 0, width: width, height: 0.5))
        sep.backgroundColor = UIColor.label.withAlphaComponent(0.15)
        view.addSubview(sep)
    }

    private func addBottomBorder(to view: UIView, width: CGFloat) {
        let height = view.frame.height
        let border = UIView(frame: CGRect(x: 0, y: height - 0.5, width: width, height: 0.5))
        border.backgroundColor = .separator
        view.addSubview(border)
    }

    // MARK: Totals

    private func sumTime(_ keyPath: KeyPath<FlightSector, String>) -> String {
        let total = flights.reduce(0.0) { $0 + (Double($1[keyPath: keyPath]) ?? 0.0) }
        guard total > 0 else { return "" }
        return config.showHHMM ? FlightSector.decimalToHHMM(total) : String(format: "%.1f", total)
    }

    private func sumInt(_ keyPath: KeyPath<FlightSector, Int>) -> Int {
        flights.reduce(0) { $0 + $1[keyPath: keyPath] }
    }

    // MARK: Misc

    private var barColor: UIColor {
        UIColor { $0.userInterfaceStyle == .dark
            ? UIColor(white: 0.15, alpha: 1)
            : UIColor(white: 0.94, alpha: 1)
        }
    }
}

// MARK: - Left frozen cell

final class LeftCell: UITableViewCell {

    static let reuseID = "LeftCell"

    private let dateLabel   = CellLabel(mono: true)
    private let flightLabel = CellLabel(mono: true)

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        separatorInset = .zero

        dateLabel.frame   = CGRect(x: 6,            y: 0, width: Col.date   - 12, height: Col.rowHeight)
        flightLabel.frame = CGRect(x: Col.date + 6, y: 0, width: Col.flight - 12, height: Col.rowHeight)
        dateLabel.textAlignment   = .center
        flightLabel.textAlignment = .center
        contentView.addSubview(dateLabel)
        contentView.addSubview(flightLabel)

        // Column dividers
        addCellDivider(at: Col.date)
        addCellDivider(at: Col.frozenWidth)
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(flight: FlightSector, index: Int, highlighted: Bool, config: SpreadsheetDisplayConfig) {
        dateLabel.text   = flight.getDisplayDate(useLocalTime: config.useLocalTime)
        flightLabel.text = flight.flightNumber
        contentView.backgroundColor = highlighted
            ? UIColor.tintColor.withAlphaComponent(0.3)
            : rowBackground(index: index)
    }

    private func addCellDivider(at x: CGFloat) {
        let div = UIView(frame: CGRect(x: x - 0.5, y: 0, width: 0.5, height: Col.rowHeight))
        div.backgroundColor = UIColor.label.withAlphaComponent(0.25)
        div.autoresizingMask = [.flexibleHeight]
        contentView.addSubview(div)
    }
}

// MARK: - Right scrolling cell

final class RightCell: UITableViewCell {

    static let reuseID = "RightCell"

    // One label per right-pane column
    private var labels: [UILabel] = []

    // Column widths in order
    private static let widths: [CGFloat] = [
        Col.reg, Col.type, Col.airport, Col.airport,
        Col.std, Col.sta, Col.out, Col.inn,
        Col.block, Col.night,
        Col.crew, Col.crew, Col.crew, Col.crew,
        Col.p1, Col.p1us, Col.p2, Col.instr, Col.sim, Col.spIns,
        Col.pax, Col.pf, Col.aiii, Col.rnp, Col.ils, Col.gls, Col.npa,
        Col.dayTO, Col.dayLdg, Col.nightTO, Col.nightLdg, Col.custom, Col.remarks,
    ]

    // Whether each column uses monospaced digits
    private static let isMono: [Bool] = [
        true,  false, true,  true,   // reg, type, from, to
        true,  true,  true,  true,   // std, sta, out, in
        true,  true,                 // block, night
        false, false, false, false,  // captain, fo, so1, so2
        true,  true,  true,  true,  true,  true,  // p1, p1us, p2, instr, sim, spIns
        true,  true,  true,  true,  true,  true,  true,  // flags (pax, pf, aiii, rnp, ils, gls, npa)
        true,  true,  true,  true,  true,  false, // dayTO, dayLdg, nightTO, nightLdg, custom, remarks
    ]

    // Flag columns (centered, show "1"/blank)
    private static let flagColumns = Set([20, 21, 22, 23, 24, 25, 26])

    // Time columns (centered): block, night, p1, p1us, p2, instr, sim, spIns
    private static let rightAlignedColumns = Set([8, 9, 14, 15, 16, 17, 18, 19])

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        separatorInset = .zero

        var x: CGFloat = 0
        for (i, width) in Self.widths.enumerated() {
            let label = CellLabel(mono: Self.isMono[i])
            if Self.flagColumns.contains(i) {
                label.textAlignment = .center
                label.frame = CGRect(x: x, y: 0, width: width, height: Col.rowHeight)
            } else if Self.rightAlignedColumns.contains(i) {
                label.textAlignment = .center
                label.frame = CGRect(x: x + 6, y: 0, width: width - 12, height: Col.rowHeight)
            } else {
                label.textAlignment = .center
                label.frame = CGRect(x: x + 6, y: 0, width: width - 12, height: Col.rowHeight)
            }
            contentView.addSubview(label)
            labels.append(label)

            // Column divider
            let div = UIView(frame: CGRect(x: x + width - 0.5, y: 0, width: 0.5, height: Col.rowHeight))
            div.backgroundColor = UIColor.label.withAlphaComponent(0.25)
            div.autoresizingMask = [.flexibleHeight]
            contentView.addSubview(div)

            x += width
        }
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(flight: FlightSector, index: Int, highlighted: Bool, config: SpreadsheetDisplayConfig) {
        let useLocal = config.useLocalTime
        let useIATA  = config.useIATA
        let hhmm     = config.showHHMM
        let rounding = config.roundingMode

        let values: [String] = [
            flight.aircraftReg,
            flight.aircraftType,
            AirportService.shared.getDisplayCode(flight.fromAirport, useIATA: useIATA),
            AirportService.shared.getDisplayCode(flight.toAirport,   useIATA: useIATA),
            flight.getSTD(useLocalTime: useLocal),
            flight.getSTA(useLocalTime: useLocal),
            flight.getOutTime(useLocalTime: useLocal),
            flight.getInTime(useLocalTime: useLocal),
            timeValue(flight.getFormattedBlockTime(asHoursMinutes: hhmm, roundingMode: rounding)),
            timeValue(flight.getFormattedNightTime(asHoursMinutes: hhmm, roundingMode: rounding)),
            flight.captainName,
            flight.foName,
            flight.so1Name ?? "",
            flight.so2Name ?? "",
            timeValue(FlightSector.formatTime(flight.p1TimeValue,         asHoursMinutes: hhmm)),
            timeValue(FlightSector.formatTime(flight.p1usTimeValue,       asHoursMinutes: hhmm)),
            timeValue(FlightSector.formatTime(flight.p2TimeValue,         asHoursMinutes: hhmm)),
            timeValue(FlightSector.formatTime(flight.instrumentTimeValue, asHoursMinutes: hhmm)),
            timeValue(flight.getFormattedSimTime(asHoursMinutes: hhmm)),
            timeValue(flight.getFormattedSpInsTime(asHoursMinutes: hhmm)),
            flight.isPositioning  ? "1" : "",
            flight.isPilotFlying  ? "1" : "",
            flight.isAIII         ? "1" : "",
            flight.isRNP          ? "1" : "",
            flight.isILS          ? "1" : "",
            flight.isGLS          ? "1" : "",
            flight.isNPA          ? "1" : "",
            countString(flight.dayTakeoffs),
            countString(flight.dayLandings),
            countString(flight.nightTakeoffs),
            countString(flight.nightLandings),
            flight.customCount > 0 ? String(flight.customCount) : "",
            flight.remarks,
        ]

        for (i, label) in labels.enumerated() {
            let raw     = i < values.count ? values[i] : ""
            let display = isBlankValue(raw) ? "" : raw
            label.text      = display
            label.textColor = display.isEmpty ? .tertiaryLabel : .label
            // Bold block time
            if i == 8 {
                label.font = UIFont.monospacedDigitSystemFont(
                    ofSize: UIFont.preferredFont(forTextStyle: .caption1).pointSize,
                    weight: .semibold
                )
            }
        }

        contentView.backgroundColor = highlighted
            ? UIColor.tintColor.withAlphaComponent(0.3)
            : rowBackground(index: index)
    }
}

// MARK: - Shared helpers (free functions, available to cells + container)

func rowBackground(index: Int) -> UIColor {
    index.isMultiple(of: 2) ? .systemBackground : .secondarySystemBackground
}

func timeValue(_ value: String) -> String {
    value.replacingOccurrences(of: " hrs", with: "")
}

func isBlankValue(_ value: String) -> Bool {
    value.isEmpty || value == "0.00" || value == "0.0" || value == "0" || value == "0:00"
}

func countString(_ value: Int) -> String {
    value == 0 ? "" : String(value)
}

// MARK: - CellLabel

private final class CellLabel: UILabel {
    init(mono: Bool) {
        super.init(frame: .zero)
        let size = UIFont.preferredFont(forTextStyle: .caption1).pointSize
        font = mono
            ? UIFont.monospacedDigitSystemFont(ofSize: size, weight: .regular)
            : UIFont.preferredFont(forTextStyle: .caption1)
        numberOfLines = 1
        lineBreakMode = .byTruncatingTail
    }
    required init?(coder: NSCoder) { fatalError() }
}

// MARK: - UIFont weight helper

private extension UIFont {
    func withWeight(_ weight: UIFont.Weight) -> UIFont {
        let descriptor = fontDescriptor.addingAttributes([
            .traits: [UIFontDescriptor.TraitKey.weight: weight]
        ])
        return UIFont(descriptor: descriptor, size: pointSize)
    }
}
