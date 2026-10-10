import SwiftUI
import CoreImage
#if canImport(UIKit)
import UIKit
#endif

@MainActor
@Observable
final class VidaActiva {
    static let compartida = VidaActiva()
    private(set) var app: Mundo?
    private(set) var panel: Mundo?

    func poner(_ m: Mundo) {
        switch m.capa {
        case .app: if app !== m { app = m }
        case .panel: if panel !== m { panel = m }
        case .muestra: break
        }
    }

    func quitar(_ m: Mundo) {
        if app === m { app = nil }
        if panel === m { panel = nil }
    }
}

struct CapaDeVida: View {
    let vida: Tema.Vida
    let colores: [Tono]
    let oscuro: Bool
    var capa: CapaDeChoque = .app
    
    var calentar: Double = 0

    @Environment(\.scenePhase) private var fase
    @Environment(\.accessibilityReduceMotion) private var menosMovimiento
    @Environment(\.accessibilityDimFlashingLights) private var menosDestellos
    @State private var mundo: Mundo?
    @State private var visible = false
    
    @State private var marco = MarcoGuardado()

    var body: some View {
        let m = mundo
        let marco = marco
        TimelineView(.animation(minimumInterval: 1 / (m?.fotogramas ?? 30), paused: pausada)) { tl in
            Canvas { ctx, tamano in
                guard let m else { return }
                if m.tamano != tamano { m.tamano = tamano }
                m.avanzar(hasta: tl.date)
                m.dibujar(&ctx, delante: false, desplazamiento: .zero)
            }
        }
        .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { r in
            marco.rect = r
            mundo?.origen = r.origin
            if let m = mundo, m.tamano != r.size { m.tamano = r.size }
        }
        .onAppear {
            if mundo == nil {
                let nuevo = Mundo(vida: vida, colores: colores, oscuro: oscuro, capa: capa,
                                  quieto: menosMovimiento, tenue: menosDestellos,
                                  ahorro: ProcessInfo.processInfo.isLowPowerModeEnabled)
                nuevo.origen = marco.rect.origin
                if marco.rect.width > 1 { nuevo.tamano = marco.rect.size }
                mundo = nuevo
            }
            visible = true
            if let m = mundo {
                m.reanudar()
                VidaActiva.compartida.poner(m)
                #if MAQUETA
                let s = Maqueta.calentarVida ?? calentar
                #else
                let s = calentar
                #endif
                if s > 0 {
                    
                    Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(600))
                        m.calentar(s)
                    }
                }
            }
        }
        .onDisappear {
            visible = false
            if let m = mundo { VidaActiva.compartida.quitar(m) }
        }
        .onChange(of: fase) { _, nueva in
            if nueva == .active { mundo?.reanudar() }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var pausada: Bool {
        !visible || fase != .active || mundo == nil || (mundo?.quieto ?? true)
    }
}

struct CapaDelanteDeLaVida: View {
    var capa: CapaDeChoque = .app
    @Environment(\.scenePhase) private var fase
    @State private var origen = OrigenGuardado()

    var body: some View {
        let activa = capa == .app ? VidaActiva.compartida.app : VidaActiva.compartida.panel
        let pausada = activa == nil || fase != .active || (activa?.quieto ?? true)
        let origen = origen
        TimelineView(.animation(minimumInterval: 1 / (activa?.fotogramas ?? 30), paused: pausada)) { tl in
            Canvas { ctx, _ in
                guard let m = activa else { return }
                m.avanzar(hasta: tl.date)
                let d = CGPoint(x: m.origen.x - origen.punto.x, y: m.origen.y - origen.punto.y)
                m.dibujar(&ctx, delante: true, desplazamiento: d)
            }
        }
        .onGeometryChange(for: CGPoint.self) { $0.frame(in: .global).origin } action: { origen.punto = $0 }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

@MainActor
private final class OrigenGuardado {
    var punto: CGPoint = .zero
}

@MainActor
private final class MarcoGuardado {
    var rect: CGRect = .zero
}

extension Mundo {

    func dibujar(_ ctx: inout GraphicsContext, delante: Bool, desplazamiento d: CGPoint) {
        
        guard !tapado, tamano.width > 1, tamano.height > 1 else { return }
        var c = ctx
        if d != .zero { c.translateBy(x: d.x, y: d.y) }
        if !delante { cielo(&c) }
        if quieto && !tieneAlgoQuieto { return }
        gotas(&c, delante: delante)
        puntos(&c, delante: delante)
        for p in ps where p.delante == delante {
            switch p.tipo {
            case .hoja, .petalo, .confeti: hoja(&c, p)
            case .moneda: moneda(&c, p)
            case .burbuja: burbuja(&c, p)
            case .corazon: corazon(&c, p)
            case .pompa: pompa(&c, p)
            case .luciernaga: luciernaga(&c, p)
            case .vilano: vilano(&c, p)
            case .fugaz: fugaz(&c, p)
            case .cohete: cohete(&c, p)
            case .anillo: anillo(&c, p)
            case .nube, .niebla: nube(&c, p)
            case .perla: perla(&c, p)
            default: break
            }
        }
        if !delante, let r = rayo { relampago(&c, r) }
    }

    private func cielo(_ c: inout GraphicsContext) {
        let W = tamano.width, H = tamano.height
        switch vida {
        case .tormenta:
            if destello > 0.001 {
                c.fill(Path(CGRect(x: 0, y: 0, width: W, height: H)),
                       with: .color(color(2).opacity(Double(destello) * 0.26)))
            }
            if let f = parpadeoAhora, f.fuerza > 0 {
                let centro = CGPoint(x: CGFloat(f.x), y: -20)
                c.fill(Path(ellipseIn: CGRect(x: centro.x - W * 0.6, y: centro.y - H * 0.25, width: W * 1.2, height: H * 0.5)),
                       with: .radialGradient(Gradient(colors: [color(2).opacity(0.22 * Double(f.fuerza)), .clear]),
                                             center: centro, startRadius: 0, endRadius: W * 0.6))
            }
        case .sol:
            sol(&c, W, H)
        case .galaxia:
            nebulosa(&c, W, H)
        case .lava:
            lava(&c, W, H)
        case .brasas:
            
            let s = Double(t)
            let f = 0.75 + 0.15 * sin(s * 1.7) + 0.1 * sin(s * 4.3 + 1)
            c.fill(Path(CGRect(x: 0, y: H * 0.45, width: W, height: H * 0.55)),
                   with: .radialGradient(Gradient(colors: [color(1).opacity(0.34 * f), color(2).opacity(0.12 * f), .clear]),
                                         center: CGPoint(x: W / 2, y: H * 1.08), startRadius: 0, endRadius: H * 0.62))
        case .burbujas:
            rayosDeLuz(&c, W, H)
        case .nubes where oscuro:
            
            let centro = CGPoint(x: W * 0.8, y: H * 0.1)
            c.fill(Path(ellipseIn: CGRect(x: centro.x - 160, y: centro.y - 160, width: 320, height: 320)),
                   with: .radialGradient(Gradient(colors: [Color.white.opacity(0.16), .clear]),
                                         center: centro, startRadius: 0, endRadius: 160))
            c.fill(Path(ellipseIn: CGRect(x: centro.x - 15, y: centro.y - 15, width: 30, height: 30)),
                   with: .color(Color.white.opacity(0.85)))
        default:
            break
        }
    }

    private func sol(_ c: inout GraphicsContext, _ W: CGFloat, _ H: CGFloat) {
        let centro = CGPoint(x: W * 0.86, y: H * 0.06)
        let s = Double(t)
        
        var rayos = Path()
        let n = 14
        for i in 0..<n {
            let a = Double(i) / Double(n) * 2 * .pi + s * 0.02
            let ancho = 0.06 + 0.03 * sin(Double(i) * 1.7)
            let largo = W * (0.85 + 0.25 * sin(Double(i) * 2.3))
            rayos.move(to: centro)
            rayos.addLine(to: CGPoint(x: centro.x + cos(a - ancho) * largo, y: centro.y + sin(a - ancho) * largo))
            rayos.addLine(to: CGPoint(x: centro.x + cos(a + ancho) * largo, y: centro.y + sin(a + ancho) * largo))
            rayos.closeSubpath()
        }
        c.fill(rayos, with: .radialGradient(Gradient(colors: [color(0).opacity(0.22), .clear]),
                                            center: centro, startRadius: 20, endRadius: W * 0.95))
        c.fill(Path(ellipseIn: CGRect(x: centro.x - W * 0.6, y: centro.y - W * 0.6, width: W * 1.2, height: W * 1.2)),
               with: .radialGradient(Gradient(colors: [Color.white.opacity(0.85), color(0).opacity(0.5), .clear]),
                                     center: centro, startRadius: 0, endRadius: W * 0.6))
        
        let hacia = CGPoint(x: W * 0.5 - centro.x, y: H * 0.55 - centro.y)
        for (k, (d, r, a)) in [(0.32, 10.0, 0.16), (0.5, 26.0, 0.08), (0.7, 14.0, 0.12), (1.05, 46.0, 0.06)].enumerated() {
            let p = CGPoint(x: centro.x + hacia.x * d, y: centro.y + hacia.y * d)
            let rect = CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2)
            c.fill(k == 1 ? hexagono(rect) : Path(ellipseIn: rect), with: .color(color(1).opacity(a)))
        }
    }

    private func hexagono(_ r: CGRect) -> Path {
        var p = Path()
        for i in 0..<6 {
            let a = Double(i) / 6 * 2 * .pi
            let q = CGPoint(x: r.midX + cos(a) * r.width / 2, y: r.midY + sin(a) * r.height / 2)
            if i == 0 { p.move(to: q) } else { p.addLine(to: q) }
        }
        p.closeSubpath()
        return p
    }

    private func nebulosa(_ c: inout GraphicsContext, _ W: CGFloat, _ H: CGFloat) {
        let s = Double(t)
        let centro = CGPoint(x: W * 0.5, y: H * 0.42)
        let manchas: [(Double, Double, Double, Int, Double)] = [
            (-0.25, -0.2, 0.55, 0, 0.32), (0.2, -0.05, 0.5, 1, 0.3), (0.05, 0.22, 0.45, 2, 0.24),
            (-0.15, 0.35, 0.38, 0, 0.2), (0.3, 0.4, 0.4, 1, 0.18), (-0.3, 0.05, 0.3, 2, 0.22),
        ]
        let giro = s * 0.004
        for (dx, dy, r, k, a) in manchas {
            let x = dx * cos(giro) - dy * sin(giro), y = dx * sin(giro) + dy * cos(giro)
            let p = CGPoint(x: centro.x + x * W, y: centro.y + y * W)
            let rr = r * W
            c.fill(Path(ellipseIn: CGRect(x: p.x - rr, y: p.y - rr, width: rr * 2, height: rr * 2)),
                   with: .radialGradient(Gradient(colors: [color(UInt8(k)).opacity(a), .clear]),
                                         center: p, startRadius: 0, endRadius: rr))
        }
    }

    private func lava(_ c: inout GraphicsContext, _ W: CGFloat, _ H: CGFloat) {
        let s = Float(t)

        c.drawLayer { capa in
            capa.opacity = oscuro ? 0.7 : 0.62
            capa.addFilter(.blur(radius: 3))
            for k in 0..<2 {
                capa.drawLayer { l in
                    l.addFilter(.alphaThreshold(min: 0.5, color: color(UInt8(k))))
                    l.addFilter(.blur(radius: 18))
                    for p in ps where p.tipo == .mancha && Int(p.color) == k {
                        let y = H * CGFloat(0.5 + p.amplitud * sin(s * p.vfase + p.fase))
                        let x = W * CGFloat(p.dx) + 26 * CGFloat(sin(s * p.vfase * 2.3 + p.fase * 1.7))
                        let r = CGFloat(p.tam) * (1 + 0.08 * CGFloat(sin(s * 0.7 + p.fase)))
                        l.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r * 1.15, width: r * 2, height: r * 2.3)),
                               with: .color(.black))
                    }
                }
            }
        }
        
        c.fill(Path(CGRect(x: 0, y: 0, width: W, height: H)),
               with: .linearGradient(Gradient(colors: [Color.white.opacity(oscuro ? 0.05 : 0.16), .clear,
                                                       color(0).opacity(oscuro ? 0.1 : 0.06)]),
                                     startPoint: .zero, endPoint: CGPoint(x: 0, y: H)))
    }

    private func rayosDeLuz(_ c: inout GraphicsContext, _ W: CGFloat, _ H: CGFloat) {
        let s = Double(t)
        for i in 0..<4 {
            let x0 = W * (0.15 + 0.24 * Double(i)) + 30 * sin(s * 0.11 + Double(i))
            let ancho = 30 + 20 * sin(Double(i) * 1.9)
            var p = Path()
            p.move(to: CGPoint(x: x0 - ancho / 2, y: -10))
            p.addLine(to: CGPoint(x: x0 + ancho / 2, y: -10))
            p.addLine(to: CGPoint(x: x0 + ancho * 1.8 + H * 0.12, y: H * 0.75))
            p.addLine(to: CGPoint(x: x0 - ancho * 0.6 + H * 0.12, y: H * 0.75))
            p.closeSubpath()
            let a = 0.07 + 0.04 * sin(s * 0.3 + Double(i) * 2)
            c.fill(p, with: .linearGradient(Gradient(colors: [Color.white.opacity(a), .clear]),
                                            startPoint: CGPoint(x: x0, y: 0), endPoint: CGPoint(x: x0, y: H * 0.75)))
        }
    }

    private func relampago(_ c: inout GraphicsContext, _ r: Rayo) {
        let edad = t - r.nacio
        guard edad < 0.9 else { return }
        let visible = min(1, edad / 0.12)
        let apagar = edad < 0.3 ? 1 : max(0, 1 - (edad - 0.3) / 0.6)
        
        let parpadeo = edad > 0.12 && edad < 0.2 ? 0.35 : 1
        let a = apagar * parpadeo * (tenue ? 0.5 : 1)
        func camino(_ pts: [SIMD2<Float>], _ hasta: Double) -> Path {
            var p = Path()
            let n = max(2, Int(Double(pts.count) * hasta))
            for i in 0..<min(n, pts.count) {
                let q = CGPoint(x: CGFloat(pts[i].x), y: CGFloat(pts[i].y))
                if i == 0 { p.move(to: q) } else { p.addLine(to: q) }
            }
            return p
        }
        let principal = camino(r.puntos, visible)
        let luz = color(1)
        c.stroke(principal, with: .color(luz.opacity(0.16 * a)), style: StrokeStyle(lineWidth: 9, lineCap: .round, lineJoin: .round))
        c.stroke(principal, with: .color(luz.opacity(0.45 * a)), style: StrokeStyle(lineWidth: 3.2, lineCap: .round, lineJoin: .round))
        c.stroke(principal, with: .color(Color.white.opacity(a)), style: StrokeStyle(lineWidth: 1.3, lineCap: .round, lineJoin: .round))
        if visible >= 1 {
            for rama in r.ramas {
                let p = camino(rama, 1)
                c.stroke(p, with: .color(luz.opacity(0.25 * a)), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                c.stroke(p, with: .color(Color.white.opacity(0.7 * a)), style: StrokeStyle(lineWidth: 0.8, lineCap: .round))
            }
        }
    }

    private func gotas(_ c: inout GraphicsContext, delante: Bool) {
        guard !delante, vida == .lluvia || vida == .tormenta else { return }
        let H = Float(tamano.height)
        var colas = [[Path]](repeating: [Path](repeating: Path(), count: 4), count: 3)
        var cabezas = colas
        var hay = false
        for p in ps where p.tipo == .gota {
            let mitad = H / 2
            let f: Float = p.y < mitad ? 0.65 + 0.35 * max(p.y, 0) / mitad : max(0, 1 - (p.y - mitad) / mitad)
            let a = p.alfa * f
            guard a.isFinite, a >= 0.02 else { continue }
            let b = min(Int(a * 4 / 0.72), 3)
            let k = Int(p.capa)
            let vn = max((p.vx * p.vx + p.vy * p.vy).squareRoot(), 1)
            let ux = p.vx / vn, uy = p.vy / vn
            let cola = CGPoint(x: CGFloat(p.x - ux * p.largo), y: CGFloat(p.y - uy * p.largo))
            let medio = CGPoint(x: CGFloat(p.x - ux * p.largo * 0.45), y: CGFloat(p.y - uy * p.largo * 0.45))
            let cabeza = CGPoint(x: CGFloat(p.x), y: CGFloat(p.y))
            colas[k][b].move(to: cola); colas[k][b].addLine(to: medio)
            cabezas[k][b].move(to: medio); cabezas[k][b].addLine(to: cabeza)
            hay = true
        }
        guard hay else { return }
        let col = color(0)
        let anchos: [CGFloat] = [0.6, 1.1, 1.8]
        for k in 0..<3 {
            for b in 0..<4 {
                let a = Double(b + 1) / 4 * 0.72
                if !colas[k][b].isEmpty {
                    c.stroke(colas[k][b], with: .color(col.opacity(a * 0.4)), style: StrokeStyle(lineWidth: anchos[k], lineCap: .round))
                    c.stroke(cabezas[k][b], with: .color(col.opacity(a)), style: StrokeStyle(lineWidth: anchos[k], lineCap: .round))
                }
            }
        }
    }

    private func puntos(_ c: inout GraphicsContext, delante: Bool) {
        
        var rellenos: [Int: Path] = [:]
        var trazos: [Int: Path] = [:]
        var brillos: [Int: Path] = [:]
        
        var luces: [(x: CGFloat, y: CGFloat, halo: Double, radio: CGFloat, cruz: Double, lado: CGFloat)] = []
        let tiempo = Float(t)
        let niveles = Mundo.niveles
        func clave(_ color: Int, _ b: Int) -> Int { color * 128 + b }
        func cubeta(_ a: Float) -> Int { a.isFinite ? min(max(Int((a * Float(niveles)).rounded()), 0), niveles) : 0 }
        func opacidad(_ k: Int) -> Double { Double(k % 128) / Double(niveles) }
        func tono(_ k: Int) -> UInt8 { UInt8(k / 128) }
        for p in ps where p.delante == delante {
            switch p.tipo {
            case .salpicadura:
                let a = p.alfa * (1 - p.edad / p.vida)
                let r = CGFloat(p.tam)
                rellenos[clave(Int(p.color), cubeta(a)), default: Path()]
                    .addEllipse(in: CGRect(x: CGFloat(p.x) - r, y: CGFloat(p.y) - r, width: r * 2, height: r * 2))
            case .rocio:
                let a = p.alfa * (1 - p.edad / p.vida)
                let w = CGFloat(p.tam) * CGFloat(0.6 + 0.4 * p.edad / p.vida)
                rellenos[clave(0, cubeta(a)), default: Path()]
                    .addEllipse(in: CGRect(x: CGFloat(p.x) - w, y: CGFloat(p.y) - 0.7, width: w * 2, height: 1.4))
            case .copo:
                let r = CGFloat(p.tam) * 0.5
                rellenos[clave(0, cubeta(p.alfa)), default: Path()]
                    .addEllipse(in: CGRect(x: CGFloat(p.x) - r, y: CGFloat(p.y) - r, width: r * 2, height: r * 2))
            case .granizo:
                let r = CGFloat(p.tam) * 0.5
                let alto = r * (p.rebotes == 0 ? 2.6 : 1.2)
                rellenos[clave(0, cubeta(p.alfa)), default: Path()]
                    .addEllipse(in: CGRect(x: CGFloat(p.x) - r, y: CGFloat(p.y) - alto, width: r * 2, height: alto * 2))
            case .estrella:

                let brillo: Float = p.forma == 1 ? 1 : centelleo(p, tiempo)
                let a = min(1, p.alfa * brillo)
                if a < 0.02 { continue }
                let r = CGFloat(p.tam), x = CGFloat(p.x), y = CGFloat(p.y)
                rellenos[clave(Int(p.color), cubeta(a)), default: Path()]
                    .addEllipse(in: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2))
                
                guard p.forma == 0, p.tam > 0.8 else { continue }
                let b = CGFloat(brillo)
                let cruz = p.tam > 1.25 ? Double(a * brillo * brillo) : 0
                luces.append((x, y, Double(0.85 * a * brillo), r * (4 + 4.5 * b), cruz, r * (5 + 10 * b * b)))
            case .purpurina:
                let destello = pow(abs(cos(p.giro)), 6)
                let a = p.alfa * (0.3 + 0.7 * destello)
                let r = CGFloat(p.tam)
                var rombo = rellenos[clave(Int(p.color), cubeta(a)), default: Path()]
                let x = CGFloat(p.x), y = CGFloat(p.y)
                rombo.move(to: CGPoint(x: x, y: y - r)); rombo.addLine(to: CGPoint(x: x + r * 0.7, y: y))
                rombo.addLine(to: CGPoint(x: x, y: y + r)); rombo.addLine(to: CGPoint(x: x - r * 0.7, y: y))
                rombo.closeSubpath()
                rellenos[clave(Int(p.color), cubeta(a))] = rombo
                if destello > 0.85 {
                    var cruz = brillos[clave(2, cubeta(a * 0.6)), default: Path()]
                    let l = r * 3.5
                    cruz.move(to: CGPoint(x: x - l, y: y)); cruz.addLine(to: CGPoint(x: x + l, y: y))
                    cruz.move(to: CGPoint(x: x, y: y - l)); cruz.addLine(to: CGPoint(x: x, y: y + l))
                    brillos[clave(2, cubeta(a * 0.6))] = cruz
                }
            case .chispa:
                let vida = p.edad / p.vida
                let a = (1 - vida) * (1 - vida) * (vida > 0.75 ? 0.6 + 0.4 * sin(tiempo * 40 + p.x) : 1)
                let largo: Float = p.largo > 0 ? 0.04 : 0.025
                var raya = trazos[clave(Int(p.color), cubeta(a)), default: Path()]
                raya.move(to: CGPoint(x: CGFloat(p.x - p.vx * largo), y: CGFloat(p.y - p.vy * largo)))
                raya.addLine(to: CGPoint(x: CGFloat(p.x), y: CGFloat(p.y)))
                trazos[clave(Int(p.color), cubeta(a))] = raya
            case .brasa:
                let vida = p.edad / p.vida
                let tono = vida < 0.3 ? 0 : (vida < 0.65 ? 1 : 2)
                let r = CGFloat(p.tam)
                rellenos[clave(tono, cubeta(p.alfa)), default: Path()]
                    .addEllipse(in: CGRect(x: CGFloat(p.x) - r, y: CGFloat(p.y) - r, width: r * 2, height: r * 2))
                let h = r * 3.2
                brillos[clave(tono, cubeta(p.alfa * 0.25)), default: Path()]
                    .addEllipse(in: CGRect(x: CGFloat(p.x) - h, y: CGFloat(p.y) - h, width: h * 2, height: h * 2))
            case .mota:
                let a = 0.5 + 0.5 * sin(tiempo * p.vfase + p.fase)
                let r = CGFloat(p.tam)
                rellenos[clave(0, cubeta(a * 0.8)), default: Path()]
                    .addEllipse(in: CGRect(x: CGFloat(p.x) - r, y: CGFloat(p.y) - r, width: r * 2, height: r * 2))
            default:
                break
            }
        }
        let suma = oscuro && (vida == .brasas || vida == .fuegos || vida == .purpurina || vida == .luciernagas
                              || vida == .estrellas || vida == .galaxia || vida == .aurora)
        if suma { c.blendMode = .plusLighter }

        if !luces.isEmpty, let halo = FormasDeVida.halo, let destello = FormasDeVida.destello {
            var l = c
            if oscuro { l.blendMode = .plusLighter }
            let imagenHalo = l.resolve(Image(uiImage: halo)), imagenDestello = l.resolve(Image(uiImage: destello))
            for e in luces {
                var g = l
                if e.halo > 0.02 {
                    g.opacity = e.halo
                    g.draw(imagenHalo, in: CGRect(x: e.x - e.radio, y: e.y - e.radio, width: e.radio * 2, height: e.radio * 2))
                }
                if e.cruz > 0.02 {
                    g.opacity = e.cruz
                    g.draw(imagenDestello, in: CGRect(x: e.x - e.lado, y: e.y - e.lado, width: e.lado * 2, height: e.lado * 2))
                }
            }
        }
        for (k, camino) in brillos {
            let col = color(tono(k))
            if vida == .brasas {
                c.fill(camino, with: .color(col.opacity(opacidad(k))))
            } else {
                c.stroke(camino, with: .color(col.opacity(opacidad(k))), lineWidth: 0.6)
            }
        }
        for (k, camino) in trazos {
            c.stroke(camino, with: .color(color(tono(k)).opacity(opacidad(k))),
                     style: StrokeStyle(lineWidth: 1.4, lineCap: .round))
        }

        if !oscuro && (vida == .nieve || vida == .granizo) {
            for (k, camino) in rellenos {
                c.stroke(camino, with: .color(Color.black.opacity(0.06 * opacidad(k))), lineWidth: 0.8)
            }
        }
        for (k, camino) in rellenos {
            c.fill(camino, with: .color(color(tono(k)).opacity(opacidad(k))))
        }
        c.blendMode = .normal
    }

    static let niveles = 64

    func centelleo(_ p: Particula, _ t: Float) -> Float {
        let onda = 0.5 + 0.5 * sin(t * p.vfase + p.fase)
        return (1 - p.amplitud) + p.amplitud * pow(onda, 1.6)
    }

    private func hoja(_ c: inout GraphicsContext, _ p: Particula) {
        var l = c
        l.translateBy(x: CGFloat(p.x), y: CGFloat(p.y))
        l.rotate(by: .radians(Double(p.giro)))
        let volteo = cos(p.volteo)
        let tumbada: CGFloat = p.estado == .libre ? 1 : 0.55
        l.scaleBy(x: CGFloat(max(abs(volteo), 0.1)) * (volteo < 0 ? -1 : 1), y: tumbada)
        let t = CGFloat(p.tam)
        let col = color(p.color)
        switch p.tipo {
        case .hoja:
            let forma = FormasDeVida.hoja(p.forma).applying(CGAffineTransform(scaleX: t, y: t))
            let oscuroCol = col.mix(with: .black, by: 0.28)
            l.fill(forma, with: .linearGradient(Gradient(colors: [col.mix(with: .white, by: 0.12), oscuroCol]),
                                                startPoint: CGPoint(x: -t * 0.4, y: -t * 0.4),
                                                endPoint: CGPoint(x: t * 0.4, y: t * 0.4)))
            l.stroke(FormasDeVida.venas(p.forma).applying(CGAffineTransform(scaleX: t, y: t)),
                     with: .color(oscuroCol.opacity(0.7)), lineWidth: 0.6)
            
            if volteo < 0 { l.fill(forma, with: .color(Color.white.opacity(0.1))) }
        case .petalo:
            let forma = FormasDeVida.petalo.applying(CGAffineTransform(scaleX: t, y: t))
            l.fill(forma, with: .linearGradient(Gradient(colors: [col.mix(with: .white, by: 0.45), col]),
                                                startPoint: CGPoint(x: 0, y: t * 0.5), endPoint: CGPoint(x: 0, y: -t * 0.5)))
        default:
            let w = t, h = t * (p.forma == 2 ? 0.28 : 0.45)
            let rect = CGRect(x: -w / 2, y: -h / 2, width: w, height: p.forma == 1 ? w : h)
            let forma = p.forma == 1 ? Path(ellipseIn: CGRect(x: -w * 0.32, y: -w * 0.32, width: w * 0.64, height: w * 0.64))
                                     : Path(roundedRect: rect, cornerRadius: 0.8)
            l.fill(forma, with: .color(col.mix(with: volteo < 0 ? .black : .white, by: 0.12)))
        }
    }

    private func moneda(_ c: inout GraphicsContext, _ p: Particula) {
        var l = c
        l.translateBy(x: CGFloat(p.x), y: CGFloat(p.y))
        l.rotate(by: .radians(Double(p.giro)))
        let r = CGFloat(p.tam)
        let angulo = p.volteo - Moneda.vista
        let ct = CGFloat(cos(angulo)), st = CGFloat(sin(angulo))
        let cara = abs(ct)
        let medio = r * cara
        
        let grueso = CGFloat(Moneda.grosor) * r * abs(st)
        let lado: CGFloat = ct * st >= 0 ? 1 : -1
        let yCara = -grueso * lado / 2, yAtras = grueso * lado / 2
        l.translateBy(x: 0, y: CGFloat(Moneda.alto(p)) - (max(yCara, yAtras) + medio))
        var canto = Path(ellipseIn: CGRect(x: -r, y: yAtras - medio, width: r * 2, height: medio * 2))
        canto.addRect(CGRect(x: -r, y: min(yCara, yAtras), width: r * 2, height: max(abs(yAtras - yCara), 0.6)))
        l.fill(canto, with: .color(color(1).mix(with: .black, by: 0.14)))
        guard cara > 0.06 else { return }
        var f = l
        f.translateBy(x: 0, y: yCara)
        f.scaleBy(x: 1, y: cara)
        let disco = Path(ellipseIn: CGRect(x: -r, y: -r, width: r * 2, height: r * 2))
        f.fill(disco, with: .radialGradient(Gradient(colors: [color(3), color(0), color(1), color(2)]),
                                            center: CGPoint(x: -r * 0.35, y: -r * 0.4), startRadius: 0, endRadius: r * 1.6))
        f.stroke(disco, with: .color(color(2)), lineWidth: 1.1)
        f.stroke(Path(ellipseIn: CGRect(x: -r * 0.7, y: -r * 0.7, width: r * 1.4, height: r * 1.4)),
                 with: .color(color(2).opacity(0.55)), lineWidth: 0.7)
        if ct >= 0 {
            let euro = f.resolve(Text("€").font(.system(size: r * 0.95, weight: .heavy, design: .rounded))
                .foregroundStyle(color(2).opacity(0.75)))
            f.draw(euro, at: .zero)
        } else {
            
            var estrellas = Path()
            let e = max(r * 0.07, 0.5)
            for k in 0..<12 {
                let a = Double(k) / 12 * 2 * .pi
                let q = CGPoint(x: cos(a) * r * 0.5, y: sin(a) * r * 0.5)
                estrellas.addEllipse(in: CGRect(x: q.x - e, y: q.y - e, width: e * 2, height: e * 2))
            }
            f.fill(estrellas, with: .color(color(2).opacity(0.8)))
        }
        
        let inclinacion = atan2(st, ct)
        let hacia = ct >= 0 ? inclinacion : (inclinacion > 0 ? inclinacion - .pi : inclinacion + .pi)
        let brillo = pow(max(0, cos(hacia - 0.45)), 14)
        if brillo > 0.02 {
            f.fill(disco, with: .linearGradient(Gradient(colors: [.clear, Color.white.opacity(0.7 * brillo), .clear]),
                                                startPoint: CGPoint(x: -r, y: -r), endPoint: CGPoint(x: r, y: r)))
        }
    }

    private func perla(_ c: inout GraphicsContext, _ p: Particula) {
        let a = Double(p.alfa)
        guard a > 0.02 else { return }
        let r = CGFloat(p.tam)
        let x = CGFloat(p.x), y = CGFloat(p.y)
        if p.vy > 0 && p.edad > p.fase {
            var rastro = Path()
            rastro.move(to: CGPoint(x: x, y: y - r))
            rastro.addLine(to: CGPoint(x: x - CGFloat(sin(p.edad * 3)) * 1.5, y: y - r - CGFloat(min(p.edad - p.fase, 2)) * 14))
            c.stroke(rastro, with: .color((oscuro ? Color.white : Color.black).opacity(0.07 * a)),
                     style: StrokeStyle(lineWidth: r * 0.9, lineCap: .round))
        }
        let cuerpo = CGRect(x: x - r, y: y - r * 1.05, width: r * 2, height: r * 2.1)
        c.fill(Path(ellipseIn: cuerpo), with: .color(Color.white.opacity((oscuro ? 0.14 : 0.3) * a)))
        var sombra = Path()
        sombra.addArc(center: CGPoint(x: x, y: y), radius: r * 0.92, startAngle: .degrees(20), endAngle: .degrees(160), clockwise: false)
        c.stroke(sombra, with: .color(Color.black.opacity((oscuro ? 0.32 : 0.26) * a)), lineWidth: max(0.5, r * 0.32))
        c.fill(Path(ellipseIn: CGRect(x: x - r * 0.45, y: y - r * 0.62, width: r * 0.5, height: r * 0.42)),
               with: .color(Color.white.opacity(0.85 * a)))
    }

    private func burbuja(_ c: inout GraphicsContext, _ p: Particula) {
        let r = CGFloat(p.tam)
        let rect = CGRect(x: CGFloat(p.x) - r, y: CGFloat(p.y) - r, width: r * 2, height: r * 2)
        let borde = color(0)
        c.fill(Path(ellipseIn: rect), with: .color(borde.opacity(0.06)))
        c.stroke(Path(ellipseIn: rect), with: .color(borde.opacity(0.5)), lineWidth: max(0.6, r * 0.12))
        var brillo = Path()
        brillo.addArc(center: CGPoint(x: rect.midX, y: rect.midY), radius: r * 0.68,
                      startAngle: .degrees(200), endAngle: .degrees(250), clockwise: false)
        c.stroke(brillo, with: .color(Color.white.opacity(0.85)), style: StrokeStyle(lineWidth: max(0.7, r * 0.16), lineCap: .round))
    }

    private func corazon(_ c: inout GraphicsContext, _ p: Particula) {
        var l = c
        l.translateBy(x: CGFloat(p.x), y: CGFloat(p.y))
        l.rotate(by: .radians(Double(p.giro)))
        let t = CGFloat(p.tam)
        let forma = FormasDeVida.corazon.applying(CGAffineTransform(scaleX: t, y: t))
        let a = Double(min(1, max(0, (p.y + 20) / 160)))
        let col = color(p.color)
        l.opacity = a
        l.fill(forma, with: .linearGradient(Gradient(colors: [col.mix(with: .white, by: 0.25), col]),
                                            startPoint: CGPoint(x: 0, y: -t * 0.5), endPoint: CGPoint(x: 0, y: t * 0.5)))
        l.fill(Path(ellipseIn: CGRect(x: -t * 0.3, y: -t * 0.3, width: t * 0.2, height: t * 0.13)),
               with: .color(Color.white.opacity(0.55)))
    }

    private func pompa(_ c: inout GraphicsContext, _ p: Particula) {
        let r = CGFloat(p.tam)
        let centro = CGPoint(x: CGFloat(p.x), y: CGFloat(p.y))
        let rect = CGRect(x: centro.x - r, y: centro.y - r, width: r * 2, height: r * 2)
        let tonos = (0..<4).map { color(UInt8($0)) }
        c.fill(Path(ellipseIn: rect), with: .radialGradient(Gradient(colors: [.clear, tonos[1].opacity(0.12), tonos[0].opacity(0.3)]),
                                                         center: centro, startRadius: 0, endRadius: r))
        c.stroke(Path(ellipseIn: rect), with: .conicGradient(Gradient(colors: tonos.map { $0.opacity(0.9) } + [tonos[0].opacity(0.9)]),
                                                           center: centro, angle: .radians(Double(p.giro))),
                 lineWidth: max(1.4, r * 0.09))
        var brillo = Path()
        brillo.addArc(center: centro, radius: r * 0.72, startAngle: .degrees(205), endAngle: .degrees(245), clockwise: false)
        c.stroke(brillo, with: .color(Color.white.opacity(0.9)), style: StrokeStyle(lineWidth: max(1, r * 0.09), lineCap: .round))
        c.fill(Path(ellipseIn: CGRect(x: centro.x + r * 0.3, y: centro.y + r * 0.3, width: r * 0.12, height: r * 0.12)),
               with: .color(Color.white.opacity(0.7)))
    }

    private func luciernaga(_ c: inout GraphicsContext, _ p: Particula) {
        let ciclo = (Float(t) + p.fase).truncatingRemainder(dividingBy: p.vfase)
        let encendida: Float = ciclo < 0.9 ? sin(ciclo / 0.9 * .pi) : 0
        let b = Double(0.1 + 0.9 * encendida)
        let centro = CGPoint(x: CGFloat(p.x), y: CGFloat(p.y))
        let r = CGFloat(18 * p.tam) * CGFloat(0.6 + 0.4 * encendida)
        var l = c
        l.blendMode = .plusLighter
        l.fill(Path(ellipseIn: CGRect(x: centro.x - r, y: centro.y - r, width: r * 2, height: r * 2)),
               with: .radialGradient(Gradient(colors: [color(p.color).opacity(0.6 * b), .clear]),
                                     center: centro, startRadius: 0, endRadius: r))
        l.fill(Path(ellipseIn: CGRect(x: centro.x - 2, y: centro.y - 2, width: 4, height: 4)),
               with: .color(color(1).opacity(0.3 + 0.7 * b)))
    }

    private func vilano(_ c: inout GraphicsContext, _ p: Particula) {
        var l = c
        l.translateBy(x: CGFloat(p.x), y: CGFloat(p.y))
        l.rotate(by: .radians(Double(p.giro)))
        l.scaleBy(x: CGFloat(p.tam), y: CGFloat(p.tam))
        let col = color(0)
        
        if !oscuro {
            l.fill(Path(ellipseIn: CGRect(x: -7.5, y: -7.5, width: 15, height: 15)),
                   with: .radialGradient(Gradient(colors: [Color.black.opacity(0.1), .clear]),
                                         center: .zero, startRadius: 0, endRadius: 8))
        }
        var tallo = Path()
        tallo.move(to: .zero); tallo.addLine(to: CGPoint(x: 0, y: 8))
        l.stroke(tallo, with: .color(color(1).opacity(0.9)), lineWidth: 0.7)
        l.fill(Path(ellipseIn: CGRect(x: -0.7, y: 7.4, width: 1.4, height: 2.8)), with: .color(color(1)))
        var hilos = Path()
        var puntas = Path()
        for i in 0..<15 {
            let a = (-165 + Double(i) * 150 / 14) * .pi / 180
            let q = CGPoint(x: cos(a) * 7.5, y: sin(a) * 7.5)
            hilos.move(to: .zero); hilos.addLine(to: q)
            puntas.addEllipse(in: CGRect(x: q.x - 0.5, y: q.y - 0.5, width: 1, height: 1))
        }
        l.stroke(hilos, with: .color(col.opacity(0.75)), lineWidth: 0.45)
        l.fill(puntas, with: .color(col.opacity(0.9)))
    }

    private func fugaz(_ c: inout GraphicsContext, _ p: Particula) {
        let vida = p.edad / p.vida
        let a = Double(vida < 0.2 ? vida / 0.2 : 1 - (vida - 0.2) / 0.8)
        let vn = max((p.vx * p.vx + p.vy * p.vy).squareRoot(), 1)
        let cola = CGPoint(x: CGFloat(p.x - p.vx / vn * p.largo), y: CGFloat(p.y - p.vy / vn * p.largo))
        let cabeza = CGPoint(x: CGFloat(p.x), y: CGFloat(p.y))
        var raya = Path()
        raya.move(to: cola); raya.addLine(to: cabeza)
        c.stroke(raya, with: .linearGradient(Gradient(colors: [.clear, Color.white.opacity(0.9 * a)]),
                                             startPoint: cola, endPoint: cabeza),
                 style: StrokeStyle(lineWidth: 1.4, lineCap: .round))
        c.fill(Path(ellipseIn: CGRect(x: cabeza.x - 1.3, y: cabeza.y - 1.3, width: 2.6, height: 2.6)),
               with: .color(Color.white.opacity(a)))
    }

    private func cohete(_ c: inout GraphicsContext, _ p: Particula) {
        let cabeza = CGPoint(x: CGFloat(p.x), y: CGFloat(p.y))
        let cola = CGPoint(x: CGFloat(p.x - p.vx * 0.03), y: CGFloat(p.y - p.vy * 0.03))
        var raya = Path()
        raya.move(to: cola); raya.addLine(to: cabeza)
        c.stroke(raya, with: .linearGradient(Gradient(colors: [.clear, color(p.color)]), startPoint: cola, endPoint: cabeza),
                 style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
        c.fill(Path(ellipseIn: CGRect(x: cabeza.x - 1.5, y: cabeza.y - 1.5, width: 3, height: 3)), with: .color(.white))
    }

    private func anillo(_ c: inout GraphicsContext, _ p: Particula) {
        let vida = Double(p.edad / p.vida)
        let centro = CGPoint(x: CGFloat(p.x), y: CGFloat(p.y))
        if p.forma == 2 {
            
            let r = CGFloat(p.tam) * CGFloat(0.6 + vida)
            var l = c
            l.blendMode = .plusLighter
            l.fill(Path(ellipseIn: CGRect(x: centro.x - r, y: centro.y - r, width: r * 2, height: r * 2)),
                   with: .radialGradient(Gradient(colors: [color(p.color).opacity(0.5 * (1 - vida)), .clear]),
                                         center: centro, startRadius: 0, endRadius: r))
            return
        }
        let r = CGFloat(p.tam) * CGFloat(1 + vida * (p.forma == 1 ? 0.5 : 0.35))
        c.stroke(Path(ellipseIn: CGRect(x: centro.x - r, y: centro.y - r, width: r * 2, height: r * 2)),
                 with: .color(color(0).opacity(0.7 * (1 - vida))), lineWidth: 1)
    }

    private func nube(_ c: inout GraphicsContext, _ p: Particula) {
        let niebla = p.tipo == .niebla
        let cual: FormasDeVida.Imagen = niebla ? .niebla : .nube(Int(p.forma))
        guard let img = FormasDeVida.imagen(cual) else { return }
        let escala = CGFloat(p.tam) * FormasDeVida.puntosPorPixel(cual)
        let ancho = img.size.width * escala, alto = img.size.height * escala
        var l = c
        l.translateBy(x: CGFloat(p.x), y: CGFloat(p.y))
        if niebla { l.rotate(by: .radians(Double(p.giro))) }
        var a = Double(p.alfa)
        if niebla { a *= Double(sin(min(max(p.edad / p.vida, 0), 1) * .pi)) }
        l.opacity = a
        if oscuro || niebla { l.addFilter(.colorMultiply(color(0))) }
        l.draw(Image(uiImage: img), in: CGRect(x: -ancho / 2, y: -alto / 2, width: ancho, height: alto))
    }
}

@MainActor
enum FormasDeVida {
    
    static func hoja(_ i: UInt8) -> Path { hojas[Int(i) % hojas.count] }
    static func venas(_ i: UInt8) -> Path { nervios[Int(i) % nervios.count] }

    private static let hojas: [Path] = [arce, roble, abedul, ginkgo]
    private static let nervios: [Path] = [nerviosArce, nerviosLargos, nerviosLargos, nerviosGinkgo]

    private static let arce: Path = {
        
        var p = Path()
        var pts: [CGPoint] = []
        func polar(_ a: Double, _ r: Double) -> CGPoint {
            CGPoint(x: cos(a * .pi / 180) * r, y: sin(a * .pi / 180) * r)
        }
        
        let orden: [(Double, Double)] = [(166, 0.36), (218, 0.47), (270, 0.5), (322, 0.47), (374, 0.36)]
        for (k, (a, r)) in orden.enumerated() {
            pts.append(polar(a - 14, r * 0.62))
            pts.append(polar(a - 6, r * 0.8))
            pts.append(polar(a, r))
            pts.append(polar(a + 6, r * 0.8))
            pts.append(polar(a + 14, r * 0.62))
            if k < orden.count - 1 {
                let siguiente = orden[k + 1].0
                pts.append(polar((a + siguiente) / 2, 0.2))
            }
        }
        pts.append(CGPoint(x: 0.04, y: 0.2))
        pts.append(CGPoint(x: -0.04, y: 0.2))
        p.move(to: pts[0])
        for q in pts.dropFirst() { p.addLine(to: q) }
        p.closeSubpath()
        
        p.addRect(CGRect(x: -0.018, y: 0.18, width: 0.036, height: 0.32))
        return p
    }()

    private static let nerviosArce: Path = {
        var p = Path()
        for (a, r) in [(-90.0, 0.42), (-38, 0.38), (218, 0.38), (14, 0.28), (166, 0.28)] {
            p.move(to: CGPoint(x: 0, y: 0.12))
            p.addLine(to: CGPoint(x: cos(a * .pi / 180) * r, y: sin(a * .pi / 180) * r))
        }
        return p
    }()

    private static let roble: Path = {
        var p = Path()
        let n = 64
        for i in 0...n {
            let a = Double(i) / Double(n) * 2 * .pi
            let lob = 1 + 0.16 * cos(a * 7)
            let q = CGPoint(x: sin(a) * 0.26 * lob, y: -cos(a) * 0.5 * (0.96 + 0.04 * lob))
            if i == 0 { p.move(to: q) } else { p.addLine(to: q) }
        }
        p.closeSubpath()
        p.addRect(CGRect(x: -0.016, y: 0.44, width: 0.032, height: 0.12))
        return p
    }()

    private static let abedul: Path = {
        var p = Path()
        p.move(to: CGPoint(x: 0, y: 0.46))
        p.addCurve(to: CGPoint(x: 0, y: -0.5), control1: CGPoint(x: 0.42, y: 0.3), control2: CGPoint(x: 0.3, y: -0.3))
        p.addCurve(to: CGPoint(x: 0, y: 0.46), control1: CGPoint(x: -0.3, y: -0.3), control2: CGPoint(x: -0.42, y: 0.3))
        p.closeSubpath()
        p.addRect(CGRect(x: -0.015, y: 0.44, width: 0.03, height: 0.1))
        return p
    }()

    private static let nerviosLargos: Path = {
        var p = Path()
        p.move(to: CGPoint(x: 0, y: 0.44)); p.addLine(to: CGPoint(x: 0, y: -0.44))
        for i in 0..<4 {
            let y = 0.28 - Double(i) * 0.18
            p.move(to: CGPoint(x: 0, y: y)); p.addLine(to: CGPoint(x: 0.16, y: y - 0.12))
            p.move(to: CGPoint(x: 0, y: y)); p.addLine(to: CGPoint(x: -0.16, y: y - 0.12))
        }
        return p
    }()

    private static let ginkgo: Path = {
        var p = Path()
        p.move(to: CGPoint(x: 0, y: 0.32))
        p.addLine(to: CGPoint(x: -0.46, y: -0.26))
        p.addQuadCurve(to: CGPoint(x: -0.04, y: -0.4), control: CGPoint(x: -0.26, y: -0.52))
        p.addLine(to: CGPoint(x: 0, y: -0.3))
        p.addLine(to: CGPoint(x: 0.04, y: -0.4))
        p.addQuadCurve(to: CGPoint(x: 0.46, y: -0.26), control: CGPoint(x: 0.26, y: -0.52))
        p.closeSubpath()
        p.addRect(CGRect(x: -0.016, y: 0.3, width: 0.032, height: 0.2))
        return p
    }()

    private static let nerviosGinkgo: Path = {
        var p = Path()
        for i in 0..<7 {
            let a = (-150 + Double(i) * 20) * .pi / 180
            p.move(to: CGPoint(x: 0, y: 0.3)); p.addLine(to: CGPoint(x: cos(a) * 0.55, y: 0.3 + sin(a) * 0.62))
        }
        return p
    }()

    static let petalo: Path = {
        var p = Path()
        p.move(to: CGPoint(x: 0, y: 0.5))
        p.addCurve(to: CGPoint(x: 0.22, y: -0.46), control1: CGPoint(x: 0.42, y: 0.18), control2: CGPoint(x: 0.4, y: -0.3))
        p.addLine(to: CGPoint(x: 0, y: -0.34))
        p.addLine(to: CGPoint(x: -0.22, y: -0.46))
        p.addCurve(to: CGPoint(x: 0, y: 0.5), control1: CGPoint(x: -0.4, y: -0.3), control2: CGPoint(x: -0.42, y: 0.18))
        p.closeSubpath()
        return p
    }()

    static let corazon: Path = {
        var p = Path()
        p.move(to: CGPoint(x: 0, y: 0.42))
        p.addCurve(to: CGPoint(x: -0.5, y: -0.12), control1: CGPoint(x: -0.2, y: 0.24), control2: CGPoint(x: -0.5, y: 0.08))
        p.addArc(center: CGPoint(x: -0.25, y: -0.16), radius: 0.25, startAngle: .degrees(170), endAngle: .degrees(350), clockwise: false)
        p.addArc(center: CGPoint(x: 0.25, y: -0.16), radius: 0.25, startAngle: .degrees(190), endAngle: .degrees(10), clockwise: false)
        p.addCurve(to: CGPoint(x: 0, y: 0.42), control1: CGPoint(x: 0.5, y: 0.08), control2: CGPoint(x: 0.2, y: 0.24))
        p.closeSubpath()
        return p
    }()

    static let halo: UIImage? = {
        let lado: CGFloat = 64
        let formato = UIGraphicsImageRendererFormat()
        formato.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: lado, height: lado), format: formato).image { ctx in
            let colores = [UIColor(white: 1, alpha: 0.62), UIColor(white: 1, alpha: 0.26),
                           UIColor(white: 1, alpha: 0.08), UIColor(white: 1, alpha: 0)].map(\.cgColor) as CFArray
            guard let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colores,
                                     locations: [0, 0.2, 0.5, 1]) else { return }
            let centro = CGPoint(x: lado / 2, y: lado / 2)
            ctx.cgContext.drawRadialGradient(g, startCenter: centro, startRadius: 0, endCenter: centro,
                                             endRadius: lado / 2, options: [])
        }
    }()

    static let destello: UIImage? = {
        let lado: CGFloat = 128, m = lado / 2, grueso: CGFloat = 1.5
        let formato = UIGraphicsImageRendererFormat()
        formato.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: lado, height: lado), format: formato).image { ctx in
            let c = ctx.cgContext
            let colores = [UIColor(white: 1, alpha: 0), UIColor(white: 1, alpha: 1), UIColor(white: 1, alpha: 0)]
                .map(\.cgColor) as CFArray
            guard let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colores,
                                     locations: [0, 0.5, 1]) else { return }
            for vertical in [false, true] {
                let rombo = CGMutablePath()
                if vertical {
                    rombo.move(to: CGPoint(x: m, y: 0)); rombo.addLine(to: CGPoint(x: m + grueso, y: m))
                    rombo.addLine(to: CGPoint(x: m, y: lado)); rombo.addLine(to: CGPoint(x: m - grueso, y: m))
                } else {
                    rombo.move(to: CGPoint(x: 0, y: m)); rombo.addLine(to: CGPoint(x: m, y: m - grueso))
                    rombo.addLine(to: CGPoint(x: lado, y: m)); rombo.addLine(to: CGPoint(x: m, y: m + grueso))
                }
                rombo.closeSubpath()
                c.saveGState()
                c.addPath(rombo)
                c.clip()
                c.drawLinearGradient(g, start: vertical ? CGPoint(x: m, y: 0) : CGPoint(x: 0, y: m),
                                     end: vertical ? CGPoint(x: m, y: lado) : CGPoint(x: lado, y: m), options: [])
                c.restoreGState()
            }
        }
    }()

    enum Imagen: Hashable { case nube(Int), niebla }
    private static var imagenes: [Imagen: UIImage] = [:]

    static func puntosPorPixel(_ cual: Imagen) -> CGFloat {
        if case .nube = cual { return 250.0 / 260 }
        return 1
    }

    static func imagen(_ cual: Imagen) -> UIImage? {
        if let i = imagenes[cual] { return i }
        var circulos: [(x: CGFloat, y: CGFloat, r: CGFloat)] = []
        let sigma: CGFloat
        
        var base: CGFloat?
        switch cual {
        case .nube(let k):
            
            var azar = AzarDeVida(s: UInt64(k) &* 7919 &+ 17)
            sigma = 8
            base = 0
            let largo: CGFloat = 200
            for i in 0..<7 {
                let x = CGFloat(i) * largo / 6 + CGFloat(azar.entre(-6, 6))
                let r = CGFloat(azar.entre(17, 26))
                circulos.append((x, -r * 0.55, r))
            }
            let m = 3 + Int(azar.uno() * 2)
            for j in 0..<m {
                let t = (CGFloat(j) + 0.5) / CGFloat(m)
                let x = largo * (0.18 + 0.64 * t) + CGFloat(azar.entre(-10, 10))
                let alto = sin(t * .pi)
                let r = CGFloat(azar.entre(26, 36)) + 14 * alto
                circulos.append((x, -r * 0.55 - 16 - 22 * alto + CGFloat(azar.entre(-4, 4)), r))
            }
        case .niebla:
            
            var azar = AzarDeVida(s: 4242)
            sigma = 18
            for i in 0..<12 {
                let afina = 0.62 + 0.38 * sin((CGFloat(i) + 0.5) / 12 * .pi)
                circulos.append((CGFloat(i) * 33 + CGFloat(azar.entre(-10, 10)), CGFloat(azar.entre(-14, 14)),
                                 CGFloat(azar.entre(32, 52)) * afina))
            }
        }
        let margen = 3 * sigma + 3
        let minX = circulos.map { $0.x - $0.r }.min() ?? 0, maxX = circulos.map { $0.x + $0.r }.max() ?? 1
        let minY = circulos.map { $0.y - $0.r }.min() ?? 0
        let maxY = base.map { $0 + 8 } ?? (circulos.map { $0.y + $0.r }.max() ?? 1)
        let tam = CGSize(width: (maxX - minX + 2 * margen).rounded(.up), height: (maxY - minY + 2 * margen).rounded(.up))
        let ox = margen - minX, oy = margen - minY
        let formato = UIGraphicsImageRendererFormat()
        formato.scale = 1
        let pintada = UIGraphicsImageRenderer(size: tam, format: formato).image { ctx in
            let c = ctx.cgContext
            UIColor.white.setFill()
            for (x, y, r) in circulos {
                c.fillEllipse(in: CGRect(x: x + ox - r, y: y + oy - r, width: r * 2, height: r * 2))
            }
            guard let base, let espacio = CGColorSpace(name: CGColorSpace.sRGB) else { return }
            let yb = base + oy, arriba = minY + oy
            
            if let g = CGGradient(colorsSpace: espacio, colors: [UIColor.white.cgColor, UIColor.white.withAlphaComponent(0).cgColor] as CFArray,
                                  locations: [0, 1]) {
                c.setBlendMode(.destinationIn)
                c.drawLinearGradient(g, start: CGPoint(x: 0, y: yb - 12), end: CGPoint(x: 0, y: yb + 4),
                                     options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
            }
            
            if let g = CGGradient(colorsSpace: espacio,
                                  colors: [UIColor.black.withAlphaComponent(0).cgColor,
                                           UIColor.black.withAlphaComponent(0.035).cgColor,
                                           UIColor.black.withAlphaComponent(0.105).cgColor] as CFArray,
                                  locations: [0, 0.5, 1]) {
                c.setBlendMode(.sourceAtop)
                c.drawLinearGradient(g, start: CGPoint(x: 0, y: arriba), end: CGPoint(x: 0, y: yb),
                                     options: [.drawsAfterEndLocation])
            }
        }
        guard let cg = pintada.cgImage else { return nil }
        let marco = CGRect(origin: .zero, size: tam)
        let ci = CIImage(cgImage: cg).applyingGaussianBlur(sigma: sigma).cropped(to: marco)
        guard let hecha = CIContext(options: [.cacheIntermediates: false]).createCGImage(ci, from: marco) else { return nil }
        let img = UIImage(cgImage: hecha)
        imagenes[cual] = img
        return img
    }
}
