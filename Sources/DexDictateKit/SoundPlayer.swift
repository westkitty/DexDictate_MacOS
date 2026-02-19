import AppKit

/// Plays a named macOS system sound as audio feedback.
public enum SoundPlayer {

    /// Plays the given system sound. Passing `.none` is a deliberate no-op.
    ///
    /// - Parameter sound: A `Settings.SystemSound` whose `rawValue` is a name resolvable
    ///   by `NSSound(named:)` (e.g. from `/System/Library/Sounds/`).
    public static func play(_ sound: AppSettings.SystemSound) {
        guard sound != .none else { return }
        NSSound(named: sound.rawValue)?.play()
    }
}
