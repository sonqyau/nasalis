// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "nasalis",
    platforms: [
        .macOS(.v26),
    ],
    products: [
        .executable(name: "nasalis", targets: ["nasalisApp"]),
    ],
    targets: [
        .target(
            name: "SMCBridge",
            path: "nasalis/SMCBridge",
            publicHeadersPath: "include",
            linkerSettings: [
                .linkedFramework("IOKit"),
            ],
        ),
        .executableTarget(
            name: "nasalisApp",
            dependencies: [
                "SMCBridge",
            ],
            path: "nasalis/Sources",
            exclude: [
                "nasalis.entitlements",
            ],
            resources: [
                .process("../Resources"),
            ],
            linkerSettings: [
                .linkedFramework("IOKit"),
            ],
        ),
    ],
)
