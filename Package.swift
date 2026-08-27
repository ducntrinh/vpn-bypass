// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "vpn-bypass",
    targets: [
        .executableTarget(
            name: "vpn-bypass",
            linkerSettings: [.linkedFramework("SystemConfiguration")]
        ),
    ]
)
