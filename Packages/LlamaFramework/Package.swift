// swift-tools-version: 5.9
import PackageDescription

// llama.cpp の xcframework（iOS 実機・シミュレータ）を Tangomiru に組み込むためのパッケージ。
// llama.xcframework は大きいので Git に入れず、scripts/setup-plamo.sh でビルドしてここに置く
let package = Package(
    name: "LlamaFramework",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "LlamaFramework", targets: ["llama"]),
    ],
    targets: [
        .binaryTarget(name: "llama", path: "llama.xcframework"),
    ]
)
