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

        // Try columnar ACARS extraction first (where labels and values are in separate sections)
        if let columnarTimes = extractTimesFromColumnarLayout(from: recognizedText) {
            print("✓ Using columnar ACARS layout extraction")
            let flightDetails = extractFlightDetails(from: recognizedText)

            // Validate time sequence and cross-check with FLT/BLK times
            validateAndCorrectTimeSequence(
                out: columnarTimes.out,
                off: columnarTimes.off,
                on: columnarTimes.on,
                in: columnarTimes.in,
                fltTime: columnarTimes.flt,
                blkTime: columnarTimes.blk
            )

            let flightData = FlightData(
                outTime: columnarTimes.out,
                inTime: columnarTimes.in,
                offTime: columnarTimes.off,
                onTime: columnarTimes.on,
                blockTime: columnarTimes.blk.isEmpty ? "" : columnarTimes.blk, // Use extracted BLK if available
                flightNumber: flightDetails.flightNumber,
                fromAirport: flightDetails.fromAirport,
                toAirport: flightDetails.toAirport,
                dayOfMonth: flightDetails.dayOfMonth,
                aircraftRegistration: nil,
                fullDate: nil
            )

            return flightData
        }

        // Fall back to standard pattern-based extraction
        print("✓ Using standard pattern-based extraction")
        let outTime = extractOutTime(from: recognizedText)
        let inTime = extractInTime(from: recognizedText)
        let offTime = extractOffTime(from: recognizedText)
        let onTime = extractOnTime(from: recognizedText)
        let blockTime = extractBlockTime(from: recognizedText)
        let fltTime = extractFlightTime(from: recognizedText)
        let flightDetails = extractFlightDetails(from: recognizedText)

        // Validate time sequence (OUT < OFF < ON < IN) and cross-check with FLT/BLK
        validateAndCorrectTimeSequence(out: outTime, off: offTime, on: onTime, in: inTime, fltTime: fltTime, blkTime: blockTime)

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

    // MARK: - Columnar Layout Extraction

    /// Detect and extract times from columnar ACARS layout where labels and values are separated
    /// Layout pattern:
    ///   OUT
    ///   OFF
    ///   ON
    ///   IN
    ///   HH:MM  <- OUT time
    ///   ...
    ///   HH:MM  <- OFF time
    ///   ...
    ///   HH:MM  <- ON time
    ///   ...
    ///   HH:MM  <- IN time
    private func extractTimesFromColumnarLayout(from text: String) -> (out: String, off: String, on: String, in: String, flt: String, blk: String)? {
        let lines = text.components(separatedBy: .newlines)

        // Find the section with OUT, OFF, ON, IN on consecutive lines
        var labelStartIndex: Int?
        for i in 0..<(lines.count - 3) {
            let line1 = lines[i].trimmingCharacters(in: .whitespaces)
            let line2 = lines[i + 1].trimmingCharacters(in: .whitespaces)
            let line3 = lines[i + 2].trimmingCharacters(in: .whitespaces)
            let line4 = lines[i + 3].trimmingCharacters(in: .whitespaces)

            if line1 == "OUT" && line2 == "OFF" && line3 == "ON" && line4 == "IN" {
                labelStartIndex = i
                print("Found columnar ACARS layout starting at line \(i)")
                break
            }
        }

        guard let startIndex = labelStartIndex else {
            return nil
        }

        // Extract times that appear after the labels
        // Look for times in the format HH:MM or with OCR errors (Ø, O, 8, etc.)
        let timePattern = try! NSRegularExpression(pattern: "^\\s*([0-9ØøOo8]{2}:[0-9ØøOo]{2})\\s*$")

        // Track which label we're capturing for
        let skipLabelsOnly = ["ON-BLX", "FUEL", "STATE", "*PRINT", "SENSORS", "INIT", "REF", "FIX", "MENU"]

        var extractedTimes: [String] = []
        var fltTime = ""
        var blkTime = ""
        var searchIndex = startIndex + 4  // Start after IN label
        var lastTimeIndex = searchIndex  // Track where we found the last time
        var captureNextTimeAs: String? = nil  // Track which field the next time belongs to

        // Extract up to 4 times (OUT, OFF, ON, IN), and also capture FLT/BLK for validation
        while extractedTimes.count < 4 && searchIndex < lines.count && (searchIndex - lastTimeIndex) < 20 {
            let line = lines[searchIndex].trimmingCharacters(in: .whitespaces)

            // Check if this line is FLT or BLK label
            if line == "FLT" {
                captureNextTimeAs = "FLT"
                searchIndex += 1
                continue
            } else if line == "BLK" {
                captureNextTimeAs = "BLK"
                searchIndex += 1
                continue
            }

            // Skip lines that are labels without associated times
            if skipLabelsOnly.contains(line) || line.isEmpty {
                searchIndex += 1
                continue
            }

            let matches = timePattern.matches(in: line, range: NSRange(line.startIndex..., in: line))

            if let match = matches.first, let timeRange = Range(match.range(at: 1), in: line) {
                let rawTime = String(line[timeRange])
                let correctedTime = smartCorrectTime(rawTime)

                // Check if this time belongs to FLT or BLK
                if let captureAs = captureNextTimeAs {
                    if captureAs == "FLT" {
                        fltTime = correctedTime
                        print("  Captured FLT time at line \(searchIndex): \(rawTime)\(rawTime != correctedTime ? " → \(correctedTime)" : "")")
                    } else if captureAs == "BLK" {
                        blkTime = correctedTime
                        print("  Captured BLK time at line \(searchIndex): \(rawTime)\(rawTime != correctedTime ? " → \(correctedTime)" : "")")
                    }
                    captureNextTimeAs = nil
                    searchIndex += 1
                    continue
                }

                // This is a flight time (OUT, OFF, ON, or IN)
                extractedTimes.append(correctedTime)
                lastTimeIndex = searchIndex

                // Map to field names for logging
                let fieldNames = ["OUT", "OFF", "ON", "IN"]
                let fieldName = extractedTimes.count <= fieldNames.count ? fieldNames[extractedTimes.count - 1] : "?"
                print("  Columnar \(fieldName) time at line \(searchIndex): \(rawTime)\(rawTime != correctedTime ? " → \(correctedTime)" : "")")
            }

            searchIndex += 1
        }

        // Need exactly 4 times
        guard extractedTimes.count == 4 else {
            print("⚠️ Columnar layout detected but found \(extractedTimes.count) times (expected 4)")
            return nil
        }

        return (
            out: extractedTimes[0],
            off: extractedTimes[1],
            on: extractedTimes[2],
            in: extractedTimes[3],
            flt: fltTime,
            blk: blkTime
        )
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
            // SPECIAL CASE: ON and IN on consecutive lines followed by TWO times (capture second time for IN)
            // Pattern: ON\n IN\n HH:MM\n HH:MM - we want the second HH:MM
            try! NSRegularExpression(pattern: "ON\\s*\\n\\s*IN\\s*\\n\\s*\\d{2}:\\d{2}\\s*\\n\\s*(\\d{2}:\\d{2})"),
            // Also handle with OCR errors in first time (8 instead of 0)
            try! NSRegularExpression(pattern: "ON\\s*\\n\\s*IN\\s*\\n\\s*[8\\d]{2}:[\\d]{2}\\s*\\n\\s*(\\d{2}:\\d{2})"),
            // Stricter: only spaces/tabs on same line (not newlines)
            try! NSRegularExpression(pattern: "IN[ \\t]+(\\d{2}:\\d{2})"),
            // Allow one newline but time must be within 5 spaces
            try! NSRegularExpression(pattern: "IN\\s*\\n[ \\t]{0,5}(\\d{2}:\\d{2})"),
            // Colon/dash/dot separator on same line
            try! NSRegularExpression(pattern: "IN[ \\t]*[:\\-\\.]?[ \\t]*(\\d{2}:\\d{2})"),
            // One newline with up to 10 chars, then another newline and time
            try! NSRegularExpression(pattern: "IN\\s*\\n[^\\n]{0,10}\\n\\s*(\\d{2}:\\d{2})"),
            // Newline with colon prefix
            try! NSRegularExpression(pattern: "IN\\s*\\n\\s*:\\s*(\\d{2})"),
            // Newline with semicolon/period prefix
            try! NSRegularExpression(pattern: "IN\\s*\\n\\s*[;\\.]\\s*(\\d{2})"),
            // More restrictive: max 10 non-digit chars between IN and time
            try! NSRegularExpression(pattern: "IN[^\\d]{0,10}(\\d{2})[ \\t]*[:\\-;\\.]?[ \\t]*(\\d{2})"),
            // Strict: max 10 chars between IN and HH:MM
            try! NSRegularExpression(pattern: "IN[^\\d]{0,10}(\\d{2}:\\d{2})"),
            // Hour and minute on separate lines after IN
            try! NSRegularExpression(pattern: "IN\\s*\\n\\s*(\\d{2})\\s*\\n\\s*(\\d{2})"),
            // Fallback: allow up to 30 chars but prefer earlier matches
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
            // SPECIAL CASE: ON and IN on consecutive lines followed by TWO times (capture first time for ON)
            // Pattern: ON\n IN\n HH:MM\n HH:MM - we want the first HH:MM
            try! NSRegularExpression(pattern: "ON\\s*\\n\\s*IN\\s*\\n\\s*([8\\d]{2}:[\\d]{2})"),
            // Stricter: only spaces/tabs on same line (not newlines)
            try! NSRegularExpression(pattern: "ON[ \\t]+(\\d{2}:\\d{2})"),
            // Allow one newline but time must be within 5 spaces
            try! NSRegularExpression(pattern: "ON\\s*\\n[ \\t]{0,5}(\\d{2}:\\d{2})"),
            // Colon/dash/dot separator on same line
            try! NSRegularExpression(pattern: "ON[ \\t]*[:\\-\\.]?[ \\t]*(\\d{2}:\\d{2})"),
            // One newline with up to 10 chars, then another newline and time
            try! NSRegularExpression(pattern: "ON\\s*\\n[^\\n]{0,10}\\n\\s*(\\d{2}:\\d{2})"),
            // Newline with colon prefix
            try! NSRegularExpression(pattern: "ON\\s*\\n\\s*:\\s*(\\d{2})"),
            // Newline with semicolon/period prefix
            try! NSRegularExpression(pattern: "ON\\s*\\n\\s*[;\\.]\\s*(\\d{2})"),
            // More restrictive: max 10 non-digit chars between ON and time
            try! NSRegularExpression(pattern: "ON[^\\d]{0,10}(\\d{2})[ \\t]*[:\\-;\\.]?[ \\t]*(\\d{2})"),
            // Strict: max 10 chars between ON and HH:MM
            try! NSRegularExpression(pattern: "ON[^\\d]{0,10}(\\d{2}:\\d{2})"),
            // Hour and minute on separate lines after ON
            try! NSRegularExpression(pattern: "ON\\s*\\n\\s*(\\d{2})\\s*\\n\\s*(\\d{2})"),
            // Fallback: allow up to 30 chars but prefer earlier matches
            try! NSRegularExpression(pattern: "ON.{0,30}?(\\d{2}:\\d{2})"),
            // Relaxed patterns for OCR errors ($ or other chars instead of digits)
            try! NSRegularExpression(pattern: "ON[ \\t]+([\\$\\d]{1,2}:[\\d]{2})"),
            try! NSRegularExpression(pattern: "ON\\s*\\n[ \\t]{0,5}([\\$\\d]{1,2}:[\\d]{2})")
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

    private func extractFlightTime(from text: String) -> String {
        let flightPatterns: [NSRegularExpression] = [
            try! NSRegularExpression(pattern: "FLT\\s+(\\d{2}:\\d{2})"),
            try! NSRegularExpression(pattern: "FLT\\s*\\n\\s*(\\d{2}:\\d{2})"),
            try! NSRegularExpression(pattern: "FLT\\s*[:\\-\\.]?\\s*(\\d{2}:\\d{2})"),
            try! NSRegularExpression(pattern: "FLT\\s*\\n[^\\n]{0,10}\\n\\s*(\\d{2}:\\d{2})"),
            try! NSRegularExpression(pattern: "FLT\\s*\\n\\s*:\\s*(\\d{2})"),
            try! NSRegularExpression(pattern: "FLT\\s*\\n\\s*[;\\.]\\s*(\\d{2})"),
            try! NSRegularExpression(pattern: "FLT[^\\d]{0,20}(\\d{2})\\s*[:\\-;\\.]?\\s*(\\d{2})"),
            try! NSRegularExpression(pattern: "FLT[^\\d]{0,10}(\\d{2}:\\d{2})"),
            try! NSRegularExpression(pattern: "FLT\\s*\\n\\s*(\\d{2})\\s*\\n\\s*(\\d{2})"),
            try! NSRegularExpression(pattern: "FLT.{0,30}?(\\d{2}:\\d{2})")
        ]

        return extractTimeWithPatterns(flightPatterns, from: text, timeType: "FLT")
    }

    private func extractTimeWithPatterns(_ patterns: [NSRegularExpression], from text: String, timeType: String) -> String {
        // Footer keywords that indicate non-flight times (like print timestamps)
        let footerKeywords = ["<RETURN", "<PRINT", "SENSORS", "MENU", "EXEC", "INIT", "REF", "FIX", "PREV", "PAGE"]

        for (index, pattern) in patterns.enumerated() {
            let matches = pattern.matches(in: text, range: NSRange(text.startIndex..., in: text))

            // Try all matches, not just the first one
            for match in matches {
                let extractedTime: String

                // Dynamically determine how to extract based on number of capture groups
                let numberOfRanges = match.numberOfRanges

                if numberOfRanges == 2 {
                    // Single capture group - could be full HH:MM or just minutes
                    guard let timeRange = Range(match.range(at: 1), in: text) else { continue }
                    let captured = String(text[timeRange])

                    // Check if it's a full time (contains ':') or just minutes
                    if captured.contains(":") {
                        // Full HH:MM format
                        extractedTime = captured
                    } else {
                        // Just minutes - find the hour
                        let hour = findHourForMinutes(captured, in: text) ?? "00"
                        extractedTime = "\(hour):\(captured)"
                    }
                } else if numberOfRanges == 3 {
                    // Two capture groups - separate hour and minute
                    guard let hourRange = Range(match.range(at: 1), in: text),
                          let minuteRange = Range(match.range(at: 2), in: text) else { continue }
                    let hour = String(text[hourRange])
                    let minute = String(text[minuteRange])
                    extractedTime = "\(hour):\(minute)"
                } else {
                    // Unexpected number of capture groups
                    continue
                }

                // Check if time appears AFTER footer keywords (not before)
                // Only skip times that are part of the footer section
                if let matchRange = Range(match.range, in: text) {
                    // Check 30 chars BEFORE the time for footer keywords
                    let contextStart = text.index(matchRange.lowerBound, offsetBy: -30, limitedBy: text.startIndex) ?? text.startIndex
                    let beforeContext = String(text[contextStart..<matchRange.lowerBound])

                    // If a footer keyword appears before this time, skip it
                    if footerKeywords.contains(where: { beforeContext.contains($0) }) {
                        print("⚠️ Skipping \(timeType) time \(extractedTime) (pattern \(index)) - appears after footer keyword")
                        continue  // Try next match
                    }
                }

                // Apply smart correction for common OCR errors
                let correctedTime = smartCorrectTime(extractedTime)
                let patternDesc = (index == 0 && (timeType == "ON" || timeType == "IN")) ? " [ON/IN special case]" : ""
                print("Found \(timeType) time (pattern \(index)\(patternDesc)): \(extractedTime)\(correctedTime != extractedTime ? " → corrected to: \(correctedTime)" : "")")
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

    // MARK: - Time Sequence Validation Helpers

    /// Convert time string (HH:MM) to total minutes for comparison
    private func timeToMinutes(_ time: String) -> Int? {
        let components = time.split(separator: ":").compactMap { Int($0) }
        guard components.count == 2, components[0] >= 0, components[0] < 24, components[1] >= 0, components[1] < 60 else {
            return nil
        }
        return components[0] * 60 + components[1]
    }

    /// Validate that extracted times follow chronological order: OUT < OFF < ON < IN
    /// Returns true if sequence is valid or if times are empty
    /// Handles midnight crossings by adding 24 hours to times that appear on the next day
    private func isValidTimeSequence(out: String, off: String, on: String, in inTime: String) -> Bool {
        // Convert times to minutes
        guard let outMin = timeToMinutes(out), !out.isEmpty else { return true }
        guard let offMin = timeToMinutes(off), !off.isEmpty else { return true }
        guard var onMin = timeToMinutes(on), !on.isEmpty else { return true }
        guard var inMin = timeToMinutes(inTime), !inTime.isEmpty else { return true }

        // Handle midnight crossing: if ON < OFF, assume ON is on the next day
        if onMin < offMin {
            onMin += 1440  // Add 24 hours
        }

        // Handle midnight crossing: if IN < ON (adjusted), assume IN is on the next day
        // Also check if IN < OUT (original) as another indicator
        if inMin < onMin || inMin < outMin {
            inMin += 1440  // Add 24 hours
        }

        // Check chronological order with adjusted times
        return outMin < offMin && offMin < onMin && onMin < inMin
    }

    /// Validate time sequence and log warnings if issues detected
    /// Handles midnight crossings by checking if times appear to cross into the next day
    private func validateAndCorrectTimeSequence(out: String, off: String, on: String, in inTime: String, fltTime: String = "", blkTime: String = "") {
        guard !out.isEmpty && !off.isEmpty && !on.isEmpty && !inTime.isEmpty else {
            print("⚠️ Cannot validate time sequence - some times are missing")
            return
        }

        // Check for midnight crossing indicators
        let outMin = timeToMinutes(out)
        let offMin = timeToMinutes(off)
        let onMin = timeToMinutes(on)
        let inMin = timeToMinutes(inTime)

        var midnightCrossing = false
        if let off = offMin, let on = onMin, on < off {
            midnightCrossing = true
        } else if let out = outMin, let in_ = inMin, in_ < out {
            midnightCrossing = true
        }

        if midnightCrossing {
            print("🌙 Midnight crossing detected (flight departed late evening, landed early morning)")
        }

        if !isValidTimeSequence(out: out, off: off, on: on, in: inTime) {
            print("⚠️ TIME SEQUENCE VIOLATION DETECTED!")
            print("   Expected: OUT < OFF < ON < IN")
            print("   Found: OUT=\(out), OFF=\(off), ON=\(on), IN=\(inTime)")
            print("   This might indicate an OCR error or data issue")
        } else {
            if midnightCrossing {
                print("✅ Time sequence is valid (with midnight crossing): OUT=\(out), OFF=\(off), ON=\(on) [next day], IN=\(inTime) [next day]")
            } else {
                print("✅ Time sequence is valid: OUT=\(out) < OFF=\(off) < ON=\(on) < IN=\(inTime)")
            }
        }

        // Additional validation: Check FLT and BLK times match the extracted values
        validateFlightAndBlockTimes(out: out, off: off, on: on, in: inTime, fltTime: fltTime, blkTime: blkTime)
    }

    /// Validate FLT and BLK times against calculated values
    /// FLT = ON - OFF (flight time), BLK = IN - OUT (block time), BLK > FLT
    /// Handles midnight crossings by adding 24 hours when necessary
    private func validateFlightAndBlockTimes(out: String, off: String, on: String, in inTime: String, fltTime: String, blkTime: String) {
        guard let outMin = timeToMinutes(out),
              let offMin = timeToMinutes(off),
              var onMin = timeToMinutes(on),
              var inMin = timeToMinutes(inTime) else {
            return
        }

        // Handle midnight crossing for ON time: if ON < OFF, assume ON is on the next day
        if onMin < offMin {
            onMin += 1440  // Add 24 hours
            print("🕐 Detected midnight crossing: ON time adjusted from \(on) to next day (\(onMin) minutes)")
        }

        // Handle midnight crossing for IN time: if IN < OUT or IN < ON (adjusted), assume IN is on the next day
        if inMin < outMin || inMin < onMin {
            inMin += 1440  // Add 24 hours
            print("🕐 Detected midnight crossing: IN time adjusted from \(inTime) to next day (\(inMin) minutes)")
        }

        // Calculate expected FLT and BLK times with adjusted values
        let calculatedFltMinutes = onMin - offMin
        let calculatedBlkMinutes = inMin - outMin

        let calculatedFlt = minutesToHHMM(calculatedFltMinutes)
        let calculatedBlk = minutesToHHMM(calculatedBlkMinutes)

        print("📊 Calculated times: FLT=\(calculatedFlt), BLK=\(calculatedBlk)")

        // Validate BLK > FLT (always true, since block includes taxi time)
        if calculatedBlkMinutes <= calculatedFltMinutes {
            print("⚠️ BLK time (\(calculatedBlk)) should be greater than FLT time (\(calculatedFlt))")
        }

        // If we extracted FLT/BLK times, compare them
        if !fltTime.isEmpty, let extractedFltMin = timeToMinutes(fltTime) {
            let difference = abs(extractedFltMin - calculatedFltMinutes)
            if difference > 2 { // Allow 2 minute tolerance for rounding
                print("⚠️ Extracted FLT time (\(fltTime)) doesn't match calculated (\(calculatedFlt)) - difference: \(difference) min")
            } else {
                print("✅ FLT time verified: extracted \(fltTime) ≈ calculated \(calculatedFlt)")
            }
        }

        if !blkTime.isEmpty, let extractedBlkMin = timeToMinutes(blkTime) {
            let difference = abs(extractedBlkMin - calculatedBlkMinutes)
            if difference > 2 { // Allow 2 minute tolerance for rounding
                print("⚠️ Extracted BLK time (\(blkTime)) doesn't match calculated (\(calculatedBlk)) - difference: \(difference) min")
            } else {
                print("✅ BLK time verified: extracted \(blkTime) ≈ calculated \(calculatedBlk)")
            }
        }
    }

    /// Convert minutes to HH:MM format
    private func minutesToHHMM(_ minutes: Int) -> String {
        let hours = minutes / 60
        let mins = minutes % 60
        return String(format: "%02d:%02d", hours, mins)
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

                // Store the day as-is (no correction - month inference happens in ViewModel)
                extractedDay = rawDay

                // Apply smart correction for leading 8 → 0
                let correctedFlightNum = smartCorrectFlightNumber(flightNum)
                print("Flight number extracted (QFA format): \(flightNum)\(correctedFlightNum != flightNum ? " → corrected to: \(correctedFlightNum)" : ""), Day: \(rawDay)")
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

                // Store the day as-is (no correction - month inference happens in ViewModel)
                extractedDay = rawDay

                // Clean and correct the flight number
                let cleanedFlightNum = smartExtractFlightNumber(flightNum)
                if !cleanedFlightNum.isEmpty {
                    print("Flight number extracted (QFA format with OCR correction) from line \(index): \(flightNum) → corrected to: \(cleanedFlightNum), Day: \(rawDay)")
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

                // Store the day as-is (no correction - month inference happens in ViewModel)
                extractedDay = rawDay

                // Clean and correct the flight number (handles special chars like Ø)
                let cleanedFlightNum = smartExtractFlightNumberVeryRelaxed(flightNum)
                if !cleanedFlightNum.isEmpty {
                    print("Flight number extracted (QFA very relaxed format) from line \(index): \(flightNum) → corrected to: \(cleanedFlightNum), Day: \(rawDay)")
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

                    // Store the day as-is (no correction - month inference happens in ViewModel)
                    extractedDay = rawDay

                    // Apply smart correction for leading 8 → 0
                    let correctedFlightNum = smartCorrectFlightNumber(flightNum)
                    print("Flight number extracted (numeric format) from line \(index): \(flightNum)\(correctedFlightNum != flightNum ? " → corrected to: \(correctedFlightNum)" : ""), Day: \(rawDay)")
                    return correctedFlightNum
                }
            }
        }

        print("No flight number found in any pattern")
        return ""
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
