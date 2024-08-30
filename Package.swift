// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.
//===----------------------------------------------------------------------===//
//
// This source file is part of the Netbot open source project
//
// Copyright (c) 2021 Junfeng Zhang. and the Netbot project authors
// Licensed under Apache License v2.0
//
// See LICENSE for license information
// See CONTRIBUTORS.txt for the list of Netbot project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import PackageDescription

let package = Package(
  name: "swift-maxminddb",
  products: [
    // Products define the executables and libraries a package produces, and make them visible to other packages.
    .library(
      name: "MaxMindDB",
      targets: ["MaxMindDB"])
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
      exclude: [
        "hash.txt",
        "LICENSE.txt",
      ],
      cSettings: [
        .define("PACKAGE_VERSION", to: "\"1.11.0\"")
      ]
    ),
    .target(
      name: "MaxMindDB",
      dependencies: ["CMaxMindDB"],
      resources: [
        .copy("PrivacyInfo.xcprivacy")
      ]
    ),
    .testTarget(
      name: "MaxMindDBTests",
      dependencies: ["MaxMindDB"]),
  ]
)
