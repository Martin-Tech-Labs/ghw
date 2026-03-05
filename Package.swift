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
  targets: [
    .executableTarget(
      name: "ghw",
      dependencies: [],
      path: "Sources/ghw"
    )
  ]
)
