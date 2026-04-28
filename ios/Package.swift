// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "UnlockAlert",
    platforms: [
        .iOS(.v17)
    ],
    dependencies: [
        .package(url: "https://github.com/firebase/firebase-ios-sdk.git", from: "10.25.0"),
    ],
    targets: [
        .target(
            name: "UnlockAlert",
            dependencies: [
                .product(name: "FirebaseFirestore", package: "firebase-ios-sdk"),
                .product(name: "FirebaseMessaging", package: "firebase-ios-sdk"),
                .product(name: "FirebaseAnalytics", package: "firebase-ios-sdk"),
            ],
            resources: [
                .process("Resources")
            ]
        )
    ]
)
