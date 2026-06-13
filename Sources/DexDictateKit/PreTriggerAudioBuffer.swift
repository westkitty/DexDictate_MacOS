import os.lock

/// A circular audio buffer that retains the most recent `durationSeconds` of audio samples.
///
/// Designed for the real-time audio hot path: writes are lock-minimal and allocation-free
/// (after initial setup). Reads happen off the audio thread and are also lock-protected.
///
/// Thread safety: `os_unfair_lock` guards all internal state. The lock is intentionally
/// low-overhead — it does not block the audio thread longer than a fast array index update.
public final class PreTriggerAudioBuffer {

    // MARK: - State (all guarded by `lock`)

    private var lock = os_unfair_lock()

    /// Ring buffer storage. Allocated once at init / reset.
    private var storage: [Float]
    /// Write index into `storage` (next sample will be written here).
    private var writeIndex: Int = 0
    /// Number of valid samples currently stored (0 … capacity).
    private var count: Int = 0
    /// Maximum number of samples the buffer can hold.
    private var capacity: Int

    // MARK: - Configuration (immutable after construction / reset)

    /// Duration in seconds.
    public let durationSeconds: Double

    // MARK: - Init

    /// Creates a pre-trigger buffer.
    /// - Parameters:
    ///   - durationSeconds: How many seconds of audio to retain (default 0.75 s).
    ///   - sampleRate: Initial sample rate. Call `reset(sampleRate:)` if it changes.
    public init(durationSeconds: Double = 0.75, sampleRate: Double = 44100) {
        self.durationSeconds = durationSeconds
        self.capacity = max(1, Int(ceil(durationSeconds * sampleRate)))
        self.storage = [Float](repeating: 0, count: self.capacity)
    }

    // MARK: - Public API

    /// Appends samples from the audio thread.
    ///
    /// - Parameters:
    ///   - samples: Raw PCM samples to append.
    ///   - sampleRate: Current sample rate — used only to recompute capacity if it has
    ///                 drifted from what was used at init/reset. In practice this stays
    ///                 constant, so the branch is nearly always not taken.
    ///
    /// Hot-path contract: no `await`, no `@MainActor` crossing, no heap allocation.
    public func append(_ samples: [Float], sampleRate: Double) {
        guard !samples.isEmpty else { return }

        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }

        // Fast path: write samples into the ring buffer one by one.
        // If `samples.count >= capacity`, only the last `capacity` samples matter —
        // we skip ahead to avoid O(n) work on very large chunks.
        let incoming = samples.count
        let startIndex: Int
        if incoming >= capacity {
            // The whole buffer will be overwritten; keep only the tail.
            startIndex = incoming - capacity
        } else {
            startIndex = 0
        }

        for i in startIndex ..< incoming {
            storage[writeIndex] = samples[i]
            writeIndex = (writeIndex + 1) % capacity
        }

        let written = incoming - startIndex
        count = min(count + written, capacity)
    }

    /// Returns the current buffer contents in chronological order (oldest first).
    ///
    /// Safe to call from any thread. Returns an empty array if the buffer has been
    /// cleared or never received samples.
    ///
    /// Not intended to be called from the real-time audio thread (allocates).
    public func snapshot() -> [Float] {
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }

        guard count > 0 else { return [] }

        if count < capacity {
            // Buffer not yet full — data runs from index 0 up to count-1, but
            // writeIndex is the next slot, so oldest is at (writeIndex - count + capacity) % capacity.
            // Since we always write sequentially from 0 when the buffer is not full,
            // the oldest sample is at index (writeIndex - count + capacity) % capacity.
            let oldest = (writeIndex - count + capacity) % capacity
            if oldest + count <= capacity {
                return Array(storage[oldest ..< oldest + count])
            } else {
                let tail = capacity - oldest
                return Array(storage[oldest ..< capacity]) + Array(storage[0 ..< count - tail])
            }
        } else {
            // Buffer is full — oldest sample is at writeIndex.
            if writeIndex == 0 {
                return Array(storage)
            } else {
                return Array(storage[writeIndex...]) + Array(storage[..<writeIndex])
            }
        }
    }

    /// Resets the buffer to empty.
    public func clear() {
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }
        writeIndex = 0
        count = 0
    }

    /// Clears the buffer and reinitializes storage for a new sample rate.
    ///
    /// Call this when `capturedSampleRate` changes so capacity is correct.
    public func reset(sampleRate: Double) {
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }
        let newCapacity = max(1, Int(ceil(durationSeconds * sampleRate)))
        if newCapacity != capacity {
            capacity = newCapacity
            storage = [Float](repeating: 0, count: newCapacity)
        }
        writeIndex = 0
        count = 0
    }
}
