// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "Nook",
    platforms: [
        .iOS(.v17),
    ],
    dependencies: [
        .package(url: "https://github.com/supabase/supabase-swift.git", from: "2.0.0"),
    ],
    products: [
        .library(name: "Nook", targets: ["Nook"]),
    ],
    targets: [
        .target(
            name: "Nook",
            dependencies: [
                .product(name: "Supabase", package: "supabase-swift"),
            ],
            path: "Nook"
        ),
    ]
)
