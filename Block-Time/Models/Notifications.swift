//
//  Notifications.swift
//  Block-Time
//
//  App-wide Notification.Name constants.
//

import Foundation

extension Notification.Name {
    static let flightDataChanged        = Notification.Name("flightDataChanged")
    static let scrollToTop              = Notification.Name("scrollToTop")
    static let reviewImportSession      = Notification.Name("reviewImportSession")
    static let navigateToBackupSettings = Notification.Name("navigateToBackupSettings")
    static let flightAdded              = Notification.Name("flightAdded")
    static let openAddFlight            = Notification.Name("openAddFlight")
    static let openAddFlightCapture     = Notification.Name("openAddFlightCapture")
}
