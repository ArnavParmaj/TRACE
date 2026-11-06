import Testing
@testable import TRACE

@Suite struct VolumeStepTests {
    @Test func stepsSnapToSixteenths() {
        #expect(MusicController.stepped(0.5, by: 1) == 0.5625)
        #expect(MusicController.stepped(0.53, by: -1) == 0.4375)   // 0.53 snaps to 8/16 first
    }

    @Test func stepsStopAtTheEnds() {
        #expect(MusicController.stepped(1, by: 1) == 1)
        #expect(MusicController.stepped(0, by: -1) == 0)
    }
}
