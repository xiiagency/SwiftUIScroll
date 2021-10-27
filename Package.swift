// swift-tools-version:5.5
import PackageDescription

let package =
  Package(
    name: "SwiftUIScroll",
    platforms: [
      .iOS(.v15),
      .watchOS(.v8),
    ],
    products: [
      .library(
        name: "SwiftUIScroll",
        targets: ["SwiftUIScroll"]
      ),
    ],
    dependencies: [
      .package(name: "SwiftFoundationExtensions", url: "https://github.com/xiiagency/SwiftFoundationExtensions", .branchItem("main")),
      .package(name: "SwiftUIExtensions", url: "https://github.com/xiiagency/SwiftUIExtensions", .branchItem("main")),
    ],
    targets: [
      .target(
        name: "SwiftUIScroll",
        dependencies: [
          "SwiftFoundationExtensions",
          "SwiftUIExtensions",
        ]
      ),
      // NOTE: Re-enable when tests are added.
//      .testTarget(
//        name: "SwiftUIScrollTests",
//        dependencies: ["SwiftUIScroll"]
//      ),
    ]
  )
