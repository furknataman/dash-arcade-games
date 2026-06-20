// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ArcadeCore",
    defaultLocalization: "en",
    platforms: [.iOS(.v17)],
    products: [
        // The engine + UI + services. No third-party deps — always builds.
        .library(name: "ArcadeCore", targets: ["ArcadeCore"]),
        // Optional AdMob implementation of `AdsProviding`. Link this only in
        // games that monetize with Google AdMob.
        .library(name: "ArcadeCoreAdMob", targets: ["ArcadeCoreAdMob"]),
    ],
    dependencies: [
        .package(url: "https://github.com/googleads/swift-package-manager-google-mobile-ads.git",
                 from: "11.13.0"),
    ],
    targets: [
        .target(name: "ArcadeCore"),
        .target(
            name: "ArcadeCoreAdMob",
            dependencies: [
                "ArcadeCore",
                .product(name: "GoogleMobileAds",
                         package: "swift-package-manager-google-mobile-ads"),
            ]
        ),
    ]
)
