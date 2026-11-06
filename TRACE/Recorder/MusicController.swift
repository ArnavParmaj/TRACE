import AVFoundation
import MediaPlayer
import Observation

/// Apple Music transport and system volume for Ride mode (decision 85). Controls whatever the
/// system Music player is doing; it never owns a queue. Needs only the media-library permission.
@MainActor
@Observable
final class MusicController {
    nonisolated static let volumeSteps: Float = 16

    /// One step up or down, snapped to 1/16 so repeated taps land on the same levels.
    nonisolated static func stepped(_ volume: Float, by steps: Int) -> Float {
        min(1, max(0, ((volume * volumeSteps).rounded() + Float(steps)) / volumeSteps))
    }

    private(set) var authorized = MPMediaLibrary.authorizationStatus() == .authorized
    private(set) var title: String?
    private(set) var artist: String?
    private(set) var playing = false
    private(set) var shuffling = false
    private(set) var repeatMode = MPMusicRepeatMode.none
    private(set) var volume = AVAudioSession.sharedInstance().outputVolume

    /// iOS has no public call to set the system volume; the slider inside an MPVolumeView is the
    /// usual workaround. shortcut: fragile across iOS updates, hardware buttons remain the fallback.
    let volumeView = MPVolumeView(frame: CGRect(x: -100, y: -100, width: 1, height: 1))
    private let player = MPMusicPlayerController.systemMusicPlayer
    private var observers: [NSObjectProtocol] = []
    private var volumeWatch: NSKeyValueObservation?

    func start() {
        player.beginGeneratingPlaybackNotifications()
        for name in [Notification.Name.MPMusicPlayerControllerNowPlayingItemDidChange,
                     .MPMusicPlayerControllerPlaybackStateDidChange] {
            observers.append(NotificationCenter.default.addObserver(forName: name, object: player, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.refresh() }
            })
        }
        volumeWatch = AVAudioSession.sharedInstance().observe(\.outputVolume) { [weak self] session, _ in
            let level = session.outputVolume
            Task { @MainActor in self?.volume = level }
        }
        refresh()
    }

    func stop() {
        player.endGeneratingPlaybackNotifications()
        observers.forEach(NotificationCenter.default.removeObserver)
        observers = []
        volumeWatch = nil
    }

    func requestAccess() {
        MPMediaLibrary.requestAuthorization { [weak self] _ in Task { @MainActor in self?.refresh() } }
    }

    func togglePlay() { playing ? player.pause() : player.play() }
    func next() { player.skipToNextItem() }
    func previous() { player.skipToPreviousItem() }

    func toggleShuffle() {
        player.shuffleMode = shuffling ? .off : .songs
        refresh()
    }

    /// Off → all → one → off, as the Music app does.
    func cycleRepeat() {
        player.repeatMode = switch repeatMode { case .none: .all; case .all: .one; default: .none }
        refresh()
    }

    func setVolume(_ level: Float) {
        let level = min(1, max(0, level))
        volumeView.subviews.compactMap { $0 as? UISlider }.first?.setValue(level, animated: false)
        volume = level
    }

    func stepVolume(_ steps: Int) { setVolume(Self.stepped(volume, by: steps)) }

    private func refresh() {
        authorized = MPMediaLibrary.authorizationStatus() == .authorized
        playing = player.playbackState == .playing
        title = player.nowPlayingItem?.title
        artist = player.nowPlayingItem?.artist
        // .default is "whatever the user set in Music"; shown as off until the rider taps.
        shuffling = [.songs, .albums].contains(player.shuffleMode)
        repeatMode = player.repeatMode == .default ? .none : player.repeatMode
    }
}
