# Vendored FluidAudio fork

Upstream: https://github.com/FluidInference/FluidAudio @ **e2ea498d** (main, 2026-11; Apache 2.0, LICENSE retained).
The previous fork was based on 0.15.5.

## Why

Upstream declares `platforms: [.iOS(.v17)]`, which makes SPM refuse to link it
into an app with a lower deployment target — even if the code is never called
on old OS versions. This fork lowers the declared floor to **iOS 15** so the
apps (Transcribe, Auto Caption) can keep their iOS 15 deployment target;
Parakeet features are `@available(iOS 17)`-gated at the call site, so iOS 15/16
users simply never see the engine.

## What is kept

Only the `FluidAudio` library, and only ASR + Shared code:

- `ASR/Parakeet`: SlidingWindow (TDT batch transcription, CTC, CustomVocabulary),
  Streaming (Nemotron streaming incl. `NemotronVocabularyBias` and BlankRescue,
  EOU), Unified (kept because `ParakeetModelVariant` and `ModelNames` reference it),
  TokenDeduplication
- `ASR/Shared`, `Shared` (download, audio conversion, logging, CoreML utils)
- `ModelNames.swift`, `ModelRegistry.swift`, `FluidAudioSwift.swift`

## Changes from upstream (all marked with `// FORK:` comments)

1. `Package.swift`: platform floor iOS 17 → 15; CLI + test targets dropped
   (their sources stay in the tree, unbuilt); `Package@swift-6.2.swift` deleted
   (it would otherwise win on Swift 6.2+ toolchains and restore the iOS 17
   floor). Excluded from the target:
   - subsystems: `TTS`, `Diarizer`, `VAD`, `Enhancement`, `Speaker`, `Decision`, `ITN`
   - ASR models: `ASR/Canary`, `ASR/Cohere`, `ASR/LFM3Audio`, `ASR/SenseVoice`,
     `ASR/Paraformer`, `ASR/NemotronTranscribeLite`
   - `ASR/Parakeet/Unified/benchmark.md` (resource noise)
2. `Shared/ForkCompat.swift` (new): compile-compatibility shims. Each one calls
   the real API whenever the OS has it (iOS 16+/macOS 13+, or 15.4+/12.3+ for
   the buffer accessors); the fallback branches are compile-only, since
   Parakeet never runs below iOS 17.
   - `MLComputeUnits.fluidCpuAndNeuralEngine` → `.cpuAndNeuralEngine`
   - `MLMultiArrayDataType.fluidFloat16` → `.float16`; `.fluidIsFloat16` → `== .float16`
   - `MLPredictionOptions.fluidSetOutputBackings(_:)` → `outputBackings =` (no-op on iOS 15)
   - `MLMultiArray.fluidWithUnsafeBytes`, `.fluidWithUnsafeMutableBytes`,
     `.fluidWithUnsafeMutableBufferPointer(ofType:)` → the iOS 15.4 accessors
     (`dataPointer` fallback on 15.0–15.3)
   - `FluidUnfairLock` → stand-in for `OSAllocatedUnfairLock` (iOS 16+), backed
     by a heap-allocated `os_unfair_lock` (the primitive `OSAllocatedUnfairLock`
     wraps); same `init(initialState:)` / `init(uncheckedState:)` / `withLock` /
     `withLockUnchecked` surface
   - `DiarizerError`: minimal re-declaration (two cases) for the shared ANE utilities
3. Mechanical substitutions of those shims at every iOS 15.4/16+ API use in the
   kept ASR/Shared code. A `switch` over `MLComputeUnits` / `MLMultiArrayDataType`
   that pattern-matched `.cpuAndNeuralEngine` / `.float16` now compares with the
   shim instead.
4. `ModelNames.swift`: members that reference excluded types are removed —
   `LocalVQE` helpers (LocalVqeVariant/Chunk), PocketTTS precision/placement
   helpers, `ChatterboxNano.requiredModels(capacity:)`,
   `Canary.requiredModels(precision:)`. Their `Repo.requiredModels` cases
   return `[]` (LocalVQE, Canary) or the default set (ChatterboxNano).

No behavioral changes on iOS 16+/macOS: every shim resolves to the upstream API
there (the lock uses the same `os_unfair_lock` primitive).

## Updating

Rebase the fork commit onto the new upstream (or cherry-pick it), then grep for
`FORK` to find every change. Also grep the kept code for new uses of
`OSAllocatedUnfairLock`, `.cpuAndNeuralEngine`, `.float16`, `outputBackings`,
`withUnsafeBytes` / `withUnsafeMutableBytes` / `withUnsafeMutableBufferPointer(ofType:)`
on `MLMultiArray`, and for new references from kept code into excluded
directories. Validate with:

- `xcodebuild -scheme FluidAudio -destination 'generic/platform=iOS' -configuration Release build`
  (from this directory — validates the iOS 15 floor)
- `swift build -c release` (macOS)
