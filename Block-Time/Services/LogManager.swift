//
//  LogManager.swift
//  Block-Time
//
//  Centralized logging service with file rotation and severity levels
//

import Foundation
import UIKit

enum LogLevel: String, CaseIterable, Comparable {
    case debug = "DEBUG  "
    case info = "INFO   "
    case warning = "WARNING"
    case error = "ERROR  "

    var emoji: String {
        switch self {
        case .debug: return "🔍"
        case .info: return "ℹ️"
        case .warning: return "⚠️"
        case .error: return "❌"
        }
    }

    var displayName: String {
        switch self {
        case .debug: return "Debug"
        case .info: return "Info"
        case .warning: return "Warning"
        case .error: return "Error"
        }
    }

    var priority: Int {
        switch self {
        case .debug: return 0
        case .info: return 1
        case .warning: return 2
        case .error: return 3
        }
    }

    static func < (lhs: LogLevel, rhs: LogLevel) -> Bool {
        return lhs.priority < rhs.priority
    }
}

class LogManager {
    static let shared = LogManager()

    // Configuration - Single large log file for easier troubleshooting
    private let maxFileSize: Int = 10 * 1024 * 1024 // 10MB - provides extensive history
    private let logFileName = "Block-Time_LogFile.log"

    // Log level filtering
    // Change this to control which logs appear in console:
    // .debug  - Show everything (most verbose)
    // .info   - Show info, warning, error (hide debug messages)
    // .warning - Show warning and error only
    // .error  - Show only errors (least verbose)
    var minimumConsoleLogLevel: LogLevel = .info

    // File management
    private let fileManager = FileManager.default
    private var logFileURL: URL
    private let queue = DispatchQueue(label: "com.thezoolab.blocktime.logmanager", qos: .utility)

    // Device and app metadata
    private let appVersion: String
    private let buildNumber: String
    private let deviceModel: String
    private let iosVersion: String

    private init() {
        // Get app info
        appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"

        // Get device info
        deviceModel = UIDevice.current.model
        iosVersion = UIDevice.current.systemVersion

        // Set up log file location
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        logFileURL = documentsPath.appendingPathComponent(logFileName)

        // Create log file if it doesn't exist
        if !fileManager.fileExists(atPath: logFileURL.path) {
            fileManager.createFile(atPath: logFileURL.path, contents: nil)
            writeInitialHeader()
        }
    }

    // MARK: - Log Level Control

    /// Set the minimum log level for console output
    /// - Parameter level: Minimum level to display (.debug shows all, .info hides debug, etc.)
    func setConsoleLogLevel(_ level: LogLevel) {
        minimumConsoleLogLevel = level
        info("Console log level set to: \(level.rawValue.trimmingCharacters(in: .whitespaces))")
    }

    // MARK: - Public Logging Methods

    func debug(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .debug, file: file, function: function, line: line)
    }

    func info(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .info, file: file, function: function, line: line)
    }

    func warning(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .warning, file: file, function: function, line: line)
    }

    func error(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .error, file: file, function: function, line: line)
    }

    // MARK: - Core Logging

    private func log(_ message: String, level: LogLevel, file: String, function: String, line: Int) {
        queue.async { [weak self] in
            guard let self = self else { return }

            // Check if rotation is needed
            self.rotateLogsIfNeeded()

            // Format log entry
            let timestamp = self.timestamp()
            let fileName = (file as NSString).lastPathComponent
            let threadInfo = Thread.isMainThread ? "Main" : "Background"

            // \(level.emoji) removed emoji from log file
            
//            let logEntry = """
//            [\(timestamp)] \(level.rawValue) - [\(threadInfo) Thread] [\(fileName):\(line)] \(function) → \(message)
//            """

            let logEntry = """
            [\(timestamp)] [\(level.rawValue)] → \(message)
            (\(fileName) - \(function)) - [\(threadInfo) Thread]
            """


            // Write ALL logs to file (regardless of level)
            self.writeToFile(logEntry)

            // Print to console only if level meets minimum threshold
            #if DEBUG
            if level >= self.minimumConsoleLogLevel {
                print(logEntry)
            }
            #endif
        }
    }

    // MARK: - File Management

    private func writeInitialHeader() {
        let header = """
        =================================================
        Block-Time App - Log File
        =================================================
        App Version: \(appVersion) (Build \(buildNumber))
        Device: \(deviceModel)
        iOS Version: \(iosVersion)
        Started: \(timestamp())
        =================================================

        """
        writeToFile(header)
    }

    private func writeToFile(_ text: String) {
        let textWithNewline = text + "\n"
        guard let data = textWithNewline.data(using: .utf8) else { return }

        if let fileHandle = try? FileHandle(forWritingTo: logFileURL) {
            fileHandle.seekToEndOfFile()
            fileHandle.write(data)
            fileHandle.closeFile()
        }
    }

    private func rotateLogsIfNeeded() {
        guard let attributes = try? fileManager.attributesOfItem(atPath: logFileURL.path),
              let fileSize = attributes[.size] as? Int else {
            return
        }

        if fileSize > maxFileSize {
            clearAndResetLog()
        }
    }

    private func clearAndResetLog() {
        // Simply delete and recreate the log file when it gets too large
        try? fileManager.removeItem(at: logFileURL)
        fileManager.createFile(atPath: logFileURL.path, contents: nil)
        writeInitialHeader()
    }

    // MARK: - Log Reading

    func getCurrentLogContent() -> String? {
        return try? String(contentsOf: logFileURL, encoding: .utf8)
    }

    func getCurrentLogURL() -> URL {
        return logFileURL
    }

    func getAllLogFiles() -> [URL] {
        // Return only the current log file (no archives with single file approach)
        return [logFileURL]
    }

    func getLogFileSize() -> String {
        guard let attributes = try? fileManager.attributesOfItem(atPath: logFileURL.path),
              let fileSize = attributes[.size] as? Int else {
            return "Unknown"
        }

        return ByteCountFormatter.string(fromByteCount: Int64(fileSize), countStyle: .file)
    }

    // MARK: - Clear Logs

    func clearAllLogs(completion: (() -> Void)? = nil) {
        queue.async { [weak self] in
            guard let self = self else { return }

            // Clear the log file (no archives to delete with single file approach)
            try? self.fileManager.removeItem(at: self.logFileURL)
            self.fileManager.createFile(atPath: self.logFileURL.path, contents: nil)
            self.writeInitialHeader()

            DispatchQueue.main.async {
                completion?()
            }
        }
    }

    // MARK: - Utilities

    private func timestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.locale = Locale(identifier: "en_AU")
        return formatter.string(from: Date())
    }
}
