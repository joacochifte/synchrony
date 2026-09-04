import Testing

@testable import SynchronyCore

@Suite struct AngularMathTests {

    @Test func differenceOfIdenticalHeadingsIsZero() {
        #expect(AngularMath.difference(90, 90) == 0)
    }

    @Test func differenceOfNearbyHeadings() {
        #expect(AngularMath.difference(10, 15) == 5)
    }

    @Test func differenceWrapsAroundThreeSixtyDegrees() {
        // 359° and 2° are 3° apart going through 0°, not 357° apart.
        #expect(AngularMath.difference(359, 2) == 3)
    }

    @Test func differenceOfOppositeHeadingsIsOneEighty() {
        #expect(AngularMath.difference(0, 180) == 180)
    }

    @Test func differenceHandlesNegativeDegrees() {
        #expect(AngularMath.difference(-10, 350) == 0)
    }

    @Test func differenceIsSymmetric() {
        #expect(AngularMath.difference(20, 340) == AngularMath.difference(340, 20))
    }
}
