// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "BlockTimeKit",
    platforms: [
        .iOS(.v18),
        .macOS(.v15)
    ],
    products: [
        .library(name: "BlockTimeDomain", targets: ["BlockTimeDomain"]),
        .library(name: "BlockTimeCalculators", targets: ["BlockTimeCalculators"]),
        .library(name: "BlockTimeData", targets: ["BlockTimeData"]),
    ],
    targets: [
        // Zero external deps. Foundation only.
        .target(name: "BlockTimeDomain", dependencies: []),

        // Pure functions. Imports BlockTimeDomain.
        .target(name: "BlockTimeCalculators", dependencies: ["BlockTimeDomain"]),

        // FlightRepository protocol + InMemoryFlightRepository.
        // Imports BlockTimeDomain. Does NOT import SwiftData.
        .target(name: "BlockTimeData", dependencies: ["BlockTimeDomain"]),

        .testTarget(
            name: "BlockTimeDomainTests",
            dependencies: ["BlockTimeDomain"],
            path: "Tests/BlockTimeDomainTests"
        ),
        .testTarget(
            name: "BlockTimeDataTests",
            dependencies: ["BlockTimeData"],
            path: "Tests/BlockTimeDataTests"
        ),
    ]
)
