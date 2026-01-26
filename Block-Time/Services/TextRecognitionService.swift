//
//  TextRecognitionService.swift
//  Block-Time
//
//  Created by Nelson on 3/9/2025.
//

import Vision
import UIKit
import Foundation
import ImageIO
import Combine

// MARK: - Data Models
struct FlightData {
    let outTime: String
    let inTime: String
    let offTime: String
    let onTime: String
    let blockTime: String
    let flightNumber: String
    let fromAirport: String
    let toAirport: String
    let dayOfMonth: String? // Day only for B737 (e.g., "03")
    let aircraftRegistration: String? // Tail number without VH- prefix
    let fullDate: String? // Complete date in DD/MM/YYYY format for B787
}

struct TextRecognitionError: LocalizedError {
    let message: String

    var errorDescription: String? {
        return message
    }
}

struct PartialExtractionError: LocalizedError {
    let message: String
    let partialData: FlightData

    var errorDescription: String? {
        return message
    }
}

// MARK: - Fleet Type Enum
enum FleetType {
    case b737
    case b787
}

// MARK: - Text Recognition Service
class TextRecognitionService: ObservableObject {

    // MARK: - Public Methods

    /// Extract flight data from an image using Vision OCR
    /// - Parameters:
    ///   - image: The image to extract text from
    ///   - fleetType: The aircraft fleet type (B737 or B787) to determine parsing strategy
    func extractFlightData(from image: UIImage, fleetType: FleetType = .b737) async throws -> FlightData {
        LogManager.shared.info("Starting text recognition for \(fleetType == .b737 ? "B737" : "B787") ACARS image")

        guard let cgImage = image.cgImage else {
            LogManager.shared.error("Failed to convert UIImage to CGImage for text recognition")
            throw TextRecognitionError(message: "Failed to process image")
        }

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    LogManager.shared.error("Vision text recognition failed: \(error.localizedDescription)")
                    continuation.resume(throwing: TextRecognitionError(message: "Text recognition failed: \(error.localizedDescription)"))
                    return
                }

                guard let results = request.results as? [VNRecognizedTextObservation] else {
                    LogManager.shared.warning("No text observations found in image")
                    continuation.resume(throwing: TextRecognitionError(message: "No text found in image"))
                    return
                }

                LogManager.shared.debug("Found \(results.count) text observations in image")

                do {
                    let flightData: FlightData
                    switch fleetType {
                    case .b737:
                        flightData = try self.processTextRecognitionResults(results)
                    case .b787:
                        flightData = try self.processB787TextRecognitionResults(results)
                    }
                    LogManager.shared.info("Successfully extracted flight data: \(flightData.flightNumber) \(flightData.fromAirport)-\(flightData.toAirport)")
                    continuation.resume(returning: flightData)
                } catch {
                    if let partialError = error as? PartialExtractionError {
                        LogManager.shared.warning("Partial extraction: \(partialError.message)")
                    } else {
                        LogManager.shared.error("Failed to parse flight data: \(error.localizedDescription)")
                    }
                    continuation.resume(throwing: error)
                }
            }

            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = false
            request.recognitionLanguages = ["en-US"]
            request.automaticallyDetectsLanguage = false

            // Convert UIImage.Orientation to CGImagePropertyOrientation for Vision framework
            let orientation = CGImagePropertyOrientation(image.imageOrientation)

            // Use image orientation and better options for improved accuracy
            let options: [VNImageOption: Any] = [
                .ciContext: CIContext(options: nil)
            ]
            let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation, options: options)

            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: TextRecognitionError(message: "Vision processing failed: \(error.localizedDescription)"))
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func processTextRecognitionResults(_ results: [VNRecognizedTextObservation]) throws -> FlightData {
        // Combine all recognized text
        var recognizedText = ""
        for observation in results {
            guard let topCandidate = observation.topCandidates(1).first else { continue }
            recognizedText += topCandidate.string + "\n"
        }

        print("Recognized text: \(recognizedText)")

        // Extract the different components
        let outTime = extractOutTime(from: recognizedText)
        let inTime = extractInTime(from: recognizedText)
        let offTime = extractOffTime(from: recognizedText)
        let onTime = extractOnTime(from: recognizedText)
        let blockTime = extractBlockTime(from: recognizedText)
        let flightDetails = extractFlightDetails(from: recognizedText)

        // Build list of missing fields for user feedback
        var missingFields: [String] = []
        if outTime.isEmpty { missingFields.append("OUT time") }
        if inTime.isEmpty { missingFields.append("IN time") }
        if !outTime.isEmpty && !isValidTimeFormat(outTime) { missingFields.append("valid OUT time") }
        if !inTime.isEmpty && !isValidTimeFormat(inTime) { missingFields.append("valid IN time") }

        // Return partial data even if some fields are missing
        // This allows users to manually fill in missing fields
        let flightData = FlightData(
            outTime: outTime,
            inTime: inTime,
            offTime: offTime,
            onTime: onTime,
            blockTime: blockTime,
            flightNumber: flightDetails.flightNumber,
            fromAirport: flightDetails.fromAirport,
            toAirport: flightDetails.toAirport,
            dayOfMonth: flightDetails.dayOfMonth,
            aircraftRegistration: nil, // B737 ACARS doesn't include tail number
            fullDate: nil // B737 uses dayOfMonth only
        )

        // If we have missing critical fields, throw error but it will be caught with partial data
        if !missingFields.isEmpty {
            print("Partial extraction - missing: \(missingFields.joined(separator: ", "))")
            throw PartialExtractionError(message: "Could not extract: \(missingFields.joined(separator: ", ")). Please verify and fill in missing fields.", partialData: flightData)
        }

        return flightData
    }
    
    private func extractOutTime(from text: String) -> String {
        let outPatterns: [NSRegularExpression] = [
            try! NSRegularExpression(pattern: "OUT\\s+(\\d{2}:\\d{2})"),
            try! NSRegularExpression(pattern: "OUT\\s*\\n\\s*(\\d{2}:\\d{2})"),
            try! NSRegularExpression(pattern: "OUT\\s*[:\\-\\.]?\\s*(\\d{2}:\\d{2})"),
            try! NSRegularExpression(pattern: "OUT\\s*\\n[^\\n]{0,10}\\n\\s*(\\d{2}:\\d{2})"),
            try! NSRegularExpression(pattern: "OUT\\s*\\n\\s*:\\s*(\\d{2})"),
            try! NSRegularExpression(pattern: "OUT\\s*\\n\\s*[;\\.]\\s*(\\d{2})"),
            try! NSRegularExpression(pattern: "OUT[^\\d]{0,20}(\\d{2})\\s*[:\\-;\\.]?\\s*(\\d{2})"),
            try! NSRegularExpression(pattern: "OUT[^\\d]{0,10}(\\d{2}:\\d{2})"),
            try! NSRegularExpression(pattern: "OUT\\s*\\n\\s*(\\d{2})\\s*\\n\\s*(\\d{2})"),
            try! NSRegularExpression(pattern: "OUT.{0,30}?(\\d{2}:\\d{2})"),
            // Relaxed patterns for OCR errors ($ or other chars instead of digits)
            // Match patterns like "$7:25" or "07:25" where first char might be $ or digit
            try! NSRegularExpression(pattern: "OUT\\s+([\\$\\d][\\d]:[\\d]{2})"),
            try! NSRegularExpression(pattern: "OUT\\s*\\n\\s*([\\$\\d][\\d]:[\\d]{2})"),
            // Even more relaxed: single digit/$ followed by colon (e.g., "$7:25")
            try! NSRegularExpression(pattern: "OUT\\s+([\\$\\d]:[\\d]{2})"),
            try! NSRegularExpression(pattern: "OUT\\s*\\n\\s*([\\$\\d]:[\\d]{2})"),
            // Very relaxed patterns for severe OCR errors (Ø, O, etc. instead of 0)
            // Match patterns like "0Ø:25", "ØØ:25", "0O:25" where Ø or O might appear instead of digits
            try! NSRegularExpression(pattern: "OUT\\s+([\\dØøOo]{2}:[\\d]{2})"),
            try! NSRegularExpression(pattern: "OUT\\s*\\n\\s*([\\dØøOo]{2}:[\\d]{2})")
        ]

        return extractTimeWithPatterns(outPatterns, from: text, timeType: "OUT")
    }
    
    private func extractInTime(from text: String) -> String {
        let inPatterns: [NSRegularExpression] = [
            try! NSRegularExpression(pattern: "IN\\s+(\\d{2}:\\d{2})"),
            try! NSRegularExpression(pattern: "IN\\s*\\n\\s*(\\d{2}:\\d{2})"),
            try! NSRegularExpression(pattern: "IN\\s*[:\\-\\.]?\\s*(\\d{2}:\\d{2})"),
            try! NSRegularExpression(pattern: "IN\\s*\\n[^\\n]{0,10}\\n\\s*(\\d{2}:\\d{2})"),
            try! NSRegularExpression(pattern: "IN\\s*\\n\\s*:\\s*(\\d{2})"),
            try! NSRegularExpression(pattern: "IN\\s*\\n\\s*[;\\.]\\s*(\\d{2})"),
            try! NSRegularExpression(pattern: "IN[^\\d]{0,20}(\\d{2})\\s*[:\\-;\\.]?\\s*(\\d{2})"),
            try! NSRegularExpression(pattern: "IN[^\\d]{0,10}(\\d{2}:\\d{2})"),
            try! NSRegularExpression(pattern: "IN\\s*\\n\\s*(\\d{2})\\s*\\n\\s*(\\d{2})"),
            try! NSRegularExpression(pattern: "IN.{0,30}?(\\d{2}:\\d{2})")
        ]

        return extractTimeWithPatterns(inPatterns, from: text, timeType: "IN")
    }

    private func extractOffTime(from text: String) -> String {
        let offPatterns: [NSRegularExpression] = [
            try! NSRegularExpression(pattern: "OFF\\s+(\\d{2}:\\d{2})"),
            try! NSRegularExpression(pattern: "OFF\\s*\\n\\s*(\\d{2}:\\d{2})"),
            try! NSRegularExpression(pattern: "OFF\\s*[:\\-\\.]?\\s*(\\d{2}:\\d{2})"),
            try! NSRegularExpression(pattern: "OFF\\s*\\n[^\\n]{0,10}\\n\\s*(\\d{2}:\\d{2})"),
            try! NSRegularExpression(pattern: "OFF\\s*\\n\\s*:\\s*(\\d{2})"),
            try! NSRegularExpression(pattern: "OFF\\s*\\n\\s*[;\\.]\\s*(\\d{2})"),
            try! NSRegularExpression(pattern: "OFF[^\\d]{0,20}(\\d{2})\\s*[:\\-;\\.]?\\s*(\\d{2})"),
            try! NSRegularExpression(pattern: "OFF[^\\d]{0,10}(\\d{2}:\\d{2})"),
            try! NSRegularExpression(pattern: "OFF\\s*\\n\\s*(\\d{2})\\s*\\n\\s*(\\d{2})"),
            try! NSRegularExpression(pattern: "OFF.{0,30}?(\\d{2}:\\d{2})")
        ]

        return extractTimeWithPatterns(offPatterns, from: text, timeType: "OFF")
    }

    private func extractOnTime(from text: String) -> String {
        let onPatterns: [NSRegularExpression] = [
            try! NSRegularExpression(pattern: "ON\\s+(\\d{2}:\\d{2})"),
            try! NSRegularExpression(pattern: "ON\\s*\\n\\s*(\\d{2}:\\d{2})"),
            try! NSRegularExpression(pattern: "ON\\s*[:\\-\\.]?\\s*(\\d{2}:\\d{2})"),
            try! NSRegularExpression(pattern: "ON\\s*\\n[^\\n]{0,10}\\n\\s*(\\d{2}:\\d{2})"),
            try! NSRegularExpression(pattern: "ON\\s*\\n\\s*:\\s*(\\d{2})"),
            try! NSRegularExpression(pattern: "ON\\s*\\n\\s*[;\\.]\\s*(\\d{2})"),
            try! NSRegularExpression(pattern: "ON[^\\d]{0,20}(\\d{2})\\s*[:\\-;\\.]?\\s*(\\d{2})"),
            try! NSRegularExpression(pattern: "ON[^\\d]{0,10}(\\d{2}:\\d{2})"),
            try! NSRegularExpression(pattern: "ON\\s*\\n\\s*(\\d{2})\\s*\\n\\s*(\\d{2})"),
            try! NSRegularExpression(pattern: "ON.{0,30}?(\\d{2}:\\d{2})"),
            // Relaxed patterns for OCR errors ($ or other chars instead of digits)
            try! NSRegularExpression(pattern: "ON\\s+([\\$\\d]{1,2}:[\\d]{2})"),
            try! NSRegularExpression(pattern: "ON\\s*\\n\\s*([\\$\\d]{1,2}:[\\d]{2})")
        ]

        return extractTimeWithPatterns(onPatterns, from: text, timeType: "ON")
    }
    
    
    private func extractBlockTime(from text: String) -> String {
        let blockPatterns: [NSRegularExpression] = [
            try! NSRegularExpression(pattern: "BLK\\s+(\\d{2}:\\d{2})"),
            try! NSRegularExpression(pattern: "BLK\\s*\\n\\s*(\\d{2}:\\d{2})"),
            try! NSRegularExpression(pattern: "BLK\\s*[:\\-\\.]?\\s*(\\d{2}:\\d{2})"),
            try! NSRegularExpression(pattern: "BLK\\s*\\n[^\\n]{0,10}\\n\\s*(\\d{2}:\\d{2})"),
            try! NSRegularExpression(pattern: "BLK\\s*\\n\\s*:\\s*(\\d{2})"),
            try! NSRegularExpression(pattern: "BLK\\s*\\n\\s*[;\\.]\\s*(\\d{2})"),
            try! NSRegularExpression(pattern: "BLK[^\\d]{0,20}(\\d{2})\\s*[:\\-;\\.]?\\s*(\\d{2})"),
            try! NSRegularExpression(pattern: "BLK[^\\d]{0,10}(\\d{2}:\\d{2})"),
            try! NSRegularExpression(pattern: "BLK\\s*\\n\\s*(\\d{2})\\s*\\n\\s*(\\d{2})"),
            try! NSRegularExpression(pattern: "BLK.{0,30}?(\\d{2}:\\d{2})")
        ]
        
        return extractTimeWithPatterns(blockPatterns, from: text, timeType: "BLOCK")
    }
    
    private func extractTimeWithPatterns(_ patterns: [NSRegularExpression], from text: String, timeType: String) -> String {
        for (index, pattern) in patterns.enumerated() {
            let matches = pattern.matches(in: text, range: NSRange(text.startIndex..., in: text))
            if let match = matches.first {
                let extractedTime: String

                switch index {
                case 0...3, 7, 9, 10...15: // Patterns that capture full HH:MM (including OCR error patterns with $, Ø, O)
                    let timeRange = Range(match.range(at: 1), in: text)!
                    extractedTime = String(text[timeRange])

                case 4, 5: // Patterns that capture only minutes
                    let minuteRange = Range(match.range(at: 1), in: text)!
                    let minutes = String(text[minuteRange])
                    let hour = findHourForMinutes(minutes, in: text) ?? "00"
                    extractedTime = "\(hour):\(minutes)"

                case 6: // Pattern that captures separate hour and minute groups
                    let hourRange = Range(match.range(at: 1), in: text)!
                    let minuteRange = Range(match.range(at: 2), in: text)!
                    let hour = String(text[hourRange])
                    let minute = String(text[minuteRange])
                    extractedTime = "\(hour):\(minute)"

                case 8: // Pattern for hour and minute on separate lines
                    let hourRange = Range(match.range(at: 1), in: text)!
                    let minuteRange = Range(match.range(at: 2), in: text)!
                    let hour = String(text[hourRange])
                    let minute = String(text[minuteRange])
                    extractedTime = "\(hour):\(minute)"

                default:
                    continue
                }

                // Apply smart correction for common OCR errors
                let correctedTime = smartCorrectTime(extractedTime)
                print("Found \(timeType) time (pattern \(index)): \(extractedTime)\(correctedTime != extractedTime ? " → corrected to: \(correctedTime)" : "")")
                return correctedTime
            }
        }

        return ""
    }

    /// Smart correction for common OCR time errors
    /// Primarily fixes leading '8' misread as '0' (e.g., 87:25 → 07:25)
    /// Also fixes '$' misread as '0' (e.g., $7:25 → 07:25)
    /// Also fixes 'Ø', 'ø', 'O', 'o' misread as '0' (e.g., 0Ø:25 → 00:25, ØØ:25 → 00:25)
    private func smartCorrectTime(_ time: String) -> String {
        var correctedTime = time

        // First pass: Replace common OCR character errors
        // $ is often misread as 0 (e.g., $7:25 → 07:25, $9:10 → 09:10)
        correctedTime = correctedTime.replacingOccurrences(of: "$", with: "0")
        // Ø (Scandinavian O with stroke) is often misread as 0 (e.g., 0Ø:25 → 00:25, ØØ:25 → 00:00)
        correctedTime = correctedTime.replacingOccurrences(of: "Ø", with: "0")
        correctedTime = correctedTime.replacingOccurrences(of: "ø", with: "0")
        // O (capital letter O) is often misread as 0 (e.g., 0O:25 → 00:25, OO:25 → 00:00)
        correctedTime = correctedTime.replacingOccurrences(of: "O", with: "0")
        correctedTime = correctedTime.replacingOccurrences(of: "o", with: "0")

        // If time is already valid after character replacement, return it
        if isValidTimeFormat(correctedTime) {
            return correctedTime
        }

        // Common OCR error: leading 8 should be 0 (e.g., 87:25 → 07:25, 89:10 → 09:10)
        if correctedTime.hasPrefix("8") {
            let corrected = "0" + correctedTime.dropFirst()
            if isValidTimeFormat(corrected) {
                return corrected
            }
        }

        // Try replacing any leading 8 in the hour portion with 0
        let components = correctedTime.split(separator: ":")
        if components.count == 2 {
            var hour = String(components[0])
            let minute = String(components[1])

            // If hour starts with 8 and is invalid, try replacing with 0
            if hour.hasPrefix("8") {
                hour = "0" + hour.dropFirst()
                let corrected = "\(hour):\(minute)"
                if isValidTimeFormat(corrected) {
                    return corrected
                }
            }

            // If hour is >= 24, try replacing first digit with 0
            if let hourInt = Int(hour), hourInt >= 24 {
                // Replace first character with 0
                if hour.count == 2 {
                    hour = "0" + String(hour.dropFirst())
                    let corrected = "\(hour):\(minute)"
                    if isValidTimeFormat(corrected) {
                        return corrected
                    }
                }
            }
        }

        // Return corrected time (with character replacements) if no valid correction found
        return correctedTime
    }
    
    private func findHourForMinutes(_ minutes: String, in text: String) -> String? {
        let hourPattern = try! NSRegularExpression(pattern: "(\\d{2})\\s*[:\\-;\\.]?\\s*\(minutes)")
        let hourMatches = hourPattern.matches(in: text, range: NSRange(text.startIndex..., in: text))
        if let hourMatch = hourMatches.first {
            let hourRange = Range(hourMatch.range(at: 1), in: text)!
            return String(text[hourRange])
        }
        return nil
    }
    
    private func extractFlightDetails(from text: String) -> (flightNumber: String, fromAirport: String, toAirport: String, dayOfMonth: String?) {
        let lines = text.components(separatedBy: .newlines)
        
        var flightNumber = ""
        var fromAirport = ""
        var toAirport = ""
        var dayOfMonth: String?
        
        // Extract flight number with improved patterns
        flightNumber = extractFlightNumber(from: lines, extractedDay: &dayOfMonth)
        
        // Extract airports
        let airports = extractAirports(from: lines)
        fromAirport = airports.from
        toAirport = airports.to
        
        return (flightNumber, fromAirport, toAirport, dayOfMonth)
    }
    
    private func extractFlightNumber(from lines: [String], extractedDay: inout String?) -> String {
        // Strict patterns (prefer these)
        let flightNumberPattern1 = try! NSRegularExpression(pattern: "QFA(\\d{4})/(\\d{2})")
        let flightNumberPattern2 = try! NSRegularExpression(pattern: "(\\d{4})/(\\d{2})")

        // Relaxed pattern for OCR errors: QFA followed by 4 chars (digits or common OCR mistakes), then /, then 2 digits
        let flightNumberPatternRelaxed = try! NSRegularExpression(pattern: "QFA([A-Z0-9]{4})/(\\d{2})")

        // Very relaxed pattern for severe OCR errors: QFA followed by any 4 non-whitespace chars, then /, then 2 digits
        // This handles cases like Ø (scandinavian O), special chars, etc.
        let flightNumberPatternVeryRelaxed = try! NSRegularExpression(pattern: "QFA([^\\s/]{4})/(\\d{2})")

        print("Searching for flight number in \(lines.count) lines...")

        // Try strict QFA format first
        for (index, line) in lines.enumerated() {
            print("  Line \(index): \(line)")
            let matches = flightNumberPattern1.matches(in: line, range: NSRange(line.startIndex..., in: line))
            if let match = matches.first {
                let numberPart = Range(match.range(at: 1), in: line)!
                let dayPart = Range(match.range(at: 2), in: line)!
                let flightNum = String(line[numberPart])
                let rawDay = String(line[dayPart])

                // Apply smart date correction based on current UTC date
                extractedDay = smartCorrectDayOfMonth(rawDay)

                // Apply smart correction for leading 8 → 0
                let correctedFlightNum = smartCorrectFlightNumber(flightNum)
                print("Flight number extracted (QFA format): \(flightNum)\(correctedFlightNum != flightNum ? " → corrected to: \(correctedFlightNum)" : ""), Day: \(rawDay)\(extractedDay != rawDay ? " → corrected to: \(extractedDay ?? "nil")" : "")")
                return correctedFlightNum
            }
        }

        // Try relaxed QFA format with OCR error correction
        for (index, line) in lines.enumerated() {
            let matches = flightNumberPatternRelaxed.matches(in: line, range: NSRange(line.startIndex..., in: line))
            if let match = matches.first {
                let numberPart = Range(match.range(at: 1), in: line)!
                let dayPart = Range(match.range(at: 2), in: line)!
                let flightNum = String(line[numberPart])
                let rawDay = String(line[dayPart])

                // Apply smart date correction based on current UTC date
                extractedDay = smartCorrectDayOfMonth(rawDay)

                // Clean and correct the flight number
                let cleanedFlightNum = smartExtractFlightNumber(flightNum)
                if !cleanedFlightNum.isEmpty {
                    print("Flight number extracted (QFA format with OCR correction) from line \(index): \(flightNum) → corrected to: \(cleanedFlightNum), Day: \(rawDay)\(extractedDay != rawDay ? " → corrected to: \(extractedDay ?? "nil")" : "")")
                    return cleanedFlightNum
                }
            }
        }

        // Try very relaxed QFA format for severe OCR errors (like Ø for 0)
        for (index, line) in lines.enumerated() {
            let matches = flightNumberPatternVeryRelaxed.matches(in: line, range: NSRange(line.startIndex..., in: line))
            if let match = matches.first {
                let numberPart = Range(match.range(at: 1), in: line)!
                let dayPart = Range(match.range(at: 2), in: line)!
                let flightNum = String(line[numberPart])
                let rawDay = String(line[dayPart])

                print("  Found potential match with very relaxed pattern on line \(index): \(flightNum)")

                // Apply smart date correction based on current UTC date
                extractedDay = smartCorrectDayOfMonth(rawDay)

                // Clean and correct the flight number (handles special chars like Ø)
                let cleanedFlightNum = smartExtractFlightNumberVeryRelaxed(flightNum)
                if !cleanedFlightNum.isEmpty {
                    print("Flight number extracted (QFA very relaxed format) from line \(index): \(flightNum) → corrected to: \(cleanedFlightNum), Day: \(rawDay)\(extractedDay != rawDay ? " → corrected to: \(extractedDay ?? "nil")" : "")")
                    return cleanedFlightNum
                }
            }
        }

        // Try numeric format
        for (index, line) in lines.enumerated() {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces).uppercased()
            if !trimmedLine.contains("DEPT") && !trimmedLine.contains("DEST") {
                let matches = flightNumberPattern2.matches(in: line, range: NSRange(line.startIndex..., in: line))
                if let match = matches.first {
                    let numberPart = Range(match.range(at: 1), in: line)!
                    let dayPart = Range(match.range(at: 2), in: line)!
                    let flightNum = String(line[numberPart])
                    let rawDay = String(line[dayPart])

                    // Apply smart date correction based on current UTC date
                    extractedDay = smartCorrectDayOfMonth(rawDay)

                    // Apply smart correction for leading 8 → 0
                    let correctedFlightNum = smartCorrectFlightNumber(flightNum)
                    print("Flight number extracted (numeric format) from line \(index): \(flightNum)\(correctedFlightNum != flightNum ? " → corrected to: \(correctedFlightNum)" : ""), Day: \(rawDay)\(extractedDay != rawDay ? " → corrected to: \(extractedDay ?? "nil")" : "")")
                    return correctedFlightNum
                }
            }
        }

        print("No flight number found in any pattern")
        return ""
    }

    /// Smart correction for day of month based on current UTC date
    /// Handles common OCR errors like "28" when it should be "20" (0 misread as 8)
    /// Only corrects when the date contains digits that could be confused (0 and 8)
    /// Uses current UTC date as context to validate and correct extracted day
    private func smartCorrectDayOfMonth(_ day: String) -> String {
        guard let extractedDay = Int(day), extractedDay >= 1, extractedDay <= 31 else {
            print("Invalid day format: \(day)")
            return day
        }

        // Only attempt correction if the day contains 0 or 8 (digits that can be confused)
        guard day.count == 2, day.contains("0") || day.contains("8") else {
            print("Day \(day) doesn't contain 0 or 8, no OCR confusion possible")
            return day
        }

        // Get current UTC date components
        var calendar = Calendar.current
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let now = Date()
        let currentDay = calendar.component(.day, from: now)

        // Calculate how far in the future the extracted day would be
        let daysUntilExtracted: Int
        if extractedDay >= currentDay {
            // Same month, future date
            daysUntilExtracted = extractedDay - currentDay
        } else {
            // Would be next month
            // Get days in current month
            let range = calendar.range(of: .day, in: .month, for: now)!
            let daysInMonth = range.count
            daysUntilExtracted = (daysInMonth - currentDay) + extractedDay
        }

        // If the extracted date is more than 7 days in the future, it's likely an OCR error
        // Most flights are logged within a few days of occurrence
        let maxFutureDays = 7

        if daysUntilExtracted > maxFutureDays {
            print("Day \(day) is \(daysUntilExtracted) days in future (current UTC day: \(currentDay)), checking for OCR errors...")

            let firstDigit = day.first!
            let secondDigit = day.last!

            // Try common OCR corrections for the second digit
            // Most common: 8 misread as 0 (e.g., "28" → "20")
            if secondDigit == "8" {
                let correctedDay = "\(firstDigit)0"
                if let correctedDayInt = Int(correctedDay),
                   correctedDayInt >= 1 && correctedDayInt <= 31 {

                    // Check if corrected day makes more sense
                    let daysUntilCorrected: Int
                    if correctedDayInt >= currentDay {
                        daysUntilCorrected = correctedDayInt - currentDay
                    } else {
                        let range = calendar.range(of: .day, in: .month, for: now)!
                        let daysInMonth = range.count
                        daysUntilCorrected = (daysInMonth - currentDay) + correctedDayInt
                    }

                    // If corrected date is within acceptable range, use it
                    if daysUntilCorrected <= maxFutureDays {
                        print("→ Corrected day from \(day) to \(correctedDay) (now \(daysUntilCorrected) days from current date)")
                        return correctedDay
                    }
                }
            }

            // Less common: 0 misread as 8 (e.g., "20" scanned as "28")
            // Only try this if second digit is 0 and first digit is 1 or 2
            if secondDigit == "0" && (firstDigit == "1" || firstDigit == "2") {
                let correctedDay = "\(firstDigit)8"
                if let correctedDayInt = Int(correctedDay),
                   correctedDayInt >= 1 && correctedDayInt <= 31 {

                    let daysUntilCorrected: Int
                    if correctedDayInt >= currentDay {
                        daysUntilCorrected = correctedDayInt - currentDay
                    } else {
                        let range = calendar.range(of: .day, in: .month, for: now)!
                        let daysInMonth = range.count
                        daysUntilCorrected = (daysInMonth - currentDay) + correctedDayInt
                    }

                    if daysUntilCorrected <= maxFutureDays {
                        print("→ Corrected day from \(day) to \(correctedDay) (now \(daysUntilCorrected) days from current date)")
                        return correctedDay
                    }
                }
            }

            print("→ No valid correction found, keeping original: \(day)")
        } else {
            print("Day \(day) is valid (\(daysUntilExtracted) days from current UTC day: \(currentDay))")
        }

        return day
    }

    /// Smart extraction and correction for flight numbers with OCR errors
    /// Handles cases like "B474" → "0474" where letters are misread digits
    private func smartExtractFlightNumber(_ flightNumber: String) -> String {
        // Common OCR character substitutions
        let ocrSubstitutions: [Character: Character] = [
            "O": "0",  // O → 0
            "I": "1",  // I → 1
            "l": "1",  // lowercase L → 1
            "Z": "2",  // Z → 2
            "S": "5",  // S → 5
            "B": "8",  // B → 8
            "G": "6",  // G → 6
            "D": "0",  // D → 0
        ]

        var corrected = ""
        for char in flightNumber {
            if let digit = ocrSubstitutions[char] {
                corrected.append(digit)
            } else if char.isNumber {
                corrected.append(char)
            }
            // Skip any other characters
        }

        // Should have exactly 4 digits now
        guard corrected.count == 4 else {
            return ""
        }

        // Apply the standard 8 → 0 correction for leading position
        return smartCorrectFlightNumber(corrected)
    }

    /// Very relaxed extraction for flight numbers with severe OCR errors
    /// Handles special Unicode characters like Ø (Scandinavian O) and other OCR misreads
    /// Processes any non-whitespace characters and converts them to digits
    private func smartExtractFlightNumberVeryRelaxed(_ flightNumber: String) -> String {
        print("  Attempting very relaxed extraction on: \(flightNumber)")

        // Extended OCR character substitutions including Unicode variants
        let ocrSubstitutions: [Character: Character] = [
            "O": "0",  // O → 0
            "o": "0",  // lowercase o → 0
            "Ø": "0",  // Scandinavian O with stroke → 0 (THIS IS THE KEY FIX!)
            "ø": "0",  // lowercase ø → 0
            "I": "1",  // I → 1
            "i": "1",  // i → 1
            "l": "1",  // lowercase L → 1
            "|": "1",  // pipe → 1
            "Z": "2",  // Z → 2
            "z": "2",  // z → 2
            "S": "5",  // S → 5
            "s": "5",  // s → 5
            "B": "8",  // B → 8
            "b": "8",  // b → 8
            "G": "6",  // G → 6
            "g": "6",  // g → 6
            "D": "0",  // D → 0
            "d": "0",  // d → 0
            "Q": "0",  // Q → 0
            "q": "0",  // q → 0
        ]

        var corrected = ""
        for char in flightNumber {
            if let digit = ocrSubstitutions[char] {
                corrected.append(digit)
                print("    Converted '\(char)' → '\(digit)'")
            } else if char.isNumber {
                corrected.append(char)
            } else {
                // Unknown character - log it but skip
                print("    Unknown character '\(char)' (Unicode: \\u{\(String(char.unicodeScalars.first!.value, radix: 16))})")
            }
        }

        // Should have exactly 4 digits now
        guard corrected.count == 4 else {
            print("    After conversion, got \(corrected.count) digits instead of 4: \(corrected)")
            return ""
        }

        print("    ✓ Converted to 4 digits: \(corrected)")

        // Apply the standard 8 → 0 correction for leading position
        let finalCorrected = smartCorrectFlightNumber(corrected)
        if finalCorrected != corrected {
            print("    ✓ Applied leading 8→0 correction: \(corrected) → \(finalCorrected)")
        }

        return finalCorrected
    }

    /// Smart correction for common OCR flight number errors
    /// QFA flight numbers are typically 3 digits (0xxx) or 4 digits (xxxx)
    /// Common OCR error: leading 0 misread as 8 (e.g., 8474 → 0474)
    private func smartCorrectFlightNumber(_ flightNumber: String) -> String {
        guard flightNumber.count == 4 else {
            return flightNumber
        }

        // If flight number starts with 8 and is 4 digits, likely should be 0
        // QFA three-digit flight numbers: QFA001-QFA999 (0001-0999 in 4-digit format)
        // QFA four-digit flight numbers: QFA1000-QFA9999
        // Starting with 8xxx (8000-8999) is very rare compared to 0xxx
        if flightNumber.hasPrefix("8") {
            if let number = Int(flightNumber), number >= 8000 && number <= 8999 {
                let corrected = "0" + flightNumber.dropFirst()
                // Most QFA flights with leading 0 are valid
                // Accept if in typical ranges: 0001-0999 (three-digit flights)
                if let correctedNum = Int(corrected), correctedNum >= 1 && correctedNum <= 999 {
                    return corrected
                }
            }
        }

        return flightNumber
    }
    
    private func extractAirports(from lines: [String]) -> (from: String, to: String) {
        let airportPattern = try! NSRegularExpression(pattern: "([A-Z]{4})/([A-Z]{4})")
        
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces).uppercased()
            if !trimmedLine.contains("QFA") && !trimmedLine.contains("DEPT") && !trimmedLine.contains("DEST") {
                let matches = airportPattern.matches(in: line, range: NSRange(line.startIndex..., in: line))
                if let match = matches.first {
                    let fromRange = Range(match.range(at: 1), in: line)!
                    let toRange = Range(match.range(at: 2), in: line)!
                    let fromAirport = String(line[fromRange])
                    let toAirport = String(line[toRange])
                    
                    if fromAirport.allSatisfy({ $0.isLetter }) && toAirport.allSatisfy({ $0.isLetter }) {
                        print("Airports extracted: FROM=\(fromAirport), TO=\(toAirport)")
                        return (fromAirport, toAirport)
                    }
                }
            }
        }
        
        return ("", "")
    }
    
    private func isValidTimeFormat(_ time: String) -> Bool {
        let timeValidationRegex = try! NSRegularExpression(pattern: "^([0-1]?[0-9]|2[0-3]):[0-5][0-9]$|^([0-9]):[0-5][0-9]$")
        return timeValidationRegex.firstMatch(in: time, range: NSRange(time.startIndex..., in: time)) != nil
    }

    // MARK: - B787 Specific Methods

    /// Process B787 ACARS text recognition results
    private func processB787TextRecognitionResults(_ results: [VNRecognizedTextObservation]) throws -> FlightData {
        // Combine all recognized text
        var recognizedText = ""
        for observation in results {
            guard let topCandidate = observation.topCandidates(1).first else { continue }
            recognizedText += topCandidate.string + "\n"
        }

        print("B787 Recognized text: \(recognizedText)")

        // Extract the different components for B787
        let outTime = extractB787CurrentFlightTime(from: recognizedText, timeType: "OUT")
        let inTime = extractB787CurrentFlightTime(from: recognizedText, timeType: "IN")
        let offTime = extractB787CurrentFlightTime(from: recognizedText, timeType: "OFF")
        let onTime = extractB787CurrentFlightTime(from: recognizedText, timeType: "ON")
        let flightDetails = extractB787FlightDetails(from: recognizedText)

        // Build list of missing fields for user feedback
        var missingFields: [String] = []
        if outTime.isEmpty { missingFields.append("OUT time") }
        if inTime.isEmpty { missingFields.append("IN time") }
        if !outTime.isEmpty && !isValidTimeFormat(outTime) { missingFields.append("valid OUT time") }
        if !inTime.isEmpty && !isValidTimeFormat(inTime) { missingFields.append("valid IN time") }

        // Return partial data even if some fields are missing
        let flightData = FlightData(
            outTime: outTime,
            inTime: inTime,
            offTime: offTime,
            onTime: onTime,
            blockTime: "", // B787 doesn't provide block time in ACARS
            flightNumber: flightDetails.flightNumber,
            fromAirport: "", // B787 ACARS doesn't include airport codes
            toAirport: "", // B787 ACARS doesn't include airport codes
            dayOfMonth: nil, // B787 uses fullDate instead
            aircraftRegistration: flightDetails.aircraftRegistration,
            fullDate: flightDetails.fullDate
        )

        // If we have missing critical fields, throw error but it will be caught with partial data
        if !missingFields.isEmpty {
            print("B787 Partial extraction - missing: \(missingFields.joined(separator: ", "))")
            throw PartialExtractionError(message: "Could not extract: \(missingFields.joined(separator: ", ")). Please verify and fill in missing fields.", partialData: flightData)
        }

        return flightData
    }

    /// Extract current flight time from B787 ACARS
    /// B787 format has "CURRENT FLIGHT" section followed by time fields
    /// Due to OCR layout, time values appear after "TAIL NO:" line in order: OUT, OFF, ON, IN
    private func extractB787CurrentFlightTime(from text: String, timeType: String) -> String {
        let lines = text.components(separatedBy: .newlines)

        // Find the line with "TAIL NO:" - times appear after this
        guard let tailNoIndex = lines.firstIndex(where: { $0.contains("TAIL NO:") }) else {
            print("Could not find TAIL NO: line")
            return ""
        }

        // Count how many time fields appear before this one
        // Order is: OUT, OFF, ON, IN
        let timeFields = ["OUT", "OFF", "ON", "IN"]
        guard let fieldIndex = timeFields.firstIndex(of: timeType) else {
            print("Invalid time type: \(timeType)")
            return ""
        }

        // Find all time values (HH:MM format) that appear after TAIL NO:
        let timePattern = try! NSRegularExpression(pattern: "^(\\d{2}:\\d{2})$")
        var timeValues: [String] = []

        // Search from line after TAIL NO: onwards for time values
        for i in (tailNoIndex + 1)..<lines.count {
            let line = lines[i].trimmingCharacters(in: .whitespaces)
            let matches = timePattern.matches(in: line, range: NSRange(line.startIndex..., in: line))

            if let match = matches.first {
                let timeRange = Range(match.range(at: 1), in: line)!
                let timeValue = String(line[timeRange])
                timeValues.append(timeValue)

                // We need 4 times for current flight (OUT, OFF, ON, IN)
                // Stop after we have enough
                if timeValues.count >= 4 {
                    break
                }
            }
        }

        // Get the time value at the field index
        if fieldIndex < timeValues.count {
            let extractedTime = timeValues[fieldIndex]
            // Apply smart correction for common OCR errors
            let correctedTime = smartCorrectTime(extractedTime)
            print("Found B787 \(timeType) time: \(extractedTime)\(correctedTime != extractedTime ? " → corrected to: \(correctedTime)" : "")")
            return correctedTime
        }

        print("No B787 \(timeType) time found at index \(fieldIndex) (found \(timeValues.count) times total)")
        return ""
    }

    /// Extract B787 flight details (flight number, date, tail number)
    private func extractB787FlightDetails(from text: String) -> (flightNumber: String, fullDate: String?, aircraftRegistration: String?) {
        let lines = text.components(separatedBy: .newlines)

        var flightNumber = ""
        var fullDate: String?
        var aircraftRegistration: String? = nil

        // Extract flight number - B787 format: "FLIGHT NO: QFA15"
        let flightNumberPattern = try! NSRegularExpression(pattern: "FLIGHT\\s+NO:\\s*QFA(\\d{1,4})")
        for line in lines {
            let matches = flightNumberPattern.matches(in: line, range: NSRange(line.startIndex..., in: line))
            if let match = matches.first {
                let numberPart = Range(match.range(at: 1), in: line)!
                flightNumber = String(line[numberPart])
                print("B787 Flight number extracted: \(flightNumber)")
                break
            }
        }

        // Extract date - B787 format in header: "DATE: MMDDYY" (e.g., "120325" = Dec 03, 2025)
        // Date value appears on the line after "DATE:" label
        if let dateIndex = lines.firstIndex(where: { $0.contains("DATE:") }) {
            // Check the next line for the date value
            let nextLineIndex = dateIndex + 1
            if nextLineIndex < lines.count {
                let nextLine = lines[nextLineIndex].trimmingCharacters(in: .whitespaces)

                // Check if this line contains a 6-digit date
                let datePattern = try! NSRegularExpression(pattern: "^(\\d{6})$")
                let matches = datePattern.matches(in: nextLine, range: NSRange(nextLine.startIndex..., in: nextLine))

                if let match = matches.first {
                    let datePart = Range(match.range(at: 1), in: nextLine)!
                    let dateString = String(nextLine[datePart])

                    // Parse MMDDYY format and convert to DD/MM/YYYY
                    if dateString.count == 6 {
                        let mmIndex = dateString.index(dateString.startIndex, offsetBy: 0)
                        let ddIndex = dateString.index(dateString.startIndex, offsetBy: 2)
                        let yyIndex = dateString.index(dateString.startIndex, offsetBy: 4)

                        let mm = String(dateString[mmIndex..<ddIndex])
                        let dd = String(dateString[ddIndex..<yyIndex])
                        let yy = String(dateString[yyIndex...])

                        // Convert 2-digit year to 4-digit (assume 20xx)
                        let yyyy = "20\(yy)"

                        fullDate = "\(dd)/\(mm)/\(yyyy)"
                        print("B787 Date extracted: \(fullDate ?? "") from MMDDYY: \(dateString)")
                    }
                }
            }
        }

        // Extract tail number - B787 format: "TAIL NO: VH-ZND"
        // We'll strip the "VH-" prefix for consistency with B737
        let tailPattern = try! NSRegularExpression(pattern: "TAIL\\s+NO:\\s*VH-([A-Z]{3})")
        for line in lines {
            let matches = tailPattern.matches(in: line, range: NSRange(line.startIndex..., in: line))
            if let match = matches.first {
                let tailPart = Range(match.range(at: 1), in: line)!
                aircraftRegistration = String(line[tailPart])
                print("B787 Aircraft registration extracted: \(aircraftRegistration ?? "")")
                break
            }
        }

        return (flightNumber, fullDate, aircraftRegistration)
    }
}

// MARK: - UIImage Orientation Extension
extension CGImagePropertyOrientation {
    init(_ uiOrientation: UIImage.Orientation) {
        switch uiOrientation {
        case .up: self = .up
        case .down: self = .down
        case .left: self = .left
        case .right: self = .right
        case .upMirrored: self = .upMirrored
        case .downMirrored: self = .downMirrored
        case .leftMirrored: self = .leftMirrored
        case .rightMirrored: self = .rightMirrored
        @unknown default: self = .up
        }
    }
}
