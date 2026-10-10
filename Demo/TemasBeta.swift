import SwiftUI
import PhotosUI
import CoreImage
#if canImport(UIKit)
import UIKit
#endif

struct Tono: Equatable, Sendable {
    let claro: UInt32
    let oscuro: UInt32

    init(_ claro: UInt32, _ oscuro: UInt32) {
        self.claro = claro
        self.oscuro = oscuro
    }

    var color: Color {
        let c = claro, o = oscuro
        return Color(UIColor { rasgos in
            UIColor(rgbDelTema: rasgos.userInterfaceStyle == .dark ? o : c)
        })
    }
}

private extension UIColor {
    convenience init(rgbDelTema rgb: UInt32) {
        self.init(red: CGFloat((rgb >> 16) & 0xFF) / 255,
                  green: CGFloat((rgb >> 8) & 0xFF) / 255,
                  blue: CGFloat(rgb & 0xFF) / 255, alpha: 1)
    }
}

struct Tema: Identifiable, Equatable, Sendable {
    
    enum Clase: Sendable {
        case base, foto, vida, textura, difuminado, plano
    }

    enum Malla: Sendable, Equatable {
        case estadio, diagonal, halo, horizonte, esquinas, remolino, ondas
    }

    enum Lienzo: Sendable, Equatable {
        
        case malla(Malla)
        
        case plano
        
        case textura(TexturaDeTema)
        
        case cielo
    }

    enum Vida: String, Sendable {
        case estrellas, hojas, lluvia, tormenta, nieve, petalos, luciernagas, burbujas, monedas, brasas
        case aurora, lava, corazones, confeti, granizo, purpurina, fuegos, nubes, sol, niebla, vilanos
        case pompas, galaxia
    }

    let id: String
    let nombre: String
    let clase: Clase
    let lienzo: Lienzo
    let vida: Vida?
    
    let soloDeNoche: Bool
    
    let soloDeDia: Bool
    
    let fondo: Tono?
    
    let tarjeta: Tono?
    
    let luz: Tono?
    
    let acento: Tono?
    
    let sobreAcento: Tono?

    let vivos: [Tono]?

    let apagados: [Tono]?
    
    let cielo: [Tono]?
    
    let particulas: [Tono]?
    
    let material: Tono?
    
    let veta: Tono?
    
    let extra: [Tono]?

    init(id: String, nombre: String, clase: Clase, lienzo: Lienzo = .malla(.estadio), vida: Vida? = nil,
         soloDeNoche: Bool = false, soloDeDia: Bool = false,
         fondo: Tono? = nil, tarjeta: Tono? = nil, luz: Tono? = nil,
         acento: Tono? = nil, sobreAcento: Tono? = nil,
         vivos: [Tono]? = nil, apagados: [Tono]? = nil, cielo: [Tono]? = nil, particulas: [Tono]? = nil,
         material: Tono? = nil, veta: Tono? = nil, extra: [Tono]? = nil) {
        self.id = id
        self.nombre = nombre
        self.clase = clase
        self.lienzo = lienzo
        self.vida = vida
        self.soloDeNoche = soloDeNoche
        self.soloDeDia = soloDeDia
        self.fondo = fondo
        self.tarjeta = tarjeta
        self.luz = luz
        self.acento = acento
        self.sobreAcento = sobreAcento
        self.vivos = vivos
        self.apagados = apagados
        self.cielo = cielo
        self.particulas = particulas
        self.material = material
        self.veta = veta
        self.extra = extra
    }

    static let original = Tema(id: "original", nombre: "Original", clase: .base)
    
    static let foto = Tema(id: "foto", nombre: "Tu foto", clase: .foto)

    var esOriginal: Bool { id == Tema.original.id }
    var esDeFoto: Bool { clase == .foto }

    var colorDeFondo: Color { fondo?.color ?? Diseno.fondo }
    
    var superficie: Color? { esDeFoto ? Tema.superficieSobreFoto : tarjeta?.color }
    
    var colorAcento: Color { acento?.color ?? Diseno.azul }
    
    var relleno: Color { acento?.color ?? Diseno.azulRelleno }
    var sobreRelleno: Color { sobreAcento?.color ?? .white }

    func tonosDelCampo(_ plataforma: String) -> [Color]? {
        guard let vivos, vivos.count == 3 else { return nil }
        let clave = plataforma == "todas" ? "todo" : plataforma
        let orden = Tema.ordenDelCampo[clave] ?? Tema.ordenDelCampo["otra"] ?? [0, 1, 2]
        return orden.map { vivos[$0].color }
    }

    func tonosDeLaJoya(_ joya: Joya) -> [Color]? {
        guard let apagados, apagados.count == 3 else { return nil }
        let orden = Tema.ordenDeLaJoya[joya.clave] ?? [0, 1, 2]
        return orden.map { apagados[$0].color }
    }

    static let superficieSobreFoto = Color(UIColor { rasgos in
        rasgos.userInterfaceStyle == .dark ? UIColor(white: 0.11, alpha: 0.72)
                                           : UIColor(white: 1, alpha: 0.74)
    })
}

extension Joya {
    
    var clave: String {
        switch self {
        case .agenda: "agenda"
        case .sala: "sala"
        case .cobros: "cobros"
        case .impuestos: "impuestos"
        case .plataforma1: "plataforma1"
        case .plataforma2: "plataforma2"
        case .tienda: "tienda"
        case .todo: "todo"
        }
    }
}

@MainActor
@Observable
final class Temas {
    static let compartido = Temas()
    
    static let clave = "tema.elegido"

    private(set) var elegido: String
    
    private(set) var foto: UIImage?
    
    private(set) var deLaFoto: Tema?
    
    @ObservationIgnored private var fuente: UIImage?

    private init() {
        let guardado = UserDefaults.standard.string(forKey: Self.clave) ?? Tema.original.id
        elegido = Tema.renombrados[guardado] ?? guardado
    }

    var actual: Tema {
        guard Compilacion.beta else { return .original }
        if elegido == Tema.foto.id { return deLaFoto ?? .original }
        return Tema.todos.first { $0.id == elegido } ?? .original
    }

    var nombreElegido: String {
        Tema.todos.first { $0.id == elegido }?.nombre ?? Tema.original.nombre
    }

    func elegir(_ id: String) {
        guard id != elegido else { return }
        elegido = id
        UserDefaults.standard.set(id, forKey: Self.clave)
        aplicarModo()
    }

    func aplicarModo(animado: Bool = true) {
        guard Compilacion.beta else { return }
        let estilo: UIUserInterfaceStyle = actual.soloDeNoche ? .dark : (actual.soloDeDia ? .light : .unspecified)
        for escena in UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }) {
            for ventana in escena.windows where ventana.overrideUserInterfaceStyle != estilo {
                if animado && !UIAccessibility.isReduceMotionEnabled {
                    UIView.transition(with: ventana, duration: 0.35,
                                      options: [.transitionCrossDissolve, .allowUserInteraction]) {
                        ventana.overrideUserInterfaceStyle = estilo
                    }
                } else {
                    ventana.overrideUserInterfaceStyle = estilo
                }
            }
        }
    }

    func ponerFoto(_ imagen: UIImage?) async {
        guard Compilacion.beta else { return }
        guard let imagen else {
            fuente = nil
            withAnimation(Diseno.suave) {
                foto = nil
                deLaFoto = nil
            }
            aplicarModo()
            return
        }
        guard imagen !== fuente, let pequena = Self.reducir(imagen) else { return }
        fuente = imagen
        let r = await Task.detached(priority: .utility) { ColorDeFoto.preparar(pequena) }.value
        
        guard fuente === imagen else { return }
        withAnimation(Diseno.suave) {
            foto = r.difuminada.map { UIImage(cgImage: $0) } ?? UIImage(cgImage: pequena)
            deLaFoto = Tema(id: Tema.foto.id, nombre: Tema.foto.nombre, clase: .foto,
                            acento: Tono(r.claro, r.oscuro),
                            sobreAcento: Tono(r.sobreClaro, r.sobreOscuro))
        }
    }

    private static func reducir(_ imagen: UIImage) -> CGImage? {
        guard imagen.size.width > 0, imagen.size.height > 0 else { return nil }
        let ancho: CGFloat = 240
        let tamano = CGSize(width: ancho, height: (ancho * imagen.size.height / imagen.size.width).rounded())
        let formato = UIGraphicsImageRendererFormat()
        formato.scale = 1
        formato.opaque = true
        return UIGraphicsImageRenderer(size: tamano, format: formato).image { _ in
            imagen.draw(in: CGRect(origin: .zero, size: tamano))
        }.cgImage
    }
}

struct ResultadoDeFoto: Sendable {
    let difuminada: CGImage?
    let claro: UInt32
    let oscuro: UInt32
    let sobreClaro: UInt32
    let sobreOscuro: UInt32
}

enum ColorDeFoto {
    nonisolated static func preparar(_ imagen: CGImage) -> ResultadoDeFoto {
        let (h, s) = tonoDominante(imagen)

        let sat = s < 0.08 ? 0.06 : min(max(s * 1.15, 0.28), 0.78)
        let claro = ajustar(h: h, l: 0.45, s: sat, sobre: [0xFFFFFF, 0xF2F2F7], minimo: 4.5, oscurecer: true)
        let oscuro = ajustar(h: h, l: 0.66, s: sat, sobre: [0x2C2C2E, 0x1C1C1E], minimo: 4.5, oscurecer: false)
        let blanco: UInt32 = 0xFFFFFF, casiNegro: UInt32 = 0x0B0B0F
        return ResultadoDeFoto(
            difuminada: difuminar(imagen),
            claro: claro, oscuro: oscuro,
            sobreClaro: contraste(blanco, claro) >= 4.5 ? blanco : casiNegro,
            sobreOscuro: contraste(casiNegro, oscuro) >= 4.5 ? casiNegro : blanco)
    }

    nonisolated static func difuminar(_ imagen: CGImage) -> CGImage? {
        let ci = CIImage(cgImage: imagen)
        let salida = ci.clampedToExtent()
            .applyingGaussianBlur(sigma: 11)
            .applyingFilter("CIColorControls", parameters: [kCIInputSaturationKey: 1.3])
            .cropped(to: ci.extent)
        return CIContext(options: [.cacheIntermediates: false]).createCGImage(salida, from: ci.extent)
    }

    nonisolated static func tonoDominante(_ imagen: CGImage) -> (h: Double, s: Double) {
        let lado = 24
        var px = [UInt8](repeating: 0, count: lado * lado * 4)
        let hecho = px.withUnsafeMutableBytes { b -> Bool in
            guard let c = CGContext(data: b.baseAddress, width: lado, height: lado, bitsPerComponent: 8,
                                    bytesPerRow: lado * 4, space: CGColorSpaceCreateDeviceRGB(),
                                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            c.interpolationQuality = .medium
            c.draw(imagen, in: CGRect(x: 0, y: 0, width: lado, height: lado))
            return true
        }
        guard hecho else { return (0.6, 0) }
        var x = 0.0, y = 0.0, peso = 0.0, satPesada = 0.0
        for i in stride(from: 0, to: px.count, by: 4) {
            let r = Double(px[i]) / 255, g = Double(px[i + 1]) / 255, b = Double(px[i + 2]) / 255
            let maximo = max(r, g, b), minimo = min(r, g, b)
            guard maximo > 0.12, maximo > minimo else { continue }
            let s = (maximo - minimo) / maximo
            var h: Double
            if maximo == r { h = (g - b) / (maximo - minimo) }
            else if maximo == g { h = 2 + (b - r) / (maximo - minimo) }
            else { h = 4 + (r - g) / (maximo - minimo) }
            h = (h / 6).truncatingRemainder(dividingBy: 1)
            if h < 0 { h += 1 }
            let w = s * s * maximo
            x += cos(h * 2 * .pi) * w
            y += sin(h * 2 * .pi) * w
            peso += w
            satPesada += s * w
        }
        guard peso > 0.001 else { return (0.6, 0) }
        var h = atan2(y, x) / (2 * .pi)
        if h < 0 { h += 1 }
        
        let cuanto = min(1, peso / Double(lado * lado) * 6)
        return (h, satPesada / peso * cuanto)
    }

    nonisolated static func ajustar(h: Double, l: Double, s: Double, sobre: [UInt32], minimo: Double,
                                    oscurecer: Bool) -> UInt32 {
        var l = l
        for _ in 0..<400 {
            let c = rgb(h: h, l: l, s: s)
            if sobre.allSatisfy({ contraste(c, $0) >= minimo }) { return c }
            l = oscurecer ? max(0, l - 0.005) : min(1, l + 0.005)
        }
        return oscurecer ? 0x000000 : 0xFFFFFF
    }

    nonisolated static func rgb(h: Double, l: Double, s: Double) -> UInt32 {
        func v(_ m1: Double, _ m2: Double, _ hue: Double) -> Double {
            var t = hue.truncatingRemainder(dividingBy: 1)
            if t < 0 { t += 1 }
            if t < 1.0 / 6 { return m1 + (m2 - m1) * t * 6 }
            if t < 0.5 { return m2 }
            if t < 2.0 / 3 { return m1 + (m2 - m1) * (2.0 / 3 - t) * 6 }
            return m1
        }
        let (r, g, b): (Double, Double, Double)
        if s == 0 {
            (r, g, b) = (l, l, l)
        } else {
            let m2 = l <= 0.5 ? l * (1 + s) : l + s - l * s
            let m1 = 2 * l - m2
            (r, g, b) = (v(m1, m2, h + 1.0 / 3), v(m1, m2, h), v(m1, m2, h - 1.0 / 3))
        }
        func byte(_ x: Double) -> UInt32 { UInt32((min(max(x, 0), 1) * 255).rounded()) }
        return byte(r) << 16 | byte(g) << 8 | byte(b)
    }

    nonisolated static func luminancia(_ c: UInt32) -> Double {
        func canal(_ x: UInt32) -> Double {
            let v = Double(x) / 255
            return v <= 0.04045 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * canal((c >> 16) & 0xFF) + 0.7152 * canal((c >> 8) & 0xFF) + 0.0722 * canal(c & 0xFF)
    }

    nonisolated static func contraste(_ a: UInt32, _ b: UInt32) -> Double {
        let la = luminancia(a), lb = luminancia(b)
        return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)
    }
}

private struct ClaveDelTema: EnvironmentKey {
    static var defaultValue: Tema { .original }
}

extension EnvironmentValues {
    
    var tema: Tema {
        get { self[ClaveDelTema.self] }
        set { self[ClaveDelTema.self] = newValue }
    }
}

struct AplicarTema: ViewModifier {
    func body(content: Content) -> some View {
        if Compilacion.beta {
            let tema = Temas.compartido.actual
            content
                .environment(\.tema, tema)
                .tint(tema.acento?.color)
        } else {
            content
        }
    }
}

struct EstiloAcento: ShapeStyle {
    func resolve(in entorno: EnvironmentValues) -> Color {
        entorno.tema.colorAcento
    }
}

extension ShapeStyle where Self == EstiloAcento {
    
    static var acento: EstiloAcento { EstiloAcento() }
}

private struct RellenoDelTema: ViewModifier {
    let original: Color?
    @Environment(\.tema) private var tema

    func body(content: Content) -> some View {
        if let acento = tema.acento {
            content
                .tint(acento.color)
                .foregroundStyle(tema.sobreRelleno)
        } else {
            content.tint(original)
        }
    }
}

private struct ListaConTema: ViewModifier {
    @Environment(\.tema) private var tema

    func body(content: Content) -> some View {
        content
            .scrollContentBackground(tema.esOriginal ? .automatic : .hidden)
            .background {
                if !tema.esOriginal { FondoDelTema().ignoresSafeArea() }
            }
            .environment(\.dentroDeUnaLista, true)
    }
}

private struct ClaveDentroDeUnaLista: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    
    var dentroDeUnaLista: Bool {
        get { self[ClaveDentroDeUnaLista.self] }
        set { self[ClaveDentroDeUnaLista.self] = newValue }
    }
}

extension View {
    
    func rellenoDelTema(_ original: Color? = Diseno.azulRelleno) -> some View {
        modifier(RellenoDelTema(original: original))
    }

    func listaConTema() -> some View {
        modifier(ListaConTema())
    }
}

struct FondoDelTema: View {
    @Environment(\.tema) private var tema

    var body: some View {
        ZStack {
            if tema.esDeFoto {
                FondoDeFoto()
            } else if tema.esOriginal {
                tema.colorDeFondo
            } else {
                
                FondoDeTema(sitio: .pantalla)
            }
        }
    }
}

struct FondoDeFoto: View {
    static let veloClaro = 0.62
    static let veloOscuro = 0.64

    @Environment(\.colorScheme) private var modo

    var body: some View {
        if let foto = Temas.compartido.foto {
            Color.clear
                .overlay {
                    Image(uiImage: foto)
                        .resizable()
                        .scaledToFill()
                }
                .overlay((modo == .dark ? Color.black : Color.white)
                    .opacity(modo == .dark ? Self.veloOscuro : Self.veloClaro))
                .clipped()
                .accessibilityHidden(true)
        } else {
            Diseno.fondo
        }
    }
}

struct GaleriaDeTemas: View {
    
    var enCristal = false

    @Environment(EstadoPanel.self) private var panel
    @Environment(\.accessibilityReduceMotion) private var menosMovimiento
    @Environment(\.dynamicTypeSize) private var letra
    @Namespace private var espacio
    @State private var eligiendoFoto = false
    @State private var fotoElegida: PhotosPickerItem?
    @State private var fallo: String?

    private var temas: Temas { .compartido }

    private struct Seccion {
        let clases: [Tema.Clase]
        let titulo: String?
    }

    private static let secciones: [Seccion] = [
        Seccion(clases: [.base, .foto], titulo: nil),
        Seccion(clases: [.vida], titulo: "Con vida"),
        Seccion(clases: [.textura], titulo: "Texturas"),
        Seccion(clases: [.difuminado], titulo: "Difuminados"),
        Seccion(clases: [.plano], titulo: "Colores planos"),
    ]

    private var columnas: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: Diseno.hueco2, alignment: .top),
              count: letra.isAccessibilitySize ? 2 : 3)
    }

    private var apoyo: AnyShapeStyle {
        enCristal ? Diseno.apoyoEnCristal : AnyShapeStyle(.secondary)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Diseno.hueco4) {
            ForEach(Self.secciones.indices, id: \.self) { i in
                seccion(Self.secciones[i])
                    .id("seccion-\(Self.secciones[i].clases.first.map { "\($0)" } ?? "")")
            }
            if let fallo {
                Text(fallo)
                    .font(.footnote)
                    .foregroundStyle(Diseno.rojo)
            }
        }
        .photosPicker(isPresented: $eligiendoFoto, selection: $fotoElegida, matching: .images)
        .onChange(of: fotoElegida) { _, elegida in
            guard let elegida else { return }
            Task { await usarFoto(elegida) }
        }
        .sensoryFeedback(.selection, trigger: temas.elegido)
        #if MAQUETA
        .task {
            guard let id = Maqueta.cambiarTema, let t = Tema.todos.first(where: { $0.id == id }) else { return }
            try? await Task.sleep(for: .seconds(3))
            tocar(t)
        }
        #endif
    }

    private func seccion(_ s: Seccion) -> some View {
        let lista = Tema.todos.filter { s.clases.contains($0.clase) }
        return VStack(alignment: .leading, spacing: Diseno.hueco2) {
            if let titulo = s.titulo {
                Text(titulo)
                    .font(.headline)
                    .padding(.leading, 4)
                    .accessibilityAddTraits(.isHeader)
            }
            LazyVGrid(columns: columnas, alignment: .leading, spacing: Diseno.hueco3) {
                ForEach(lista) { celda($0).id($0.id) }
            }

            if s.clases.contains(.foto) {
                Text("«Tu foto» es la imagen del centro de control.")
                    .font(.footnote)
                    .foregroundStyle(apoyo)
                    .padding(.leading, 4)
            }
            if s.clases.contains(.vida) {
                
                Label("Se mueven y chocan con lo que hay en pantalla; gastan algo más de batería.",
                      systemImage: "sparkles")
                    .font(.footnote)
                    .foregroundStyle(apoyo)
                    .padding(.leading, 4)
            }
            if lista.contains(where: \.soloDeNoche) || lista.contains(where: \.soloDeDia) {
                HStack(spacing: Diseno.hueco2) {
                    if lista.contains(where: \.soloDeNoche) {
                        Label("Pone la app en oscuro", systemImage: "moon.fill")
                    }
                    if lista.contains(where: \.soloDeDia) {
                        Label("En claro", systemImage: "sun.max.fill")
                    }
                }
                .font(.footnote)
                .foregroundStyle(apoyo)
                .padding(.leading, 4)
            }
        }
    }

    @ViewBuilder
    private func celda(_ t: Tema) -> some View {
        
        if t.esDeFoto && temas.foto != nil {
            boton(t).contextMenu {
                Button("Cambiar la foto", systemImage: "photo") { eligiendoFoto = true }
            }
        } else {
            boton(t)
        }
    }

    private func boton(_ t: Tema) -> some View {
        let elegido = temas.elegido == t.id
        let muestra = t.esDeFoto ? (temas.deLaFoto ?? t) : t
        let sinFoto = t.esDeFoto && temas.foto == nil
        return Button { tocar(t) } label: {
            VStack(spacing: Diseno.hueco1 + 2) {
                MuestraTema(tema: muestra, foto: t.esDeFoto ? temas.foto : nil)
                    .padding(4)
                    .overlay {
                        if elegido {
                            RoundedRectangle(cornerRadius: MuestraTema.radio + 4, style: .continuous)
                                .strokeBorder(.acento, lineWidth: 2.5)
                                .matchedGeometryEffect(id: "aro", in: espacio)
                        }
                    }
                HStack(spacing: 4) {
                    Text(t.nombre)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    if t.soloDeNoche || t.soloDeDia {
                        Image(systemName: t.soloDeNoche ? "moon.fill" : "sun.max.fill")
                            .font(.caption2)
                            .foregroundStyle(apoyo)
                    }
                }
                .font(.footnote.weight(elegido ? .semibold : .regular))
                .foregroundStyle(.primary)
            }
        }
        .buttonStyle(MuestraPulsada())
        .accessibilityLabel(t.nombre)
        .accessibilityValue(t.soloDeNoche ? "Pone la app en oscuro" : (t.soloDeDia ? "Pone la app en claro" : ""))
        .accessibilityHint(sinFoto ? "Elige una foto" : "")
        .accessibilityAddTraits(elegido ? .isSelected : [])
    }

    static func llevarAlElegido(_ lector: ScrollViewProxy) {
        #if MAQUETA
        if let s = Maqueta.seccionDeTemas {
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(500))
                lector.scrollTo("seccion-\(s)", anchor: .top)
            }
            return
        }
        #endif
        let id = Temas.compartido.elegido
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(16))
            var sinAnimar = Transaction()
            sinAnimar.disablesAnimations = true
            withTransaction(sinAnimar) { lector.scrollTo(id, anchor: .center) }
        }
    }

    private func tocar(_ t: Tema) {
        fallo = nil
        if t.esDeFoto && temas.foto == nil {
            eligiendoFoto = true
            return
        }
        withAnimation(menosMovimiento ? .easeInOut(duration: 0.2) : .smooth(duration: 0.45)) {
            temas.elegir(t.id)
        }
    }

    private func usarFoto(_ elegida: PhotosPickerItem) async {
        defer { fotoElegida = nil }
        guard let datos = try? await elegida.loadTransferable(type: Data.self),
              await panel.ponerFondo(datos) else {
            fallo = "No se ha podido usar esa imagen."
            return
        }
        withAnimation(.smooth(duration: 0.45)) { temas.elegir(Tema.foto.id) }
    }
}

private struct MuestraPulsada: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var menosMovimiento

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .contentShape(.rect)
            .scaleEffect(configuration.isPressed && !menosMovimiento ? 0.96 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.8), value: configuration.isPressed)
    }
}

struct MuestraTema: View {
    let tema: Tema
    
    var foto: UIImage?

    static let radio: CGFloat = 18

    @Environment(\.colorScheme) private var modo

    var body: some View {
        let oscuro = tema.soloDeNoche || (modo == .dark && !tema.soloDeDia)
        Pantallita(tema: tema, foto: foto, oscuro: oscuro)
            .environment(\.colorScheme, oscuro ? .dark : .light)
    }
}

private struct Pantallita: View {
    let tema: Tema
    let foto: UIImage?
    let oscuro: Bool

    var body: some View {
        let forma = RoundedRectangle(cornerRadius: MuestraTema.radio, style: .continuous)
        Color.clear
            .aspectRatio(0.6, contentMode: .fit)
            .overlay {
                GeometryReader { g in
                    contenido(g.size)
                }
            }
            .clipShape(forma)
            .overlay(forma.strokeBorder(Color.primary.opacity(oscuro ? 0.18 : 0.1), lineWidth: 0.75))
            .accessibilityHidden(true)
    }

    private func contenido(_ s: CGSize) -> some View {
        ZStack(alignment: .topLeading) {
            fondo(s.width)
            if tema.esDeFoto && foto == nil {

                VStack(spacing: s.width * 0.05) {
                    Image(systemName: "photo.badge.plus")
                        .font(.system(size: s.width * 0.17))
                    Text("Elegir foto")
                        .font(.system(size: max(9, s.width * 0.085), weight: .semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .foregroundStyle(Marcador.apoyo)
                .frame(width: s.width, height: s.height)
            } else {
                maqueta(s.width, s.height)
            }
        }
        .frame(width: s.width, height: s.height)
    }

    @ViewBuilder
    private func fondo(_ w: CGFloat) -> some View {
        if tema.esDeFoto {
            if let foto {
                Color.clear
                    .overlay { Image(uiImage: foto).resizable().scaledToFill() }
                    .overlay((oscuro ? Color.black : Color.white)
                        .opacity(oscuro ? FondoDeFoto.veloOscuro : FondoDeFoto.veloClaro))
                    .clipped()
            } else {
                ZStack {
                    Diseno.fondo
                    RoundedRectangle(cornerRadius: MuestraTema.radio - 6, style: .continuous)
                        .strokeBorder(Marcador.apoyo.opacity(0.45),
                                      style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                        .padding(6)
                }
            }
        } else if tema.esOriginal {
            let base = tema.colorDeFondo

            let tonos = Tema.coloresDeMuestra(tema, oscuro: oscuro)
            let medio = tonos.map { $0.mix(with: base, by: 0.55) }
            let luz = Joya.agenda.luz
            ZStack {
                MeshGradient(width: 3, height: 4,
                             points: [[0, 0], [0.5, 0], [1, 0],
                                      [0, 0.24], [0.5, 0.27], [1, 0.22],
                                      [0, 0.52], [0.5, 0.56], [1, 0.5],
                                      [0, 1], [0.5, 1], [1, 1]],
                             colors: [tonos[0], tonos[1], tonos[2], tonos[0], tonos[1], tonos[2],
                                      medio[0], medio[1], medio[2], base, base, base])
                RadialGradient(colors: [luz.opacity(oscuro ? 0.34 : 0.3), luz.opacity(0)],
                               center: UnitPoint(x: 0.5, y: 0.1),
                               startRadius: 0, endRadius: w * 0.75)
                    .blendMode(oscuro ? .plusLighter : .normal)
            }
        } else {

            ZStack {
                switch tema.lienzo {
                case .malla(let forma):
                    MallaDeTema.malla(forma, colores: Tema.coloresDeMuestra(tema, oscuro: oscuro),
                                      base: tema.colorDeFondo, t: 0)
                    if let luz = tema.luz?.color {
                        RadialGradient(colors: [luz.opacity(oscuro ? 0.34 : 0.3), luz.opacity(0)],
                                       center: UnitPoint(x: 0.5, y: 0.1),
                                       startRadius: 0, endRadius: w * 0.75)
                            .blendMode(oscuro ? .plusLighter : .normal)
                    }
                case .plano:
                    Tema.coloresDeMuestra(tema, oscuro: oscuro).first ?? tema.colorDeFondo
                case .textura(let material):
                    MiniaturaDeTextura(textura: material, tema: tema, oscuro: oscuro)
                case .cielo:
                    LinearGradient(colors: (tema.cielo ?? []).map(\.color), startPoint: .top, endPoint: .bottom)
                }
                if let vida = tema.vida {
                    if vida == .aurora { CortinasDeAurora(colores: tema.particulas ?? []) }
                    MiniaturaDeVida(tema: tema, vida: vida, oscuro: oscuro)
                }
            }
        }
    }

    private func maqueta(_ w: CGFloat, _ h: CGFloat) -> some View {
        let tinta = Color.primary
        let superficie = tema.superficie ?? Diseno.superficie
        return ZStack(alignment: .topLeading) {
            VStack(alignment: .leading, spacing: h * 0.022) {
                Capsule().fill(tinta.opacity(0.5))
                    .frame(width: w * 0.3, height: max(3, h * 0.02))
                Capsule().fill(tinta.opacity(0.88))
                    .frame(width: w * 0.58, height: h * 0.058)
                Capsule().fill(tinta.opacity(0.38))
                    .frame(width: w * 0.44, height: max(2.5, h * 0.017))
            }
            .padding(.leading, w * 0.1)
            .padding(.top, h * 0.14)

            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: h * 0.02) {
                    Capsule().fill(tinta.opacity(0.7))
                        .frame(width: w * 0.3, height: max(2.5, h * 0.018))
                    Capsule().fill(tinta.opacity(0.32))
                        .frame(width: w * 0.2, height: max(2, h * 0.014))
                }
                Spacer(minLength: 0)
                
                Capsule().fill(tema.colorAcento)
                    .frame(width: w * 0.2, height: w * 0.12)
                    .overlay(alignment: .trailing) {
                        Circle().fill(.white).padding(w * 0.013)
                    }
            }
            .padding(.horizontal, w * 0.07)
            .frame(width: w * 0.82, height: h * 0.15)
            .background(superficie, in: .rect(cornerRadius: w * 0.07, style: .continuous))
            .offset(x: w * 0.09, y: h * 0.5)

            HStack(spacing: w * 0.075) {
                Circle().fill(tema.colorAcento).frame(width: w * 0.062, height: w * 0.062)
                ForEach(0..<3, id: \.self) { _ in
                    Circle().fill(tinta.opacity(0.3)).frame(width: w * 0.05, height: w * 0.05)
                }
            }
            .frame(width: w * 0.62, height: h * 0.075)
            .background {
                Capsule()
                    .fill(Color.white.opacity(oscuro ? 0.13 : 0.72))
                    .overlay(Capsule().strokeBorder(Color.white.opacity(oscuro ? 0.12 : 0.6), lineWidth: 0.5))
                    .shadow(color: .black.opacity(oscuro ? 0.3 : 0.08), radius: 3, y: 1)
            }
            .offset(x: w * 0.19, y: h * 0.875)
        }
        .frame(width: w, height: h, alignment: .topLeading)
    }
}

struct MuestraRedonda: View {
    let tema: Tema
    var foto: UIImage?

    var body: some View {
        ZStack {
            if tema.esDeFoto, let foto {
                Image(uiImage: foto).resizable().scaledToFill()
            } else if case .textura(let material) = tema.lienzo {
                MiniaturaDeTextura(textura: material, tema: tema, oscuro: tema.soloDeNoche)
            } else if case .cielo = tema.lienzo, let cielo = tema.cielo {
                LinearGradient(colors: cielo.map(\.color), startPoint: .top, endPoint: .bottom)
                if let vida = tema.vida { MiniaturaDeVida(tema: tema, vida: vida, oscuro: tema.soloDeNoche) }
            } else {
                let tonos = Tema.coloresDeMuestra(tema, oscuro: tema.soloDeNoche)
                AngularGradient(colors: tonos + [tonos[0]], center: .center)
            }
            Circle()
                .fill(tema.colorAcento)
                .frame(width: 16, height: 16)
                .overlay(Circle().strokeBorder(.white.opacity(0.9), lineWidth: 1.5))
        }
        .clipShape(.circle)
        .environment(\.colorScheme, tema.soloDeNoche ? .dark : .light)
        .accessibilityHidden(true)
    }
}

extension Tema {

    func veloEnElPanel(minimo: Double = 0.22) -> Double {

        var pintados: [UInt32]
        switch lienzo {
        case .malla(let forma):
            pintados = (vivos ?? []).map(\.oscuro) + [fondo].compactMap { $0?.oscuro }

            if forma == .halo {
                pintados += pintados.map { c in
                    func canal(_ x: UInt32) -> UInt32 { let v = x & 0xFF; return v + UInt32((Double(255 - v) * 0.28).rounded()) }
                    return canal(c >> 16) << 16 | canal(c >> 8) << 8 | canal(c)
                }
            }
        case .plano: pintados = (vivos ?? []).map(\.oscuro)
        case .textura: pintados = [material ?? fondo].compactMap { $0?.oscuro }
        case .cielo: pintados = (cielo ?? []).map(\.oscuro)
        }
        
        if vida == .sol { pintados.append(0xFFFFFF) }
        guard let peor = pintados.max(by: { ColorDeFoto.luminancia($0) < ColorDeFoto.luminancia($1) }) else {
            return minimo
        }
        var velo = minimo
        while velo < 0.9 {
            let k = 1 - velo
            func canal(_ c: UInt32) -> UInt32 { min(255, UInt32((Double(c & 0xFF) * k).rounded()) + Self.brilloDelCristal) }
            let r = canal(peor >> 16), g = canal(peor >> 8), b = canal(peor)
            if ColorDeFoto.contraste(0xFFFFFF, r << 16 | g << 8 | b) >= 4.5 { return velo }
            velo += 0.01
        }
        return velo
    }

    static let brilloDelCristal: UInt32 = 60

    static func coloresDeMuestra(_ tema: Tema, oscuro: Bool) -> [Color] {
        if let campo = tema.tonosDelCampo("todo") { return campo }
        return ["todo", "tienda", "plataforma2"].map { CampoDeColor.tonos($0, tema: .original, oscuro: oscuro)[0] }
    }
}

struct PantallaTemas: View {
    var body: some View {
        ScrollViewReader { lector in
            ScrollView {
                GaleriaDeTemas()
                    .padding(.horizontal, Diseno.margen)
                    .padding(.vertical, Diseno.hueco2)
            }
            .onAppear { GaleriaDeTemas.llevarAlElegido(lector) }
        }
        .fondoDePantalla()
        .navigationTitle("Temas")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct HojaTemas: View {
    @Environment(\.dismiss) private var cerrar
    @Environment(\.accessibilityReduceTransparency) private var menosTransparencia
    @State private var altura: PresentationDetent = .medium

    private var opaca: Bool { altura == .large || menosTransparencia }

    var body: some View {
        NavigationStack {
            ScrollViewReader { lector in
                ScrollView {
                    GaleriaDeTemas(enCristal: !opaca)
                        .padding(.horizontal, Diseno.margen)
                        .padding(.vertical, Diseno.hueco2)
                }
                .onAppear { GaleriaDeTemas.llevarAlElegido(lector) }
            }
            .background {
                if opaca { FondoDelTema().ignoresSafeArea().transition(.opacity) }
            }
            .animation(Diseno.suave, value: opaca)
            .containerBackground(.clear, for: .navigation)
            .navigationTitle("Temas")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(role: .close) { cerrar() }
                }
            }
        }
        .presentationDetents([.medium, .large], selection: $altura)
        .presentationContentInteraction(.scrolls)
    }
}
