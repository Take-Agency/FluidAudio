// swift-tools-version: 6.0
import PackageDescription

// Vendored fork of https://github.com/FluidInference/FluidAudio at 0.15.5.
// See FORK.md for the local changes. Purpose of the fork: lower the declared
// iOS platform floor from 17 to 15 so the app (deployment target iOS 15) can
// link the package; Parakeet itself remains @available(iOS 17)-gated at the
// call site in ParakeetKit. CLI and test targets are dropped from the vendor.
let package = Package(
    name: "FluidAudio",
    platforms: [
        .macOS(.v14),
        .iOS(.v15),
    ],
    products: [
        .library(
            name: "FluidAudio",
            targets: ["FluidAudio"]
        )
    ],
    dependencies: [],
    targets: [
        .target(
            name: "FluidAudio",
            dependencies: [
                "FastClusterWrapper",
                "MachTaskSelfWrapper",
            ],
            path: "Sources/FluidAudio",
            // FORK: only the ASR path is needed; TTS/VAD/Diarizer use iOS 16+
            // APIs throughout and are excluded rather than annotated.
            exclude: ["TTS", "VAD", "Diarizer"]
        ),
        .target(
            name: "FastClusterWrapper",
            path: "Sources/FastClusterWrapper",
            publicHeadersPath: "include"
        ),
        .target(
            name: "MachTaskSelfWrapper",
            path: "Sources/MachTaskSelfWrapper",
            publicHeadersPath: "include"
        ),
    ],
    cxxLanguageStandard: .cxx17
)
