import MediaPlayer
import SwiftUI

/// Landscape Ride mode: now playing + transport, or one ALLOW button until the media-library
/// permission is granted (asked on first tap, never at ride start: capture never blocks).
struct MusicStrip: View {
    let music: MusicController

    var body: some View {
        if music.authorized {
            VStack(alignment: .leading, spacing: 4) {
                Text(nowPlaying).font(.condensed(16, .medium)).foregroundStyle(Color.inkDim).lineLimit(1)
                transport
            }
        } else {
            Button { music.requestAccess() } label: {
                Text("ALLOW APPLE MUSIC").font(.oswald(18, .semibold)).tracking(4).foregroundStyle(Color.accent)
                    .frame(maxWidth: .infinity, minHeight: minTouch)
                    .overlay { Rectangle().stroke(Color.accent, lineWidth: 2) }
                    .contentShape(Rectangle())
            }
            .buttonStyle(PressStyle())
        }
    }

    private var nowPlaying: String {
        guard let title = music.title else { return "Nothing playing" }
        return music.artist.map { "\($0) · \(title)" } ?? title
    }

    private var transport: some View {
        HStack(spacing: 0) {
            key("backward.end.fill", "Previous track", width: 72, action: music.previous)
            key(music.playing ? "pause.fill" : "play.fill", music.playing ? "Pause" : "Play",
                width: 96, tint: .accent, outlined: true, action: music.togglePlay)
            key("forward.end.fill", "Next track", width: 72, action: music.next)
            key("shuffle", music.shuffling ? "Shuffle on" : "Shuffle off", width: 60,
                tint: music.shuffling ? .accent : .inkFaint, action: music.toggleShuffle)
            key(music.repeatMode == .one ? "repeat.1" : "repeat",
                ["Repeat off", "Repeat all", "Repeat one"][music.repeatMode == .none ? 0 : music.repeatMode == .all ? 1 : 2],
                width: 60, tint: music.repeatMode == .none ? .inkFaint : .accent, action: music.cycleRepeat)
        }
        .frame(maxWidth: .infinity)
    }

    /// Outlines, not fills: a filled button is lit pixels (DESIGN.md rule 2).
    private func key(_ symbol: String, _ label: String, width: CGFloat, tint: Color = .ink,
                     outlined: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: 26)).foregroundStyle(tint)
                .frame(width: width, height: minTouch)
                .overlay { if outlined { Rectangle().stroke(tint, lineWidth: 2) } }
                .contentShape(Rectangle())
        }
        .buttonStyle(PressStyle())
        .accessibilityLabel(label)
        .frame(maxWidth: .infinity)
    }
}

/// [−] ─────●───── [+]: tap the track to jump, drag the ring, or step with the ends (1/16 each).
struct VolumeRow: View {
    let music: MusicController

    var body: some View {
        HStack(spacing: 6) {
            step("−", "Volume down", -1)
            GeometryReader { g in
                let level = CGFloat(music.volume)
                ZStack(alignment: .leading) {
                    Rectangle().fill(Color.surfaceLine).frame(height: 3)
                    Rectangle().fill(Color.accent).frame(width: g.size.width * level, height: 3)
                    Circle().fill(Color.ground).overlay { Circle().stroke(Color.ink, lineWidth: 2) }
                        .frame(width: 36, height: 36).offset(x: g.size.width * level - 18)
                }
                .frame(maxHeight: .infinity)
                .contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 0).onChanged {
                    music.setVolume(Float($0.location.x / max(1, g.size.width)))
                })
            }
            .frame(height: minTouch)
            .accessibilityElement()
            .accessibilityLabel("Volume")
            .accessibilityValue("\(Int(music.volume * 100)) percent")
            .accessibilityAdjustableAction { music.stepVolume($0 == .increment ? 1 : -1) }
            step("+", "Volume up", 1)
        }
    }

    private func step(_ glyph: String, _ label: String, _ by: Int) -> some View {
        Button { music.stepVolume(by) } label: {
            Text(glyph).font(.oswald(36, .medium)).foregroundStyle(Color.ink)
                .frame(width: minTouch, height: minTouch).contentShape(Rectangle())
        }
        .buttonStyle(PressStyle())
        .accessibilityLabel(label)
    }
}

/// Zero-size host that keeps the MPVolumeView in the window so its slider can set the volume.
struct VolumeHost: UIViewRepresentable {
    let music: MusicController
    func makeUIView(context: Context) -> MPVolumeView { music.volumeView }
    func updateUIView(_ view: MPVolumeView, context: Context) {}
}
