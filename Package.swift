// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "nasalis",
    platforms: [
        .macOS(.v26),
    ],
    products: [
        .executable(name: "nasalis", targets: ["NasalisApp"]),
    ],
    targets: [
        .target(
            name: "SMCBridge",
            path: "nasalis/Resources/SMCBridge",
            publicHeadersPath: "include",
            linkerSettings: [
                .linkedFramework("IOKit"),
            ],
        ),
        .executableTarget(
            name: "NasalisApp",
            dependencies: [
                "SMCBridge",
            ],
            path: "nasalis/Sources",
            resources: [
                .process("../Resources/Assets.xcassets"),
                .process("../Resources/Localizations"),
            ],
        ),
    ],
)
