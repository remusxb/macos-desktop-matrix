// swift-tools-version:6.0
import PackageDescription

// Dependencies point one way: the app wires System and UI, which both build only on Core
// (docs/ARCHITECTURE.md). A wrong-way import doesn't compile.
let package = Package(
    name: "macos-desktop-matrix",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "DesktopMatrixCore"),
        .target(name: "DesktopMatrixSystem", dependencies: ["DesktopMatrixCore"]),
        .target(name: "DesktopMatrixUI", dependencies: ["DesktopMatrixCore"]),
        .executableTarget(
            name: "DesktopMatrix",
            dependencies: ["DesktopMatrixCore", "DesktopMatrixSystem", "DesktopMatrixUI"]
        ),
        .testTarget(name: "DesktopMatrixCoreTests", dependencies: ["DesktopMatrixCore"]),
        .testTarget(name: "DesktopMatrixSystemTests", dependencies: ["DesktopMatrixSystem"]),
        .testTarget(name: "DesktopMatrixTests", dependencies: ["DesktopMatrix", "DesktopMatrixCore"]),
    ]
)
