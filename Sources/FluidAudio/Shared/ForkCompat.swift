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
import os

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

/// Drop-in replacement for `OSAllocatedUnfairLock` (iOS 16+). Backed by a
/// heap-allocated `os_unfair_lock` — the same primitive `OSAllocatedUnfairLock`
/// wraps — so locking behaves the same on every OS. Matches the
/// `init(initialState:)` / `init(uncheckedState:)` / `withLock` /
/// `withLockUnchecked` surface the Shared code uses.
final class FluidUnfairLock<State>: @unchecked Sendable {
    private let lock: os_unfair_lock_t
    private var state: State

    init(uncheckedState initialState: State) {
        self.lock = .allocate(capacity: 1)
        self.lock.initialize(to: os_unfair_lock())
        self.state = initialState
    }

    init(initialState: State) where State: Sendable {
        self.lock = .allocate(capacity: 1)
        self.lock.initialize(to: os_unfair_lock())
        self.state = initialState
    }

    deinit {
        lock.deinitialize(count: 1)
        lock.deallocate()
    }

    func withLockUnchecked<R>(_ body: (inout State) throws -> R) rethrows -> R {
        os_unfair_lock_lock(lock)
        defer { os_unfair_lock_unlock(lock) }
        return try body(&state)
    }

    func withLock<R: Sendable>(_ body: @Sendable (inout State) throws -> R) rethrows -> R where State: Sendable {
        os_unfair_lock_lock(lock)
        defer { os_unfair_lock_unlock(lock) }
        return try body(&state)
    }
}

extension MLMultiArray {
    /// Storage extent in elements (what the iOS 15.4+ buffer APIs expose):
    /// the furthest addressable element + 1, so padded strides are covered.
    private var fluidStorageElementCount: Int {
        guard count > 0 else { return 0 }
        var last = 0
        for (dim, stride) in zip(shape, strides) {
            last += (dim.intValue - 1) * stride.intValue
        }
        return last + 1
    }

    /// `withUnsafeBytes` (iOS 15.4+/macOS 12.3+); `dataPointer` fallback below.
    func fluidWithUnsafeBytes<R>(_ body: (UnsafeRawBufferPointer) throws -> R) rethrows -> R {
        if #available(iOS 15.4, macOS 12.3, *) {
            return try withUnsafeBytes(body)
        }
        let byteCount = fluidStorageElementCount * ANEMemoryUtils.getElementSize(for: dataType)
        return try body(UnsafeRawBufferPointer(start: dataPointer, count: byteCount))
    }

    /// `withUnsafeMutableBytes` (iOS 15.4+/macOS 12.3+); `dataPointer` fallback below.
    func fluidWithUnsafeMutableBytes<R>(
        _ body: (UnsafeMutableRawBufferPointer, [Int]) throws -> R
    ) rethrows -> R {
        if #available(iOS 15.4, macOS 12.3, *) {
            return try withUnsafeMutableBytes(body)
        }
        let byteCount = fluidStorageElementCount * ANEMemoryUtils.getElementSize(for: dataType)
        return try body(
            UnsafeMutableRawBufferPointer(start: dataPointer, count: byteCount), strides.map { $0.intValue })
    }

    /// `withUnsafeMutableBufferPointer(ofType:)` (iOS 15.4+/macOS 12.3+);
    /// `dataPointer` fallback below.
    func fluidWithUnsafeMutableBufferPointer<S, R>(
        ofType type: S.Type, _ body: (UnsafeMutableBufferPointer<S>, [Int]) throws -> R
    ) rethrows -> R where S: MLShapedArrayScalar {
        if #available(iOS 15.4, macOS 12.3, *) {
            return try withUnsafeMutableBufferPointer(ofType: type, body)
        }
        let elements = fluidStorageElementCount
        let base = dataPointer.bindMemory(to: S.self, capacity: elements)
        return try body(UnsafeMutableBufferPointer(start: base, count: elements), strides.map { $0.intValue })
    }
}
