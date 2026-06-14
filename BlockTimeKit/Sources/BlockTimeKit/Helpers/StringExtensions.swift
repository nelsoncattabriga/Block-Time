//
//  StringExtensions.swift
//  BlockTimeKit
//

import Foundation
import CommonCrypto

public extension String {
    /// Creates a deterministic UUID from the string using SHA256 hash.
    /// Not for cryptographic security — used to generate consistent UUIDs from flight data for duplicate detection.
    func md5UUID() -> String {
        guard let data = self.data(using: .utf8) else {
            return UUID().uuidString
        }

        var digest = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        data.withUnsafeBytes { buffer in
            _ = CC_SHA256(buffer.baseAddress, CC_LONG(buffer.count), &digest)
        }

        digest[6] = (digest[6] & 0x0F) | 0x50
        digest[8] = (digest[8] & 0x3F) | 0x80

        return String(format: "%02x%02x%02x%02x-%02x%02x-%02x%02x-%02x%02x-%02x%02x%02x%02x%02x%02x",
                     digest[0], digest[1], digest[2], digest[3],
                     digest[4], digest[5],
                     digest[6], digest[7],
                     digest[8], digest[9],
                     digest[10], digest[11], digest[12], digest[13], digest[14], digest[15])
    }
}
