// swift-tools-version: 6.0
import PackageDescription

// Take-Agency fork of https://github.com/FluidInference/FluidAudio (Apache 2.0, LICENSE retained).
// FORK: the declared floor is lowered from iOS 17 to iOS 15 so apps with an iOS 15 deployment target
// (Transcribe, Auto Caption) can link it; the engines stay @available(iOS 17)-gated at the call site.
// Only the library is kept, and only the ASR + Shared code: TTS, Diarizer, VAD, Enhancement, Speaker,
// Decision and ITN are excluded, as are the non-Parakeet ASR models (unused by the apps, full of
// iOS 16+ API). See FORK.md.
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
            // FORK: ASR + Shared only (no TTS/Diarizer defines either). Of the ASR models only Parakeet
            // (TDT, CTC, EOU, Nemotron streaming, Unified) is kept; the other model families are excluded.
            exclude: [
                "ASR/Parakeet/Unified/benchmark.md", "TTS", "Diarizer", "VAD", "Enhancement", "Speaker", "Decision",
                "ITN", "ASR/Canary", "ASR/Cohere", "ASR/LFM3Audio", "ASR/SenseVoice", "ASR/Paraformer",
                "ASR/NemotronTranscribeLite",
            ]
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
