import Testing

@testable import SynchronyTransport

@Suite struct ClockOffsetEstimatorTests {

    // MARK: - ClockSyncSample

    @Test func roundTripIsReceiveMinusSend() {
        let sample = ClockSyncSample(localSendNanos: 1_000, localReceiveNanos: 1_100, remoteReplyNanos: 5_050)
        #expect(sample.roundTripNanos == 100)
    }

    @Test func estimatedOffsetAssumesSymmetricLatency() {
        // Local sends at t=1000, receives at t=1100 (RTT 100). Remote replied
        // at t=5050 on its own clock — offset should land at 5050 - 1050 = 4000.
        let sample = ClockSyncSample(localSendNanos: 1_000, localReceiveNanos: 1_100, remoteReplyNanos: 5_050)
        #expect(sample.estimatedOffsetNanos == 4_000)
    }

    // MARK: - estimateOffsetNanos

    @Test func throwsOnEmptySamples() {
        #expect(throws: ClockOffsetEstimator.EstimationError.noSamples) {
            try ClockOffsetEstimator.estimateOffsetNanos(from: [])
        }
    }

    @Test func singleSampleReturnsItsOwnOffset() throws {
        let sample = ClockSyncSample(localSendNanos: 0, localReceiveNanos: 100, remoteReplyNanos: 4_050)
        let offset = try ClockOffsetEstimator.estimateOffsetNanos(from: [sample])
        #expect(offset == sample.estimatedOffsetNanos)
    }

    @Test func returnsMedianOfConsistentSamples() throws {
        // Three samples with a clean, consistent 4000ns offset and a bit of
        // symmetric jitter in round-trip time.
        let samples = [
            ClockSyncSample(localSendNanos: 0, localReceiveNanos: 100, remoteReplyNanos: 4_050),
            ClockSyncSample(localSendNanos: 1_000, localReceiveNanos: 1_120, remoteReplyNanos: 5_060),
            ClockSyncSample(localSendNanos: 2_000, localReceiveNanos: 2_080, remoteReplyNanos: 6_040),
        ]
        let offset = try ClockOffsetEstimator.estimateOffsetNanos(from: samples, discardingSlowestFraction: 0)
        #expect(offset == 4_000)
    }

    @Test func discardsSlowestSamplesAsOutliers() throws {
        // Four fast, consistent samples (offset ~4000) and one very slow,
        // wildly-off one. Discarding the slowest 25% (1 of 4) should drop
        // the outlier and leave the median unaffected by it.
        let fastSamples = (0..<4).map { index -> ClockSyncSample in
            let base = Int64(index) * 1_000
            return ClockSyncSample(localSendNanos: base, localReceiveNanos: base + 100, remoteReplyNanos: base + 4_050)
        }
        let slowOutlier = ClockSyncSample(localSendNanos: 5_000, localReceiveNanos: 55_000, remoteReplyNanos: 999_999)

        let offset = try ClockOffsetEstimator.estimateOffsetNanos(
            from: fastSamples + [slowOutlier],
            discardingSlowestFraction: 0.25
        )
        #expect(offset == 4_000)
    }

    // MARK: - roundTripVarianceNanos

    @Test func varianceIsZeroForIdenticalRoundTrips() {
        let samples = (0..<3).map {
            ClockSyncSample(localSendNanos: Int64($0), localReceiveNanos: Int64($0) + 100, remoteReplyNanos: 0)
        }
        #expect(ClockOffsetEstimator.roundTripVarianceNanos(of: samples) == 0)
    }

    @Test func varianceIsZeroForFewerThanTwoSamples() {
        #expect(ClockOffsetEstimator.roundTripVarianceNanos(of: []) == 0)
        let single = [ClockSyncSample(localSendNanos: 0, localReceiveNanos: 100, remoteReplyNanos: 0)]
        #expect(ClockOffsetEstimator.roundTripVarianceNanos(of: single) == 0)
    }

    @Test func varianceIsPositiveForJitteryRoundTrips() {
        let samples = [
            ClockSyncSample(localSendNanos: 0, localReceiveNanos: 100, remoteReplyNanos: 0),
            ClockSyncSample(localSendNanos: 0, localReceiveNanos: 5_000, remoteReplyNanos: 0),
        ]
        #expect(ClockOffsetEstimator.roundTripVarianceNanos(of: samples) > 0)
    }

    // MARK: - ConnectionQuality

    @Test func lowVarianceClassifiesAsGood() {
        #expect(ConnectionQuality.classify(roundTripVarianceNanos: 0) == .good)
    }

    @Test func highVarianceClassifiesAsDegraded() {
        // 100ms² of variance, well above the 50ms² threshold.
        #expect(ConnectionQuality.classify(roundTripVarianceNanos: 100_000_000_000_000) == .degraded)
    }
}
