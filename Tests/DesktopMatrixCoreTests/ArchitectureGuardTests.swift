import Foundation
import Testing

// Rules from docs/STANDARDS.md that a test can hold, checked by reading the sources.

/// Every Swift file under Sources/, with its path relative to the repository.
private let sources: [(path: String, text: String)] = {
    let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent()
    let enumerator = FileManager.default.enumerator(
        at: root.appending(path: "Sources"), includingPropertiesForKeys: nil)
    return (enumerator?.allObjects as? [URL] ?? []).filter { $0.pathExtension == "swift" }.compactMap { url in
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        return (String(url.path.dropFirst(root.path.count + 1)), text)
    }
}()

@Test func theSourcesAreFound() {
    #expect(sources.count > 10)
}

/// S1: Core builds on nothing but the platform's basics.
@Test func coreImportsOnlyFoundationCoreGraphicsAndOS() {
    let allowed: Set = ["Foundation", "CoreGraphics", "os"]
    for file in sources where file.path.hasPrefix("Sources/DesktopMatrixCore/") {
        for line in file.text.split(separator: "\n") where line.hasPrefix("import ") {
            #expect(allowed.contains(String(line.dropFirst("import ".count))), "\(file.path): \(line)")
        }
    }
}

/// S4: private symbols are declared in one place.
@Test func onlySkyLightLooksUpPrivateSymbols() {
    for file in sources where file.path != "Sources/DesktopMatrixSystem/SkyLight.swift" {
        for marker in ["dlsym(", "dlopen(", "@_silgen_name"] {
            #expect(!file.text.contains(marker), "\(file.path) uses \(marker)")
        }
    }
}

/// S15: one logger.
@Test func nothingPrintsInsteadOfLogging() {
    for file in sources {
        for marker in ["print(", "NSLog(", "FileHandle.standardError"] {
            #expect(!file.text.contains(marker), "\(file.path) uses \(marker)")
        }
    }
}
