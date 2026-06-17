// swift-tools-version: 6.2
import PackageDescription
import Foundation

// PropertyTestingKit requires the patched Swift toolchain (parameter packs) and
// macOS 26. Build via ./scripts/swift-toolchain.sh, not system `swift`.
//
// `-sanitize-coverage=edge,pc-table` instruments the code under test so PTK's
// SanCovHooks can observe edge coverage; `-sanitize=undefined` matches PTK's own
// build. Any product linking the instrumented `RBT` module must also link PTK
// (which provides the SanitizerCoverage callbacks).
// Compiler-generated edges are filtered at COMPILE time by PropertyTestingKit's
// TagCompilerGenerated LLVM pass plugin (PTK deleted its runtime edge filter).
// The dylib is built by ../PropertyTestingKit/scripts/build-llvm-plugins.sh,
// which swift-toolchain.sh invokes before building.
let ptkPluginDir = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .appendingPathComponent("../PropertyTestingKit/.build/llvm-plugins")
    .standardizedFileURL
func loadPass(_ name: String) -> [String] {
    ["-Xfrontend", "-load-pass-plugin=\(ptkPluginDir.appendingPathComponent(name + ".dylib").path)"]
}

let sanitize: [SwiftSetting] = [
    .unsafeFlags(["-sanitize=undefined", "-sanitize-coverage=edge,pc-table"] + loadPass("TagCompilerGenerated"))
]

let package = Package(
    name: "etna-swift-rbt",
    platforms: [.macOS(.v26)],
    products: [
        .executable(name: "rbt", targets: ["Solve"]),
        .executable(name: "rbt-sampler", targets: ["rbt-sampler"]),
    ],
    dependencies: [
        .package(path: "../PropertyTestingKit"),
    ],
    targets: [
        // System under test + spec + decoders. Instrumented for coverage.
        .target(
            name: "RBT",
            swiftSettings: sanitize
        ),
        // PTK-backed generators + coverage-guided solve/sample strategy.
        .target(
            name: "RBTGen",
            dependencies: [
                "RBT",
                .product(name: "PropertyTestingKit", package: "PropertyTestingKit"),
            ],
            swiftSettings: sanitize
        ),
        // Target dir is `Solve` (not `rbt`) to avoid a case-insensitive
        // filesystem clash with the `RBT` library; the product is still `rbt`.
        .executableTarget(
            name: "Solve",
            dependencies: ["RBTGen"],
            swiftSettings: sanitize
        ),
        .executableTarget(
            name: "rbt-sampler",
            dependencies: ["RBTGen"],
            swiftSettings: sanitize
        ),
        .testTarget(
            name: "RBTTests",
            dependencies: [
                "RBT",
                // Provides the SanitizerCoverage runtime for the instrumented RBT module.
                .product(name: "PropertyTestingKit", package: "PropertyTestingKit"),
            ],
            swiftSettings: sanitize
        ),
    ]
)
