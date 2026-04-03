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
import Photos

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
    case a330   // auto-detects screen vs printer format
    case a321   // same ACARS layout as A330/B737 screen format
    case a380   // NSS AVNCS EVENT TIMES screen — same columnar layout as B737
}

// MARK: - Text Recognition Service
class TextRecognitionService: ObservableObject {

    // Reused across calls — CIContext creation is expensive
    private static let ciContext = CIContext(options: [.useSoftwareRenderer: false])

    // MARK: - Image Pre-processing

    /// Cleans an ACARS screen photo before passing it to Vision OCR.
    /// Pipeline: greyscale → contrast boost → unsharp mask → binarise.
    /// Returns the original CGImage unchanged if any step fails.
    private func preprocessForOCR(_ cgImage: CGImage) -> CGImage {
        var image = CIImage(cgImage: cgImage)

        // 1. Strip colour — Vision reads monochrome text more reliably
        if let greyscale = CIFilter(name: "CIColorControls", parameters: [
            kCIInputImageKey: image,
            "inputSaturation": 0.0,
            "inputBrightness": 0.05,
            "inputContrast": 1.3
        ])?.outputImage {
            image = greyscale
        }

        // 2. Sharpen — compensates for soft focus through dusty cover panels
        if let sharpened = CIFilter(name: "CIUnsharpMask", parameters: [
            kCIInputImageKey: image,
            kCIInputRadiusKey: 2.5,
            kCIInputIntensityKey: 0.8
        ])?.outputImage {
            image = sharpened
        }

        // 3. Binarise — threshold 0.35 turns dust/smudge artefacts into clean black-or-white
        //    whilst preserving dim green MCDU pixels that a 0.5 threshold kills.
        //    CIColorThreshold is available from iOS 17; fall back gracefully on older OS.
        if #available(iOS 17, *) {
            if let binary = CIFilter(name: "CIColorThreshold", parameters: [
                kCIInputImageKey: image,
                "inputThreshold": 0.35
            ])?.outputImage {
                image = binary
            }
        }

        guard let output = Self.ciContext.createCGImage(image, from: image.extent) else {
            LogManager.shared.debug("Image pre-processing: CIContext render failed, using original")
            return cgImage
        }
        LogManager.shared.debug("Image pre-processing complete")

        // To inspect pre-processing output, uncomment the block below (DEBUG builds only):
         #if DEBUG
         let debugImage = UIImage(cgImage: output)
         PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
             guard status == .authorized || status == .limited else { return }
             PHPhotoLibrary.shared().performChanges({
                 PHAssetChangeRequest.creationRequestForAsset(from: debugImage)
             }, completionHandler: nil)
         }
         #endif

        return output
    }

    /// Pre-processes an A380 NSS AVNCS screen image for OCR.
    ///
    /// The A380 NSS screen uses a strict two-colour convention:
    ///   • White  = field labels  (FLIGHT NUMBER, DEPARTURE, …)
    ///   • Green  = data values   (QF0001, WSSS, 0330, …)
    ///
    /// Pipeline:
    ///   1. Isolate green channel — CIColorMatrix maps (R,G,B) → (G-R, G-R, G-R).
    ///      Pixels where green dominates become bright; white/grey labels collapse to ~0.
    ///   2. Clamp negatives — CIColorClamp ensures no sub-zero artefacts.
    ///   3. Contrast boost + unsharp mask + binarise — same tail as preprocessForOCR.
    ///
    /// Result: only the green data values survive as white text on black, and Vision
    /// reads them top-to-bottom without having to untangle the two-column label layout.
    private func preprocessForA380OCR(_ cgImage: CGImage) -> CGImage {
        var image = CIImage(cgImage: cgImage)

        // 1. Green isolation — output = G − max(R, B), all channels equal (greyscale-ish).
        //    CIColorMatrix: each output channel = dot(inputRGBA, column vector) + bias.
        //    We map: out.r = out.g = out.b = 0*R + 1*G + 0*B  (green channel only),
        //    then subtract a scaled copy of red to suppress white pixels.
        //    Matrix is row-major per CIColorMatrix convention:
        //      Rout = inputR·rVector + inputG·gVector + inputB·bVector + inputA·aVector + biasVector
        //    We want:  out = G - 0.5*(R+B)  for all three channels.
        if let greenOnly = CIFilter(name: "CIColorMatrix", parameters: [
            kCIInputImageKey: image,
            "inputRVector": CIVector(x: -0.5, y: 0.0, z: 0.0, w: 0.0),  // R contribution
            "inputGVector": CIVector(x:  1.0, y: 1.0, z: 1.0, w: 0.0),  // G contribution
            "inputBVector": CIVector(x: -0.5, y: 0.0, z: 0.0, w: 0.0),  // B contribution
            "inputAVector": CIVector(x:  0.0, y: 0.0, z: 0.0, w: 1.0),
            "inputBiasVector": CIVector(x: 0.0, y: 0.0, z: 0.0, w: 0.0)
        ])?.outputImage {
            image = greenOnly
        }

        // 2. Clamp to [0, 1] — negative values from the subtraction above become black.
        if let clamped = CIFilter(name: "CIColorClamp", parameters: [
            kCIInputImageKey: image,
            "inputMinComponents": CIVector(x: 0, y: 0, z: 0, w: 0),
            "inputMaxComponents": CIVector(x: 1, y: 1, z: 1, w: 1)
        ])?.outputImage {
            image = clamped
        }

        // 3. Contrast boost (brightness −0.05 to compensate filter bias, contrast ×2).
        if let boosted = CIFilter(name: "CIColorControls", parameters: [
            kCIInputImageKey: image,
            "inputSaturation": 0.0,
            "inputBrightness": -0.05,
            "inputContrast": 2.0
        ])?.outputImage {
            image = boosted
        }

        // 4. Sharpen.
        if let sharpened = CIFilter(name: "CIUnsharpMask", parameters: [
            kCIInputImageKey: image,
            kCIInputRadiusKey: 2.5,
            kCIInputIntensityKey: 0.8
        ])?.outputImage {
            image = sharpened
        }

        // 5. Binarise — green values land well above 0.35 after the isolation step.
        if #available(iOS 17, *) {
            if let binary = CIFilter(name: "CIColorThreshold", parameters: [
                kCIInputImageKey: image,
                "inputThreshold": 0.35
            ])?.outputImage {
                image = binary
            }
        }

        guard let output = Self.ciContext.createCGImage(image, from: image.extent) else {
            LogManager.shared.debug("A380 image pre-processing: CIContext render failed, using standard pipeline")
            return preprocessForOCR(cgImage)
        }
        LogManager.shared.debug("A380 green-channel image pre-processing complete")

        #if DEBUG
        let debugImage = UIImage(cgImage: output)
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            guard status == .authorized || status == .limited else { return }
            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.creationRequestForAsset(from: debugImage)
            }, completionHandler: nil)
        }
        #endif

        return output
    }

    // MARK: - Public Methods

    /// Extract flight data from an image using Vision OCR
    /// - Parameters:
    ///   - image: The image to extract text from
    ///   - fleetType: The aircraft fleet type (B737 or B787) to determine parsing strategy
    func extractFlightData(from image: UIImage, fleetType: FleetType = .b737) async throws -> FlightData {
        let fleetName: String
        switch fleetType {
        case .b737: fleetName = "B737"
        case .b787: fleetName = "B787"
        case .a330: fleetName = "A330"
        case .a321: fleetName = "A321"
        case .a380: fleetName = "A380"
        }
        LogManager.shared.info("Starting text recognition for \(fleetName) ACARS image")

        guard let rawCGImage = image.cgImage else {
            LogManager.shared.error("Failed to convert UIImage to CGImage for text recognition")
            throw TextRecognitionError(message: "Failed to process image")
        }
        let cgImage = fleetType == .a380 ? preprocessForA380OCR(rawCGImage) : preprocessForOCR(rawCGImage)

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    LogManager.shared.error("Vision text recognition failed: \(error.localizedDescription)")
                    continuation.resume(throwing: TextRecognitionError(message: "Text recognition failed: \(error.localizedDescription)"))
                    return
                }

                guard let results = request.results as? [VNRecognizedTextObservation] else {
                    LogManager.shared.warning("No text observations found in image")
                    continuation.resume(throwing: TextRecognitionError(message: "No text found in image. Make sure you're photographing the ACARS screen."))
                    return
                }

                LogManager.shared.debug("Found \(results.count) text observations in image")

                guard results.count >= 5 else {
                    LogManager.shared.warning("Too few text observations (\(results.count)) — image is probably not an ACARS screen")
                    continuation.resume(throwing: TextRecognitionError(message: "Make sure you're photographing the ACARS screen directly."))
                    return
                }

                do {
                    let flightData: FlightData
                    switch fleetType {
                    case .b737:
                        flightData = try self.processTextRecognitionResults(results)
                    case .b787:
                        flightData = try self.processB787TextRecognitionResults(results)
                    case .a330, .a321:
                        flightData = try self.processA330TextRecognitionResults(results)
                    case .a380:
                        flightData = try self.processA380TextRecognitionResults(results)
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

            let options: [VNImageOption: Any] = [.ciContext: Self.ciContext]
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

        LogManager.shared.debug("Recognized text: \(recognizedText)")

        // Pre-process: rejoin split times where OCR breaks "HH\n:MM" across two lines.
        // e.g. "09\n:57" → "09:57", "09\n:4.7" → "09:47"
        recognizedText = rejoinSplitTimes(in: recognizedText)

        // Try columnar ACARS extraction first (where all labels come first, then all values)
        if let columnarTimes = extractTimesFromColumnarLayout(from: recognizedText) {
        LogManager.shared.debug("✓ Using columnar ACARS layout extraction")
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
                LogManager.shared.debug("✓ Using standard pattern-based extraction")
        let rawOutTime = extractOutTime(from: recognizedText)
        let rawInTime = extractInTime(from: recognizedText)
        let rawOffTime = extractOffTime(from: recognizedText)
        let rawOnTime = extractOnTime(from: recognizedText)
        let blockTime = extractBlockTime(from: recognizedText)
        let fltTime = extractFlightTime(from: recognizedText)
        let flightDetails = extractFlightDetails(from: recognizedText)

        // If the time sequence is invalid, try correcting a leading '8' → '0' OCR error on any
        // time field before accepting a midnight crossing or flagging a violation.
        // e.g. OUT=08:44 should be 00:44 when OFF=01:02, ON=05:59, IN=06:02
        let (outTime, offTime, onTime, inTime) = correctLeadingEightIfNeeded(
            out: rawOutTime, off: rawOffTime, on: rawOnTime, in: rawInTime
        )

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

        // Last resort: try interleaved layout (OUT\nHH:MM\nOFF\nHH:MM…) for degraded OCR images
        if !missingFields.isEmpty, let interleavedTimes = extractTimesFromInterleavedLayout(from: recognizedText) {
            LogManager.shared.debug("✓ Using interleaved ACARS layout extraction (last resort)")
            let interleavedData = FlightData(
                outTime: interleavedTimes.out, inTime: interleavedTimes.in,
                offTime: interleavedTimes.off, onTime: interleavedTimes.on,
                blockTime: interleavedTimes.blk.isEmpty ? "" : interleavedTimes.blk,
                flightNumber: flightDetails.flightNumber,
                fromAirport: flightDetails.fromAirport, toAirport: flightDetails.toAirport,
                dayOfMonth: flightDetails.dayOfMonth, aircraftRegistration: nil, fullDate: nil
            )
            validateAndCorrectTimeSequence(
                out: interleavedTimes.out, off: interleavedTimes.off,
                on: interleavedTimes.on, in: interleavedTimes.in,
                fltTime: interleavedTimes.flt, blkTime: interleavedTimes.blk
            )
            var interleavedMissing: [String] = []
            if interleavedTimes.out.isEmpty { interleavedMissing.append("OUT time") }
            if interleavedTimes.in.isEmpty  { interleavedMissing.append("IN time") }
            if interleavedTimes.off.isEmpty { interleavedMissing.append("OFF time") }
            if interleavedTimes.on.isEmpty  { interleavedMissing.append("ON time") }
            try throwIfMissingCritical(interleavedMissing, partialData: interleavedData)
            return interleavedData
        }

        // If we have missing critical fields, throw error but it will be caught with partial data
        if !missingFields.isEmpty {
                    LogManager.shared.debug("Partial extraction - missing: \(missingFields.joined(separator: ", "))")
            throw PartialExtractionError(message: "Missing: \(missingFields.joined(separator: ", "))", partialData: flightData)
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

            if line1 == "OUT" && line2 == "OFF" && line3 == "ON" && (line4 == "IN" || line4 == "IN.") {
                labelStartIndex = i
                        LogManager.shared.debug("Found columnar ACARS layout starting at line \(i)")
                break
            }
        }

        guard let startIndex = labelStartIndex else {
            return nil
        }

        // Extract times that appear after the labels
        // Look for times in the format HH:MM or with OCR errors (Ø, O, 8, etc.)
        // Also handles OCR spaces around the colon: "03: 21" or "09 :47"
        let timePattern = try! NSRegularExpression(pattern: "^\\s*([0-9ØøOo8]{2} ?: ?[0-9ØøOo]{2})\\s*$")

        // Track which label we're capturing for
        let skipLabelsOnly = ["ON-BLX", "FUEL", "STATE", "*PRINT", "SENSORS", "INIT", "REF", "FIX", "MENU", "<RETURN"]

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
            // Also skip any line that contains "<RETURN" (the footer timestamp line)
            if skipLabelsOnly.contains(where: { line.hasPrefix($0) }) || line.isEmpty {
                searchIndex += 1
                continue
            }

            // Detect OCR-split times: a line of just digits ("04") followed by ": MM" on the next line
            let splitHoursPattern = try! NSRegularExpression(pattern: "^([0-9ØøOo8]{2})$")
            if splitHoursPattern.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) != nil,
               searchIndex + 1 < lines.count {
                let nextLine = lines[searchIndex + 1].trimmingCharacters(in: .whitespaces)
                let splitMinsPattern = try! NSRegularExpression(pattern: "^: ?([0-9ØøOo]{2})$")
                if let minsMatch = splitMinsPattern.firstMatch(in: nextLine, range: NSRange(nextLine.startIndex..., in: nextLine)),
                   let minsRange = Range(minsMatch.range(at: 1), in: nextLine) {
                    let rejoined = line + ":" + nextLine[minsRange]
                    let correctedTime = smartCorrectTime(rejoined)
                    LogManager.shared.debug("  Rejoined split time at line \(searchIndex): '\(line)' + '\(nextLine)' → \(correctedTime)")
                    searchIndex += 2  // consume both lines

                    if let captureAs = captureNextTimeAs {
                        if captureAs == "FLT" { fltTime = correctedTime }
                        else if captureAs == "BLK" { blkTime = correctedTime }
                        captureNextTimeAs = nil
                    } else {
                        extractedTimes.append(correctedTime)
                        lastTimeIndex = searchIndex
                        let fieldNames = ["OUT", "OFF", "ON", "IN"]
                        let fieldName = extractedTimes.count <= fieldNames.count ? fieldNames[extractedTimes.count - 1] : "?"
                        LogManager.shared.debug("  Columnar \(fieldName) time (rejoined): \(correctedTime)")
                    }
                    continue
                }
            }

            let matches = timePattern.matches(in: line, range: NSRange(line.startIndex..., in: line))

            if let match = matches.first, let timeRange = Range(match.range(at: 1), in: line) {
                let rawTime = String(line[timeRange])
                let correctedTime = smartCorrectTime(rawTime)

                // Check if this time belongs to FLT or BLK
                if let captureAs = captureNextTimeAs {
                    if captureAs == "FLT" {
                        fltTime = correctedTime
                                LogManager.shared.debug("  Captured FLT time at line \(searchIndex): \(rawTime)\(rawTime != correctedTime ? " → \(correctedTime)" : "")")
                    } else if captureAs == "BLK" {
                        blkTime = correctedTime
                                LogManager.shared.debug("  Captured BLK time at line \(searchIndex): \(rawTime)\(rawTime != correctedTime ? " → \(correctedTime)" : "")")
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
                        LogManager.shared.debug("  Columnar \(fieldName) time at line \(searchIndex): \(rawTime)\(rawTime != correctedTime ? " → \(correctedTime)" : "")")
            }

            searchIndex += 1
        }

        // Need exactly 4 times
        guard extractedTimes.count == 4 else {
                    LogManager.shared.debug("⚠️ Columnar layout detected but found \(extractedTimes.count) times (expected 4)")
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

    /// Rejoin OCR-split times where the hour and minutes land on separate lines.
    /// Handles patterns like:
    ///   "09\n:57"   → "09:57"
    ///   "09\n:4.7"  → "09:47"  (dot-for-digit corrected later by smartCorrectTime)
    ///   "02\n:00"   → "02:00"
    private func rejoinSplitTimes(in text: String) -> String {
        // Match a line that is just 1-2 digits, followed by a line starting with ":"
        // and containing 1-2 digit/dot characters (minutes fragment).
        let pattern = try! NSRegularExpression(
            pattern: "([0-9]{1,2})\\n(:[0-9.]{1,2})",
            options: []
        )
        var result = text
        // Work backwards through matches so ranges stay valid
        let matches = pattern.matches(in: result, range: NSRange(result.startIndex..., in: result)).reversed()
        for match in matches {
            guard let fullRange = Range(match.range, in: result),
                  let hoursRange = Range(match.range(at: 1), in: result),
                  let minsRange  = Range(match.range(at: 2), in: result) else { continue }
            let hours = String(result[hoursRange])
            let mins  = String(result[minsRange])  // still has leading ":"
            let rejoined = hours + mins             // e.g. "09" + ":57" → "09:57"
            LogManager.shared.debug("  Rejoined split time: '\(hours)\\n\(mins)' → '\(rejoined)'")
            result.replaceSubrange(fullRange, with: rejoined)
        }
        return result
    }

    /// Detect and extract times from interleaved ACARS layout where each label is immediately
    /// followed by its time on the next line:
    ///   OUT          OFF          ON           IN / IN.
    ///   HH:MM        HH:MM        HH:MM        HH:MM
    /// The four pairs may appear in any order but must all be present.
    private func extractTimesFromInterleavedLayout(from text: String) -> (out: String, off: String, on: String, in: String, flt: String, blk: String)? {
        let lines = text.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespaces) }

        // Loose time pattern: accepts OCR noise around the colon and common OCR digit substitutions
        let timeRegex = try! NSRegularExpression(pattern: "^[0-9ØøOo8$@]{1,2} ?[:\\-] ?[0-9ØøOo.]{1,2}$")

        func isTimelike(_ s: String) -> Bool {
            timeRegex.firstMatch(in: s, range: NSRange(s.startIndex..., in: s)) != nil
        }

        func isLabel(_ s: String) -> Bool {
            ["OUT", "OFF", "ON", "IN", "IN."].contains(s)
        }

        // Scan for label→time pairs
        var out = "", off = "", on = "", inTime = "", flt = "", blk = ""
        var found = 0

        for i in 0..<(lines.count - 1) {
            let label = lines[i]
            let next = lines[i + 1]
            guard isLabel(label) && isTimelike(next) else { continue }

            let corrected = smartCorrectTime(next)
            switch label {
            case "OUT":
                if out.isEmpty { out = corrected; found += 1
                    LogManager.shared.debug("  Interleaved OUT at line \(i+1): \(next)\(next != corrected ? " → \(corrected)" : "")") }
            case "OFF":
                if off.isEmpty { off = corrected; found += 1
                    LogManager.shared.debug("  Interleaved OFF at line \(i+1): \(next)\(next != corrected ? " → \(corrected)" : "")") }
            case "ON":
                if on.isEmpty { on = corrected; found += 1
                    LogManager.shared.debug("  Interleaved ON at line \(i+1): \(next)\(next != corrected ? " → \(corrected)" : "")") }
            case "IN", "IN.":
                if inTime.isEmpty { inTime = corrected; found += 1
                    LogManager.shared.debug("  Interleaved IN at line \(i+1): \(next)\(next != corrected ? " → \(corrected)" : "")") }
            default: break
            }
        }

        // Also pick up FLT / BLK the same way
        for i in 0..<(lines.count - 1) {
            let label = lines[i]
            let next = lines[i + 1]
            if (label == "FLT" || label == "FLT.") && isTimelike(next) && flt.isEmpty {
                flt = smartCorrectTime(next)
                LogManager.shared.debug("  Interleaved FLT at line \(i+1): \(next)")
            }
            if (label == "BLK" || label == "BLK.") && isTimelike(next) && blk.isEmpty {
                blk = smartCorrectTime(next)
                LogManager.shared.debug("  Interleaved BLK at line \(i+1): \(next)")
            }
        }

        guard found >= 3 else {
            if found > 0 { LogManager.shared.debug("⚠️ Interleaved layout found only \(found)/4 times — skipping") }
            return nil
        }
        if found < 4 { LogManager.shared.debug("⚠️ Interleaved layout found \(found)/4 times — partial result") }

        return (out: out, off: off, on: on, in: inTime, flt: flt, blk: blk)
    }

    private func extractOutTime(from text: String) -> String {
        // D = digit class including slashed-zero variants OCR'd from the B737 FMC (Ø, ø, O, o)
        let d = "[\\dØøOo@]"
        let outPatterns: [NSRegularExpression] = [
            try! NSRegularExpression(pattern: "OUT\\s+(\(d){2}:\(d){2})"),
            try! NSRegularExpression(pattern: "OUT\\s*\\n\\s*(\(d){2}:\(d){2})"),
            try! NSRegularExpression(pattern: "OUT\\s*[:\\-\\.]?\\s*(\(d){2}:\(d){2})"),
            try! NSRegularExpression(pattern: "OUT\\s*\\n[^\\n]{0,10}\\n\\s*(\(d){2}:\(d){2})"),
            try! NSRegularExpression(pattern: "OUT\\s*\\n\\s*:\\s*(\(d){2})"),
            try! NSRegularExpression(pattern: "OUT\\s*\\n\\s*[;\\.]\\s*(\(d){2})"),
            try! NSRegularExpression(pattern: "OUT[^\(d)]{0,20}(\(d){2})\\s*[:\\-;\\.]?\\s*(\(d){2})"),
            try! NSRegularExpression(pattern: "OUT[^\(d)]{0,10}(\(d){2}:\(d){2})"),
            try! NSRegularExpression(pattern: "OUT\\s*\\n\\s*(\(d){2})\\s*\\n\\s*(\(d){2})"),
            try! NSRegularExpression(pattern: "OUT.{0,30}?(\(d){2}:\(d){2})"),
            // Relaxed patterns for OCR errors ($ or other chars instead of digits)
            try! NSRegularExpression(pattern: "OUT\\s+([\\$\(d)][\(d)]:\(d){2})"),
            try! NSRegularExpression(pattern: "OUT\\s*\\n\\s*([\\$\(d)][\(d)]:\(d){2})"),
            // Even more relaxed: single digit/$ followed by colon
            try! NSRegularExpression(pattern: "OUT\\s+([\\$\(d)]:\(d){2})"),
            try! NSRegularExpression(pattern: "OUT\\s*\\n\\s*([\\$\(d)]:\(d){2})")
        ]

        return extractTimeWithPatterns(outPatterns, from: text, timeType: "OUT")
    }
    
    private func extractInTime(from text: String) -> String {
        // D = digit class including slashed-zero variants OCR'd from the B737 FMC (Ø, ø, O, o)
        let d = "[\\dØøOo@]"
        let inPatterns: [NSRegularExpression] = [
            // OCR variants: "I.N", "I N", "l.N" etc. (Vision sometimes inserts period or space in "IN")
            try! NSRegularExpression(pattern: "I[\\. ]N\\s*\\n\\s*(\(d){2}:\(d){2})"),
            try! NSRegularExpression(pattern: "I[\\. ]N[ \\t]+(\(d){2}:\(d){2})"),
            try! NSRegularExpression(pattern: "I[\\. ]N[^\(d)]{0,10}(\(d){2}:\(d){2})"),
            // SPECIAL CASE: ON and IN on consecutive lines followed by TWO times (capture second time for IN)
            // Pattern: ON\n IN\n HH:MM\n HH:MM - we want the second HH:MM
            try! NSRegularExpression(pattern: "ON\\s*\\n\\s*IN\\s*\\n\\s*\(d){2}:\(d){2}\\s*\\n\\s*(\(d){2}:\(d){2})"),
            // Also handle with OCR errors in first time (8 instead of 0)
            try! NSRegularExpression(pattern: "ON\\s*\\n\\s*IN\\s*\\n\\s*[8\(d)]{2}:[\(d)]{2}\\s*\\n\\s*(\(d){2}:\(d){2})"),
            // Stricter: only spaces/tabs on same line (not newlines)
            try! NSRegularExpression(pattern: "IN[ \\t]+(\(d){2}:\(d){2})"),
            // Allow one newline but time must be within 5 spaces
            try! NSRegularExpression(pattern: "IN\\s*\\n[ \\t]{0,5}(\(d){2}:\(d){2})"),
            // Colon/dash/dot separator on same line
            try! NSRegularExpression(pattern: "IN[ \\t]*[:\\-\\.]?[ \\t]*(\(d){2}:\(d){2})"),
            // One newline with up to 10 chars, then another newline and time
            try! NSRegularExpression(pattern: "IN\\s*\\n[^\\n]{0,10}\\n\\s*(\(d){2}:\(d){2})"),
            // Newline with colon prefix
            try! NSRegularExpression(pattern: "IN\\s*\\n\\s*:\\s*(\(d){2})"),
            // Newline with semicolon/period prefix
            try! NSRegularExpression(pattern: "IN\\s*\\n\\s*[;\\.]\\s*(\(d){2})"),
            // More restrictive: max 10 non-digit chars between IN and time
            try! NSRegularExpression(pattern: "IN[^\(d)]{0,10}(\(d){2})[ \\t]*[:\\-;\\.]?[ \\t]*(\(d){2})"),
            // Strict: max 10 chars between IN and HH:MM
            try! NSRegularExpression(pattern: "IN[^\(d)]{0,10}(\(d){2}:\(d){2})"),
            // Hour and minute on separate lines after IN
            try! NSRegularExpression(pattern: "IN\\s*\\n\\s*(\(d){2})\\s*\\n\\s*(\(d){2})"),
            // Fallback: allow up to 30 chars but prefer earlier matches
            try! NSRegularExpression(pattern: "IN.{0,30}?(\(d){2}:\(d){2})")
        ]

        return extractTimeWithPatterns(inPatterns, from: text, timeType: "IN")
    }

    private func extractOffTime(from text: String) -> String {
        let d = "[\\dØøOo@]"
        let offPatterns: [NSRegularExpression] = [
            try! NSRegularExpression(pattern: "OFF\\s+(\(d){2}:\(d){2})"),
            try! NSRegularExpression(pattern: "OFF\\s*\\n\\s*(\(d){2}:\(d){2})"),
            try! NSRegularExpression(pattern: "OFF\\s*[:\\-\\.]?\\s*(\(d){2}:\(d){2})"),
            try! NSRegularExpression(pattern: "OFF\\s*\\n[^\\n]{0,10}\\n\\s*(\(d){2}:\(d){2})"),
            try! NSRegularExpression(pattern: "OFF\\s*\\n\\s*:\\s*(\(d){2})"),
            try! NSRegularExpression(pattern: "OFF\\s*\\n\\s*[;\\.]\\s*(\(d){2})"),
            try! NSRegularExpression(pattern: "OFF[^\(d)]{0,20}(\(d){2})\\s*[:\\-;\\.]?\\s*(\(d){2})"),
            try! NSRegularExpression(pattern: "OFF[^\(d)]{0,10}(\(d){2}:\(d){2})"),
            try! NSRegularExpression(pattern: "OFF\\s*\\n\\s*(\(d){2})\\s*\\n\\s*(\(d){2})"),
            try! NSRegularExpression(pattern: "OFF.{0,30}?(\(d){2}:\(d){2})"),
            // Relaxed: $ or other OCR noise as leading digit
            try! NSRegularExpression(pattern: "OFF\\s+([\\$\(d)][\(d)]:\(d){2})"),
            try! NSRegularExpression(pattern: "OFF\\s*\\n\\s*([\\$\(d)][\(d)]:\(d){2})")
        ]

        return extractTimeWithPatterns(offPatterns, from: text, timeType: "OFF")
    }

    private func extractOnTime(from text: String) -> String {
        let d = "[\\dØøOo@]"
        let onPatterns: [NSRegularExpression] = [
            // SPECIAL CASE: ON and IN on consecutive lines followed by TWO times (capture first time for ON)
            try! NSRegularExpression(pattern: "ON\\s*\\n\\s*IN\\s*\\n\\s*([8\(d)]{2}:[\(d)]{2})"),
            // Stricter: only spaces/tabs on same line (not newlines)
            try! NSRegularExpression(pattern: "ON[ \\t]+(\(d){2}:\(d){2})"),
            // Allow one newline but time must be within 5 spaces
            try! NSRegularExpression(pattern: "ON\\s*\\n[ \\t]{0,5}(\(d){2}:\(d){2})"),
            // Colon/dash/dot separator on same line
            try! NSRegularExpression(pattern: "ON[ \\t]*[:\\-\\.]?[ \\t]*(\(d){2}:\(d){2})"),
            // One newline with up to 10 chars, then another newline and time
            try! NSRegularExpression(pattern: "ON\\s*\\n[^\\n]{0,10}\\n\\s*(\(d){2}:\(d){2})"),
            // Newline with colon prefix
            try! NSRegularExpression(pattern: "ON\\s*\\n\\s*:\\s*(\(d){2})"),
            // Newline with semicolon/period prefix
            try! NSRegularExpression(pattern: "ON\\s*\\n\\s*[;\\.]\\s*(\(d){2})"),
            // More restrictive: max 10 non-digit chars between ON and time
            try! NSRegularExpression(pattern: "ON[^\(d)]{0,10}(\(d){2})[ \\t]*[:\\-;\\.]?[ \\t]*(\(d){2})"),
            // Strict: max 10 chars between ON and HH:MM
            try! NSRegularExpression(pattern: "ON[^\(d)]{0,10}(\(d){2}:\(d){2})"),
            // Hour and minute on separate lines after ON
            try! NSRegularExpression(pattern: "ON\\s*\\n\\s*(\(d){2})\\s*\\n\\s*(\(d){2})"),
            // Fallback: allow up to 30 chars but prefer earlier matches
            try! NSRegularExpression(pattern: "ON.{0,30}?(\(d){2}:\(d){2})"),
            // Relaxed: $ or other OCR noise as leading digit
            try! NSRegularExpression(pattern: "ON[ \\t]+([\\$\(d)]{1,2}:[\(d)]{2})"),
            try! NSRegularExpression(pattern: "ON\\s*\\n[ \\t]{0,5}([\\$\(d)]{1,2}:[\(d)]{2})")
        ]

        return extractTimeWithPatterns(onPatterns, from: text, timeType: "ON")
    }

    private func extractBlockTime(from text: String) -> String {
        let d = "[\\dØøOo@]"
        let blockPatterns: [NSRegularExpression] = [
            try! NSRegularExpression(pattern: "BLK\\s+(\(d){2}:\(d){2})"),
            try! NSRegularExpression(pattern: "BLK\\s*\\n\\s*(\(d){2}:\(d){2})"),
            try! NSRegularExpression(pattern: "BLK\\s*[:\\-\\.]?\\s*(\(d){2}:\(d){2})"),
            try! NSRegularExpression(pattern: "BLK\\s*\\n[^\\n]{0,10}\\n\\s*(\(d){2}:\(d){2})"),
            try! NSRegularExpression(pattern: "BLK\\s*\\n\\s*:\\s*(\(d){2})"),
            try! NSRegularExpression(pattern: "BLK\\s*\\n\\s*[;\\.]\\s*(\(d){2})"),
            try! NSRegularExpression(pattern: "BLK[^\(d)]{0,20}(\(d){2})\\s*[:\\-;\\.]?\\s*(\(d){2})"),
            try! NSRegularExpression(pattern: "BLK[^\(d)]{0,10}(\(d){2}:\(d){2})"),
            try! NSRegularExpression(pattern: "BLK\\s*\\n\\s*(\(d){2})\\s*\\n\\s*(\(d){2})"),
            try! NSRegularExpression(pattern: "BLK.{0,30}?(\(d){2}:\(d){2})")
        ]

        return extractTimeWithPatterns(blockPatterns, from: text, timeType: "BLOCK")
    }

    private func extractFlightTime(from text: String) -> String {
        let d = "[\\dØøOo@]"
        let flightPatterns: [NSRegularExpression] = [
            try! NSRegularExpression(pattern: "FLT\\s+(\(d){2}:\(d){2})"),
            try! NSRegularExpression(pattern: "FLT\\s*\\n\\s*(\(d){2}:\(d){2})"),
            try! NSRegularExpression(pattern: "FLT\\s*[:\\-\\.]?\\s*(\(d){2}:\(d){2})"),
            try! NSRegularExpression(pattern: "FLT\\s*\\n[^\\n]{0,10}\\n\\s*(\(d){2}:\(d){2})"),
            try! NSRegularExpression(pattern: "FLT\\s*\\n\\s*:\\s*(\(d){2})"),
            try! NSRegularExpression(pattern: "FLT\\s*\\n\\s*[;\\.]\\s*(\(d){2})"),
            try! NSRegularExpression(pattern: "FLT[^\(d)]{0,20}(\(d){2})\\s*[:\\-;\\.]?\\s*(\(d){2})"),
            try! NSRegularExpression(pattern: "FLT[^\(d)]{0,10}(\(d){2}:\(d){2})"),
            try! NSRegularExpression(pattern: "FLT\\s*\\n\\s*(\(d){2})\\s*\\n\\s*(\(d){2})"),
            try! NSRegularExpression(pattern: "FLT.{0,30}?(\(d){2}:\(d){2})")
        ]

        return extractTimeWithPatterns(flightPatterns, from: text, timeType: "FLT")
    }

    // MARK: - Shared Parser Infrastructure

    /// Generic label-based time extractor shared by all parsers.
    /// Builds patterns from strict (same-line) to relaxed (multi-line, OCR noise),
    /// then delegates to extractTimeWithPatterns for footer filtering and smartCorrectTime.
    private func extractTimeField(label: String, from text: String) -> String {
        let d = "[\\dØøOo@]"
        let esc = NSRegularExpression.escapedPattern(for: label)
        let patterns: [NSRegularExpression] = [
            // Strict: label + whitespace + HH:MM on same line (with OCR noise)
            try! NSRegularExpression(pattern: "\\b\(esc)\\b\\s+(\(d){1,2}:\(d){2})"),
            // Label then HH:MM on the next line (common with thermal printer OCR)
            try! NSRegularExpression(pattern: "\\b\(esc)\\b\\s*\\n\\s*(\(d){1,2}:\(d){2})"),
            // Optional separator (colon/dash/dot) on same line
            try! NSRegularExpression(pattern: "\\b\(esc)\\b\\s*[:\\-\\.]?\\s*(\(d){1,2}:\(d){2})"),
            // Label + newline + short junk line + HH:MM
            try! NSRegularExpression(pattern: "\\b\(esc)\\b\\s*\\n[^\\n]{0,10}\\n\\s*(\(d){1,2}:\(d){2})"),
            // Relaxed fallback: up to 30 chars between label and time
            try! NSRegularExpression(pattern: "\\b\(esc)\\b.{0,30}?(\(d){2}:\(d){2})")
        ]
        return extractTimeWithPatterns(patterns, from: text, timeType: label)
    }

    /// Shared partial-extraction reporter used by all parsers.
    /// Throws PartialExtractionError (with partial data attached) if missingFields is non-empty.
    private func throwIfMissingCritical(_ missingFields: [String], partialData: FlightData) throws {
        guard !missingFields.isEmpty else { return }
        LogManager.shared.debug("Partial extraction — missing: \(missingFields.joined(separator: ", "))")
        throw PartialExtractionError(
            message: "Missing: \(missingFields.joined(separator: ", "))",
            partialData: partialData
        )
    }

    private func extractTimeWithPatterns(_ patterns: [NSRegularExpression], from text: String, timeType: String) -> String {
        // Footer keywords that indicate non-flight times (like print timestamps).
        // Also checked inside the full match span, so "HF IN\n<RETURN 06:05" is rejected
        // even though <RETURN appears after the label rather than before the captured time.
        let footerKeywords = ["<RETURN", "<PRINT", "SENSORS", "MENU", "EXEC", "INIT", "REF", "FIX", "PREV", "PAGE",
                              "HF IN", "HF\nIN"]

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

                // Reject matches whose full span (label + time) or 30-char prefix contains a
                // footer keyword. This catches both "HF IN\n<RETURN 06:05" (keyword inside span)
                // and times that appear after a footer line (keyword before span).
                if let matchRange = Range(match.range, in: text) {
                    let fullMatchText = String(text[matchRange])

                    let contextStart = text.index(matchRange.lowerBound, offsetBy: -30, limitedBy: text.startIndex) ?? text.startIndex
                    let beforeContext = String(text[contextStart..<matchRange.lowerBound])

                    let combined = beforeContext + fullMatchText
                    if footerKeywords.contains(where: { combined.contains($0) }) {
                        LogManager.shared.debug("⚠️ Skipping \(timeType) time \(extractedTime) (pattern \(index)) - footer keyword in match context")
                        continue  // Try next match
                    }
                }

                // Apply smart correction for common OCR errors
                let correctedTime = smartCorrectTime(extractedTime)
                let patternDesc = (index == 0 && (timeType == "ON" || timeType == "IN")) ? " [ON/IN special case]" : ""
                        LogManager.shared.debug("Found \(timeType) time (pattern \(index)\(patternDesc)): \(extractedTime)\(correctedTime != extractedTime ? " → corrected to: \(correctedTime)" : "")")
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

        // Strip OCR-introduced spaces around colon (e.g. "03: 21" → "03:21", "09 :47" → "09:47")
        correctedTime = correctedTime.replacingOccurrences(of: ": ", with: ":")
        correctedTime = correctedTime.replacingOccurrences(of: " :", with: ":")

        // Replace dot used as digit in minutes (e.g. "09:4.7" → "09:47", ":4.7" → ":47")
        // Only replace dots between digits in the minutes portion
        if let colonIdx = correctedTime.firstIndex(of: ":") {
            let minutesPart = correctedTime[correctedTime.index(after: colonIdx)...]
            let fixedMinutes = minutesPart.replacingOccurrences(of: ".", with: "")
            correctedTime = correctedTime[...colonIdx] + fixedMinutes
        }

        // First pass: Replace common OCR character errors
        // $ is often misread as 0 (e.g., $7:25 → 07:25, $9:10 → 09:10)
        correctedTime = correctedTime.replacingOccurrences(of: "$", with: "0")
        // @ is sometimes misread as 0 (e.g., @7:22 → 07:22)
        correctedTime = correctedTime.replacingOccurrences(of: "@", with: "0")
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

        // Pad a single-digit minute to two digits (e.g. "01:0" → "01:00", "9:5" → "09:05")
        let paddingComponents = correctedTime.split(separator: ":", maxSplits: 1)
        if paddingComponents.count == 2 {
            var hour = String(paddingComponents[0])
            var minute = String(paddingComponents[1])
            if hour.count == 1 { hour = "0" + hour }
            if minute.count == 1 { minute = minute + "0" }
            let padded = "\(hour):\(minute)"
            if isValidTimeFormat(padded) { return padded }
        }

        // Return corrected time (with character replacements) if no valid correction found
        return correctedTime
    }
    
    /// If the four extracted times don't form a valid sequence, try replacing a leading '8'
    /// with '0' on each field in priority order (OUT first, then IN, OFF, ON) and return
    /// the first combination that produces a valid sequence without a midnight crossing.
    /// Returns the originals unchanged if no single-field correction helps.
    private func correctLeadingEightIfNeeded(
        out: String, off: String, on: String, in inTime: String
    ) -> (String, String, String, String) {
        // Already valid — nothing to do
        if isValidTimeSequence(out: out, off: off, on: on, in: inTime) {
            return (out, off, on, inTime)
        }

        func fix8(_ t: String) -> String? {
            guard t.hasPrefix("8") else { return nil }
            let candidate = "0" + t.dropFirst()
            return isValidTimeFormat(candidate) ? candidate : nil
        }

        // Try correcting each field individually, prioritise OUT then IN
        for (fixedOut, fixedOff, fixedOn, fixedIn) in [
            (fix8(out) ?? out, off,           on,           inTime),
            (out,              off,           on,           fix8(inTime) ?? inTime),
            (out,              fix8(off) ?? off, on,        inTime),
            (out,              off,           fix8(on) ?? on, inTime),
        ] {
            if isValidTimeSequence(out: fixedOut, off: fixedOff, on: fixedOn, in: fixedIn) {
                if fixedOut != out   { LogManager.shared.debug("🔧 Corrected OUT '8'→'0': \(out) → \(fixedOut)") }
                if fixedOff != off   { LogManager.shared.debug("🔧 Corrected OFF '8'→'0': \(off) → \(fixedOff)") }
                if fixedOn != on     { LogManager.shared.debug("🔧 Corrected ON '8'→'0': \(on) → \(fixedOn)") }
                if fixedIn != inTime { LogManager.shared.debug("🔧 Corrected IN '8'→'0': \(inTime) → \(fixedIn)") }
                return (fixedOut, fixedOff, fixedOn, fixedIn)
            }
        }

        return (out, off, on, inTime)
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
                    LogManager.shared.debug("⚠️ Cannot validate time sequence - some times are missing")
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
                    LogManager.shared.debug("🌙 Midnight crossing detected (flight departed late evening, landed early morning)")
        }

        if !isValidTimeSequence(out: out, off: off, on: on, in: inTime) {
                    LogManager.shared.debug("⚠️ TIME SEQUENCE VIOLATION DETECTED!")
                    LogManager.shared.debug("   Expected: OUT < OFF < ON < IN")
                    LogManager.shared.debug("   Found: OUT=\(out), OFF=\(off), ON=\(on), IN=\(inTime)")
                    LogManager.shared.debug("   This might indicate an OCR error or data issue")
        } else {
            if midnightCrossing {
                        LogManager.shared.debug("✅ Time sequence is valid (with midnight crossing): OUT=\(out), OFF=\(off), ON=\(on) [next day], IN=\(inTime) [next day]")
            } else {
                        LogManager.shared.debug("✅ Time sequence is valid: OUT=\(out) < OFF=\(off) < ON=\(on) < IN=\(inTime)")
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
                    LogManager.shared.debug("🕐 Detected midnight crossing: ON time adjusted from \(on) to next day (\(onMin) minutes)")
        }

        // Handle midnight crossing for IN time: if IN < OUT or IN < ON (adjusted), assume IN is on the next day
        if inMin < outMin || inMin < onMin {
            inMin += 1440  // Add 24 hours
                    LogManager.shared.debug("🕐 Detected midnight crossing: IN time adjusted from \(inTime) to next day (\(inMin) minutes)")
        }

        // Calculate expected FLT and BLK times with adjusted values
        let calculatedFltMinutes = onMin - offMin
        let calculatedBlkMinutes = inMin - outMin

        let calculatedFlt = minutesToHHMM(calculatedFltMinutes)
        let calculatedBlk = minutesToHHMM(calculatedBlkMinutes)

                LogManager.shared.debug("📊 Calculated times: FLT=\(calculatedFlt), BLK=\(calculatedBlk)")

        // Validate BLK > FLT (always true, since block includes taxi time)
        if calculatedBlkMinutes <= calculatedFltMinutes {
                    LogManager.shared.debug("⚠️ BLK time (\(calculatedBlk)) should be greater than FLT time (\(calculatedFlt))")
        }

        // If we extracted FLT/BLK times, compare them
        if !fltTime.isEmpty, let extractedFltMin = timeToMinutes(fltTime) {
            let difference = abs(extractedFltMin - calculatedFltMinutes)
            if difference > 2 { // Allow 2 minute tolerance for rounding
                        LogManager.shared.debug("⚠️ Extracted FLT time (\(fltTime)) doesn't match calculated (\(calculatedFlt)) - difference: \(difference) min")
            } else {
                        LogManager.shared.debug("✅ FLT time verified: extracted \(fltTime) ≈ calculated \(calculatedFlt)")
            }
        }

        if !blkTime.isEmpty, let extractedBlkMin = timeToMinutes(blkTime) {
            let difference = abs(extractedBlkMin - calculatedBlkMinutes)
            if difference > 2 { // Allow 2 minute tolerance for rounding
                        LogManager.shared.debug("⚠️ Extracted BLK time (\(blkTime)) doesn't match calculated (\(calculatedBlk)) - difference: \(difference) min")
            } else {
                        LogManager.shared.debug("✅ BLK time verified: extracted \(blkTime) ≈ calculated \(calculatedBlk)")
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

                LogManager.shared.debug("Searching for flight number in \(lines.count) lines...")

        // Try strict QFA format first
        for (index, line) in lines.enumerated() {
                    LogManager.shared.debug("  Line \(index): \(line)")
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
                        LogManager.shared.debug("Flight number extracted (QFA format): \(flightNum)\(correctedFlightNum != flightNum ? " → corrected to: \(correctedFlightNum)" : ""), Day: \(rawDay)")
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
                            LogManager.shared.debug("Flight number extracted (QFA format with OCR correction) from line \(index): \(flightNum) → corrected to: \(cleanedFlightNum), Day: \(rawDay)")
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

                        LogManager.shared.debug("  Found potential match with very relaxed pattern on line \(index): \(flightNum)")

                // Store the day as-is (no correction - month inference happens in ViewModel)
                extractedDay = rawDay

                // Clean and correct the flight number (handles special chars like Ø)
                let cleanedFlightNum = smartExtractFlightNumberVeryRelaxed(flightNum)
                if !cleanedFlightNum.isEmpty {
                            LogManager.shared.debug("Flight number extracted (QFA very relaxed format) from line \(index): \(flightNum) → corrected to: \(cleanedFlightNum), Day: \(rawDay)")
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
                            LogManager.shared.debug("Flight number extracted (numeric format) from line \(index): \(flightNum)\(correctedFlightNum != flightNum ? " → corrected to: \(correctedFlightNum)" : ""), Day: \(rawDay)")
                    return correctedFlightNum
                }
            }
        }

                LogManager.shared.debug("No flight number found in any pattern")
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
                LogManager.shared.debug("  Attempting very relaxed extraction on: \(flightNumber)")

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
                        LogManager.shared.debug("    Converted '\(char)' → '\(digit)'")
            } else if char.isNumber {
                corrected.append(char)
            } else {
                // Unknown character - log it but skip
                        LogManager.shared.debug("    Unknown character '\(char)' (Unicode: \\u{\(String(char.unicodeScalars.first!.value, radix: 16))})")
            }
        }

        // Should have exactly 4 digits now
        guard corrected.count == 4 else {
                    LogManager.shared.debug("    After conversion, got \(corrected.count) digits instead of 4: \(corrected)")
            return ""
        }

                LogManager.shared.debug("    ✓ Converted to 4 digits: \(corrected)")

        // Apply the standard 8 → 0 correction for leading position
        let finalCorrected = smartCorrectFlightNumber(corrected)
        if finalCorrected != corrected {
                    LogManager.shared.debug("    ✓ Applied leading 8→0 correction: \(corrected) → \(finalCorrected)")
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
                // Compact spaces so OCR artefacts like "Y SSY/WSSS" become "YSSY/WSSS"
                let compactLine = trimmedLine.replacingOccurrences(of: " ", with: "")
                let matches = airportPattern.matches(in: compactLine, range: NSRange(compactLine.startIndex..., in: compactLine))
                if let match = matches.first {
                    let fromRange = Range(match.range(at: 1), in: compactLine)!
                    let toRange = Range(match.range(at: 2), in: compactLine)!
                    let fromAirport = String(compactLine[fromRange])
                    let toAirport = String(compactLine[toRange])

                    if fromAirport.allSatisfy({ $0.isLetter }) && toAirport.allSatisfy({ $0.isLetter }) {
                        LogManager.shared.debug("Airports extracted: FROM=\(fromAirport), TO=\(toAirport)")
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
        guard results.count >= 5 else {
            throw TextRecognitionError(message: "Make sure you're photographing the ACARS screen directly.")
        }
        // Combine all recognized text
        var recognizedText = ""
        for observation in results {
            guard let topCandidate = observation.topCandidates(1).first else { continue }
            recognizedText += topCandidate.string + "\n"
        }

                LogManager.shared.debug("B787 Recognized text: \(recognizedText)")

        // Extract the different components for B787
        let outTime = extractB787CurrentFlightTime(from: recognizedText, timeType: "OUT")
        let inTime = extractB787CurrentFlightTime(from: recognizedText, timeType: "IN")
        let offTime = extractB787CurrentFlightTime(from: recognizedText, timeType: "OFF")
        let onTime = extractB787CurrentFlightTime(from: recognizedText, timeType: "ON")
        let flightDetails = extractB787FlightDetails(from: recognizedText)

        validateAndCorrectTimeSequence(out: outTime, off: offTime, on: onTime, in: inTime)

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

        var missingFields: [String] = []
        if outTime.isEmpty { missingFields.append("OUT time") }
        if inTime.isEmpty { missingFields.append("IN time") }
        if !outTime.isEmpty && !isValidTimeFormat(outTime) { missingFields.append("valid OUT time") }
        if !inTime.isEmpty && !isValidTimeFormat(inTime) { missingFields.append("valid IN time") }
        try throwIfMissingCritical(missingFields, partialData: flightData)

        return flightData
    }

    /// Extract current flight time from B787 ACARS
    /// B787 format has "CURRENT FLIGHT" section followed by time fields
    /// Due to OCR layout, time values appear after "TAIL NO:" line in order: OUT, OFF, ON, IN
    private func extractB787CurrentFlightTime(from text: String, timeType: String) -> String {
        let lines = text.components(separatedBy: .newlines)

        // Find the line with "TAIL NO:" - times appear after this
        guard let tailNoIndex = lines.firstIndex(where: { $0.contains("TAIL NO:") }) else {
                    LogManager.shared.debug("Could not find TAIL NO: line")
            return ""
        }

        // Count how many time fields appear before this one
        // Order is: OUT, OFF, ON, IN
        let timeFields = ["OUT", "OFF", "ON", "IN"]
        guard let fieldIndex = timeFields.firstIndex(of: timeType) else {
                    LogManager.shared.debug("Invalid time type: \(timeType)")
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
                    LogManager.shared.debug("Found B787 \(timeType) time: \(extractedTime)\(correctedTime != extractedTime ? " → corrected to: \(correctedTime)" : "")")
            return correctedTime
        }

                LogManager.shared.debug("No B787 \(timeType) time found at index \(fieldIndex) (found \(timeValues.count) times total)")
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
                        LogManager.shared.debug("B787 Flight number extracted: \(flightNumber)")
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
                                LogManager.shared.debug("B787 Date extracted: \(fullDate ?? "") from MMDDYY: \(dateString)")
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
                        LogManager.shared.debug("B787 Aircraft registration extracted: \(aircraftRegistration ?? "")")
                break
            }
        }

        return (flightNumber, fullDate, aircraftRegistration)
    }

    // MARK: - A330 Parser

    private func processA330TextRecognitionResults(_ results: [VNRecognizedTextObservation]) throws -> FlightData {
        guard results.count >= 5 else {
            throw TextRecognitionError(message: "Make sure you're photographing the ACARS screen directly.")
        }
        let recognizedText = results.compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n")
        LogManager.shared.debug("A330 Recognized text: \(recognizedText)")

        if recognizedText.contains("ACARS-BEGIN") || recognizedText.contains("ACARS BEGIN") {
            LogManager.shared.debug("✓ Detected A330 printer format")
            return try parseA330PrinterFormat(from: recognizedText)
        } else {
            LogManager.shared.debug("✓ Detected A330 ACARS screen format — using B737 parser")
            return try processTextRecognitionResults(results)
        }
    }

    private func parseA330PrinterFormat(from text: String) throws -> FlightData {
        // Registration: e.g. "VH-QPD" → "QPD"
        var aircraftRegistration: String? = nil
        let regPattern = try! NSRegularExpression(pattern: #"\.?VH-([A-Z]{3})"#)
        if let m = regPattern.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) {
            aircraftRegistration = String(text[Range(m.range(at: 1), in: text)!])
        }

        // Flight number + day-of-month: e.g. "QFA0127/03" or "QFA0127'03" (OCR artifact for /)
        // The /DD suffix is the LOCAL departure date (not the UTC print date).
        var flightNumber = ""
        var dayOfMonth: String? = nil
        let flightPattern = try! NSRegularExpression(pattern: #"QFA(\d{1,4})[^0-9A-Z](\d{1,2})"#)
        if let m = flightPattern.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) {
            flightNumber = String(text[Range(m.range(at: 1), in: text)!])
            if m.range(at: 2).location != NSNotFound, let dayRange = Range(m.range(at: 2), in: text) {
                dayOfMonth = String(text[dayRange])
            }
        }
        LogManager.shared.debug("A330 printer: flight=\(flightNumber) dayOfMonth=\(dayOfMonth ?? "nil")")

        // Airports: ICAO pair separated by "/" or space (OCR often reads "/" as space)
        var fromAirport = ""
        var toAirport = ""
        let icaoPattern = try! NSRegularExpression(pattern: #"\b([A-Z]{4})[/ ]([A-Z]{4})\b"#)
        if let m = icaoPattern.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) {
            fromAirport = String(text[Range(m.range(at: 1), in: text)!])
            toAirport   = String(text[Range(m.range(at: 2), in: text)!])
        }

        // Times: use columnar scanner (labels and values are in separate sections of the printout).
        // Falls back to label-adjacent extraction if columnar detection fails.
        var outTime = "", offTime = "", onTime = "", inTime = "", blockTime = ""
        if let times = extractA330PrinterTimes(from: text) {
            outTime   = times.out
            offTime   = times.off
            onTime    = times.on
            inTime    = times.inTime
            blockTime = times.block
        } else {
            LogManager.shared.debug("A330 printer: columnar scan failed, falling back to label-adjacent extraction")
            outTime   = extractTimeField(label: "OUT",   from: text)
            offTime   = extractTimeField(label: "OFF",   from: text)
            onTime    = extractTimeField(label: "ON",    from: text)
            inTime    = extractTimeField(label: "IN",    from: text)
            blockTime = extractTimeField(label: "BLOCK", from: text)
        }

        validateAndCorrectTimeSequence(out: outTime, off: offTime, on: onTime, in: inTime, fltTime: "", blkTime: blockTime)

        LogManager.shared.debug("A330 printer parsed — flight:\(flightNumber) \(fromAirport)-\(toAirport) OUT:\(outTime) OFF:\(offTime) ON:\(onTime) IN:\(inTime) BLK:\(blockTime) day:\(dayOfMonth ?? "nil") reg:\(aircraftRegistration ?? "nil")")

        let flightData = FlightData(
            outTime: outTime,
            inTime: inTime,
            offTime: offTime,
            onTime: onTime,
            blockTime: blockTime,
            flightNumber: flightNumber,
            fromAirport: fromAirport,
            toAirport: toAirport,
            dayOfMonth: dayOfMonth,
            aircraftRegistration: aircraftRegistration,
            fullDate: nil
        )

        var missingFields: [String] = []
        if outTime.isEmpty { missingFields.append("OUT time") }
        if inTime.isEmpty { missingFields.append("IN time") }
        if !outTime.isEmpty && !isValidTimeFormat(outTime) { missingFields.append("valid OUT time") }
        if !inTime.isEmpty && !isValidTimeFormat(inTime) { missingFields.append("valid IN time") }
        try throwIfMissingCritical(missingFields, partialData: flightData)

        return flightData
    }

    // MARK: - A380 Parser

    /// Process A380 NSS AVNCS "EVENT TIMES" screen.
    ///
    /// Layout differences from B737 CURRENT-FLT screen:
    ///   • Flight number appears as a standalone line (e.g. "QF0000"), no "/DD" suffix
    ///   • Day-of-month appears on the line immediately after the flight number
    ///   • Airports appear on individual lines (not "XXXX/YYYY" pairs) in the right column:
    ///       DEPARTURE  → line N,  value → line N+1  (e.g. "WSSS" — may have trailing OCR chars)
    ///       DESTINATION → line M, value → line M+1  (e.g. "YSSY")
    ///   • Times (OUT/OFF/ON/IN) use the same columnar layout as the B737 screen.
    private func processA380TextRecognitionResults(_ results: [VNRecognizedTextObservation]) throws -> FlightData {
        guard results.count >= 5 else {
            throw TextRecognitionError(message: "Make sure you're photographing the ACARS screen directly.")
        }

        var recognizedText = results.compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n")
        LogManager.shared.debug("A380 Recognized text: \(recognizedText)")
        recognizedText = rejoinSplitTimes(in: recognizedText)

        // --- Times (reuse B737 columnar / pattern-based / interleaved pipeline) ---
        var outTime = "", offTime = "", onTime = "", inTime = "", blockTime = ""
        if let t = extractTimesFromColumnarLayout(from: recognizedText) {
            LogManager.shared.debug("✓ A380: using columnar layout")
            outTime = t.out; offTime = t.off; onTime = t.on; inTime = t.in
            blockTime = t.blk
            validateAndCorrectTimeSequence(out: outTime, off: offTime, on: onTime, in: inTime, fltTime: t.flt, blkTime: t.blk)
        } else {
            LogManager.shared.debug("✓ A380: columnar failed, using pattern-based extraction")
            let rawOut = extractOutTime(from: recognizedText)
            let rawOff = extractOffTime(from: recognizedText)
            let rawOn  = extractOnTime(from: recognizedText)
            let rawIn  = extractInTime(from: recognizedText)
            blockTime  = extractBlockTime(from: recognizedText)
            let flt    = extractFlightTime(from: recognizedText)
            (outTime, offTime, onTime, inTime) = correctLeadingEightIfNeeded(out: rawOut, off: rawOff, on: rawOn, in: rawIn)
            validateAndCorrectTimeSequence(out: outTime, off: offTime, on: onTime, in: inTime, fltTime: flt, blkTime: blockTime)
        }

        // --- Flight details: A380-specific extraction ---
        let (flightNumber, dayOfMonth, fromAirport, toAirport) = extractA380FlightDetails(from: recognizedText)

        LogManager.shared.debug("A380 parsed — flight:\(flightNumber) \(fromAirport)-\(toAirport) OUT:\(outTime) OFF:\(offTime) ON:\(onTime) IN:\(inTime) BLK:\(blockTime) day:\(dayOfMonth ?? "nil")")

        let flightData = FlightData(
            outTime: outTime, inTime: inTime, offTime: offTime, onTime: onTime,
            blockTime: blockTime,
            flightNumber: flightNumber,
            fromAirport: fromAirport, toAirport: toAirport,
            dayOfMonth: dayOfMonth,
            aircraftRegistration: nil, fullDate: nil
        )

        var missingFields: [String] = []
        if outTime.isEmpty { missingFields.append("OUT time") }
        if inTime.isEmpty  { missingFields.append("IN time") }
        if !outTime.isEmpty && !isValidTimeFormat(outTime) { missingFields.append("valid OUT time") }
        if !inTime.isEmpty  && !isValidTimeFormat(inTime)  { missingFields.append("valid IN time") }
        try throwIfMissingCritical(missingFields, partialData: flightData)

        return flightData
    }

    /// Extract flight number, day-of-month and airports from the A380 EVENT TIMES screen.
    ///
    /// Pattern-based approach — no label hunting:
    ///   1. Flight number: first line matching an airline prefix + 3–4 digits (e.g. "QF0000").
    ///      OCR sometimes misreads O→0, so we normalise after finding the prefix.
    ///   2. Day-of-month: the line immediately after the flight number line that is 1–2 digits.
    ///   3. Airports: scan all lines for exactly 4 uppercase letters (ICAO code pattern).
    ///      The first two found that are not known non-airport words are departure + destination.
    ///      Trailing OCR noise (e.g. "WSSSR") is stripped to 4 letters.
    private func extractA380FlightDetails(from text: String) -> (flightNumber: String, dayOfMonth: String?, fromAirport: String, toAirport: String) {
        let lines = text.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespaces) }

        // QF A380 route network — all airports the type serves.
        // Used as a whitelist: only lines matching one of these (after stripping 1 trailing
        // noise char) are accepted as airport codes.
        let a380Airports: Set<String> = [
            "YSSY","YMML","YBBN","YPPH","YPAD","YPDN","YMAV","YSCB","YWLM","YBAS","NWWW","NZAA","NZCH","NFFN","NSFA","NSTU","NTAA","SAWH","SAEZ","SCEL","PHKO","PHNL","PHTO","PGUM","WADD","WIII","WSSS","WIDD","WMKK","VVTS","VTBS","RPLL","RPLC","VHHH","ZGSZ","ZGGG","RCTP","VECC","VAAH","VABB","VOHS","VOBL","VCRI","VCBI","VRMM","FJDG","VIDP","OPIS","FIMP","FMEE","FALE","FAOR","OOSA","OOMS","OMAL","OMDB","OMAA","OMDW","OBBI","OTHH","OKKK","UZTT","UTAA","UBBB","LTCE","LTCG","LTAC","LTFM","LGAV","HECA","LCLK","UUDD","EPWA","LOWW","LKPR","EDDM","EDDK","EHAM","EDDH","LFPG","LFPO","LFBO","EGLL","EGSS","EGKK","EGBB","EGCC","EINN","EGPK","KLAX","KVBG","KSMX","KSFO","KLAS","KTUS","KELP","KSAT","KAUS","KDFW","KIAH","MMLT","MMSD","KORD","KIAD","KJFK","KBOS","CYEG","PANC","CYFB","BGSF","BIKF"
        ]

        // Regex patterns
        let flightNumRegex  = try! NSRegularExpression(pattern: #"^([A-Z]{2,3})([0-9O]{3,4})$"#, options: .caseInsensitive)
        let dayOnlyRegex    = try! NSRegularExpression(pattern: #"^\d{1,2}$"#)

        // OCR substitution for digits inside flight number suffix
        let digitMap: [Character: Character] = [
            "O": "0", "o": "0", "Ø": "0", "ø": "0",
            "I": "1", "l": "1", "Z": "2", "S": "5", "B": "8", "G": "6"
        ]

        func matchesRegex(_ regex: NSRegularExpression, _ s: String) -> Bool {
            regex.firstMatch(in: s, range: NSRange(s.startIndex..., in: s)) != nil
        }

        // 1. Find flight number
        var flightNumber = ""
        var flightNumberLineIndex: Int? = nil
        for (i, line) in lines.enumerated() {
            let upper = line.uppercased()
            guard let m = flightNumRegex.firstMatch(in: upper, range: NSRange(upper.startIndex..., in: upper)),
                  let prefixRange = Range(m.range(at: 1), in: upper),
                  let suffixRange = Range(m.range(at: 2), in: upper) else { continue }
            let prefix = String(upper[prefixRange])
            let suffix = String(upper[suffixRange])
            var corrected = ""
            for ch in suffix { corrected.append(digitMap[ch] ?? ch) }
            let digits = corrected.filter { $0.isNumber }
            flightNumber = prefix + String(digits.prefix(4))
            flightNumberLineIndex = i
            LogManager.shared.debug("A380: flight number line '\(line)' → '\(flightNumber)'")
            break
        }

        // 2. Day-of-month: line immediately after flight number that is 1–2 digits
        var dayOfMonth: String? = nil
        if let idx = flightNumberLineIndex, idx + 1 < lines.count {
            let candidate = lines[idx + 1]
            if matchesRegex(dayOnlyRegex, candidate) {
                let digits = candidate.filter { $0.isNumber }
                dayOfMonth = digits.count == 1 ? "0\(digits)" : String(digits)
                LogManager.shared.debug("A380: day '\(candidate)' → '\(dayOfMonth!)'")
            }
        }

        // 3. Airports: scan for lines matching known A380 route airports.
        //    Accept exact 4-letter match OR 5-letter line where first 4 chars match
        //    (handles OCR trailing-noise like "WSSSR" → "WSSS").
        var airports: [String] = []
        for line in lines {
            let upper = line.uppercased().filter { $0.isLetter }
            guard upper.count == 4 || upper.count == 5 else { continue }
            let code = String(upper.prefix(4))
            guard a380Airports.contains(code) else { continue }
            if !airports.contains(code) { airports.append(code) }
            if airports.count == 2 { break }
        }

        let fromAirport = airports.count > 0 ? airports[0] : ""
        let toAirport   = airports.count > 1 ? airports[1] : ""
        LogManager.shared.debug("A380 details: flight=\(flightNumber) day=\(dayOfMonth ?? "nil") dep=\(fromAirport) dest=\(toAirport)")

        return (flightNumber, dayOfMonth, fromAirport, toAirport)
    }

    /// Columnar time extractor for the A330 thermal printer format.
    ///
    /// The printout has two columns which OCR reads sequentially:
    ///   Left column:  [BLOCK / OUT / ON] labels, then their values further down
    ///   Right column: [NIGHT? / OFF / IN] labels, then their values further down
    ///
    /// In the OCR output the value cluster for the left group appears between the
    /// last left-column label and the first right-column label.  Any leading times
    /// in that cluster (e.g. a REPORT time) are skipped; the last 3 are BLOCK/OUT/ON.
    ///
    /// For the right group, if a NIGHT label was present its value (night-hours)
    /// is the first time after the label block and is skipped; the next two are OFF/IN.
    private func extractA330PrinterTimes(from text: String) -> (block: String, out: String, off: String, on: String, inTime: String)? {
        let lines = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }

        // Match an entire trimmed line that is a time "HH:MM" (handles OCR space "00: 38")
        let timeRegex = try! NSRegularExpression(pattern: #"^(\d{1,2}):\s*(\d{2})$"#)

        func parseLine(_ line: String) -> String? {
            guard let m = timeRegex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
                  let r1 = Range(m.range(at: 1), in: line),
                  let r2 = Range(m.range(at: 2), in: line) else { return nil }
            return smartCorrectTime("\(String(line[r1])):\(String(line[r2]))")
        }

        // Find the first line index whose trimmed content equals the label (or starts with it
        // followed by a non-letter, to catch minor OCR additions like trailing colons)
        func firstIndex(of label: String) -> Int? {
            lines.firstIndex(where: { line in
                line == label ||
                (line.hasPrefix(label) && line.count > label.count && !line[line.index(line.startIndex, offsetBy: label.count)].isLetter)
            })
        }

        guard let blockIdx = firstIndex(of: "BLOCK"),
              let outIdx   = firstIndex(of: "OUT"),
              let onIdx    = firstIndex(of: "ON"),
              let offIdx   = firstIndex(of: "OFF"),
              let inIdx    = firstIndex(of: "IN") else {
            LogManager.shared.debug("A330 printer columnar: missing required label(s) — cannot use columnar scanner")
            return nil
        }

        // NIGHT label marks a "night hours" value that leads the right-group values
        let nightIdx = firstIndex(of: "NIGHT")

        // Left group: labels end at the last of BLOCK/OUT/ON
        let leftEnd = max(blockIdx, outIdx, onIdx)
        // Right group: starts at the earliest of NIGHT/OFF (whichever appears first)
        let rightStart = nightIdx.map { min($0, offIdx) } ?? offIdx
        // Right group: labels end at the last of NIGHT/OFF/IN
        let rightEnd = max(offIdx, inIdx, nightIdx ?? 0)

        guard leftEnd < rightStart else {
            LogManager.shared.debug("A330 printer columnar: left/right label groups overlap — cannot use columnar scanner")
            return nil
        }

        // Collect times in the left-group value region (between the two label blocks)
        var leftTimes: [String] = []
        for i in (leftEnd + 1)..<rightStart {
            if let t = parseLine(lines[i]) { leftTimes.append(t) }
        }

        guard leftTimes.count >= 3 else {
            LogManager.shared.debug("A330 printer columnar: found \(leftTimes.count) left-group times (need ≥3)")
            return nil
        }
        // Any leading times (e.g. REPORT time) precede the actual values; take the LAST 3
        let blockTime = leftTimes[leftTimes.count - 3]
        let outTime   = leftTimes[leftTimes.count - 2]
        let onTime    = leftTimes[leftTimes.count - 1]

        // Collect times after the right-group label block
        var rightTimes: [String] = []
        for i in (rightEnd + 1)..<lines.count {
            if let t = parseLine(lines[i]) { rightTimes.append(t) }
        }

        // If NIGHT label was present, its value is the first right-group time — skip it
        let skip = nightIdx != nil ? 1 : 0
        guard rightTimes.count >= skip + 2 else {
            LogManager.shared.debug("A330 printer columnar: found \(rightTimes.count) right-group times (need ≥\(skip + 2))")
            return nil
        }
        let offTime = rightTimes[skip]
        let inTime  = rightTimes[skip + 1]

        LogManager.shared.debug("A330 printer columnar — BLOCK:\(blockTime) OUT:\(outTime) ON:\(onTime) OFF:\(offTime) IN:\(inTime)")
        return (block: blockTime, out: outTime, off: offTime, on: onTime, inTime: inTime)
    }

    private func monthNumber(from abbreviation: String) -> Int? {
        switch abbreviation.uppercased() {
        case "JAN": return 1
        case "FEB": return 2
        case "MAR": return 3
        case "APR": return 4
        case "MAY": return 5
        case "JUN": return 6
        case "JUL": return 7
        case "AUG": return 8
        case "SEP": return 9
        case "OCT": return 10
        case "NOV": return 11
        case "DEC": return 12
        default: return nil
        }
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
