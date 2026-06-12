//
//  AppUpdateService.swift
//  Block-Time
//
//  Checks the iTunes Search API for a newer App Store version.
//  Returns the newer version string, or nil when up to date / offline / empty results.
//
//  Design notes:
//  - Pure static functions — no singleton, no class, no shared state.
//  - Fail-safe: empty results array (region-locked lookup returns resultCount=0 for
//    some App Store regions) is treated identically to "up to date". The app always
//    proceeds normally when the lookup cannot confirm a newer version.
//  - 24h cache: after a successful comparison the check date and (optionally) the newer
//    version string are stored in UserDefaults so repeated launches don't hammer the API.
//    On network/decode errors the cache is NOT updated, preserving the previous result.

import Foundation

public enum AppUpdateService {

    // MARK: - UserDefaults keys

    private static let lastCheckDateKey = "appUpdateLastCheckDate"
    private static let cachedStoreVersionKey = "appUpdateCachedStoreVersion"

    // MARK: - iTunes lookup

    private static let lookupURL = URL(string: "https://itunes.apple.com/lookup?bundleId=com.thezoolab.blocktime&country=au")!

    // MARK: - Public API

    /// Returns the App Store version string when a newer version is available, otherwise nil.
    ///
    /// Behaviour:
    /// - If the last successful check was within 24 hours, returns the cached result without
    ///   hitting the network.
    /// - On network error, decode failure, or an empty results array (region-locked lookup),
    ///   returns nil so the app proceeds normally.
    /// - Uses numeric component-wise comparison so "1.10.0" > "1.9.0".
    public static func checkForUpdate() async -> String? {
        #if DEBUG
        return nil //"1.99"
        #else
        let defaults = UserDefaults.standard

        // 24h cache check
        if let lastCheck = defaults.object(forKey: lastCheckDateKey) as? Date,
           Date.now.timeIntervalSince(lastCheck) < 86_400 {
            // Return cached newer version only if it's still newer than the installed version
            let cached = defaults.string(forKey: cachedStoreVersionKey)
            if let cached, !cached.isEmpty {
                let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
                return isVersion(cached, newerThan: currentVersion) ? cached : nil
            }
            return nil
        }

        // Fetch from iTunes
        guard let storeVersion = await fetchStoreVersion() else {
            // Network/decode error or empty results — do not update cache, fail safe
            return nil
        }

        // Compare versions
        let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
        print("[AppUpdateService] current: \(currentVersion), store: \(storeVersion)")
        let isNewer = isVersion(storeVersion, newerThan: currentVersion)

        // Persist result
        defaults.set(Date.now, forKey: lastCheckDateKey)
        if isNewer {
            defaults.set(storeVersion, forKey: cachedStoreVersionKey)
        } else {
            defaults.removeObject(forKey: cachedStoreVersionKey)
        }

        return isNewer ? storeVersion : nil
        #endif
    }

    // MARK: - Private helpers

    private static func fetchStoreVersion() async -> String? {
        do {
            let (data, _) = try await URLSession.shared.data(from: lookupURL)
            let response = try JSONDecoder().decode(LookupResponse.self, from: data)
            // Empty results = region-locked or not found — treat as up to date
            guard let first = response.results.first else { return nil }
            return first.version
        } catch {
            return nil
        }
    }

    /// Numeric component-wise comparison: returns true only when `candidate` > `base`.
    private static func isVersion(_ candidate: String, newerThan base: String) -> Bool {
        let candidateParts = candidate.split(separator: ".").compactMap { Int($0) }
        let baseParts = base.split(separator: ".").compactMap { Int($0) }

        let maxLength = max(candidateParts.count, baseParts.count)
        for i in 0..<maxLength {
            let c = i < candidateParts.count ? candidateParts[i] : 0
            let b = i < baseParts.count ? baseParts[i] : 0
            if c != b { return c > b }
        }
        return false // equal versions
    }

    // MARK: - Decodable types

    private struct LookupResponse: Decodable {
        let resultCount: Int
        let results: [LookupResult]
    }

    private struct LookupResult: Decodable {
        let version: String
    }
}
