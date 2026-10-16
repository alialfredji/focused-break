// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "EventHorizon",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "EventHorizon", targets: ["EventHorizon"])],
    targets: [
        .target(name: "HorizonCore"),
        .target(name: "HorizonMedia", dependencies: ["HorizonCore"]),
        .executableTarget(name: "EventHorizon", dependencies: ["HorizonCore", "HorizonMedia"],
                          resources: [.copy("BlackHole.metal"), .copy("HaveABreak.gif")]),
        .testTarget(name: "HorizonCoreTests", dependencies: ["HorizonCore"]),
        .testTarget(name: "HorizonMediaTests", dependencies: ["HorizonMedia"])
    ]
)
