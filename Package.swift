// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CapacitorCommunitySpeechRecognition",
    platforms: [.iOS(.v15)],
    products: [
        .library(
            name: "CapacitorCommunitySpeechRecognition",
            targets: ["SpeechRecognitionPlugin"]
        ),
    ],
    dependencies: [
        // Capacitor 8.0 推荐使用的官方 Swift PM 依赖
        .package(url: "https://github.com/ionic-team/capacitor-swift-pm.git", branch: "8.0.0")
    ],
    targets: [
        .target(
            name: "SpeechRecognitionPlugin",
            dependencies: [
                .product(name: "Capacitor", package: "capacitor-swift-pm")
                .product(name: "Cordova", package: "capacitor-swift-pm")
            ],
            path: "ios/Plugin" // 对应截图中的源码路径
        )
    ]
)
