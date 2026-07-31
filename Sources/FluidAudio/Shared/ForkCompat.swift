//
//  ForkCompat.swift
//  FluidAudio (vendored fork)
//
//  FORK: iOS 15 compile-compatibility shims. The app's deployment target is
//  iOS 15 while Parakeet is @available(iOS 17)-gated at the call site, so the
//  iOS 15 fallback branches below exist only to satisfy the compiler — they
//  are never executed on a supported configuration.
//

import CoreML
import Foundation

extension MLComputeUnits {
    /// `.cpuAndNeuralEngine` (iOS 16+/macOS 13+) with a compile-only `.all`
    /// fallback for iOS 15.
    public static var fluidCpuAndNeuralEngine: MLComputeUnits {
        if #available(iOS 16.0, macOS 13.0, *) {
            return .cpuAndNeuralEngine
        }
        return .all
    }
}

extension MLMultiArrayDataType {
    /// `.float16` (iOS 16+/macOS 13+) with a compile-only `.float32` fallback
    /// for iOS 15.
    public static var fluidFloat16: MLMultiArrayDataType {
        if #available(iOS 16.0, macOS 13.0, *) {
            return .float16
        }
        return .float32
    }

    /// True when this is `.float16` (iOS 16+); always false on iOS 15, where
    /// fp16 model outputs cannot occur.
    var fluidIsFloat16: Bool {
        if #available(iOS 16.0, macOS 13.0, *) {
            return self == .float16
        }
        return false
    }
}

extension MLPredictionOptions {
    /// Set `outputBackings` (iOS 16+/macOS 13+). No-op on iOS 15 — output
    /// buffer reuse is a performance optimization, not a correctness need.
    func fluidSetOutputBackings(_ backings: [String: Any]) {
        if #available(iOS 16.0, macOS 13.0, *) {
            self.outputBackings = backings
        }
    }
}

/// FORK: `DiarizerError` is defined in the excluded Diarizer subsystem, but
/// shared ANE memory utilities throw two of its cases. Minimal re-declaration.
public enum DiarizerError: Error, LocalizedError {
    case memoryAllocationFailed
    case invalidArrayBounds

    public var errorDescription: String? {
        switch self {
        case .memoryAllocationFailed: return "Failed to allocate ANE-aligned memory"
        case .invalidArrayBounds: return "Array access out of bounds"
        }
    }
}

/// Drop-in replacement for `OSAllocatedUnfairLock` (iOS 16+) backed by NSLock.
/// Matches the `withLockUnchecked` surface FileDownloader uses.
final class FluidUnfairLock<State>: @unchecked Sendable {
    private let lock = NSLock()
    private var state: State

    init(uncheckedState initialState: State) {
        self.state = initialState
    }

    init(initialState: State) where State: Sendable {
        self.state = initialState
    }

    func withLockUnchecked<R>(_ body: (inout State) -> R) -> R {
        lock.lock()
        defer { lock.unlock() }
        return body(&state)
    }

    func withLock<R: Sendable>(_ body: @Sendable (inout State) throws -> R) rethrows -> R where State: Sendable {
        lock.lock()
        defer { lock.unlock() }
        return try body(&state)
    }
}
