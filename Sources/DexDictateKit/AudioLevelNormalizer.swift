import Darwin

/// Converts a linear audio amplitude value to a decibel-normalized level in 0.0...1.0.
///
/// Uses a -60 dB floor and 0 dB ceiling (60 dB range), which better represents
/// normal speech dynamics than a narrower range.
enum AudioLevelNormalizer {
    /// The floor in dB below which signal is treated as silence.
    static let floorDB: Double = -60.0

    /// The ceiling in dB (linear amplitude of 1.0 corresponds to 0 dB).
    static let ceilingDB: Double = 0.0

    /// The dynamic range in dB.
    static let rangeDB: Double = ceilingDB - floorDB  // 60.0

    /// Minimum amplitude clamped before log10 to prevent -infinity / NaN.
    private static let minimumAmplitude: Double = 1e-10

    /// Normalizes a linear RMS amplitude value to a 0.0...1.0 level.
    ///
    /// - Parameter amplitude: Linear amplitude (RMS), typically in 0.0...1.0 but may exceed 1.0.
    /// - Returns: A value in `0.0...1.0` where 0.0 represents silence at or below -60 dB
    ///   and 1.0 represents full-scale (0 dB or above).
    static func normalize(_ amplitude: Double) -> Double {
        // Amplitude must be finite and positive for log10. We use an explicit isFinite
        // check because Swift's max() propagates NaN rather than ignoring it.
        // +infinity and NaN both fail isFinite, mapping to silence (0.0).
        let safeAmplitude = (amplitude.isFinite && amplitude > minimumAmplitude) ? amplitude : minimumAmplitude
        let dB = 20.0 * log10(safeAmplitude)
        let normalized = (dB - floorDB) / rangeDB
        return min(max(normalized, 0.0), 1.0)
    }
}
