import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

enum FormaDeChoque: Equatable, Sendable {
    
    case caja(radio: CGFloat)
    case capsula
    case circulo
    
    case texto(arriba: CGFloat, abajo: CGFloat)
    
    case linea([CGPoint])
}

enum CapaDeChoque: Sendable {
    case app, panel, muestra
}

@MainActor
@Observable
final class Golpe {
    private(set) var veces = 0
    @ObservationIgnored private(set) var fuerza: CGFloat = 0

    func dar(_ f: CGFloat) {
        fuerza = f
        veces &+= 1
    }
}

@MainActor
final class Choques {
    static let compartido = Choques()

    struct Cuerpo {
        var marco: CGRect
        var forma: FormaDeChoque
        var capa: CapaDeChoque
        var golpe: Golpe?
    }

    private(set) var cuerpos: [UUID: Cuerpo] = [:]
    func poner(_ id: UUID, _ c: Cuerpo) { cuerpos[id] = c }
    func quitar(_ id: UUID) { cuerpos[id] = nil }

    private(set) var hojas: [UUID: CGRect] = [:]
    private(set) var altoDeVentana: CGFloat = 900

    func ponerHoja(_ id: UUID, _ marco: CGRect, alto: CGFloat) {
        hojas[id] = marco
        altoDeVentana = alto
    }

    func quitarHoja(_ id: UUID) { hojas[id] = nil }
}

private struct SondaDeHoja: UIViewRepresentable {
    
    let activa: Bool

    func makeUIView(context: Context) -> Sonda { Sonda() }
    func updateUIView(_ vista: Sonda, context: Context) { vista.activa = activa }

    final class Sonda: UIView {
        private let id = UUID()
        private var enlace: CADisplayLink?
        var activa = false {
            didSet { if activa != oldValue { empezar() } }
        }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            empezar()
        }

        private func empezar() {
            enlace?.invalidate()
            enlace = nil
            if window != nil, activa {
                isUserInteractionEnabled = false
                let e = CADisplayLink(target: self, selector: #selector(medir))
                e.preferredFrameRateRange = CAFrameRateRange(minimum: 15, maximum: 60, preferred: 30)
                e.add(to: .main, forMode: .common)
                enlace = e
                medir()
            } else {
                Choques.compartido.quitarHoja(id)
            }
        }

        @objc private func medir() {
            guard let w = window else { return }
            Choques.compartido.ponerHoja(id, convert(bounds, to: w), alto: w.bounds.height)
        }
    }
}

extension View {

    @ViewBuilder
    func hojaQueChoca() -> some View {
        if Compilacion.beta {
            modifier(SondaDeLaHoja())
        } else {
            self
        }
    }
}

private struct SondaDeLaHoja: ViewModifier {
    @Environment(\.tema) private var tema

    func body(content: Content) -> some View {
        content.background {
            SondaDeHoja(activa: tema.vida != nil)
                .ignoresSafeArea()
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }
}

private struct ClaveCapaDeChoque: EnvironmentKey {
    static let defaultValue = CapaDeChoque.app
}

extension EnvironmentValues {
    
    var capaDeChoque: CapaDeChoque {
        get { self[ClaveCapaDeChoque.self] }
        set { self[ClaveCapaDeChoque.self] = newValue }
    }
}

@MainActor
private final class UltimoMarco {
    var marco: CGRect = .zero
}

private struct Chocable: ViewModifier {
    let forma: FormaDeChoque
    let reacciona: Bool
    @Environment(\.tema) private var tema
    @Environment(\.capaDeChoque) private var capa
    @Environment(\.accessibilityReduceMotion) private var menosMovimiento
    @State private var id = UUID()
    @State private var golpe = Golpe()
    @State private var ultimo = UltimoMarco()

    func body(content: Content) -> some View {
        let vivo = tema.vida != nil
        let forma = forma, capa = capa, id = id, golpe = reacciona ? golpe : nil, ultimo = ultimo
        content
            .onGeometryChange(for: CGRect.self) { p in vivo ? p.frame(in: .global) : .zero } action: { r in
                ultimo.marco = r
                if r == .zero || r.width < 1 {
                    Choques.compartido.quitar(id)
                } else {
                    Choques.compartido.poner(id, .init(marco: r, forma: forma, capa: capa, golpe: golpe))
                }
            }
            .modifier(Sacudida(golpe: golpe ?? self.golpe, activa: reacciona && vivo && !menosMovimiento))
            .onAppear {
                if ultimo.marco.width >= 1 {
                    Choques.compartido.poner(id, .init(marco: ultimo.marco, forma: forma, capa: capa, golpe: golpe))
                }
            }
            .onDisappear { Choques.compartido.quitar(id) }
            .onChange(of: forma) { _, nueva in
                if ultimo.marco.width >= 1 {
                    Choques.compartido.poner(id, .init(marco: ultimo.marco, forma: nueva, capa: capa, golpe: golpe))
                }
            }
    }
}

private struct Sacudida: ViewModifier {
    let golpe: Golpe
    let activa: Bool

    func body(content: Content) -> some View {
        content.keyframeAnimator(initialValue: CGFloat(0), trigger: golpe.veces) { vista, dy in
            vista.offset(y: activa ? dy : 0)
        } keyframes: { _ in
            KeyframeTrack {
                SpringKeyframe(golpe.fuerza, duration: 0.07, spring: .snappy)
                SpringKeyframe(0, duration: 0.7, spring: Spring(response: 0.42, dampingRatio: 0.42))
            }
        }
    }
}

extension View {

    @ViewBuilder
    func chocable(_ forma: FormaDeChoque = .caja(radio: 0), reacciona: Bool = false) -> some View {
        if Compilacion.beta {
            modifier(Chocable(forma: forma, reacciona: reacciona))
        } else {
            self
        }
    }

    @ViewBuilder
    func chocableComoTexto(tamano: CGFloat, reacciona: Bool = true) -> some View {
        if Compilacion.beta {
            modifier(Chocable(forma: formaDeTexto(tamano), reacciona: reacciona))
        } else {
            self
        }
    }
}

private func formaDeTexto(_ tamano: CGFloat) -> FormaDeChoque {
    let f = UIFont.systemFont(ofSize: tamano, weight: .bold)

    let arriba = max(f.ascender - f.capHeight, 0) + max(f.lineHeight - (f.ascender - f.descender), 0) / 2
    let abajo = max(-f.descender, 0) + max(f.lineHeight - (f.ascender - f.descender), 0) / 2
    return .texto(arriba: arriba, abajo: abajo)
}

struct Solido {
    let id: UUID?
    let minX: Float, minY: Float, maxX: Float, maxY: Float
    let radio: Float
    let linea: [SIMD2<Float>]?
    let golpe: Golpe?
    
    let hoja: Bool
    
    var superficie = false

    var ancho: Float { maxX - minX }

    @inline(__always)
    func techo(_ x: Float) -> Float? {
        if let l = linea {
            guard let a = l.first, let b = l.last, x >= a.x, x <= b.x else { return nil }
            var i = 1
            while i < l.count - 1 && l[i].x < x { i += 1 }
            let p = l[i - 1], q = l[i]
            let t = q.x - p.x > 0.001 ? (x - p.x) / (q.x - p.x) : 0
            return p.y + (q.y - p.y) * t
        }
        guard x >= minX, x <= maxX else { return nil }
        let r = min(radio, ancho / 2, (maxY - minY) / 2)
        if r > 0.5 {
            if x < minX + r {
                let d = minX + r - x
                return minY + r - (max(r * r - d * d, 0)).squareRoot()
            }
            if x > maxX - r {
                let d = x - (maxX - r)
                return minY + r - (max(r * r - d * d, 0)).squareRoot()
            }
        }
        return minY
    }

    @inline(__always)
    func suelo(_ x: Float) -> Float? {
        if linea != nil || hoja { return nil }
        guard x >= minX, x <= maxX else { return nil }
        let r = min(radio, ancho / 2, (maxY - minY) / 2)
        if r > 0.5 {
            if x < minX + r {
                let d = minX + r - x
                return maxY - r + (max(r * r - d * d, 0)).squareRoot()
            }
            if x > maxX - r {
                let d = x - (maxX - r)
                return maxY - r + (max(r * r - d * d, 0)).squareRoot()
            }
        }
        return maxY
    }

    func pendiente(_ x: Float) -> Float {
        guard let a = techo(x - 1), let b = techo(x + 1) else { return 0 }
        return (b - a) / 2
    }
}

enum Moneda {
    
    static let gravedad: Float = 1100
    static let maxima: Float = 560
    
    static let grosor: Float = 0.2
    
    static let giroMaximo: Float = 26

    static let vista: Float = 0.3
    
    static let rebote: Float = 0.5

    static let centro: Float = 0.45
    
    static let roce: Float = 0.2
    
    static let giroPlano: Float = 14

    static let arriba: Float = -0.3
    
    static let dentro: Float = 1.5

    static let botes: UInt8 = 2
    static let nuevaAltura: Float = 12
    
    static let sinBajar: Float = 0.8
    
    static let engancha: Float = 0.2

    static func alto(_ p: Particula) -> Float { alto(p.tam, p.volteo) }

    static func alto(_ tam: Float, _ volteo: Float) -> Float {
        tam * abs(cos(volteo)) + grosor * tam * 0.5 * abs(sin(volteo))
    }

    @inline(__always)
    static func soporte(_ tam: Float, _ volteo: Float, _ giro: Float,
                        _ nx: Float, _ ny: Float) -> (alcance: Float, cx: Float, cy: Float) {
        let a = tam, b = alto(tam, volteo)
        let ux = cos(giro), uy = sin(giro)
        let wu = -(ux * nx + uy * ny), wv = -(ux * ny - uy * nx)
        let alcance = (a * a * wu * wu + b * b * wv * wv).squareRoot()
        guard alcance > 0.0001 else { return (0, 0, 0) }
        let cu = a * a * wu / alcance, cv = b * b * wv / alcance
        return (alcance, cu * ux - cv * uy, cu * uy + cv * ux)
    }
}

struct Particula {
    enum Tipo: UInt8 {
        case gota, salpicadura, rocio, hoja, petalo, confeti, copo, granizo, moneda, chispa, burbuja,
             corazon, pompa, brasa, luciernaga, vilano, estrella, fugaz, purpurina, cohete, anillo,
             nube, niebla, mota, mancha, perla
    }
    enum Estado: UInt8 {
        case libre, posada, resbala, debajo, muerta
    }

    var tipo: Tipo
    var x: Float = 0, y: Float = 0
    var vx: Float = 0, vy: Float = 0
    var giro: Float = 0, vgiro: Float = 0
    var fase: Float = 0, vfase: Float = 0
    var volteo: Float = 0, vvolteo: Float = 0
    var tam: Float = 1
    var largo: Float = 0
    var edad: Float = 0
    var vida: Float = .infinity
    var alfa: Float = 1
    var color: UInt8 = 0
    var forma: UInt8 = 0
    
    var capa: UInt8 = 0
    var estado: Estado = .libre
    var delante = false
    var choca = false
    var rebotes: UInt8 = 0
    
    var sobre: UUID?
    var dx: Float = 0
    
    var dy: Float = 0
    var espera: Float = 0
    var amplitud: Float = 0
}

struct AzarDeVida {
    var s: UInt64

    mutating func siguiente() -> UInt64 {
        s &+= 0x9E37_79B9_7F4A_7C15
        var z = s
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    mutating func uno() -> Float { Float(siguiente() >> 40) / Float(1 << 24) }
    mutating func entre(_ a: Float, _ b: Float) -> Float { a + (b - a) * uno() }
    mutating func signo() -> Float { uno() < 0.5 ? -1 : 1 }
    mutating func de(_ n: Int) -> Int { Int(siguiente() % UInt64(max(n, 1))) }
}

@MainActor
final class Mundo {
    let vida: Tema.Vida
    let oscuro: Bool
    let capa: CapaDeChoque
    
    let colores: [Color]
    
    let calidad: Float
    
    let quieto: Bool
    
    let tenue: Bool

    var tamano: CGSize = .zero
    var origen: CGPoint = .zero
    
    private(set) var tapado = false

    private(set) var ps: [Particula] = []
    private(set) var solidos: [Solido] = []
    private var indice: [UUID: Int] = [:]
    var azar: AzarDeVida
    
    private(set) var t: Double = 0
    private var ultimo: Double?
    private var nacer: [Double] = Array(repeating: 0, count: 8)
    private var preparado = false

    var rayo: Rayo?
    
    private(set) var destello: Float = 0
    private var proximoRayo: Double = 6
    private var parpadeo: (t: Double, x: Float)?
    private var proximoParpadeo: Double = 3

    struct Rayo {
        var puntos: [SIMD2<Float>]
        var ramas: [[SIMD2<Float>]]
        var nacio: Double
        var destino: UUID?
    }

    init(vida: Tema.Vida, colores: [Tono], oscuro: Bool, capa: CapaDeChoque, quieto: Bool, tenue: Bool,
         ahorro: Bool, semilla: UInt64 = 0x5EED) {
        self.vida = vida
        self.oscuro = oscuro
        self.capa = capa
        self.colores = colores.map { Color(rgbDeVida: oscuro ? $0.oscuro : $0.claro) }
        self.calidad = ahorro ? 0.5 : 1
        self.quieto = quieto
        self.tenue = tenue
        self.azar = AzarDeVida(s: semilla &+ vida.rawValue.unicodeScalars.reduce(UInt64(7)) { $0 &* 31 &+ UInt64($1.value) })
    }

    var fotogramas: Double {
        switch vida {
        case .estrellas, .galaxia, .nubes, .niebla, .aurora, .lava, .sol, .luciernagas: 30
        default: calidad < 1 ? 30 : 60
        }
    }

    var tieneAlgoQuieto: Bool {
        switch vida {
        case .estrellas, .galaxia, .nubes, .niebla, .aurora, .lava, .sol: true
        default: false
        }
    }

    func color(_ i: UInt8) -> Color {
        colores.isEmpty ? (oscuro ? .white : .black) : colores[Int(i) % colores.count]
    }

    func avanzar(hasta fecha: Date) {
        let ahora = fecha.timeIntervalSinceReferenceDate
        guard tamano.width > 1, tamano.height > 1 else { return }
        if !preparado {
            preparado = true
            empezar()
        }
        guard let antes = ultimo else { ultimo = ahora; return }
        guard ahora > antes else { return }
        ultimo = ahora
        if quieto { return }
        let dt = Float(min(ahora - antes, 1.0 / 20))
        leerSolidos()
        if tapado { return }
        paso(dt)
    }

    func reanudar() { ultimo = nil }

    func calentar(_ segundos: Double) {
        guard tamano.width > 1 else { return }
        if !preparado { preparado = true; empezar() }
        leerSolidos()
        var quedan = Float(segundos)
        while quedan > 0 {
            let dt = min(quedan, 1.0 / 30)
            paso(dt)
            quedan -= dt
        }
    }

    private func leerSolidos() {
        var lista: [Solido] = []
        indice.removeAll(keepingCapacity: true)
        let ox = Float(origen.x), oy = Float(origen.y)
        for (id, c) in Choques.compartido.cuerpos where c.capa == capa {
            let r = c.marco
            var minX = Float(r.minX) - ox, minY = Float(r.minY) - oy
            var maxX = Float(r.maxX) - ox, maxY = Float(r.maxY) - oy
            var radio: Float = 0
            var linea: [SIMD2<Float>]?
            switch c.forma {
            case .caja(let rr): radio = Float(rr)
            case .capsula: radio = Float(min(r.width, r.height) / 2)
            case .circulo: radio = Float(min(r.width, r.height) / 2)
            case .texto(let arriba, let abajo):
                minY += Float(arriba)
                maxY -= Float(abajo)
                if maxY <= minY { continue }
            case .linea(let puntos):
                guard puntos.count >= 2 else { continue }
                linea = puntos.sorted { $0.x < $1.x }
                    .map { SIMD2(Float($0.x + r.minX) - ox, Float($0.y + r.minY) - oy) }
                minX = linea!.first!.x; maxX = linea!.last!.x
            }
            
            if maxY < -40 || minY > Float(tamano.height) + 40 { continue }
            indice[id] = lista.count
            var s = Solido(id: id, minX: minX, minY: minY, maxX: maxX, maxY: maxY, radio: radio,
                           linea: linea, golpe: c.golpe, hoja: false)
            switch c.forma {
            case .caja, .capsula, .circulo: s.superficie = (maxX - minX) * (maxY - minY) > 500
            default: break
            }
            lista.append(s)
        }
        tapado = false
        if capa == .app {
            let alto = Choques.compartido.altoDeVentana
            for (id, m) in Choques.compartido.hojas {
                if m.minY < alto * 0.14 { tapado = true; continue }
                lista.append(Solido(id: id, minX: Float(m.minX) - ox, minY: Float(m.minY) - oy,
                                    maxX: Float(m.maxX) - ox, maxY: Float(m.maxY) - oy,
                                    radio: 38, linea: nil, golpe: nil, hoja: true))
            }
        }
        
        lista.sort { ($0.minY, $0.minX) < ($1.minY, $1.minX) }
        indice.removeAll(keepingCapacity: true)
        for (i, s) in lista.enumerated() { if let id = s.id { indice[id] = i } }
        solidos = lista
    }

    private func solido(_ id: UUID?) -> Solido? {
        guard let id, let i = indice[id] else { return nil }
        return solidos[i]
    }

    private func paso(_ dt: Float) {
        t += Double(dt)
        nacimientos(dt)
        tormentaYCielo(dt)
        let W = Float(tamano.width), H = Float(tamano.height)
        var i = 0
        while i < ps.count {
            mover(&ps[i], dt, W, H)
            i += 1
        }
        if !nuevas.isEmpty {
            ps.append(contentsOf: nuevas)
            nuevas.removeAll(keepingCapacity: true)
        }
        ps.removeAll { $0.estado == .muerta }
    }

    private var nuevas: [Particula] = []

    private func empezar() {
        let W = Float(tamano.width), H = Float(tamano.height)
        switch vida {
        case .estrellas, .aurora:
            sembrarEstrellas(cuantas: vida == .aurora ? 90 : 260, arriba: true, W, H)
            nacer[0] = Double(azar.entre(6, 18))
            nacer[1] = Double(azar.entre(40, 90))
        case .galaxia:
            sembrarEstrellas(cuantas: 190, arriba: false, W, H)
            nacer[0] = Double(azar.entre(10, 25))
        case .luciernagas:
            for _ in 0..<Int(16 * calidad + 0.5) {
                var p = Particula(tipo: .luciernaga)
                p.x = azar.entre(0, W); p.y = azar.entre(0.1 * H, 0.95 * H)
                p.giro = azar.entre(0, 2 * .pi)
                p.tam = azar.entre(0.8, 1.2)
                p.vfase = azar.entre(2.4, 5.2)
                p.fase = azar.entre(0, p.vfase)
                p.amplitud = azar.entre(9, 18)
                p.color = UInt8(azar.de(2))
                ps.append(p)
            }
        case .nubes:
            for k in 0..<6 {
                var p = Particula(tipo: .nube)
                p.x = azar.entre(-0.2 * W, 1.1 * W)
                p.y = azar.entre(0.02, 0.6) * H
                p.tam = azar.entre(0.55, 1.35)
                p.vx = (3 + 6 * p.tam) * (oscuro ? 0.7 : 1)
                p.alfa = oscuro ? azar.entre(0.22, 0.42) : azar.entre(0.55, 0.92)
                p.forma = UInt8(k % 3)
                ps.append(p)
            }
        case .niebla:
            for k in 0..<7 {
                var p = Particula(tipo: .niebla)
                p.x = azar.entre(-0.3 * W, 1.2 * W)
                p.y = azar.entre(0.05, 1.0) * H
                p.tam = azar.entre(0.8, 1.6)
                p.vx = -azar.entre(5, 13)
                p.vgiro = azar.signo() * azar.entre(0.004, 0.012)
                p.vida = azar.entre(45, 80)
                p.edad = azar.entre(0, p.vida)
                p.alfa = oscuro ? azar.entre(0.16, 0.3) : azar.entre(0.3, 0.55)
                p.forma = UInt8(k % 2)
                ps.append(p)
            }
        case .pompas:
            
            for _ in 0..<Int(6 * calidad + 0.5) {
                var p = Particula(tipo: .pompa)
                p.tam = azar.entre(14, 30)
                p.x = azar.entre(20, W - 20); p.y = azar.entre(0.15, 0.95) * H
                p.vy = -azar.entre(16, 30); p.vx = azar.entre(-10, 10)
                p.vfase = azar.entre(0.6, 1.2); p.fase = azar.entre(0, 6.3)
                p.giro = azar.entre(0, 6.3); p.vgiro = azar.entre(-0.4, 0.4)
                p.choca = true
                ps.append(p)
            }
        case .sol:
            for _ in 0..<Int(26 * calidad + 0.5) {
                var p = Particula(tipo: .mota)
                p.x = azar.entre(0, W); p.y = azar.entre(0, H)
                p.vx = azar.entre(-4, 4); p.vy = azar.entre(-3, 3)
                p.tam = azar.entre(0.6, 1.6)
                p.fase = azar.entre(0, 6.3); p.vfase = azar.entre(0.6, 1.8)
                ps.append(p)
            }
        case .lava:
            let n = calidad < 1 ? 5 : 8
            for k in 0..<n {
                var p = Particula(tipo: .mancha)
                p.tam = k < 3 ? azar.entre(34, 54) : azar.entre(18, 32)
                p.amplitud = azar.entre(0.3, 0.46)
                p.vfase = azar.entre(0.045, 0.1)
                p.fase = azar.entre(0, 6.3)
                p.dx = azar.entre(0.15, 0.85)
                p.color = UInt8(k % 2)
                ps.append(p)
            }
        default:
            break
        }
        
        switch vida {
        case .lluvia: calentar(1.5)
        case .tormenta: calentar(1.5)
        case .nieve: calentar(5)
        case .granizo: calentar(1)
        case .burbujas: calentar(7)
        case .brasas: calentar(3)
        case .purpurina: calentar(4)
        case .petalos, .confeti: calentar(3)
        case .hojas: calentar(2)
        case .corazones, .vilanos, .pompas: calentar(6)
        default: break
        }
    }

    private func sembrarEstrellas(cuantas: Int, arriba: Bool, _ W: Float, _ H: Float) {
        let n = Int(Float(cuantas) * (W * H) / (440 * 956))
        for _ in 0..<n {
            var p = Particula(tipo: .estrella)
            p.x = azar.entre(0, W)
            
            p.y = arriba ? pow(azar.uno(), 1.5) * 0.85 * H : azar.entre(0, H)
            let grande = azar.uno() < 0.08
            p.tam = grande ? azar.entre(1.5, 2.3) : azar.entre(0.55, 1.35)
            p.color = UInt8(azar.de(3))
            
            p.fase = azar.entre(0, 6.3)
            p.vfase = azar.entre(0.8, 2.0)
            p.amplitud = azar.entre(0.78, 0.95)
            p.alfa = arriba ? min(1, max(0, 1.15 - p.y / (0.9 * H))) * azar.entre(0.55, 1) : azar.entre(0.35, 1)
            ps.append(p)
        }
    }

    private func cada(_ k: Int, _ intervalo: () -> Float) -> Bool {
        if t >= nacer[k] {
            nacer[k] = t + Double(intervalo())
            return true
        }
        return false
    }

    private func cuantas(_ tasa: Float, _ dt: Float) -> Int {
        let esperadas = tasa * calidad * dt
        var n = Int(esperadas)
        if azar.uno() < esperadas - Float(n) { n += 1 }
        return n
    }

    private func nacimientos(_ dt: Float) {
        let W = Float(tamano.width), H = Float(tamano.height)
        let k = W / 640   
        switch vida {
        case .lluvia:
            lluvia(dt, W, H, k, fuerte: false)
            perlas(dt, tasa: 1.6)
        case .tormenta:
            lluvia(dt, W, H, k, fuerte: true)
            perlas(dt, tasa: 2.6)
        case .nieve:
            for (tasa, capa) in [(52, UInt8(0)), (10, 1), (3, 2), (2, 2)] as [(Float, UInt8)] {
                for _ in 0..<cuantas(tasa, dt) {
                    var p = Particula(tipo: .copo)
                    p.x = azar.entre(-20, W + 20); p.y = -6
                    p.capa = capa
                    p.tam = capa == 0 ? azar.entre(0.5, 1.5) : (capa == 1 ? azar.entre(1.4, 2.6) : azar.entre(2.4, 4.4))
                    p.vy = azar.entre(60, 120) * (0.6 + 0.2 * Float(capa))
                    p.vx = azar.entre(-12, 12)
                    p.amplitud = azar.entre(6, 18)
                    p.vfase = azar.entre(0.6, 1.6); p.fase = azar.entre(0, 6.3)
                    p.alfa = capa == 0 ? azar.entre(0.35, 0.85) : azar.entre(0.6, 0.95)
                    p.choca = capa > 0 || azar.uno() < 0.15
                    ps.append(p)
                }
            }
        case .granizo:
            for (tasa, v, tam) in [(36, 464, 1.2), (44, 825, 1.8), (9, 1290, 2.6)] as [(Float, Float, Float)] {
                for _ in 0..<cuantas(tasa, dt) {
                    var p = Particula(tipo: .granizo)
                    p.x = azar.entre(-10, W + 10); p.y = -8
                    p.vy = v * azar.entre(0.85, 1.1); p.vx = p.vy * 0.04
                    p.tam = tam * azar.entre(0.8, 1.2)
                    p.choca = true
                    p.alfa = azar.entre(0.55, 0.95)
                    ps.append(p)
                }
            }
        case .hojas:
            if cada(0, { azar.entre(1.8, 4.6) / calidad }) && cuantasDe(.hoja) < 7 {
                ps.append(nuevaHoja(W, tipo: .hoja))
            }
        case .petalos:
            if cada(0, { azar.entre(0.45, 1.1) / calidad }) && cuantasDe(.petalo) < 16 {
                ps.append(nuevaHoja(W, tipo: .petalo))
            }
        case .confeti:
            if cada(0, { azar.entre(0.22, 0.5) / calidad }) && cuantasDe(.confeti) < 34 {
                ps.append(nuevaHoja(W, tipo: .confeti))
            }
        case .monedas:
            if cada(0, { azar.entre(1.6, 3.4) / calidad }) && cuantasDe(.moneda) < 6 {
                var p = Particula(tipo: .moneda)
                p.x = azar.entre(20, W - 20); p.y = -16
                p.tam = azar.entre(7, 10)
                p.vy = azar.entre(80, 160); p.vx = azar.entre(-20, 20)
                
                p.volteo = azar.entre(0, 6.3); p.vvolteo = azar.entre(6, 12) * azar.signo()
                p.giro = azar.entre(-0.5, 0.5); p.vgiro = azar.entre(-0.6, 0.6)
                p.choca = true
                
                p.delante = true
                p.dx = p.y
                ps.append(p)
            }
        case .burbujas:
            for _ in 0..<cuantas(3.2, dt) where cuantasDe(.burbuja) < 42 {
                var p = Particula(tipo: .burbuja)
                p.tam = pow(azar.uno(), 1.8) * 7 + 1.6
                p.x = azar.entre(0, W); p.y = H + p.tam + 4
                p.vy = -(12 + p.tam * 5.5)
                p.amplitud = azar.entre(2, 6); p.vfase = azar.entre(2, 4); p.fase = azar.entre(0, 6.3)
                p.vida = azar.entre(9, 20)
                p.choca = true
                ps.append(p)
            }
        case .corazones:
            if cada(0, { azar.entre(0.7, 1.4) / calidad }) && cuantasDe(.corazon) < 14 {
                var p = Particula(tipo: .corazon)
                p.tam = azar.entre(9, 18)
                p.x = azar.entre(10, W - 10); p.y = H + 20
                p.vy = -azar.entre(16, 30)
                p.amplitud = azar.entre(4, 12); p.vfase = azar.entre(1.2, 2.2); p.fase = azar.entre(0, 6.3)
                p.color = UInt8(azar.de(3))
                p.choca = true
                ps.append(p)
            }
        case .pompas:
            if cada(0, { azar.entre(0.6, 1.2) / calidad }) && cuantasDe(.pompa) < 12 {
                var p = Particula(tipo: .pompa)
                p.tam = azar.entre(14, 32)
                p.x = azar.entre(0, W); p.y = H + p.tam
                p.vy = -azar.entre(16, 30); p.vx = azar.entre(-10, 10)
                p.vfase = azar.entre(0.6, 1.2); p.fase = azar.entre(0, 6.3)
                p.giro = azar.entre(0, 6.3); p.vgiro = azar.entre(-0.4, 0.4)
                p.choca = true
                ps.append(p)
            }
        case .brasas:
            for _ in 0..<cuantas(13, dt) where cuantasDe(.brasa) < 80 {
                var p = Particula(tipo: .brasa)
                p.x = (azar.uno() + azar.uno()) * 0.5 * W
                p.y = H - azar.entre(-10, 60)
                p.vy = -azar.entre(60, 150)
                p.tam = azar.entre(1.2, 2.8)
                p.vida = azar.entre(2.8, 6)
                p.fase = azar.entre(0, 6.3); p.vfase = azar.entre(2, 5)
                p.amplitud = azar.entre(10, 30)
                p.choca = true
                ps.append(p)
            }
        case .vilanos:
            if cada(0, { azar.entre(1.2, 2.6) / calidad }) && cuantasDe(.vilano) < 9 {
                var p = Particula(tipo: .vilano)
                p.x = -20; p.y = azar.entre(0.08, 0.85) * H
                p.vx = azar.entre(18, 34)
                p.amplitud = azar.entre(5, 11); p.vfase = azar.entre(0.5, 1.1); p.fase = azar.entre(0, 6.3)
                p.giro = azar.entre(-0.3, 0.3); p.tam = azar.entre(1.1, 1.6)
                p.choca = true
                ps.append(p)
            }
        case .purpurina:
            for _ in 0..<cuantas(9, dt) where cuantasDe(.purpurina) < 110 {
                var p = Particula(tipo: .purpurina)
                p.x = azar.entre(-10, W + 10); p.y = -4
                p.vy = azar.entre(14, 32)
                p.tam = azar.entre(0.9, 2.2)
                p.giro = azar.entre(0, 6.3); p.vgiro = azar.entre(2, 6) * azar.signo()
                p.amplitud = azar.entre(4, 10); p.vfase = azar.entre(0.8, 1.6); p.fase = azar.entre(0, 6.3)
                p.color = UInt8(azar.de(3))
                p.choca = azar.uno() < 0.6
                ps.append(p)
            }
        case .fuegos:
            if cada(0, { azar.entre(2.2, 5.2) / max(calidad, 0.6) }) {
                var p = Particula(tipo: .cohete)
                p.x = azar.entre(0.15, 0.85) * W; p.y = H + 6
                p.vy = -azar.entre(520, 680); p.vx = azar.entre(-30, 30)
                p.espera = azar.entre(0.18, 0.45) * H   
                p.color = UInt8(azar.de(5))
                ps.append(p)
            }
        case .estrellas, .aurora, .galaxia:
            
            if cada(0, { azar.entre(14, 38) }) && !quieto {
                var p = Particula(tipo: .fugaz)
                p.x = azar.entre(0.15, 0.85) * W; p.y = azar.entre(0.03, 0.28) * H
                let a = azar.entre(0.25, 0.55) * .pi / 2 * (azar.uno() < 0.7 ? 1 : -1)
                let v = 687 * azar.entre(0.8, 1.2)
                p.vx = sin(a) * v * (azar.uno() < 0.5 ? 1 : -1); p.vy = cos(a) * v * 0.55
                p.vida = azar.entre(0.35, 0.6)
                p.largo = azar.entre(60, 100)
                ps.append(p)
            }
            if vida == .estrellas && cada(1, { azar.entre(50, 110) }) && !quieto {
                
                var p = Particula(tipo: .estrella)
                p.forma = 1
                p.y = azar.entre(0.05, 0.3) * H
                p.x = azar.uno() < 0.5 ? -4 : W + 4
                p.vx = (p.x < 0 ? 1 : -1) * azar.entre(14, 22)
                p.tam = 0.95; p.alfa = 0.8; p.color = 2
                p.vida = (W + 8) / abs(p.vx)
                ps.append(p)
            }
        default:
            break
        }
    }

    private func cuantasDe(_ tipo: Particula.Tipo) -> Int {
        var n = 0
        for p in ps where p.tipo == tipo { n += 1 }
        return n
    }

    private func nuevaHoja(_ W: Float, tipo: Particula.Tipo) -> Particula {
        var p = Particula(tipo: tipo)
        p.x = azar.entre(-10, W + 10); p.y = -30
        switch tipo {
        case .hoja:
            p.tam = azar.entre(19, 30)
            p.vy = azar.entre(26, 42)
            p.amplitud = azar.entre(16, 34)
            p.vfase = azar.entre(1.4, 2.4)
            p.vvolteo = azar.entre(0.6, 2.2) * azar.signo()
            p.largo = p.vy
            p.forma = UInt8(azar.de(4))
            p.color = UInt8(azar.de(5))
        case .petalo:
            p.tam = azar.entre(8, 13)
            p.vy = azar.entre(18, 30)
            p.amplitud = azar.entre(10, 22)
            p.vfase = azar.entre(2, 3.4)
            p.vvolteo = azar.entre(1.5, 3.5) * azar.signo()
            p.largo = p.vy
            p.color = UInt8(azar.de(4))
        default:
            p.tam = azar.entre(7, 12)
            p.vy = azar.entre(42, 72)
            p.amplitud = azar.entre(6, 16)
            p.vfase = azar.entre(2.5, 4)
            p.vvolteo = azar.entre(4, 9) * azar.signo()
            p.vgiro = azar.entre(-3, 3)
            p.largo = p.vy
            p.forma = UInt8(azar.de(3))
            p.color = UInt8(azar.de(5))
        }
        p.fase = azar.entre(0, 6.3)
        p.volteo = azar.entre(0, 6.3)
        p.giro = azar.entre(-0.5, 0.5)
        p.choca = true
        return p
    }

    private func perlas(_ dt: Float, tasa: Float) {
        let superficies = solidos.indices.filter { solidos[$0].superficie && solidos[$0].id != nil }
        guard !superficies.isEmpty else { return }
        for _ in 0..<cuantas(tasa, dt) where cuantasDe(.perla) < 34 {
            let s = solidos[superficies[azar.de(superficies.count)]]
            let alto = s.maxY - s.minY, ancho = s.maxX - s.minX
            guard alto > 8, ancho > 8 else { continue }
            var p = Particula(tipo: .perla)
            p.sobre = s.id
            p.dx = azar.entre(4, ancho - 4)
            p.espera = azar.entre(3, alto - 3)     
            p.x = s.minX + p.dx; p.y = s.minY + p.espera
            p.tam = pow(azar.uno(), 2) * 1.6 + 0.9
            p.vida = azar.entre(6, 14)
            p.alfa = 0
            
            p.vy = azar.uno() < 0.25 ? azar.entre(10, 26) : 0
            p.fase = azar.entre(0.8, 3)
            p.amplitud = azar.entre(-0.6, 0.6)
            p.delante = true
            ps.append(p)
        }
    }

    private func lluvia(_ dt: Float, _ W: Float, _ H: Float, _ k: Float, fuerte: Bool) {

        let capas: [(tasa: Float, v: Float, rv: Float, escala: Float, re: Float, alfa: Float, ancho: Float)] = fuerte
            ? [(520, 1000, 400, 0.25, 0.5, 0.16, 0.7), (130, 2000, 800, 1.2, 0.4, 0.2, 1.2), (24, 2400, 800, 1.8, 0.3, 0.12, 2)]
            : [(275, 1000, 400, 0.35, 0.4, 0.2184, 0.7), (94, 2000, 1000, 0.9, 0.5, 0.2997, 1.2), (18, 2400, 800, 1.8, 0.3, 0.1463, 2)]
        let inclinacion: Float = fuerte ? 0.2 : 0.02
        for (c, l) in capas.enumerated() {
            for _ in 0..<cuantas(l.tasa, dt) {
                var p = Particula(tipo: .gota)
                p.capa = UInt8(c)
                let v = (l.v + azar.entre(-l.rv, l.rv)) * k
                p.vy = v
                p.vx = v * inclinacion
                let escala = max(l.escala + azar.entre(-l.re, l.re), 0.08)
                p.largo = 50 * escala * k
                p.tam = l.ancho
                p.alfa = min(max(l.alfa + azar.entre(-0.5, 0.5), 0), 0.72)
                if p.alfa < 0.04 { continue }
                p.x = azar.entre(-0.25 * W * inclinacion - 10, W + 10)
                p.y = azar.entre(-30, -5)
                p.choca = c > 0
                ps.append(p)
            }
        }
    }

    private func mover(_ p: inout Particula, _ dt: Float, _ W: Float, _ H: Float) {
        p.edad += dt
        if p.edad >= p.vida { p.estado = .muerta; return }
        switch p.tipo {
        case .gota: moverGota(&p, dt, H)
        case .salpicadura, .chispa:
            p.vy += (p.tipo == .chispa ? 520 : 1375) * dt
            p.vx *= (1 - 1.2 * dt)
            let y0 = p.y
            p.x += p.vx * dt; p.y += p.vy * dt
            if p.tipo == .chispa && p.vy > 0, case let (s, sy)? = choqueArriba(p.x, y0, p.y, 0.5) {
                _ = s
                p.y = sy - 0.5; p.vy = -p.vy * 0.3; p.vx *= 0.6
            }
        case .rocio, .anillo:
            break
        case .hoja, .petalo, .confeti: moverHoja(&p, dt, H)
        case .copo: moverCopo(&p, dt, H)
        case .granizo: moverGranizo(&p, dt, H)
        case .moneda: moverMoneda(&p, dt, W, H)
        case .burbuja, .corazon: moverBurbuja(&p, dt, W)
        case .pompa: moverPompa(&p, dt, W, H)
        case .brasa: moverBrasa(&p, dt, W)
        case .luciernaga: moverLuciernaga(&p, dt, W, H)
        case .vilano: moverVilano(&p, dt, W, H)
        case .estrella:
            if p.forma == 1 { p.x += p.vx * dt }
        case .fugaz:
            p.x += p.vx * dt; p.y += p.vy * dt
        case .purpurina: moverPurpurina(&p, dt, H)
        case .cohete: moverCohete(&p, dt)
        case .nube:
            p.x += p.vx * dt
            if p.x > W + 220 * p.tam { p.x = -260 * p.tam; p.y = azar.entre(0.02, 0.6) * H }
        case .niebla:
            p.x += p.vx * dt; p.giro += p.vgiro * dt
            if p.x < -420 * p.tam { p.x = W + 380 * p.tam; p.y = azar.entre(0.05, 1) * H }
            if p.edad > p.vida - dt * 2 { p.edad = 0 }
        case .mota:
            p.vx += azar.entre(-6, 6) * dt; p.vy += azar.entre(-6, 6) * dt
            p.vx = min(max(p.vx, -6), 6); p.vy = min(max(p.vy, -5), 5)
            p.x += p.vx * dt; p.y += p.vy * dt
            if p.x < -5 { p.x = W + 5 } else if p.x > W + 5 { p.x = -5 }
            if p.y < -5 { p.y = H + 5 } else if p.y > H + 5 { p.y = -5 }
        case .mancha:
            break
        case .perla:
            guard let s = solido(p.sobre) else { p.estado = .muerta; return }
            
            p.alfa = min(1, p.edad / 0.15) * min(1, (p.vida - p.edad) / 1.5)
            if p.vy > 0 && p.edad > p.fase {
                
                p.espera += p.vy * dt * (0.6 + 0.4 * p.tam / 2.5)
                p.dx += sin(p.edad * 3 + p.amplitud * 5) * 6 * dt
                if p.espera > s.maxY - s.minY - 2 { p.estado = .muerta; return }
            }
            p.x = s.minX + p.dx; p.y = s.minY + p.espera
        }
    }

    private func moverGota(_ p: inout Particula, _ dt: Float, _ H: Float) {
        let y0 = p.y
        p.x += p.vx * dt; p.y += p.vy * dt
        if p.choca, case let (s, sy)? = choqueArriba(p.x, y0, p.y, 0) {
            salpicar(x: p.x, y: sy, fuerza: p.capa == 2 ? 1 : 0.7, sobre: s)
            p.estado = .muerta
            return
        }
        if p.y - p.largo > H { p.estado = .muerta }
    }

    private func salpicar(x: Float, y: Float, fuerza: Float, sobre s: Int) {
        let n = 2 + azar.de(2)
        for _ in 0..<n {
            var g = Particula(tipo: .salpicadura)
            let a = azar.entre(-1.05, 1.05)
            let v = azar.entre(90, 190) * fuerza
            g.x = x; g.y = y - 0.5
            g.vx = sin(a) * v; g.vy = -cos(a) * v
            g.tam = azar.entre(0.6, 1.3) * (0.7 + 0.3 * fuerza)
            g.vida = azar.entre(0.18, 0.32)
            g.alfa = azar.entre(0.55, 0.9)
            g.delante = true
            nuevas.append(g)
        }
        var r = Particula(tipo: .rocio)
        r.x = x; r.y = y
        r.tam = azar.entre(4, 8) * fuerza
        r.vida = 0.13
        r.alfa = 0.5
        r.delante = true
        nuevas.append(r)
    }

    private func moverHoja(_ p: inout Particula, _ dt: Float, _ H: Float) {
        switch p.estado {
        case .libre:
            p.fase += p.vfase * dt
            p.volteo += p.vvolteo * dt
            let vaiven = cos(p.fase)
            let objetivoX = p.amplitud * p.vfase * vaiven * 0.55
            p.vx += (objetivoX - p.vx) * min(1, 3 * dt)
            let objetivoY = p.largo * (0.45 + 0.95 * abs(vaiven))
            p.vy += (objetivoY - p.vy) * min(1, 2.5 * dt)
            if p.tipo == .confeti {
                p.giro += p.vgiro * dt
            } else {
                p.giro += (0.55 * sin(p.fase) - p.giro) * min(1, 2 * dt)
            }
            let y0 = p.y
            p.x += p.vx * dt; p.y += p.vy * dt
            if p.choca, case let (s, sy)? = choqueArriba(p.x, y0, p.y, apoyo(p)) {
                posar(&p, en: s, y: sy)
            }
            if p.y - p.tam > H + 10 { p.estado = .muerta }
        case .posada:
            guard let s = solido(p.sobre) else { soltar(&p); return }
            p.x = s.minX + p.dx
            guard let sy = s.techo(p.x) else { soltar(&p); return }
            p.y = sy - apoyo(p)
            p.giro += (s.pendiente(p.x) * 0.8 - p.giro) * min(1, 6 * dt)
            p.volteo += ((p.volteo / .pi).rounded() * .pi - p.volteo) * min(1, 5 * dt)
            p.espera -= dt
            
            if p.espera < 0.5 { p.giro += sin(Float(t) * 18) * 0.012 }
            if p.espera <= 0 {
                if p.tipo == .confeti && azar.uno() < 0.5 {
                    p.vida = p.edad + 0.6   
                    p.espera = 99
                } else {
                    p.estado = .resbala
                    let centro = (s.minX + s.maxX) / 2
                    p.amplitud = p.x < centro ? -1 : 1
                    p.vx = 0
                }
            }
        case .resbala:
            guard let s = solido(p.sobre) else { soltar(&p); return }
            let pend = s.pendiente(p.x)
            p.vx += (p.amplitud * 34 + pend * 160) * dt
            p.vx = min(max(p.vx, -60), 60)
            p.dx += p.vx * dt
            p.x = s.minX + p.dx
            if let sy = s.techo(p.x) {
                p.y = sy - apoyo(p)
                p.giro += (pend * 0.9 - p.giro) * min(1, 6 * dt)
            } else {
                soltar(&p)
                p.vx = p.amplitud * 22
            }
        default:
            break
        }
    }

    private func apoyo(_ p: Particula) -> Float {
        switch p.tipo {
        case .hoja: p.tam * 0.16
        case .petalo: p.tam * 0.18
        case .confeti: p.tam * 0.2
        case .moneda: p.tam * 0.5
        default: p.tam
        }
    }

    private func posar(_ p: inout Particula, en s: Int, y sy: Float) {
        let solido = solidos[s]
        let golpe = abs(p.vy)
        p.estado = .posada
        p.sobre = solido.id
        p.dx = p.x - solido.minX
        p.y = sy - apoyo(p)
        p.vy = 0; p.vx = 0
        p.delante = true
        switch p.tipo {
        case .hoja:
            p.espera = azar.entre(0.8, 3)
            empujar(solido, min(1.6, 0.5 + golpe * 0.022))
        case .petalo:
            p.espera = azar.entre(0.3, 1.2)
            empujar(solido, 0.5)
        default:
            p.espera = azar.entre(1.2, 3.5)
        }
    }

    private func soltar(_ p: inout Particula) {
        p.estado = .libre
        p.sobre = nil
        p.vy = max(p.vy, 12)
    }

    private func empujar(_ s: Solido, _ fuerza: Float) {
        guard let g = s.golpe else { return }
        let f = CGFloat(fuerza)
        DispatchQueue.main.async { g.dar(f) }
    }

    private func moverCopo(_ p: inout Particula, _ dt: Float, _ H: Float) {
        switch p.estado {
        case .libre:
            p.fase += p.vfase * dt
            let terminal: Float = 26 + 14 * Float(p.capa)
            p.vy += (terminal - p.vy) * min(1, 0.35 * dt)
            let vx = p.vx + cos(p.fase) * p.amplitud * p.vfase * 0.5
            let y0 = p.y
            p.x += vx * dt; p.y += p.vy * dt
            if p.choca, case let (s, sy)? = choqueArriba(p.x, y0, p.y, p.tam * 0.5) {
                let solido = solidos[s]
                p.estado = .posada
                p.sobre = solido.id
                p.dx = p.x - solido.minX
                p.y = sy - p.tam * 0.45
                p.delante = true
                p.vida = p.edad + azar.entre(7, 15)
                if solido.id == nil { p.vida = p.edad + azar.entre(1.5, 3) }
            }
            if p.y - p.tam > H { p.estado = .muerta }
        case .posada:
            if let s = solido(p.sobre) {
                p.x = s.minX + p.dx
                if let sy = s.techo(p.x) { p.y = sy - p.tam * 0.45 } else { soltar(&p) }
            } else if p.sobre != nil {
                soltar(&p)
            }
            
            let queda = p.vida - p.edad
            if queda < 2 { p.alfa = max(0, min(p.alfa, queda / 2)) }
        default:
            break
        }
    }

    private func moverGranizo(_ p: inout Particula, _ dt: Float, _ H: Float) {
        if p.rebotes > 0 { p.vy += 1375 * dt }
        let y0 = p.y
        p.x += p.vx * dt; p.y += p.vy * dt
        if p.vy > 0, case let (s, sy)? = choqueArriba(p.x, y0, p.y, p.tam) {
            if p.rebotes >= 2 { p.estado = .muerta; return }
            p.rebotes += 1
            p.y = sy - p.tam
            p.vy = -min(abs(p.vy) * azar.entre(0.3, 0.42), 275 * azar.entre(0.6, 1)) / Float(p.rebotes)
            p.vx = azar.entre(-90, 90) + solidos[s].pendiente(p.x) * 120
            p.delante = true
            if p.rebotes == 1 { empujar(solidos[s], 0.35) }
        }
        if p.y > H + 10 { p.estado = .muerta }
    }

    private func moverMoneda(_ p: inout Particula, _ dt: Float, _ W: Float, _ H: Float) {
        
        let rapidez = (p.vx * p.vx + p.vy * p.vy).squareRoot()
        let pasos = min(8, max(1, Int((rapidez * dt / 3).rounded(.up))))
        let h = dt / Float(pasos)
        for _ in 0..<pasos {
            let antes = (x: p.x, y: p.y, volteo: p.volteo, giro: p.giro)
            p.vy = min(p.vy + Moneda.gravedad * h, Moneda.maxima)
            p.x += p.vx * h; p.y += p.vy * h
            p.volteo += p.vvolteo * h
            p.giro += p.vgiro * h
            
            if !p.choca && p.y > p.dy { p.choca = true }
            if p.choca { chocarMoneda(&p, h, antes) }
        }

        if p.y > p.dx + Moneda.nuevaAltura {
            p.dx = p.y; p.largo = 0; p.rebotes = 0
        } else {
            p.largo += dt
        }
        if p.y - p.tam > H + 10 || p.x < -60 || p.x > W + 60 { p.estado = .muerta }
    }

    private func chocarMoneda(_ p: inout Particula, _ h: Float,
                              _ antes: (x: Float, y: Float, volteo: Float, giro: Float)) {
        let r = p.tam
        var toca = false
        
        var fondo = -Float.infinity
        for i in solidos.indices {
            let s = solidos[i]
            if p.x + r < s.minX - 1 || p.x - r > s.maxX + 1 || p.y + r < s.minY - 1 || p.y - r > s.maxY + 1 { continue }
            
            guard case let (d, nx, ny)? = distanciaA(s, p.x, p.y), ny <= Moneda.arriba else { continue }
            let (alcance, cx, cy) = Moneda.soporte(r, p.volteo, p.giro, nx, ny)
            let hunde = alcance - d
            guard hunde > 0 else { continue }

            if hunde > Moneda.dentro, case let (d0, nx0, ny0)? = distanciaA(s, antes.x, antes.y),
               Moneda.soporte(r, antes.volteo, antes.giro, nx0, ny0).alcance - d0 > Moneda.dentro { continue }

            let ct = cos(p.volteo), st = sin(p.volteo)
            let cz: Float = abs(ct) < 0.12 ? 0 : (ct >= 0 ? 1 : -1) * r * st * abs(ny)
            var vcx = p.vx - p.vgiro * cy
            var vcy = p.vy + p.vgiro * cx - p.vvolteo * cz
            let vn = -(vcx * nx + vcy * ny)
            p.x += nx * hunde; p.y += ny * hunde
            toca = true
            fondo = max(fondo, fondoDe(s, p.x, r))
            guard vn > 0 else { continue }
            
            let e: Float = vn < 60 ? 0 : Moneda.rebote * pow(0.75, Float(min(p.rebotes, 4)))
            let b = Moneda.alto(r, p.volteo)
            let iz = (r * r + b * b) / 4
            let cn = cx * ny - cy * nx
            let k = 1 + cn * cn / iz + 4 * (cz * ny) * (cz * ny) / (r * r)

            let jn = (1 + e * (Moneda.centro + (1 - Moneda.centro) / k)) * vn
            let jr = (1 + e) * vn / k
            let antesV = p.vvolteo
            p.vx += jn * nx; p.vy += jn * ny
            p.vgiro += cn * jr / iz
            p.vvolteo -= cz * jr * ny * 4 / (r * r)
            
            let tx = -ny, ty = nx
            vcx = p.vx - p.vgiro * cy
            vcy = p.vy + p.vgiro * cx - p.vvolteo * cz
            let ctn = cx * ty - cy * tx
            let jt = min(max(-(vcx * tx + vcy * ty) / (1 + ctn * ctn / iz), -Moneda.roce * jn), Moneda.roce * jn)
            p.vx += jt * tx; p.vy += jt * ty
            p.vgiro += ctn * jt / iz

            let minimo = 3 + vn * 0.02
            if vn > 40 && abs(p.vvolteo - antesV) < minimo {
                let sentido: Float = abs(antesV) > 0.5 ? (antesV >= 0 ? 1 : -1) : azar.signo()
                p.vvolteo = antesV + sentido * minimo
            }
            p.vvolteo = min(max(p.vvolteo, -Moneda.giroMaximo), Moneda.giroMaximo)
            p.vgiro = min(max(p.vgiro, -Moneda.giroPlano), Moneda.giroPlano)
            p.vx += azar.entre(-1, 1) * min(15, vn * 0.04)
            let llega = p.rebotes == 0
            if vn > 110 {
                if llega || vn > 280 { empujar(s, min(2.6, 0.6 + vn * 0.004)) }
                if vn > 170 { destelloDeMoneda(p.x - nx * alcance, p.y - ny * alcance) }
            }
            guard vn > 150 else { continue }
            if p.rebotes < 255 { p.rebotes += 1 }
            
            if llega && azar.uno() < Moneda.engancha {
                p.vy = -min(80, vn * 0.15)
                p.vx += azar.entre(-40, 40)
                soltarMoneda(&p, hasta: fondo)
                return
            }
        }
        p.espera = toca ? p.espera + h : max(0, p.espera - h)
        
        guard toca, (abs(p.vy) < 45 && p.espera > 0.05) || p.espera > 0.25
                || p.rebotes > Moneda.botes || p.largo > Moneda.sinBajar else { return }
        p.vy = max(p.vy, 50)
        p.vx += azar.entre(-25, 25)
        soltarMoneda(&p, hasta: fondo)
    }

    private func fondoDe(_ s: Solido, _ x: Float, _ r: Float) -> Float {
        if s.linea != nil { return (s.techo(x) ?? s.maxY) + r + 2 }
        return s.maxY
    }

    private func soltarMoneda(_ p: inout Particula, hasta fondo: Float) {
        p.choca = false
        p.dy = fondo
        p.vvolteo = min(max(p.vvolteo + azar.signo() * azar.entre(5, 9), -Moneda.giroMaximo), Moneda.giroMaximo)
        p.espera = 0
    }

    private func destelloDeMoneda(_ x: Float, _ y: Float) {
        for _ in 0..<2 {
            var c = Particula(tipo: .chispa)
            c.x = x; c.y = y - 1
            let a = azar.entre(-1.2, 1.2)
            c.vx = sin(a) * 90; c.vy = -cos(a) * 110
            c.vida = 0.25; c.tam = 0.9; c.color = 3; c.delante = true
            nuevas.append(c)
        }
    }

    private func distanciaA(_ s: Solido, _ x: Float, _ y: Float) -> (Float, Float, Float)? {
        if s.linea != nil {
            guard let sy = s.techo(x) else { return nil }
            let m = s.pendiente(x)
            let largo = (1 + m * m).squareRoot()
            return ((sy - y) / largo, m / largo, -1 / largo)
        }
        let cx = (s.minX + s.maxX) / 2, cy = (s.minY + s.maxY) / 2
        let hx = (s.maxX - s.minX) / 2, hy = (s.maxY - s.minY) / 2
        let r = max(0, min(s.radio, hx, hy))
        let qx = abs(x - cx) - (hx - r), qy = abs(y - cy) - (hy - r)
        let sx: Float = x < cx ? -1 : 1, sy: Float = y < cy ? -1 : 1
        if qx > 0 && qy > 0 {
            let l = (qx * qx + qy * qy).squareRoot()
            return (l - r, sx * qx / l, sy * qy / l)
        }
        return qx > qy ? (qx - r, sx, 0) : (qy - r, 0, sy)
    }

    private func moverBurbuja(_ p: inout Particula, _ dt: Float, _ W: Float) {
        switch p.estado {
        case .libre:
            p.fase += p.vfase * dt
            let vx = cos(p.fase) * p.amplitud * p.vfase
            let y0 = p.y
            p.x += vx * dt + p.vx * dt
            p.vx *= (1 - 1.5 * dt)
            p.y += p.vy * dt
            if p.tipo == .corazon { p.giro = sin(p.fase) * 0.22 }
            if p.choca, case let (s, sy)? = choqueAbajo(p.x, y0, p.y, radioDe(p)) {
                let solido = solidos[s]
                p.estado = .debajo
                p.sobre = solido.id
                p.dx = p.x - solido.minX
                p.y = sy + radioDe(p)
                let centro = (solido.minX + solido.maxX) / 2
                p.amplitud = p.x < centro ? -1 : 1
                p.vx = 0
                p.delante = true
            }
            if p.y < -40 {
                p.estado = .muerta
            }
            if p.tipo == .burbuja && p.vida.isFinite && p.vida - p.edad < 0.02 { estallar(p) }
        case .debajo:
            guard let s = solido(p.sobre) else { p.estado = .libre; return }
            p.vx += p.amplitud * (p.tipo == .burbuja ? 50 + radioDe(p) * 6 : 40) * dt
            p.vx = min(max(p.vx, -70), 70)
            p.dx += p.vx * dt
            p.x = s.minX + p.dx
            if let sy = s.suelo(p.x) {
                p.y = sy + radioDe(p)
            } else {
                p.estado = .libre
                p.sobre = nil
                p.vx = p.amplitud * 18
            }
        default:
            break
        }
    }

    private func radioDe(_ p: Particula) -> Float {
        p.tipo == .corazon ? p.tam * 0.5 : p.tam
    }

    private func estallar(_ p: Particula) {
        var a = Particula(tipo: .anillo)
        a.x = p.x; a.y = p.y; a.tam = p.tam; a.vida = 0.16; a.delante = p.delante
        nuevas.append(a)
    }

    private func moverPompa(_ p: inout Particula, _ dt: Float, _ W: Float, _ H: Float) {
        p.fase += p.vfase * dt
        p.giro += p.vgiro * dt
        let vx = p.vx + sin(p.fase) * 8
        let x0 = p.x, y0 = p.y
        p.x += vx * dt; p.y += p.vy * dt
        if p.y < -p.tam - 10 || p.x < -60 || p.x > W + 60 { p.estado = .muerta; return }

        for s in solidos where s.superficie {
            
            let cx = min(max(p.x, s.minX), s.maxX), cy = min(max(p.y, s.minY), s.maxY)
            let dx = p.x - cx, dy = p.y - cy
            if dx * dx + dy * dy < p.tam * p.tam * 0.9 {
                _ = (x0, y0)
                p.estado = .muerta
                var a = Particula(tipo: .anillo)
                a.x = p.x; a.y = p.y; a.tam = p.tam; a.vida = 0.22; a.delante = true; a.forma = 1
                nuevas.append(a)
                for _ in 0..<7 {
                    var g = Particula(tipo: .salpicadura)
                    let ang = azar.entre(0, 6.3)
                    g.x = p.x + cos(ang) * p.tam * 0.8; g.y = p.y + sin(ang) * p.tam * 0.8
                    g.vx = cos(ang) * azar.entre(30, 70); g.vy = sin(ang) * azar.entre(30, 70)
                    g.tam = 0.8; g.vida = 0.25; g.alfa = 0.7; g.delante = true; g.color = 1
                    nuevas.append(g)
                }
                empujar(s, 0.5)
                return
            }
        }
    }

    private func moverBrasa(_ p: inout Particula, _ dt: Float, _ W: Float) {
        p.fase += p.vfase * dt
        let empuje = sin(p.fase) * p.amplitud + sin(p.fase * 2.3 + 1.7) * p.amplitud * 0.5
        p.vx += (empuje - p.vx) * min(1, 2 * dt)
        p.vy += (-70 - p.vy) * min(1, 0.6 * dt)
        let y0 = p.y
        p.x += p.vx * dt; p.y += p.vy * dt
        if p.choca, case let (s, sy)? = choqueAbajo(p.x, y0, p.y, p.tam) {
            let centro = (solidos[s].minX + solidos[s].maxX) / 2
            p.y = sy + p.tam
            p.vy = abs(p.vy) * 0.25
            p.vx = (p.x < centro ? -1 : 1) * 70
            p.delante = true
        }
        let vida = p.edad / p.vida
        p.alfa = vida < 0.1 ? vida / 0.1 : max(0, 1 - (vida - 0.1) / 0.9)
    }

    private func moverLuciernaga(_ p: inout Particula, _ dt: Float, _ W: Float, _ H: Float) {
        switch p.estado {
        case .libre:
            p.giro += azar.entre(-1.6, 1.6) * dt
            let v = p.amplitud
            let y0 = p.y
            p.x += cos(p.giro) * v * dt
            p.y += sin(p.giro) * v * dt
            if p.x < 8 || p.x > W - 8 { p.giro = .pi - p.giro; p.x = min(max(p.x, 8), W - 8) }
            if p.y < 0.08 * H || p.y > 0.97 * H { p.giro = -p.giro; p.y = min(max(p.y, 0.08 * H), 0.97 * H) }
            if sin(p.giro) > 0, case let (s, sy)? = choqueArriba(p.x, y0, p.y, 2) {
                let solido = solidos[s]
                guard solido.id != nil else { p.giro = -p.giro; return }
                p.estado = .posada
                p.sobre = solido.id
                p.dx = p.x - solido.minX
                p.y = sy - 2.5
                p.espera = azar.entre(1.5, 4.5)
                p.delante = true
            }
        case .posada:
            guard let s = solido(p.sobre), let sy = s.techo(s.minX + p.dx) else { p.estado = .libre; return }
            p.x = s.minX + p.dx; p.y = sy - 2.5
            p.espera -= dt
            if p.espera <= 0 {
                p.estado = .libre
                p.sobre = nil
                p.giro = -.pi / 2 + azar.entre(-0.6, 0.6)
                p.y -= 3
            }
        default:
            break
        }
    }

    private func moverVilano(_ p: inout Particula, _ dt: Float, _ W: Float, _ H: Float) {
        p.fase += p.vfase * dt
        let vy = sin(p.fase) * p.amplitud + p.vy
        p.vy *= (1 - 1.5 * dt)
        p.giro = sin(p.fase * 0.7) * 0.25
        let x0 = p.x, y0 = p.y
        p.x += p.vx * dt; p.y += vy * dt
        p.vx += (azar.entre(20, 32) - p.vx) * min(1, 0.4 * dt)
        for s in solidos where s.superficie {
            if p.x > s.minX - 4, p.x < s.maxX + 4, p.y > s.minY - 4, p.y < s.maxY + 4 {
                
                p.x = x0; p.y = y0
                if y0 <= s.minY - 2 { p.vy = -30 } else if y0 >= s.maxY + 2 { p.vy = 30 } else { p.vx = -abs(p.vx) * 0.4 }
                p.delante = true
                break
            }
        }
        if p.x > W + 30 || p.y < -30 || p.y > H + 30 { p.estado = .muerta }
    }

    private func moverPurpurina(_ p: inout Particula, _ dt: Float, _ H: Float) {
        p.giro += p.vgiro * dt
        switch p.estado {
        case .libre:
            p.fase += p.vfase * dt
            let y0 = p.y
            p.x += cos(p.fase) * p.amplitud * p.vfase * 0.5 * dt
            p.y += p.vy * dt
            if p.choca, case let (s, sy)? = choqueArriba(p.x, y0, p.y, 0.5) {
                let solido = solidos[s]
                p.estado = .posada
                p.sobre = solido.id
                p.dx = p.x - solido.minX
                p.y = sy - 0.6
                p.vgiro *= 0.3
                p.delante = true
                p.vida = p.edad + azar.entre(5, 12)
            }
            if p.y > H + 5 { p.estado = .muerta }
        case .posada:
            if let s = solido(p.sobre), let sy = s.techo(s.minX + p.dx) {
                p.x = s.minX + p.dx; p.y = sy - 0.6
            } else { soltar(&p) }
            let queda = p.vida - p.edad
            if queda < 1.5 { p.alfa = max(0, queda / 1.5) }
        default:
            break
        }
    }

    private func moverCohete(_ p: inout Particula, _ dt: Float) {
        p.vy += 300 * dt
        p.x += p.vx * dt; p.y += p.vy * dt
        if p.y <= p.espera || p.vy > -60 {
            p.estado = .muerta
            let n = Int(Float(azar.entre(48, 72)) * max(calidad, 0.6))
            for _ in 0..<n {
                var c = Particula(tipo: .chispa)
                let a = azar.entre(0, 2 * .pi)
                let v = azar.entre(70, 200)
                c.x = p.x; c.y = p.y
                c.vx = cos(a) * v; c.vy = sin(a) * v
                c.vida = azar.entre(1.1, 1.9)
                c.tam = azar.entre(0.9, 1.6)
                c.color = azar.uno() < 0.15 ? 4 : p.color
                c.largo = 1
                nuevas.append(c)
            }
            var f = Particula(tipo: .anillo)
            f.x = p.x; f.y = p.y; f.tam = 60; f.vida = 0.25; f.forma = 2; f.color = p.color
            nuevas.append(f)
        }
    }

    private func choqueArriba(_ x: Float, _ y0: Float, _ y1: Float, _ r: Float) -> (Int, Float)? {
        var mejor: (Int, Float)?
        for (i, s) in solidos.enumerated() {
            if x < s.minX || x > s.maxX { continue }
            if y1 + r < s.minY - 1 { continue }
            guard let sy = s.techo(x) else { continue }
            if y0 + r <= sy + 1.5, y1 + r >= sy {
                if mejor == nil || sy < mejor!.1 { mejor = (i, sy) }
            }
        }
        return mejor
    }

    private func choqueAbajo(_ x: Float, _ y0: Float, _ y1: Float, _ r: Float) -> (Int, Float)? {
        var mejor: (Int, Float)?
        for (i, s) in solidos.enumerated() {
            if x < s.minX || x > s.maxX { continue }
            guard let sy = s.suelo(x) else { continue }
            if y0 - r >= sy - 1.5, y1 - r <= sy {
                if mejor == nil || sy > mejor!.1 { mejor = (i, sy) }
            }
        }
        return mejor
    }

    private func tormentaYCielo(_ dt: Float) {
        guard vida == .tormenta else { return }
        let W = Float(tamano.width), H = Float(tamano.height)
        if t >= proximoRayo {
            proximoRayo = t + Double(azar.entre(7, 16))
            rayo = nuevoRayo(W, H)
        }
        if let r = rayo {
            let edad = Float(t - r.nacio)
            
            let d: Float
            switch edad {
            case ..<0.08: d = 0.5
            case ..<0.16: d = 0
            case ..<0.24: d = 1
            default: d = max(0, 1 - (edad - 0.24) / 0.9)
            }
            destello = tenue ? d * 0.15 : d
            if edad > 1.3 { rayo = nil; destello = 0 }
            if edad >= 0.12, edad - dt < 0.12, let id = r.destino, let s = solido(id), let fin = r.puntos.last {
                
                empujar(s, 2.2)
                for _ in 0..<10 {
                    var c = Particula(tipo: .chispa)
                    let a = azar.entre(-1.3, 1.3)
                    let v = azar.entre(80, 200)
                    c.x = fin.x; c.y = fin.y - 1
                    c.vx = sin(a) * v; c.vy = -cos(a) * v
                    c.vida = azar.entre(0.25, 0.5); c.tam = 1; c.color = 1; c.delante = true
                    nuevas.append(c)
                }
            }
        }
        
        if t >= proximoParpadeo {
            proximoParpadeo = t + Double(azar.entre(2.5, 6))
            parpadeo = (t, azar.entre(0.1, 0.9) * W)
        }
    }

    var parpadeoAhora: (fuerza: Float, x: Float)? {
        guard let p = parpadeo else { return nil }
        let e = Float(t - p.t)
        guard e < 1.2 else { return nil }
        
        let pasos: [Float] = [0, 0.75, 0, 0.25, 0, 0.25, 0, 1, 0, 0.5, 0, 0.75]
        let i = min(Int(e / 0.1), pasos.count - 1)
        return ((tenue ? 0.2 : 1) * pasos[i], p.x)
    }

    private func nuevoRayo(_ W: Float, _ H: Float) -> Rayo {
        
        let candidatos = solidos.filter { $0.id != nil && $0.minY > 40 && $0.minY < H * 0.6 && $0.ancho > 20 }
        var destino: UUID?
        var fin: SIMD2<Float>
        if !candidatos.isEmpty, azar.uno() < 0.5 {
            let s = candidatos[azar.de(candidatos.count)]
            let x = azar.entre(s.minX + 6, s.maxX - 6)
            fin = SIMD2(x, s.techo(x) ?? s.minY)
            destino = s.id
        } else {
            fin = SIMD2(azar.entre(0.15, 0.85) * W, azar.entre(0.3, 0.55) * H)
        }
        let inicio = SIMD2(fin.x + azar.entre(-0.25, 0.25) * W, -10)
        var puntos = [inicio, fin]
        var desvio = (fin.y - inicio.y) * 0.22
        for _ in 0..<6 {
            var nuevos: [SIMD2<Float>] = [puntos[0]]
            for i in 1..<puntos.count {
                let a = puntos[i - 1], b = puntos[i]
                var m = (a + b) / 2
                m.x += azar.entre(-desvio, desvio)
                nuevos.append(m)
                nuevos.append(b)
            }
            puntos = nuevos
            desvio *= 0.55
        }
        var ramas: [[SIMD2<Float>]] = []
        for _ in 0..<(2 + azar.de(2)) {
            let i = azar.de(max(puntos.count / 2, 1)) + puntos.count / 6
            guard i < puntos.count else { continue }
            var p = puntos[i]
            var rama = [p]
            let lado = azar.signo()
            for _ in 0..<Int(azar.entre(5, 10)) {
                p += SIMD2(lado * azar.entre(4, 14), azar.entre(6, 16))
                rama.append(p)
            }
            ramas.append(rama)
        }
        return Rayo(puntos: puntos, ramas: ramas, nacio: t, destino: destino)
    }
}

extension Color {
    
    init(rgbDeVida rgb: UInt32) {
        self.init(.sRGB, red: Double((rgb >> 16) & 0xFF) / 255, green: Double((rgb >> 8) & 0xFF) / 255,
                  blue: Double(rgb & 0xFF) / 255, opacity: 1)
    }
}
