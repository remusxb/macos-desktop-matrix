import DesktopMatrixCore
import Foundation

/// The private SkyLight (WindowServer) calls the app makes, and the only place they're declared. Each is
/// looked up at runtime, so a macOS that drops one turns off what needs it instead of stopping the app
/// from launching. None of them needs System Integrity Protection turned off.
enum SkyLight {
    typealias ConnectionID = Int32
    typealias SpaceID = UInt64

    static let mainConnectionID = load("SLSMainConnectionID", as: (@convention(c) () -> ConnectionID).self)
    static let getActiveSpace = load("SLSGetActiveSpace", as: (@convention(c) (ConnectionID) -> SpaceID).self)
    // The Copy functions return a +1 reference, read through `owned`.
    static let copyManagedDisplaySpaces = load(
        "SLSCopyManagedDisplaySpaces", as: (@convention(c) (ConnectionID) -> UnsafeMutableRawPointer?).self)
    static let copySpacesForWindows = load(
        "SLSCopySpacesForWindows", as: (@convention(c) (ConnectionID, Int32, CFArray) -> UnsafeMutableRawPointer?).self)
    static let spaceCreate = load(
        "SLSSpaceCreate", as: (@convention(c) (ConnectionID, Int32, CFDictionary?) -> SpaceID).self)
    static let spaceSetAbsoluteLevel = load(
        "SLSSpaceSetAbsoluteLevel", as: (@convention(c) (ConnectionID, SpaceID, Int32) -> Void).self)
    static let showSpaces = load("SLSShowSpaces", as: (@convention(c) (ConnectionID, CFArray) -> Void).self)
    static let addWindowsToSpaces = load(
        "SLSAddWindowsToSpaces", as: (@convention(c) (ConnectionID, CFArray, CFArray) -> Void).self)

    /// The bit mask asking for a window's spaces on every display.
    static let allSpacesMask: Int32 = 7

    /// Takes ownership of what a Copy function returned.
    static func owned<T: AnyObject>(_ pointer: UnsafeMutableRawPointer?, as _: T.Type) -> T? {
        pointer.map { Unmanaged<T>.fromOpaque($0).takeRetainedValue() }
    }

    private nonisolated(unsafe) static let handle = dlopen(
        "/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_LAZY)

    private static func load<T>(_ name: String, as _: T.Type) -> T? {
        guard let symbol = dlsym(handle, name) else {
            Log.app.error("SkyLight has no \(name, privacy: .public): the feature using it is off")
            return nil
        }
        return unsafeBitCast(symbol, to: T.self)
    }
}
