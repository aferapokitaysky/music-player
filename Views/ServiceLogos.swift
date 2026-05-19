import SwiftUI

// MARK: - Brand colors
extension Color {
    static let spotifyGreen = Color(red: 0.117, green: 0.843, blue: 0.376)
    static let soundcloudOrange = Color(red: 1.000, green: 0.333, blue: 0.000)
}

// MARK: - Spotify mark — official PNG from Wikimedia Commons, vector fallback
struct SpotifyLogo: View {
    var size: CGFloat = 18

    private static let url = URL(string:
        "https://upload.wikimedia.org/wikipedia/commons/thumb/8/84/Spotify_icon.svg/240px-Spotify_icon.svg.png"
    )

    var body: some View {
        AsyncImage(url: Self.url) { phase in
            switch phase {
            case .success(let image):
                image.resizable().interpolation(.high).scaledToFit()
            default:
                LegacySpotifyLogo(size: size)
            }
        }
        .frame(width: size, height: size)
    }
}

// Local vector fallback (used while loading or offline)
struct LegacySpotifyLogo: View {
    var size: CGFloat = 18
    var body: some View {
        ZStack {
            Circle().fill(Color.spotifyGreen)
            SpotifyArcs()
                .stroke(Color.white, style: StrokeStyle(lineWidth: size * 0.13, lineCap: .round))
                .padding(size * 0.18)
        }
        .frame(width: size, height: size)
    }
}

private struct SpotifyArcs: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width
        let h = rect.height
        // Three concave arcs (open downward) at increasing radii — top of the "disc"
        let centers: [(CGFloat, CGFloat)] = [
            (0.50 * w, 0.92 * h),
            (0.50 * w, 1.05 * h),
            (0.50 * w, 1.20 * h)
        ]
        let radii: [CGFloat] = [0.50, 0.65, 0.80]
        for (i, c) in centers.enumerated() {
            let r = radii[i] * w
            let center = CGPoint(x: c.0, y: c.1)
            // Arc on top half (negative y from center)
            p.addArc(
                center: center,
                radius: r,
                startAngle: .degrees(220),
                endAngle: .degrees(320),
                clockwise: false
            )
        }
        return p
    }
}

// MARK: - SoundCloud mark — official PNG from Wikimedia Commons, vector fallback
struct SoundCloudLogo: View {
    var size: CGFloat = 18

    private static let url = URL(string:
        "https://upload.wikimedia.org/wikipedia/commons/thumb/a/a2/Antu_soundcloud.svg/240px-Antu_soundcloud.svg.png"
    )

    var body: some View {
        AsyncImage(url: Self.url) { phase in
            switch phase {
            case .success(let image):
                image.resizable().interpolation(.high).scaledToFit()
            default:
                LegacySoundCloudLogo(size: size)
            }
        }
        .frame(width: size, height: size)
    }
}

// Local vector fallback
struct LegacySoundCloudLogo: View {
    var size: CGFloat = 18
    var body: some View {
        ZStack {
            CloudShape()
                .fill(Color.soundcloudOrange)
            CloudBars()
                .fill(Color.white.opacity(0.95))
                .padding(.horizontal, size * 0.24)
                .padding(.vertical, size * 0.30)
        }
        .frame(width: size * 1.4, height: size)
    }
}

private struct CloudShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width
        let h = rect.height
        // Compose a cloud silhouette from overlapping circles + base capsule
        let r1 = h * 0.40
        let r2 = h * 0.50
        let r3 = h * 0.42

        p.addEllipse(in: CGRect(x: w * 0.05, y: h * 0.25, width: r1 * 2, height: r1 * 2))
        p.addEllipse(in: CGRect(x: w * 0.30, y: h * 0.05, width: r2 * 2, height: r2 * 2))
        p.addEllipse(in: CGRect(x: w * 0.55, y: h * 0.20, width: r3 * 2, height: r3 * 2))
        p.addRoundedRect(
            in: CGRect(x: w * 0.05, y: h * 0.55, width: w * 0.90, height: h * 0.45),
            cornerSize: CGSize(width: h * 0.22, height: h * 0.22)
        )
        return p
    }
}

private struct CloudBars: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let count = 7
        let gap: CGFloat = rect.width / CGFloat(count * 2)
        let barW: CGFloat = gap
        // Heights chosen to evoke a soundwave
        let heights: [CGFloat] = [0.45, 0.70, 0.55, 1.00, 0.65, 0.85, 0.50]
        for i in 0..<count {
            let h = rect.height * heights[i % heights.count]
            let x = CGFloat(i) * (barW + gap)
            let y = rect.maxY - h
            p.addRoundedRect(
                in: CGRect(x: x, y: y, width: barW, height: h),
                cornerSize: CGSize(width: barW * 0.4, height: barW * 0.4)
            )
        }
        return p
    }
}
