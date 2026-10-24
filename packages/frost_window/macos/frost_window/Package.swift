// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "frost_window",
    platforms: [.macOS("12.0")],
    products: [
        .library(name: "frost-window", targets: ["frost_window"])
    ],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework")
    ],
    targets: [
        .target(
            name: "frost_window",
            dependencies: [
                .product(name: "FlutterFramework", package: "FlutterFramework")
            ]
        )
    ]
)
