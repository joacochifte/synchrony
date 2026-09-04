import Foundation

/// Compass-heading comparisons for direction prompts. Headings wrap around
/// at 360°, so a plain subtraction would say 359° and 1° are almost
/// opposite when they're actually 2° apart.
public enum AngularMath: Sendable {

    /// Smallest angle between two headings in degrees, always in `0...180`.
    public static func difference(_ lhs: Double, _ rhs: Double) -> Double {
        let delta = abs(normalize(lhs) - normalize(rhs))
        return Swift.min(delta, 360 - delta)
    }

    private static func normalize(_ degrees: Double) -> Double {
        let remainder = degrees.truncatingRemainder(dividingBy: 360)
        return remainder < 0 ? remainder + 360 : remainder
    }
}
