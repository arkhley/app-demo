import SwiftUI
import ImageIO
#if canImport(UIKit)
import UIKit
#endif

enum SitioDelFondo: Equatable {
    
    case inicio(plataforma: String, directo: Bool)

    case joya(Joya, luz: Color?, late: Bool)
    
    case pantalla
    
    case panel
}

struct FondoDeTema: View {
    let sitio: SitioDelFondo

    @Environment(\.tema) private var tema
    @Environment(\.colorScheme) private var modo
    @Environment(\.accessibilityReduceMotion) private var menosMovimiento
    @Environment(\.accessibilityReduceTransparency) private var menosTransparencia
    @State private var enHoja: Bool?

    var body: some View {
        ZStack {
            if enHoja == true {
                
                tema.colorDeFondo
            } else {
                lienzo
                    .opacity(menosTransparencia && sitio != .pantalla ? 0.75 : 1)
                luces
                if enHoja == false, let vida = tema.vida, sitio != .pantalla || vida.tambienEnListas {
                    if vida == .aurora { CortinasDeAurora(colores: tema.particulas ?? []).transition(.opacity) }
                    CapaDeVida(vida: vida, colores: tema.particulas ?? [], oscuro: modo == .dark,
                               capa: sitio == .panel ? .panel : .app)
                        .id("\(tema.id)-\(modo == .dark)-\(sitio == .panel)")
                }
            }
        }
        .background { DetectorDeHoja { enHoja = $0 } }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var lienzo: some View {
        switch tema.lienzo {
        case .malla(let forma):
            TimelineView(.animation(minimumInterval: 1 / 30, paused: menosMovimiento)) { t in
                MallaDeTema.malla(forma, colores: coloresDeMalla,
                                  base: sitio == .pantalla ? tema.colorDeFondo : tema.colorDeFondo,
                                  t: Float(menosMovimiento ? 0 : t.date.timeIntervalSinceReferenceDate),
                                  latido: latido(t.date))
            }
        case .plano:
            colorPlano
        case .textura(let material):
            TexturaDeFondo(textura: material, tema: tema, velada: sitio == .pantalla)
        case .cielo:
            if sitio == .pantalla {
                tema.colorDeFondo
            } else {
                LinearGradient(colors: (tema.cielo ?? []).map(\.color), startPoint: .top, endPoint: .bottom)
            }
        }
    }

    private func latido(_ fecha: Date) -> Float {
        guard case .inicio(_, true) = sitio, !menosMovimiento else { return 0 }
        return 0.08 * sin(Float(fecha.timeIntervalSinceReferenceDate) * 2.4)
    }

    private var coloresDeMalla: [Color] {
        let oscuro = modo == .dark
        switch sitio {
        case .inicio(let plataforma, let directo):
            var a = tema.tonosDelCampo(plataforma) ?? []
            if directo, a.count == 3 {
                a[1] = a[1].mix(with: Color.red.mix(with: oscuro ? .black : .white, by: oscuro ? 0.32 : 0.22), by: 0.7)
            }
            return a
        case .joya(let joya, _, _):
            return tema.tonosDeLaJoya(joya) ?? []
        case .pantalla:
            return (tema.tonosDeLaJoya(.impuestos) ?? []).map { $0.mix(with: tema.colorDeFondo, by: 0.45) }
        case .panel:
            return tema.tonosDelCampo("todo") ?? []
        }
    }

    @ViewBuilder
    private var colorPlano: some View {
        switch sitio {
        case .inicio(let plataforma, _):
            (tema.tonosDelCampo(plataforma)?.first ?? tema.colorDeFondo)
        case .joya(let joya, _, _):
            (tema.tonosDeLaJoya(joya)?.first ?? tema.colorDeFondo)
        case .pantalla:
            tema.colorDeFondo
        case .panel:
            (tema.tonosDelCampo("todo")?.first ?? tema.colorDeFondo)
        }
    }

    @ViewBuilder
    private var luces: some View {
        switch sitio {
        case .joya(let joya, let luz, let late):
            if case .malla = tema.lienzo {
                LuzQuePasea(color: luz ?? tema.luz?.color ?? joya.luz, late: late)
            } else if let luz {
                LuzQuePasea(color: luz, late: late)
            }
        case .inicio(_, let directo):
            if case .malla = tema.lienzo {
                LuzQuePasea(color: tema.luz?.color ?? Joya.todo.luz, late: false)
            } else if directo {
                LuzQuePasea(color: Joya.luzDirecto, late: true, quieta: true)
            }
        case .pantalla, .panel:
            EmptyView()
        }
    }
}

extension Tema.Vida {

    var tambienEnListas: Bool {
        switch self {
        case .aurora, .galaxia, .sol, .lava, .nubes, .niebla: false
        default: true
        }
    }
}

struct LuzQuePasea: View {
    let color: Color
    var late = false
    var quieta = false

    @Environment(\.colorScheme) private var modo
    @Environment(\.accessibilityReduceMotion) private var menosMovimiento

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: menosMovimiento)) { t in
            let s = menosMovimiento ? 0 : t.date.timeIntervalSinceReferenceDate
            let latido = late && !menosMovimiento ? 0.75 + 0.25 * sin(s * 2.4) : 1
            let x = quieta ? 0.5 : 0.5 + 0.28 * sin(s * 0.11)
            let y = quieta ? 0.12 : 0.1 + 0.05 * cos(s * 0.16)
            let fuerza = (modo == .dark ? 0.34 : 0.3) * latido
            GeometryReader { g in
                RadialGradient(colors: [color.opacity(fuerza), color.opacity(0)],
                               center: UnitPoint(x: x, y: y),
                               startRadius: 0, endRadius: max(g.size.width, 1) * (quieta ? 0.8 : 0.75))
                    .blendMode(modo == .dark ? .plusLighter : .normal)
                    .mask {
                        LinearGradient(stops: [.init(color: .black, location: 0),
                                               .init(color: .black, location: quieta ? 0.45 : 0.3),
                                               .init(color: .clear, location: quieta ? 0.75 : 0.58)],
                                       startPoint: .top, endPoint: .bottom)
                    }
            }
        }
        .allowsHitTesting(false)
    }
}

enum MallaDeTema {
    static func malla(_ forma: Tema.Malla, colores: [Color], base: Color, t s: Float, latido: Float = 0) -> MeshGradient {
        let a = colores.count == 3 ? colores : [base, base, base]
        let m = a.map { $0.mix(with: base, by: 0.55) }
        switch forma {
        case .estadio:
            return MeshGradient(
                width: 3, height: 4,
                points: [
                    [0, 0], [0.5, 0], [1, 0],
                    [0, 0.24 + 0.03 * sin(s * 0.5)],
                    [0.5 + 0.10 * sin(s * 0.33), 0.28 + 0.05 * cos(s * 0.41) + latido],
                    [1, 0.22 + 0.03 * cos(s * 0.47)],
                    [0, 0.50], [0.5 + 0.06 * cos(s * 0.29), 0.54], [1, 0.48],
                    [0, 1], [0.5, 1], [1, 1],
                ],
                colors: [a[0], a[1], a[2], a[2], a[0], a[1], m[1], m[2], m[0], base, base, base])
        case .diagonal:
            
            let d = 0.04 * sin(s * 0.3)
            return MeshGradient(
                width: 4, height: 4,
                points: [
                    [0, 0], [0.33, 0], [0.66, 0], [1, 0],
                    [0, 0.22], [0.36 + d, 0.2 + latido], [0.7, 0.24 - d], [1, 0.2],
                    [0, 0.5], [0.3, 0.48 + d], [0.64 - d, 0.52], [1, 0.5],
                    [0, 1], [0.33, 1], [0.66, 1], [1, 1],
                ],
                colors: [a[0], a[0], a[1], a[2],
                         a[0], a[1], a[2], m[2],
                         a[1], a[2], m[2], base,
                         m[1], m[2], base, base])
        case .halo:
            
            let luz = a[0].mix(with: .white, by: 0.28)
            let r = 0.02 * sin(s * 0.4)
            return MeshGradient(
                width: 4, height: 4,
                points: [
                    [0, 0], [0.33, 0], [0.66, 0], [1, 0],
                    [0, 0.26], [0.36 - r, 0.18 + latido], [0.64 + r, 0.18 + latido], [1, 0.26],
                    [0, 0.56], [0.3, 0.5 + r], [0.7, 0.5 - r], [1, 0.56],
                    [0, 1], [0.33, 1], [0.66, 1], [1, 1],
                ],
                colors: [a[2], a[0], a[0], a[2],
                         a[1], luz, luz, a[1],
                         m[2], a[1], a[1], m[2],
                         base, base, base, base])
        case .horizonte:
            
            func y(_ x: Float, _ b: Float, _ f: Float) -> Float { b + 0.025 * sin(x * 4 + s * f) }
            return MeshGradient(
                width: 3, height: 5,
                points: [
                    [0, 0], [0.5, 0], [1, 0],
                    [0, y(0, 0.17, 0.3)], [0.5, y(0.5, 0.15, 0.3) + latido], [1, y(1, 0.18, 0.3)],
                    [0, y(0, 0.34, 0.25)], [0.5, y(0.5, 0.33, 0.25)], [1, y(1, 0.36, 0.25)],
                    [0, 0.6], [0.5, 0.62], [1, 0.6],
                    [0, 1], [0.5, 1], [1, 1],
                ],
                colors: [a[2], a[2], a[2],
                         a[0], a[0], a[0],
                         a[1], a[1], a[1],
                         m[1], m[1], m[1],
                         base, base, base])
        case .esquinas:
            
            let calma = base.mix(with: a[2], by: 0.18)
            let d = 0.03 * sin(s * 0.35)
            return MeshGradient(
                width: 4, height: 4,
                points: [
                    [0, 0], [0.33, 0], [0.66, 0], [1, 0],
                    [0, 0.24], [0.36 + d, 0.26 + latido], [0.64 - d, 0.26], [1, 0.24],
                    [0, 0.5], [0.34, 0.54 - d], [0.66, 0.54 + d], [1, 0.5],
                    [0, 1], [0.33, 1], [0.66, 1], [1, 1],
                ],
                colors: [a[0], a[0].mix(with: base, by: 0.4), a[1].mix(with: base, by: 0.4), a[1],
                         a[0].mix(with: base, by: 0.3), calma, calma, a[1].mix(with: base, by: 0.3),
                         a[2], a[2].mix(with: base, by: 0.5), a[2].mix(with: base, by: 0.6), m[2],
                         base, base, base, base])
        case .remolino:
            
            let g = 0.5 + 0.12 * sin(s * 0.18)
            func giro(_ x: Float, _ y: Float, _ k: Float) -> SIMD2<Float> {
                let cx: Float = 0.5, cy: Float = 0.36
                let ang = g * k
                let dx = x - cx, dy = y - cy
                return [cx + dx * cos(ang) - dy * sin(ang), cy + dx * sin(ang) + dy * cos(ang)]
            }
            return MeshGradient(
                width: 4, height: 4,
                points: [
                    [0, 0], [0.33, 0], [0.66, 0], [1, 0],
                    [0, 0.26], giro(0.33, 0.24, 1), giro(0.66, 0.24, 1), [1, 0.26],
                    [0, 0.56], giro(0.33, 0.5, 0.6), giro(0.66, 0.5, 0.6), [1, 0.56],
                    [0, 1], [0.33, 1], [0.66, 1], [1, 1],
                ],
                colors: [a[0], a[1], a[2], a[0],
                         a[2], m[0], a[1], a[1],
                         a[1], a[2], m[0], a[2],
                         base, base, base, base])
        case .ondas:
            
            func y(_ x: Float, _ b: Float, _ fase: Float) -> Float { b + 0.05 * sin(x * 6.2 + fase + s * 0.35) }
            return MeshGradient(
                width: 4, height: 5,
                points: [
                    [0, 0], [0.33, 0], [0.66, 0], [1, 0],
                    [0, y(0, 0.16, 0)], [0.33, y(0.33, 0.16, 0) + latido], [0.66, y(0.66, 0.16, 0)], [1, y(1, 0.16, 0)],
                    [0, y(0, 0.34, 1.6)], [0.33, y(0.33, 0.34, 1.6)], [0.66, y(0.66, 0.34, 1.6)], [1, y(1, 0.34, 1.6)],
                    [0, 0.6], [0.33, 0.6], [0.66, 0.6], [1, 0.6],
                    [0, 1], [0.33, 1], [0.66, 1], [1, 1],
                ],
                colors: [a[1], a[1], a[1], a[1],
                         a[0], a[2], a[0], a[2],
                         a[2], a[0], a[2], a[0],
                         m[1], m[1], m[1], m[1],
                         base, base, base, base])
        }
    }
}

struct CortinasDeAurora: View {
    let colores: [Tono]
    @Environment(\.accessibilityReduceMotion) private var menosMovimiento

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: menosMovimiento)) { t in
            let s = Float(menosMovimiento ? 40 : t.date.timeIntervalSinceReferenceDate)
            let c = colores.count >= 3 ? colores.prefix(3).map { $0.color } : [Color.green, Color.teal, Color.purple]
            let ondear: (Float, Float) -> Float = { x, f in 0.06 * sin(x * 5 + s * 0.12 * f) + 0.03 * sin(x * 11 - s * 0.2 * f) }
            MeshGradient(
                width: 5, height: 4,
                points: (0..<4).flatMap { j -> [SIMD2<Float>] in
                    let yb: Float = [0, 0.16, 0.3, 0.62][j]
                    return (0..<5).map { i -> SIMD2<Float> in
                        let x = Float(i) / 4
                        let dy: Float = (j == 1 || j == 2) ? ondear(x + Float(j), Float(j)) : 0
                        let dx: Float = (i > 0 && i < 4) ? 0.04 * sin(s * 0.09 + Float(i + j)) : 0
                        return [x + dx, yb + dy]
                    }
                },
                colors: [
                    .clear, .clear, .clear, .clear, .clear,
                    c[0].opacity(0.5), c[1].opacity(0.35), c[0].opacity(0.6), c[1].opacity(0.3), c[0].opacity(0.45),
                    c[2].opacity(0.22), c[0].opacity(0.25), c[2].opacity(0.3), c[0].opacity(0.2), c[2].opacity(0.25),
                    .clear, .clear, .clear, .clear, .clear,
                ])
            .blendMode(.plusLighter)
        }
        .allowsHitTesting(false)
    }
}

struct TexturaDeFondo: View {
    let textura: TexturaDeTema
    let tema: Tema
    var velada = false

    @Environment(\.colorScheme) private var modo
    @Environment(\.displayScale) private var escala

    var body: some View {
        let oscuro = modo == .dark
        GeometryReader { g in
            let p = TexturasDeTema.peticion(textura, tema: tema, oscuro: oscuro, tamano: g.size)
            ZStack {
                Color(rgbDeVida: p.base)
                if g.size.width > 20, let img = TexturasDeTema.compartidas.imagen(p) {
                    Image(decorative: img, scale: CGFloat(p.pxPorPunto))
                        .resizable()
                        .scaledToFill()
                        .frame(width: g.size.width, height: g.size.height)
                        .clipped()
                        .transition(.opacity)
                }
                if velada { tema.colorDeFondo.opacity(0.72) }
            }
            .animation(.easeOut(duration: 0.35), value: TexturasDeTema.compartidas.lista(p))
        }
    }
}

@MainActor
@Observable
final class TexturasDeTema {
    static let compartidas = TexturasDeTema()
    private var hechas: [PeticionDeTextura: CGImage] = [:]
    @ObservationIgnored private var haciendo: Set<PeticionDeTextura> = []

    static func peticion(_ t: TexturaDeTema, tema: Tema, oscuro: Bool, tamano: CGSize, pxPorPunto: Float = 2) -> PeticionDeTextura {
        let w = max(Int((tamano.width / 8).rounded(.up)) * 8, 8)
        let h = max(Int((tamano.height / 8).rounded(.up)) * 8, 8)
        func rgb(_ tono: Tono?) -> UInt32 { tono.map { oscuro ? $0.oscuro : $0.claro } ?? 0x808080 }
        return PeticionDeTextura(textura: t, ancho: Int(Float(w) * pxPorPunto), alto: Int(Float(h) * pxPorPunto),
                                 pxPorPunto: pxPorPunto, base: rgb(tema.material ?? tema.fondo), veta: rgb(tema.veta),
                                 extra: (tema.extra ?? []).map { oscuro ? $0.oscuro : $0.claro }, oscuro: oscuro)
    }

    func lista(_ p: PeticionDeTextura) -> Bool { hechas[p] != nil }

    @ObservationIgnored private var uso: [PeticionDeTextura] = []

    private static let maxGrandes = 4
    private static let maxPequenas = 120

    private func usada(_ p: PeticionDeTextura) {
        if let i = uso.lastIndex(of: p) { uso.remove(at: i) }
        uso.append(p)
    }

    private func guardar(_ img: CGImage, _ p: PeticionDeTextura) {
        hechas[p] = img
        usada(p)
        let grande = Self.esGrande(p)
        let mismas = uso.filter { Self.esGrande($0) == grande }
        for vieja in mismas.dropLast(grande ? Self.maxGrandes : Self.maxPequenas) {
            hechas[vieja] = nil
            uso.removeAll { $0 == vieja }
        }
    }

    private nonisolated static func esGrande(_ p: PeticionDeTextura) -> Bool { p.ancho * p.alto > 400_000 }

    func imagen(_ p: PeticionDeTextura) -> CGImage? {
        if let i = hechas[p] { usada(p); return i }
        #if MAQUETA

        if p.ancho * p.alto < 250_000, let img = Self.imagen(Self.delDisco(p) ?? Self.hacer(p), p) {
            guardar(img, p)
            return img
        }
        #endif
        guard !haciendo.contains(p) else { return nil }
        haciendo.insert(p)
        Task.detached(priority: .userInitiated) {
            let pixeles = Self.delDisco(p) ?? Self.hacer(p)
            await MainActor.run {
                if let img = Self.imagen(pixeles, p) {
                    self.guardar(img, p)
                }
                self.haciendo.remove(p)
            }
        }
        return nil
    }

    #if MAQUETA

    func hacerYaParaLasFotos() {
        let tema = Temas.compartido.actual
        guard case .textura(let material) = tema.lienzo,
              let pantalla = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first?.screen
                ?? Optional(UIScreen.main) else { return }
        let oscuro = tema.soloDeNoche || (!tema.soloDeDia && pantalla.traitCollection.userInterfaceStyle == .dark)
        let p = Self.peticion(material, tema: tema, oscuro: oscuro, tamano: pantalla.bounds.size)
        if let img = Self.imagen(Self.delDisco(p) ?? Self.hacer(p), p) { guardar(img, p) }
    }
    #endif

    private nonisolated static func hacer(_ p: PeticionDeTextura) -> [UInt8] {
        let px = GeneradorDeTexturas.pixeles(p)
        
        if esGrande(p) { guardarEnDisco(px, p) }
        return px
    }

    private nonisolated static func imagen(_ px: [UInt8], _ p: PeticionDeTextura) -> CGImage? {
        guard px.count == p.ancho * p.alto * 4,
              let proveedor = CGDataProvider(data: Data(px) as CFData) else { return nil }
        return CGImage(width: p.ancho, height: p.alto, bitsPerComponent: 8, bitsPerPixel: 32,
                       bytesPerRow: p.ancho * 4, space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
                       bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue),
                       provider: proveedor, decode: nil, shouldInterpolate: true, intent: .defaultIntent)
    }

    private nonisolated static func archivo(_ p: PeticionDeTextura) -> URL? {
        guard let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else { return nil }
        let carpeta = caches.appendingPathComponent("texturas", isDirectory: true)
        try? FileManager.default.createDirectory(at: carpeta, withIntermediateDirectories: true)
        let colores = ([p.base, p.veta] + p.extra).map { String(format: "%06X", $0) }.joined(separator: "-")
        return carpeta.appendingPathComponent("v\(GeneradorDeTexturas.version)-\(p.textura.rawValue)-\(p.ancho)x\(p.alto)-\(colores).jpg")
    }

    private nonisolated static func guardarEnDisco(_ px: [UInt8], _ p: PeticionDeTextura) {
        guard let url = archivo(p), let img = imagen(px, p),
              let destino = CGImageDestinationCreateWithURL(url as CFURL, "public.jpeg" as CFString, 1, nil) else { return }
        CGImageDestinationAddImage(destino, img, [kCGImageDestinationLossyCompressionQuality: 0.9] as CFDictionary)
        CGImageDestinationFinalize(destino)
    }

    private nonisolated static func delDisco(_ p: PeticionDeTextura) -> [UInt8]? {
        guard let url = archivo(p), FileManager.default.fileExists(atPath: url.path),
              let fuente = CGImageSourceCreateWithURL(url as CFURL, nil),
              let img = CGImageSourceCreateImageAtIndex(fuente, 0, nil),
              img.width == p.ancho, img.height == p.alto else { return nil }
        var px = [UInt8](repeating: 255, count: p.ancho * p.alto * 4)
        let hecho = px.withUnsafeMutableBytes { b -> Bool in
            guard let c = CGContext(data: b.baseAddress, width: p.ancho, height: p.alto, bitsPerComponent: 8,
                                    bytesPerRow: p.ancho * 4, space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
                                    bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { return false }
            c.draw(img, in: CGRect(x: 0, y: 0, width: p.ancho, height: p.alto))
            return true
        }
        return hecho ? px : nil
    }
}

struct DetectorDeHoja: UIViewRepresentable {
    let dice: (Bool) -> Void

    func makeUIView(context: Context) -> Sonda {
        let s = Sonda()
        s.dice = dice
        return s
    }

    func updateUIView(_ vista: Sonda, context: Context) {
        vista.dice = dice
    }

    final class Sonda: UIView {
        var dice: ((Bool) -> Void)?
        private var dicho: Bool?

        override func didMoveToWindow() {
            super.didMoveToWindow()
            guard window != nil else { return }
            DispatchQueue.main.async { [weak self] in self?.mirar() }
        }

        private func mirar() {
            var r: UIResponder? = self
            var enHoja = false
            while let siguiente = r?.next {
                if let vc = siguiente as? UIViewController {
                    enHoja = vc.presentingViewController != nil
                    break
                }
                r = siguiente
            }
            if dicho != enHoja {
                dicho = enHoja
                dice?(enHoja)
            }
        }
    }
}

struct MiniaturaDeTextura: View {
    let textura: TexturaDeTema
    let tema: Tema
    let oscuro: Bool

    var body: some View {
        GeometryReader { g in
            let ancho = max(g.size.width, 1)
            
            let p = TexturasDeTema.peticion(textura, tema: tema, oscuro: oscuro,
                                            tamano: CGSize(width: 440, height: 440 * g.size.height / ancho),
                                            pxPorPunto: Float(ancho * 2 / 440))
            ZStack {
                Color(rgbDeVida: p.base)
                if let img = TexturasDeTema.compartidas.imagen(p) {
                    Image(decorative: img, scale: 1)
                        .resizable()
                        .scaledToFill()
                        .frame(width: g.size.width, height: g.size.height)
                        .clipped()
                }
            }
        }
    }
}

struct MiniaturaDeVida: View {
    let tema: Tema
    let vida: Tema.Vida
    let oscuro: Bool

    var body: some View {
        Canvas { ctx, tamano in
            let mundo = MundosDeMuestra.mundo(tema: tema, vida: vida, oscuro: oscuro,
                                              alto: 440 * tamano.height / max(tamano.width, 1))
            var c = ctx
            c.scaleBy(x: tamano.width / 440, y: tamano.width / 440)
            mundo.dibujar(&c, delante: false, desplazamiento: .zero)
            mundo.dibujar(&c, delante: true, desplazamiento: .zero)
        }
        .allowsHitTesting(false)
    }
}

@MainActor
private enum MundosDeMuestra {
    private static var hechos: [String: Mundo] = [:]

    static func mundo(tema: Tema, vida: Tema.Vida, oscuro: Bool, alto: CGFloat) -> Mundo {
        let clave = "\(tema.id)-\(oscuro)"
        if let m = hechos[clave] { return m }
        let m = Mundo(vida: vida, colores: tema.particulas ?? [], oscuro: oscuro, capa: .muestra,
                      quieto: false, tenue: false, ahorro: false, semilla: 7)
        m.tamano = CGSize(width: 440, height: alto)
        m.calentar(vida == .hojas || vida == .monedas ? 9 : 4)
        hechos[clave] = m
        return m
    }
}
