import Foundation

/// The user's chosen clip within a song: start/end time and whether to fade.
struct TrimSelection {
    /// Ringtones are conventionally 30 seconds or less.
    static let maxDuration: TimeInterval = 30
    /// Fixed fade length used on both ends when `fadeEnabled` is true.
    static let fadeDuration: TimeInterval = 1.5

    var start: TimeInterval
    var end: TimeInterval
    var fadeEnabled: Bool = true

    var duration: TimeInterval { end - start }

    init(start: TimeInterval = 0, end: TimeInterval, fadeEnabled: Bool = true) {
        self.start = start
        self.end = end
        self.fadeEnabled = fadeEnabled
    }

    /// Clamps a candidate (start, end) pair so it stays within the source
    /// duration and never exceeds `maxDuration`.
    static func clamped(start: TimeInterval, end: TimeInterval, sourceDuration: TimeInterval) -> (start: TimeInterval, end: TimeInterval) {
        var s = max(0, start)
        var e = min(sourceDuration, end)
        if e - s > maxDuration {
            // Keep the drag anchored to whichever edge moved; trim the other side.
            e = s + maxDuration
        }
        if e > sourceDuration {
            e = sourceDuration
            s = max(0, e - maxDuration)
        }
        // Never allow the handles to cross: a negative duration isn't real.
        e = max(e, s)
        return (s, e)
    }
}
