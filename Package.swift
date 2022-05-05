// swift-tools-version:5.5
import PackageDescription

let package =
  Package(
    name: "SwiftUIScroll",
    platforms: [
      .iOS(.v15),
      .watchOS(.v8),
      .macOS(.v12),
    ],
    products: [
      .library(
        name: "SwiftUIScroll",
        targets: ["SwiftUIScroll"]
      ),
    ],
    dependencies: [
      .package(
        name: "SwiftFoundationExtensions",
        url: "https://github.com/xiiagency/SwiftFoundationExtensions",
        .upToNextMinor(from: "1.0.0")
      ),
      .package(
        name: "SwiftUIExtensions",
        url: "https://github.com/xiiagency/SwiftUIExtensions",
        .upToNextMinor(from: "1.0.0")
      ),
    ],
    targets: [
      .target(
        name: "SwiftUIScroll",
        dependencies: [
          "SwiftFoundationExtensions",
          "SwiftUIExtensions",
        ]
      ),
    ]
  )
