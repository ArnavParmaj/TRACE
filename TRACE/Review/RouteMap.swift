import Charts
import MapKit
import Network
import SwiftUI

/// Network up or down, for choosing the map or the offline drawing. Starts on first use.
@MainActor
@Observable
final class Connectivity {
    static let shared = Connectivity()
    private(set) var online = true
    private let monitor = NWPathMonitor()

    private init() {
        monitor.pathUpdateHandler = { path in
            let up = path.status == .satisfied
            Task { @MainActor in Connectivity.shared.online = up }
        }
        monitor.start(queue: DispatchQueue(label: "connectivity"))
    }
}

extension RideAnalysis.Band {
    /// Slow → moderate → fast reads as grey → white → amber. Red stays reserved (invariant 9).
    var color: Color { [Color.inkMuted, Color.ink, Color.accent][rawValue] }
}

/// S07 map: the route coloured by speed, start ○, end □, top speed and stops marked.
/// Offline it draws the same line on black over the hatch, a designed state, not an error.
struct RouteMap: View {
    let analysis: RideAnalysis
    let stops: [StopEvent]
    private var connectivity = Connectivity.shared

    init(analysis: RideAnalysis, stops: [StopEvent]) {
        self.analysis = analysis
        self.stops = stops
    }

    var body: some View {
        Group {
            if connectivity.online { live } else { offline }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Route map, \(stops.count) stops")
    }

    private var live: some View {
        Map(initialPosition: framing, interactionModes: [.pan, .zoom]) {
            ForEach(analysis.segments.indices, id: \.self) { i in
                let seg = analysis.segments[i]
                MapPolyline(coordinates: seg.points.map(\.coordinate))
                    .stroke(seg.band.color, style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
            }
            if let p = analysis.start { Annotation("", coordinate: p.coordinate) { marker(Circle()) } }
            if let p = analysis.end { Annotation("", coordinate: p.coordinate) { marker(Rectangle()) } }
            if let p = analysis.topSpeedAt {
                Annotation("", coordinate: p.coordinate) {
                    tag(String(format: "%.0f KM/H", analysis.topSpeedKph), color: .accent)
                }
            }
            ForEach(stops) { stop in
                Annotation("", coordinate: CLLocationCoordinate2D(latitude: stop.lat, longitude: stop.lon)) {
                    tag(Self.minutes(stop.endedAt.timeIntervalSince(stop.startedAt)), color: .inkDim)
                }
            }
        }
        .mapStyle(.standard(elevation: .flat, emphasis: .muted, pointsOfInterest: .excludingAll))
        .environment(\.colorScheme, .dark)
    }

    /// The whole route with a margin; `.automatic` framed only part of it.
    private var framing: MapCameraPosition {
        let pts = analysis.segments.flatMap(\.points).map { MKMapPoint($0.coordinate) }
        guard let first = pts.first else { return .automatic }
        var rect = MKMapRect(origin: first, size: MKMapSize(width: 0, height: 0))
        for p in pts { rect = rect.union(MKMapRect(origin: p, size: MKMapSize(width: 0, height: 0))) }
        let pad = max(rect.width, rect.height) * 0.15 + 500
        return .rect(rect.insetBy(dx: -pad, dy: -pad))
    }

    private var offline: some View {
        Canvas { ctx, size in
            let all = analysis.segments.flatMap(\.points)
            guard let fit = Fit(all, in: size, inset: 28) else { return }
            for seg in analysis.segments {
                var path = Path()
                path.addLines(seg.points.map(fit.point))
                ctx.stroke(path, with: .color(seg.band.color), style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
            }
            if let s = analysis.start {
                let c = fit.point(s)
                ctx.stroke(Path(ellipseIn: CGRect(x: c.x - 6, y: c.y - 6, width: 12, height: 12)), with: .color(.ink), lineWidth: 2)
            }
            if let e = analysis.end {
                let c = fit.point(e)
                ctx.stroke(Path(CGRect(x: c.x - 6, y: c.y - 6, width: 12, height: 12)), with: .color(.ink), lineWidth: 2)
            }
        }
        .background { Hatch(spacing: 18) }
        .overlay(alignment: .topLeading) {
            Text("OFFLINE MAP").font(.oswald(12, .medium)).tracking(2.4).foregroundStyle(Color.inkMuted)
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(Color.ground)
                .overlay { Rectangle().stroke(Color.surfaceRule, lineWidth: 1) }
                .padding(16)
        }
    }

    private func marker(_ shape: some Shape) -> some View {
        shape.fill(Color.ground).stroke(Color.ink, lineWidth: 2).frame(width: 14, height: 14)
    }

    private func tag(_ text: String, color: Color) -> some View {
        Text(text).font(.oswald(11, .semibold)).tracking(0.8).foregroundStyle(color)
            .padding(.horizontal, 5).padding(.vertical, 2)
            .background(Color.ground)
            .overlay { Rectangle().stroke(color, lineWidth: 1) }
    }

    static func minutes(_ s: TimeInterval) -> String { "\(Int((s / 60).rounded())) MIN" }

    /// Lat/lon → canvas points, longitude scaled by cos(latitude) so the shape is true.
    private struct Fit {
        let minLat, maxLat, minLon, scale, kx, ox, oy: Double

        init?(_ pts: [RideAnalysis.Point], in size: CGSize, inset: Double) {
            guard let f = pts.first else { return nil }
            var lo = (lat: f.lat, lon: f.lon), hi = lo
            for p in pts { lo = (min(lo.lat, p.lat), min(lo.lon, p.lon)); hi = (max(hi.lat, p.lat), max(hi.lon, p.lon)) }
            kx = cos((lo.lat + hi.lat) / 2 * .pi / 180)
            let w = max((hi.lon - lo.lon) * kx, 1e-6), h = max(hi.lat - lo.lat, 1e-6)
            scale = min((size.width - 2 * inset) / w, (size.height - 2 * inset) / h)
            minLat = lo.lat; maxLat = hi.lat; minLon = lo.lon
            ox = (size.width - w * scale) / 2
            oy = (size.height - h * scale) / 2
        }

        func point(_ p: RideAnalysis.Point) -> CGPoint {
            CGPoint(x: ox + (p.lon - minLon) * kx * scale, y: oy + (maxLat - p.lat) * scale)
        }
    }
}

extension RideAnalysis.Point {
    var coordinate: CLLocationCoordinate2D { CLLocationCoordinate2D(latitude: lat, longitude: lon) }
}

/// 02 ELEVATION: smoothed GPS altitude against distance.
struct ElevationChart: View {
    let analysis: RideAnalysis

    var body: some View {
        Chart(analysis.elevation.indices, id: \.self) { i in
            let h = analysis.elevation[i]
            AreaMark(x: .value("km", h.km), yStart: .value("m", domain.lowerBound), yEnd: .value("m", h.metres))
                .foregroundStyle(Color.surfaceLine)
            LineMark(x: .value("km", h.km), y: .value("m", h.metres))
                .foregroundStyle(Color.inkDim).lineStyle(StrokeStyle(lineWidth: 2))
        }
        .chartYScale(domain: domain)
        .chartXAxis { AxisMarks(values: .automatic(desiredCount: 4)) { _ in AxisValueLabel().foregroundStyle(Color.inkMuted) } }
        .chartYAxis {
            AxisMarks(values: .automatic(desiredCount: 3)) { _ in
                AxisGridLine().foregroundStyle(Color.surfaceLine)
                AxisValueLabel().foregroundStyle(Color.inkMuted)
            }
        }
        .frame(height: 110)
        .accessibilityLabel(elevationLabel)
    }

    /// Lowest to highest with a little headroom, so a flat ride does not look like a cliff.
    private var domain: ClosedRange<Double> {
        let m = analysis.elevation.map(\.metres)
        let lo = m.min() ?? 0, hi = m.max() ?? 0
        let pad = max(5, (hi - lo) * 0.15)
        return (lo - pad)...(hi + pad)
    }

    private var elevationLabel: String {
        let m = analysis.elevation.map(\.metres)
        return "Elevation from \(Int(m.min() ?? 0)) to \(Int(m.max() ?? 0)) metres"
    }
}
