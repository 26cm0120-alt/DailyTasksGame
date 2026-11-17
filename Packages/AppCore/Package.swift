// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AppCore",
    platforms: [
        .iOS(.v17),
        // パッケージ単体テストをMac上で実行するための最低バージョン。
        .macOS(.v13)
    ],
    products: [
        .library(name: "AppCore", targets: ["AppCore"])
    ],
    targets: [
        .target(name: "AppCore"),
        .testTarget(name: "AppCoreTests", dependencies: ["AppCore"])
    ],
    swiftLanguageModes: [.v6]
)
