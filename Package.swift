// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "macos-workspace-matrix",
    platforms: [.macOS(.v14)],
    targets: [
        // Instant desktop switching, vendored from InstantSpaceSwitcher (MIT, see Sources/ISS/LICENSE).
        .target(
            name: "ISS",
            exclude: ["LICENSE", "SOURCE"],
            linkerSettings: [
                .linkedFramework("ApplicationServices"),
                .linkedFramework("CoreFoundation"),
                .linkedFramework("IOKit"),
            ]
        ),
        .executableTarget(name: "WorkspaceMatrix", dependencies: ["ISS"]),
        .testTarget(name: "WorkspaceMatrixTests", dependencies: ["WorkspaceMatrix", "ISS"]),
    ]
)
