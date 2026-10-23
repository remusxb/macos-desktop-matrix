// swift-tools-version:6.0
import PackageDescription

// Dependencies point one way: the app wires System and UI, which both build only on Core
// (docs/ARCHITECTURE.md). A wrong-way import doesn't compile.
let package = Package(
    name: "macos-workspace-matrix",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "WorkspaceMatrixCore"),
        .target(name: "WorkspaceMatrixSystem", dependencies: ["WorkspaceMatrixCore"]),
        .target(name: "WorkspaceMatrixUI", dependencies: ["WorkspaceMatrixCore"]),
        .executableTarget(
            name: "WorkspaceMatrix",
            dependencies: ["WorkspaceMatrixCore", "WorkspaceMatrixSystem", "WorkspaceMatrixUI"]
        ),
        .testTarget(name: "WorkspaceMatrixCoreTests", dependencies: ["WorkspaceMatrixCore"]),
        .testTarget(name: "WorkspaceMatrixSystemTests", dependencies: ["WorkspaceMatrixSystem"]),
        .testTarget(name: "WorkspaceMatrixTests", dependencies: ["WorkspaceMatrix", "WorkspaceMatrixCore"]),
    ]
)
