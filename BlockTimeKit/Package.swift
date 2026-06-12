// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "BlockTimeKit",
    defaultLocalization: "en",
    platforms: [.iOS(.v18), .macOS(.v14)],
    products: [
        .library(name: "BlockTimeKit", targets: ["BlockTimeKit"]),
    ],
    targets: [
        .target(
            name: "BlockTimeKit",
            resources: [
                .process("Data/FlightDataModel.xcdatamodeld")
            ],
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        ),
        .testTarget(name: "BlockTimeKitTests", dependencies: ["BlockTimeKit"]),
    ]
)
