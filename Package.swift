// swift-tools-version:5.9
import Foundation
import PackageDescription

// Embeds Info.plist into the executable, so running straight from Xcode (no .app bundle)
// still has the Bluetooth usage description and doesn't crash on permission checks.
let infoPlist = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .appendingPathComponent("Resources/Info.plist")
    .path

let package = Package(
    name: "Headshare",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "Headshare",
            path: "Sources/Headshare",
            linkerSettings: [
                .linkedFramework("CoreAudio"),
                .linkedFramework("IOBluetooth"),
                .linkedFramework("ServiceManagement"),
                .linkedFramework("UserNotifications"),
                .linkedFramework("Carbon"),
                .unsafeFlags(["-Xlinker", "-sectcreate", "-Xlinker", "__TEXT",
                              "-Xlinker", "__info_plist", "-Xlinker", infoPlist]),
            ]
        )
    ]
)
