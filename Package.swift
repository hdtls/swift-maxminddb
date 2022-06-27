// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "swift-maxminddb",
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "MaxMindDB",
            targets: ["MaxMindDB"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        // .package(url: /* package url */, from: "1.0.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "CMaxMindDB",
            cSettings: [
                .define("PACKAGE_VERSION", to: "\"1.6.0\""),
                // cmake CheckTypeSize
                .define("MMDB_UINT128_USING_MODE", to: "0"),
                .define("MMDB_UINT128_IS_BYTE_ARRAY", to: "0"),
                // cmake TestBigEndian
                .define("MMDB_LITTLE_ENDIAN"),
            ]),
        .target(name: "MaxMindDB", dependencies: ["CMaxMindDB"]),
        .testTarget(
            name: "MaxMindDBTests",
            dependencies: ["MaxMindDB"]),
    ]
)
