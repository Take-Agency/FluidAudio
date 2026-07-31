# Vendored FluidAudio fork

Upstream: https://github.com/FluidInference/FluidAudio @ **0.15.5** (Apache 2.0, LICENSE retained).

## Why

Upstream declares `platforms: [.iOS(.v17)]`, which makes SPM refuse to link it
into an app with a lower deployment target — even if the code is never called
on old OS versions. This fork lowers the declared floor to **iOS 15** so the
app can keep its iOS 15 deployment target; Parakeet features are
`@available(iOS 17)`-gated at the call site (ParakeetKit), so iOS 15/16 users
simply never see the engine.

## Changes from upstream (all marked with `// FORK:` comments)

1. `Package.swift`: platform floor iOS 17 → 15; CLI + test targets dropped;
   `TTS/`, `VAD/`, `Diarizer/` excluded from the target (unused by the app and
   full of iOS 16+ API).
2. `Shared/ForkCompat.swift` (new): compile-compatibility shims —
   `MLComputeUnits.fluidCpuAndNeuralEngine`, `MLMultiArrayDataType.fluidFloat16`
   / `.fluidIsFloat16`, `MLPredictionOptions.fluidSetOutputBackings` (no-op on
   iOS 15), `FluidUnfairLock` (NSLock-backed `OSAllocatedUnfairLock` stand-in),
   and a minimal `DiarizerError` re-declaration for shared ANE utilities.
3. Mechanical substitutions of the above shims at every iOS 16+ API use in
   ASR/Shared code, plus two `MLMultiArray.withUnsafeMutableBufferPointer`
   (iOS 15.4+) uses rewritten to the equivalent `dataPointer` form.
4. `ModelNames.swift` / `FluidAudioSwift.swift`: members referencing excluded
   TTS/Diarizer types removed.

No behavioral changes on iOS 16+/macOS: every shim resolves to the exact
upstream API there. The iOS 15 fallback branches are compile-only — Parakeet
is never constructed below iOS 17.

## Updating

Diff upstream's new tag against 0.15.5, re-apply (the `// FORK:` markers locate
every change), rebuild with:
`xcodebuild -scheme FluidAudio -destination 'generic/platform=iOS' build`
(from this directory — this validates the iOS 15 floor).
