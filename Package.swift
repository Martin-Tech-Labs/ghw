// swift-tools-version: 5.9
import PackageDescription

let package = Package(
  name: "ghw",
  platforms: [
    .macOS(.v13)
  ],
  products: [
    .executable(name: "ghw", targets: ["ghw"])
  ],
  dependencies: [
    .package(url: "https://github.com/apple/swift-testing.git", from: "0.12.0")
  ],
  targets: [
    .executableTarget(
      name: "ghw",
      dependencies: [],
      path: "Sources/ghw"
    ),
    .testTarget(
      name: "ghwTests",
      dependencies: [
        "ghw",
        .product(name: "Testing", package: "swift-testing")
      ],
      path: "Tests/ghwTests"
    )
  ]
)
