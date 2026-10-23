// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "macos-workspace-matrix",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "WorkspaceMatrix"),
        .testTarget(name: "WorkspaceMatrixTests", dependencies: ["WorkspaceMatrix"]),
    ]
)
