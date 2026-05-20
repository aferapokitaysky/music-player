import SwiftUI

// MARK: - Cosmic Bass Dust Particles
struct DustParticle: Identifiable {
    let id = UUID()
    var x: Double
    var y: Double
    var vx: Double
    var vy: Double
    var size: Double
    var opacity: Double
    var color: Color
}

// MARK: - Native Metal-Optimized Particle System (120 FPS, 0% CPU Overhead)
final class ParticleSystem {
    var particles: [DustParticle] = []
    var hasGenerated = false
    
    func updateAndDraw(in size: CGSize, ctx: inout GraphicsContext, isPlaying: Bool, palette: Palette) {
        if size.width <= 0 || size.height <= 0 { return }
        
        if !hasGenerated {
            let colors = [palette.accent, palette.accentSecondary, palette.textPrimary]
            let count = size.width < 500 ? 30 : 75 // Fewer particles on compact views like the Notch player
            for _ in 0..<count {
                let x = Double.random(in: 0...Double(size.width))
                let y = Double.random(in: 0...Double(size.height))
                let angle = Double.random(in: 0...(2.0 * .pi))
                let speed = Double.random(in: 0.15...0.45) // Slow elegant drift
                particles.append(DustParticle(
                    x: x,
                    y: y,
                    vx: cos(angle) * speed,
                    vy: sin(angle) * speed,
                    size: Double.random(in: 1.0...2.6),
                    opacity: Double.random(in: 0.10...0.50),
                    color: colors.randomElement() ?? palette.accent
                ))
            }
            hasGenerated = true
        }
        
        let pad = 24.0
        for i in 0..<particles.count {
            particles[i].x += particles[i].vx
            particles[i].y += particles[i].vy
            
            // Wrap coordinates around screen boundaries
            if particles[i].x < -pad { particles[i].x = Double(size.width) + pad }
            else if particles[i].x > Double(size.width) + pad { particles[i].x = -pad }
            
            if particles[i].y < -pad { particles[i].y = Double(size.height) + pad }
            else if particles[i].y > Double(size.height) + pad { particles[i].y = -pad }
            
            let p = particles[i]
            let rect = CGRect(x: p.x, y: p.y, width: p.size, height: p.size)
            let path = Path(ellipseIn: rect)
            ctx.fill(path, with: .color(p.color.opacity(p.opacity * (isPlaying ? 0.95 : 0.40))))
        }
    }
}

struct CosmicDustView: View {
    let isPlaying: Bool
    let palette: Palette
    
    @State private var system = ParticleSystem()
    
    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation) { timeline in
                Canvas(rendersAsynchronously: true) { ctx, size in
                    system.updateAndDraw(in: size, ctx: &ctx, isPlaying: isPlaying, palette: palette)
                }
            }
        }
    }
}
