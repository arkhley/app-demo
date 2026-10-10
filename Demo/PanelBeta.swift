import SwiftUI
import PhotosUI
#if canImport(UIKit)
import UIKit
#endif

@MainActor
@Observable
final class EstadoPanel {

    var progreso: CGFloat = 0

    private(set) var enPantalla = false
    
    var conElDedo = false
    
    var ajuste: AjusteLateral?

    var isla = CGRect(x: 157, y: 14, width: 126, height: 37.33)
    
    var alto: CGFloat = 956
    
    private(set) var meta = false
    
    var fondoDeLaLosa: CGFloat?

    private(set) var fondo: UIImage?

    init() {
        #if MAQUETA
        if let demo = Maqueta.fondoDePrueba {
            fondo = demo
            fondoLeido = true
        }
        #endif
    }

    @ObservationIgnored private var fondoLeido = false

    func cargarFondo() async {
        guard !fondoLeido else { return }
        fondoLeido = true
        let guardado = await FondoDelPanel.cargar()
        if fondo == nil { fondo = guardado }
    }

    func ponerFondo(_ datos: Data) async -> Bool {
        guard let imagen = await FondoDelPanel.guardar(datos) else { return false }
        withAnimation(Diseno.suave) { fondo = imagen }

        FondoDelCerrojo.recordado = imagen
        await Temas.compartido.ponerFoto(imagen)
        return true
    }

    func quitarFondo() {
        FondoDelPanel.borrar()
        withAnimation(Diseno.suave) { fondo = nil }
        FondoDelCerrojo.recordado = nil
        Task { await Temas.compartido.ponerFoto(nil) }
    }

    private(set) var pista = 0
    
    var bordeDeLaCapsula: CGFloat?

    func quizaPista(ahora: Date = .now) {
        guard !enPantalla else { return }
        let d = UserDefaults.standard
        let veces = d.integer(forKey: Self.clavePistaVeces)
        let abierto = d.object(forKey: Self.claveAbierto) as? Date
        if let ultima = d.object(forKey: Self.clavePistaUltima) as? Date {
            let desdeLaPista = ahora.timeIntervalSince(ultima)
            let noLoAbrioDesde = abierto.map { $0 < ultima } ?? true
            let unaSemanaSinAbrir = abierto.map { ahora.timeIntervalSince($0) > 7 * 86_400 } ?? true
            let toca = (veces < 3 && noLoAbrioDesde && desdeLaPista > 20 * 3_600)
                || (unaSemanaSinAbrir && desdeLaPista > 7 * 86_400)
            guard toca else { return }
        }
        d.set(ahora, forKey: Self.clavePistaUltima)
        d.set(veces + 1, forKey: Self.clavePistaVeces)
        pista += 1
    }

    private static let clavePistaUltima = "panel.pista.ultima"
    private static let clavePistaVeces = "panel.pista.veces"
    private static let claveAbierto = "panel.abierto.ultimo"

    var fondoAbierto: CGFloat { min(fondoDeLaLosa ?? alto * 0.8, alto - 24) }

    var abierto: Bool {
        get { meta }
        set { if newValue { abrir() } else { cerrar() } }
    }

    var recorrido: CGFloat { max(fondoAbierto - isla.maxY, 1) }

    func abrir(velocidad: CGFloat = 0) {
        enPantalla = true
        meta = true
        UserDefaults.standard.set(Date.now, forKey: Self.claveAbierto)
        withAnimation(Self.muelle(abrir: true, velocidad: velocidad)) { progreso = 1 }
    }

    func cerrar(velocidad: CGFloat = 0) {
        meta = false
        withAnimation(Self.muelle(abrir: false, velocidad: velocidad)) {
            progreso = 0
        } completion: { [weak self] in
            guard let self, !self.meta, !self.conElDedo else { return }
            self.enPantalla = false
        }
    }

    func seguir(_ p: CGFloat) {
        enPantalla = true
        if p > 1 {
            let extra = (p - 1) * recorrido
            progreso = 1 + (extra * 400 * 0.55) / (400 + 0.55 * extra) * 0.4 / recorrido
        } else {
            progreso = max(0, p)
        }
    }

    private static func muelle(abrir: Bool, velocidad: CGFloat) -> Animation {
        if UIAccessibility.isReduceMotionEnabled { return .easeOut(duration: 0.2) }
        
        return .interpolatingSpring(.init(response: abrir ? 0.46 : 0.38, dampingRatio: abrir ? 0.86 : 1),
                                    initialVelocity: min(max(velocidad, -4), 12))
    }
}

extension Herramienta {
    
    var corto: String {
        switch self {
        case .directo: return "En directo"
        case .ocultar: return "Ocultar"
        case .tokens: return "Tokens"
        default: return titulo
        }
    }
}

struct PanelBeta: View {
    @Environment(EstadoPanel.self) private var estado
    @Environment(Sesion.self) private var sesion
    @Environment(\.openURL) private var abrirWeb
    @Environment(\.accessibilityReduceMotion) private var menosMovimiento
    @Environment(\.accessibilityReduceTransparency) private var menosTransparencia
    @Environment(\.dynamicTypeSize) private var letra

    @Environment(\.tema) private var tema
    @State private var hoja: HojaHerramienta?
    @State private var eligiendoFondo = false
    @State private var fotoDelFondo: PhotosPickerItem?
    @State private var preguntandoDirecto = false
    @State private var avisando = false
    @State private var aviso: (texto: String, bien: Bool)?
    @State private var tocada = 0
    
    @State private var desde: CGFloat = 1

    private var privacidad: Privacidad { .compartida }

    static let umbral: CGFloat = 0.3

    private static let veloDelFondo = 0.4

    private static let veloDelTema = 0.22

    private var conTema: Bool { !tema.esOriginal && !tema.esDeFoto }

    var body: some View {
        ZStack(alignment: .top) {
            
            Color.clear.allowsHitTesting(false)
            if estado.enPantalla { centroDeControl }
        }
        .sheet(item: $hoja) { h in
            Group {
                switch h {
                case .tokens: HojaTokens()
                case .adelanto: HojaAdelanto()
                case .enlaces: HojaEnlaces()
                case .comprobar: HojaComprobar()
                case .tema: HojaTemas()
                }
            }
            .hojaQueChoca()
        }
        .confirmationDialog("¿Avisar en el canal de que estás en directo?",
                            isPresented: $preguntandoDirecto, titleVisibility: .visible) {
            Button("Avisar") { Task { await avisarDirecto() } }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Se publica en el canal de Tienda y se borra sola a las 2 horas.")
        }
        
        .photosPicker(isPresented: $eligiendoFondo, selection: $fotoDelFondo, matching: .images)
        .onChange(of: fotoDelFondo) { _, elegida in
            guard let elegida else { return }
            Task {
                defer { fotoDelFondo = nil }
                guard let datos = try? await elegida.loadTransferable(type: Data.self),
                      await estado.ponerFondo(datos) else {
                    aviso = ("No se ha podido usar esa imagen.", false)
                    return
                }
            }
        }
        .sensoryFeedback(.selection, trigger: tocada)
        
        .sensoryFeedback(.impact(weight: .light), trigger: estado.progreso > Self.umbral) { _, pasa in
            pasa && estado.conElDedo
        }
        .animation(Diseno.suave, value: aviso?.texto)
        .onChange(of: estado.abierto) { _, abierto in
            if abierto { aviso = nil }
        }
        #if MAQUETA
        .task {
            
            guard let h = Maqueta.herramienta.flatMap(HojaHerramienta.init(rawValue:)) else { return }
            try? await Task.sleep(for: .seconds(2))
            estado.abierto = false
            hoja = h
        }
        #endif
    }

    private var p: CGFloat { menosMovimiento ? 1 : estado.progreso }

    private var arribaDeLasPiezas: CGFloat { estado.isla.maxY + 22 }

    private var negro: Double {
        Double(1 - FormaDeIsla.suave((p - 0.06) / 0.3))
    }

    private var centroDeControl: some View {
        let forma = FormaDeIsla(p: p, isla: estado.isla, fondo: estado.fondoAbierto)
        let isla = estado.isla
        let visto = Double(min(p, 1))
        let fondo = estado.fondo
        return ZStack(alignment: .top) {
            
            Color.clear
                .contentShape(.rect)
                .onTapGesture { cerrar() }
                .accessibilityHidden(true)
            if conTema {
                
                FueraDeLaLosa(forma: forma)
                    .fill(Color.black.opacity(0.45 * visto), style: FillStyle(eoFill: true))
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                FondoDeTema(sitio: .panel)
                    .overlay(Color.black.opacity(tema.veloEnElPanel(minimo: Self.veloDelTema)))
                    .clipShape(forma)
                    .opacity(menosTransparencia ? 1 : Double(FormaDeIsla.suave((p - 0.6) / 0.4)))
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            } else if let fondo {

                FueraDeLaLosa(forma: forma)
                    .fill(Color.black.opacity(0.45 * visto), style: FillStyle(eoFill: true))
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                Color.clear
                    .overlay {
                        Image(uiImage: fondo)
                            .resizable()
                            .scaledToFill()
                    }
                    .overlay(Color.black.opacity(Self.veloDelFondo))
                    .clipShape(forma)
                    .opacity(menosTransparencia ? 1 : Double(FormaDeIsla.suave((p - 0.6) / 0.4)))
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            } else {
                
                Color.black
                    .opacity(0.45 * visto)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
            cuerpo(forma, conFondo: fondo != nil || conTema)
            
            forma
                .fill(LinearGradient(stops: [
                    .init(color: .black.opacity(0.7), location: 0),
                    .init(color: .black.opacity(0), location: min(1, (isla.maxY + 46) / max(estado.alto, 1))),
                ], startPoint: .top, endPoint: .bottom))
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            
            CentroDeControl(activa: activa, trabajando: trabajando, tocar: tocar, cerrar: cerrar,
                            aviso: aviso, arriba: arribaDeLasPiezas, alMedir: medirLosa,
                            conFondo: fondo != nil || conTema, elegirFondo: { tocada += 1; eligiendoFondo = true },
                            quitarFondo: { estado.quitarFondo() })
                .environment(\.capaDeChoque, .panel)
                .scaleEffect(0.7 + 0.3 * FormaDeIsla.suave(p),
                             anchor: UnitPoint(x: 0.5, y: isla.midY / max(estado.alto, 1)))
                .clipShape(forma)
            
            if conTema && tema.vida != nil {
                CapaDelanteDeLaVida(capa: .panel)
                    .clipShape(forma)
                    .allowsHitTesting(false)
            }
            
            forma
                .fill(Color.black.opacity(negro))
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
        .ignoresSafeArea()
        
        .environment(\.colorScheme, .dark)
        .opacity(menosMovimiento ? Double(min(estado.progreso, 1)) : 1)

        .simultaneousGesture(empujarParaCerrar, including: letra.isAccessibilitySize ? .subviews : .all)

        .defersSystemGestures(on: estado.abierto ? .bottom : [])
        
        .allowsHitTesting(estado.abierto)
        .accessibilityAddTraits(.isModal)
        .accessibilityAction(.escape) { cerrar() }
    }

    private func cuerpo(_ forma: FormaDeIsla, conFondo: Bool) -> some View {
        Color.clear
            .cristal(conFondo ? (menosTransparencia ? .identity : .clear)
                              : .regular.tint(Color.black.opacity(0.3)), en: forma)
            .contentShape(forma)
            .onTapGesture {}
            .accessibilityHidden(true)
    }

    private func medirLosa(_ altoPiezas: CGFloat) {
        let fondo = arribaDeLasPiezas + altoPiezas + 22
        if abs((estado.fondoDeLaLosa ?? 0) - fondo) > 0.5 { estado.fondoDeLaLosa = fondo }
    }

    private var empujarParaCerrar: some Gesture {
        DragGesture(minimumDistance: 12, coordinateSpace: .global)
            .onChanged { g in
                guard estado.abierto, !menosMovimiento else { return }
                if !estado.conElDedo {
                    estado.conElDedo = true
                    desde = estado.progreso
                }
                estado.seguir(desde + g.translation.height / estado.recorrido)
            }
            .onEnded { g in
                guard estado.conElDedo else { return }
                estado.conElDedo = false
                let recorrido = estado.recorrido
                let v = g.velocity.height
                let destino = estado.progreso + Self.proyeccion(v) / recorrido
                if destino < 0.55 {
                    estado.cerrar(velocidad: -v / max(estado.progreso * recorrido, 1))
                } else {
                    estado.abrir(velocidad: v / max(abs(1 - estado.progreso) * recorrido, 1))
                }
            }
    }

    static func proyeccion(_ velocidad: CGFloat, deceleracion: CGFloat = 0.998) -> CGFloat {
        (velocidad / 1000) * deceleracion / (1 - deceleracion)
    }

    private func activa(_ h: Herramienta) -> Bool { h == .ocultar && privacidad.oculta }
    private func trabajando(_ h: Herramienta) -> Bool { h == .directo && avisando }

    private func tocar(_ h: Herramienta) {
        tocada += 1
        aviso = nil
        switch h {
        case .directo:
            preguntandoDirecto = true
        case .ocultar:
            withAnimation(Diseno.suave) { privacidad.oculta.toggle() }
        case .bloquear:
            cerrar()
            sesion.bloquear()
        case .tokens, .adelanto, .enlaces, .comprobar, .tema:

            cerrar()
            let h2 = HojaHerramienta(rawValue: h.rawValue) ?? .tokens
            Task {
                try? await Task.sleep(for: .milliseconds(300))
                hoja = h2
            }
        case .asesoria, .monedero, .plataforma1, .plataforma2:
            if let url = h.web { abrirWeb(url) }
        case .codigos, .videos, .plataformas:
            cerrar()

            Task {
                try? await Task.sleep(for: .milliseconds(260))
                estado.ajuste = h.ajuste
            }
        }
    }

    private func cerrar() {
        estado.cerrar()
    }

    private func avisarDirecto() async {
        avisando = true
        defer { avisando = false }
        do {
            let r = try await API.pedir("api/canal/accion", metodo: "POST",
                                        cuerpo: ["accion": "directo"], testigo: sesion.testigo)
            let ok = r["ok"] as? Bool ?? false
            aviso = (ok ? "Avisado: sale en el canal en unos segundos."
                        : (r["mensaje"] as? String ?? "No se ha podido."), ok)
        } catch {
            aviso = (error.localizedDescription, false)
        }
    }
}

struct FormaDeIsla: Shape {
    var p: CGFloat
    let isla: CGRect
    
    let fondo: CGFloat

    var animatableData: CGFloat {
        get { p }
        set { p = newValue }
    }

    static func suave(_ x: CGFloat) -> CGFloat {
        let t = min(1, max(0, x))
        return t * t * (3 - 2 * t)
    }

    func path(in r: CGRect) -> Path {
        let q = max(0, p)
        let margen: CGFloat = 10
        let despliega = Self.suave(q / 0.16)
        let ancho = isla.width + (r.width - 2 * margen - isla.width) * despliega
        let arriba = isla.minY
        let abajo = isla.maxY + (fondo - isla.maxY) * q
        let alto = max(abajo - arriba, isla.height)
        let radio = min(isla.height / 2 + (44 - isla.height / 2) * despliega, alto / 2, ancho / 2)
        let rect = CGRect(x: r.midX - ancho / 2, y: arriba, width: ancho, height: alto)
        return Path(roundedRect: rect, cornerRadius: radio, style: .continuous)
    }
}

struct PistaDelPanel: View {
    let veces: Int
    
    let ancho: CGFloat

    @Environment(\.accessibilityReduceMotion) private var menosMovimiento

    struct Raya {
        var opacidad: Double = 0
        var bajada: CGFloat = 0
    }

    static let recorrido: CGFloat = 14

    var body: some View {

        VStack(spacing: 5) {
            palabra
            raya
        }
        .foregroundStyle(.white)
        .shadow(color: .black.opacity(0.25), radius: 4, y: 1)
        .fixedSize()
        .frame(maxWidth: ancho, alignment: .leading)
        
        .dynamicTypeSize(...DynamicTypeSize.xxLarge)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var inicio: (palabra: Double, raya: Raya) {
        #if MAQUETA
        if let f = Maqueta.pistaFija {
            return (1, Raya(opacidad: f < 0.6 ? 1 : 1 - Double((f - 0.6) / 0.4),
                            bajada: Self.recorrido * f))
        }
        #endif
        return (0, Raya())
    }

    private var palabra: some View {
        let quieta = menosMovimiento ? 2.4 : 3.5
        return Text("Desliza")
            .font(.subheadline.weight(.semibold))
            .keyframeAnimator(initialValue: inicio.palabra, trigger: veces) { vista, opacidad in
                vista.opacity(opacidad)
            } keyframes: { _ in
                KeyframeTrack {
                    LinearKeyframe(1.0, duration: 0.3)
                    LinearKeyframe(1.0, duration: quieta)
                    LinearKeyframe(0.0, duration: 0.4)
                }
            }
    }

    @ViewBuilder
    private var raya: some View {
        let linea = Capsule().frame(width: 26, height: 3)
        if menosMovimiento {
            
            linea.keyframeAnimator(initialValue: inicio.raya, trigger: veces) { vista, r in
                vista.opacity(r.opacidad)
            } keyframes: { _ in
                KeyframeTrack(\.opacidad) {
                    LinearKeyframe(1, duration: 0.3)
                    LinearKeyframe(1, duration: 2.4)
                    LinearKeyframe(0, duration: 0.4)
                }
            }
        } else {

            linea.keyframeAnimator(initialValue: inicio.raya, trigger: veces) { vista, r in
                vista.offset(y: r.bajada).opacity(r.opacidad)
            } keyframes: { _ in
                KeyframeTrack(\.opacidad) {
                        LinearKeyframe(1, duration: 0.25)
                        LinearKeyframe(1, duration: 0.4)
                        LinearKeyframe(0, duration: 0.4)
                        LinearKeyframe(0, duration: 0.2)
                        LinearKeyframe(1, duration: 0.25)
                        LinearKeyframe(1, duration: 0.4)
                        LinearKeyframe(0, duration: 0.4)
                        LinearKeyframe(0, duration: 0.2)
                        LinearKeyframe(1, duration: 0.25)
                        LinearKeyframe(1, duration: 0.4)
                        LinearKeyframe(0, duration: 0.4)
                        LinearKeyframe(0, duration: 0.2)
                }
                KeyframeTrack(\.bajada) {
                        LinearKeyframe(0, duration: 0.4)
                        CubicKeyframe(PistaDelPanel.recorrido, duration: 0.65)
                        LinearKeyframe(0, duration: 0.01)
                        LinearKeyframe(0, duration: 0.19)
                        LinearKeyframe(0, duration: 0.4)
                        CubicKeyframe(PistaDelPanel.recorrido, duration: 0.65)
                        LinearKeyframe(0, duration: 0.01)
                        LinearKeyframe(0, duration: 0.19)
                        LinearKeyframe(0, duration: 0.4)
                        CubicKeyframe(PistaDelPanel.recorrido, duration: 0.65)
                        LinearKeyframe(0, duration: 0.01)
                        LinearKeyframe(0, duration: 0.19)
                }
            }
        }
    }
}

struct FueraDeLaLosa: Shape {
    var forma: FormaDeIsla

    var animatableData: CGFloat {
        get { forma.p }
        set { forma.p = newValue }
    }

    func path(in r: CGRect) -> Path {
        var camino = Path(r)
        camino.addPath(forma.path(in: r))
        return camino
    }
}

enum FondoDelPanel {
    private static var archivo: URL? {
        try? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                     appropriateFor: nil, create: true)
            .appendingPathComponent("fondo-del-panel.jpg")
    }

    @MainActor private static var enMemoria: UIImage?
    @MainActor private static var leida = false
    @MainActor private static var lectura: Task<UIImage?, Never>?

    @MainActor static func cargar() async -> UIImage? {
        if leida { return enMemoria }
        if let lectura { return await lectura.value }
        let t = Task.detached(priority: .userInitiated) { () -> UIImage? in
            guard let archivo, let datos = try? Data(contentsOf: archivo) else { return nil }
            return await UIImage(data: datos)?.byPreparingForDisplay()
        }
        lectura = t
        let imagen = await t.value
        if lectura == t { recordar(imagen) }
        return leida ? enMemoria : imagen
    }

    @MainActor private static func recordar(_ imagen: UIImage?) {
        enMemoria = imagen
        leida = true
        lectura = nil
    }

    static func guardar(_ datos: Data) async -> UIImage? {
        let jpeg = await Task.detached(priority: .userInitiated) { () -> Data? in
            guard let imagen = UIImage(data: datos), imagen.size.width > 0, imagen.size.height > 0 else {
                return nil
            }
            let escala = min(1, 2868 / max(imagen.size.width, imagen.size.height))
            let tamano = CGSize(width: (imagen.size.width * escala).rounded(),
                                height: (imagen.size.height * escala).rounded())
            let formato = UIGraphicsImageRendererFormat()
            formato.scale = 1
            formato.opaque = true
            return UIGraphicsImageRenderer(size: tamano, format: formato).image { _ in
                imagen.draw(in: CGRect(origin: .zero, size: tamano))
            }.jpegData(compressionQuality: 0.9)
        }.value
        guard let jpeg, let archivo, (try? jpeg.write(to: archivo, options: .atomic)) != nil else { return nil }
        let imagen = await UIImage(data: jpeg)?.byPreparingForDisplay()
        await recordar(imagen)
        return imagen
    }

    @MainActor static func borrar() {
        if let archivo { try? FileManager.default.removeItem(at: archivo) }
        recordar(nil)
    }
}

#if canImport(UIKit)

struct TirarDeLaIsla: UIViewRepresentable {
    let estado: EstadoPanel

    func makeUIView(context: Context) -> AnclaDeLaIsla { AnclaDeLaIsla(estado: estado) }
    func updateUIView(_ vista: AnclaDeLaIsla, context: Context) {}
}

final class AnclaDeLaIsla: UIView {
    private let tiron: TironDeLaIsla

    init(estado: EstadoPanel) {
        tiron = TironDeLaIsla(estado: estado)
        super.init(frame: .zero)
        isUserInteractionEnabled = false
    }

    required init?(coder: NSCoder) { nil }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        tiron.enganchar(a: window)
    }
}

@MainActor
final class TironDeLaIsla: NSObject, UIGestureRecognizerDelegate {
    private let estado: EstadoPanel
    private var gesto: UIPanGestureRecognizer?
    private weak var ventana: UIWindow?

    init(estado: EstadoPanel) {
        self.estado = estado
    }

    func enganchar(a nueva: UIWindow?) {
        if let g = gesto {
            g.view?.removeGestureRecognizer(g)
            gesto = nil
        }
        ventana = nueva
        guard let nueva else { return }
        let g = UIPanGestureRecognizer(target: self, action: #selector(tirar(_:)))
        g.delegate = self
        g.maximumNumberOfTouches = 1
        nueva.addGestureRecognizer(g)
        gesto = g
        medir(nueva)
    }

    private func medir(_ ventana: UIWindow) {
        let ancho = ventana.bounds.width
        let segura = ventana.safeAreaInsets.top
        let y: CGFloat = segura >= 62 ? 14 : (segura >= 59 ? 11 : 6)
        estado.isla = CGRect(x: (ancho - 126) / 2, y: y, width: 126, height: 37.33)
        estado.alto = ventana.bounds.height
    }

    func gestureRecognizer(_ g: UIGestureRecognizer, shouldReceive toque: UITouch) -> Bool {
        guard let ventana, !estado.abierto else { return false }
        
        if ventana.rootViewController?.presentedViewController != nil { return false }
        let y = toque.location(in: ventana).y
        let segura = ventana.safeAreaInsets.top
        return y >= segura - 6 && y <= segura + 54
    }

    func gestureRecognizerShouldBegin(_ g: UIGestureRecognizer) -> Bool {
        guard let pan = g as? UIPanGestureRecognizer, let ventana else { return false }
        let v = pan.velocity(in: ventana)
        let t = pan.translation(in: ventana)
        let dy = abs(v.y) > 1 ? v.y : t.y
        let dx = abs(v.x) > 1 ? v.x : t.x
        
        return dy > 0 && dy > abs(dx) * 1.2
    }

    func gestureRecognizer(_ g: UIGestureRecognizer,
                           shouldBeRequiredToFailBy otro: UIGestureRecognizer) -> Bool {
        otro.view is UIScrollView
    }

    @objc private func tirar(_ g: UIPanGestureRecognizer) {
        guard let ventana else { return }
        let dedo = g.location(in: ventana).y
        switch g.state {
        case .began:
            medir(ventana)
            estado.conElDedo = true
            estado.seguir((dedo - estado.isla.maxY) / estado.recorrido)
        case .changed:
            
            estado.seguir((dedo - estado.isla.maxY) / estado.recorrido)
        case .ended, .cancelled, .failed:
            estado.conElDedo = false
            let v = g.velocity(in: ventana).y
            let p = estado.progreso
            let destino = p + PanelBeta.proyeccion(v) / estado.recorrido
            if g.state == .ended, destino > PanelBeta.umbral {
                estado.abrir(velocidad: v / max((1 - p) * estado.recorrido, 1))
            } else {
                estado.cerrar(velocidad: -v / max(p * estado.recorrido, 1))
            }
        default:
            break
        }
    }
}
#endif

private struct CabeceraPanel: View {
    let titulo: String
    let cerrar: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: Diseno.hueco2) {
            Text(titulo)
                .font(.largeTitle.weight(.bold))
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 0)
            Button(role: .close) { cerrar() } label: {
                Image(systemName: "xmark")
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
            .accessibilityLabel("Cerrar")
        }
    }
}

private struct CentroDeControl: View {
    let activa: (Herramienta) -> Bool
    let trabajando: (Herramienta) -> Bool
    let tocar: (Herramienta) -> Void
    let cerrar: () -> Void
    let aviso: (texto: String, bien: Bool)?
    
    let arriba: CGFloat
    
    let alMedir: (CGFloat) -> Void
    
    let conFondo: Bool
    let elegirFondo: () -> Void
    let quitarFondo: () -> Void

    @Environment(\.dynamicTypeSize) private var letra
    
    @Environment(\.tema) private var temaPuesto
    @ScaledMetric(relativeTo: .body) private var altoModulo: CGFloat = 92
    @ScaledMetric(relativeTo: .body) private var ladoCirculo: CGFloat = 58

    var body: some View {
        if letra.isAccessibilitySize {
            ScrollView {
                VStack(alignment: .leading, spacing: Diseno.hueco2 + 2) {
                    CabeceraPanel(titulo: "Herramientas", cerrar: cerrar)
                    piezas
                }
                .padding(.top, arriba)
                .padding(.horizontal, Diseno.margen + 12)
                .padding(.bottom, Diseno.hueco5 + 34)
            }
            .scrollIndicators(.hidden)
            
            .onAppear { alMedir(10_000) }
        } else {

            piezas
                .fixedSize(horizontal: false, vertical: true)
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { alMedir($0) }
                .padding(.top, arriba)
                
                .padding(.horizontal, Diseno.margen + 12)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }

    private var piezas: some View {
        VStack(alignment: .leading, spacing: Diseno.hueco2 + 2) {
            if let aviso {
                Banda(aviso).transition(.opacity)
            }
            VStack(spacing: Diseno.hueco2 + 2) {
                directo
                pareja(.ocultar, .bloquear)
                pareja(.tokens, .adelanto)
                pareja(.enlaces, .comprobar)
                if Compilacion.beta { moduloTema }
            }
            circulos(.abrir)
            circulos(.gestionar)
        }
    }

    private var moduloTema: some View {
        Button { tocar(.tema) } label: {
            HStack(spacing: Diseno.hueco2) {
                MuestraRedonda(tema: temaPuesto, foto: Temas.compartido.foto)
                    .frame(width: 46, height: 46)
                VStack(alignment: .leading, spacing: 1) {
                    Text(Herramienta.tema.titulo)
                        .font(.headline)
                        .foregroundStyle(Color.primary)
                    Text(Temas.compartido.nombreElegido)
                        .font(.subheadline)
                        .foregroundStyle(Diseno.apoyoEnCristal)
                        .contentTransition(.opacity)
                }
                .lineLimit(letra.isAccessibilitySize ? 3 : 1)
                .minimumScaleFactor(letra.isAccessibilitySize ? 1 : 0.75)
                .fixedSize(horizontal: false, vertical: letra.isAccessibilitySize)
                Spacer(minLength: 0)
            }
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .pieza(encendida: false, radio: 28, cristal: conFondo)
        .accessibilityLabel(Herramienta.tema.titulo)
        .accessibilityValue(Temas.compartido.nombreElegido)
    }

    private var directo: some View {
        Button { tocar(.directo) } label: {
            HStack(spacing: Diseno.hueco2) {
                ZStack {
                    Circle().fill(Diseno.rojoRelleno)
                    if trabajando(.directo) {
                        ProgressView().tint(.white)
                    } else {
                        Image(systemName: Herramienta.directo.simbolo(activa: false))
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.white)
                    }
                }
                .frame(width: 46, height: 46)
                Text(Herramienta.directo.titulo)
                    .font(.headline)
                    .foregroundStyle(Color.primary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(letra.isAccessibilitySize ? 3 : 1)
                    .minimumScaleFactor(letra.isAccessibilitySize ? 1 : 0.75)
                    .fixedSize(horizontal: false, vertical: letra.isAccessibilitySize)
                Spacer(minLength: 0)
            }
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .pieza(encendida: false, radio: 28, cristal: conFondo)
        .disabled(trabajando(.directo))
        .accessibilityLabel(Herramienta.directo.titulo)
    }

    @ViewBuilder
    private func pareja(_ a: Herramienta, _ b: Herramienta) -> some View {
        if letra.isAccessibilitySize {
            VStack(spacing: Diseno.hueco2 + 2) { modulo(a); modulo(b) }
        } else {
            HStack(spacing: Diseno.hueco2 + 2) { modulo(a); modulo(b) }
        }
    }

    @ViewBuilder
    private func modulo(_ h: Herramienta) -> some View {
        let encendida = activa(h)
        let simbolo = Image(systemName: h.simbolo(activa: encendida))
            .font(.title2.weight(.semibold))
            .foregroundStyle(encendida ? temaPuesto.sobreRelleno : Color.primary)
            .contentTransition(.symbolEffect(.replace))
        let nombre = Text(h.titulo)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(encendida ? temaPuesto.sobreRelleno : Color.primary)

        let contenido = Group {
            if letra.isAccessibilitySize {
                HStack(spacing: Diseno.hueco2) {
                    simbolo
                    nombre.lineLimit(3).multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 6)
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    simbolo
                    Spacer(minLength: Diseno.hueco2)
                    nombre.lineLimit(1).minimumScaleFactor(0.75)
                }
                .frame(maxWidth: .infinity, minHeight: altoModulo - 24, alignment: .leading)
                .padding(.vertical, 4)
            }
        }

        Button { tocar(h) } label: { contenido }
            .pieza(encendida: encendida, radio: 26, cristal: conFondo)
            .accessibilityLabel(h.titulo)
            .accessibilityValue(h == .ocultar ? (encendida ? "Activado" : "Desactivado") : "")
            .accessibilityAddTraits(h == .ocultar ? .isToggle : [])
    }

    private func circulos(_ g: Herramienta.Grupo) -> some View {
        let lista = Herramienta.allCases.filter { $0.grupo == g }
        let columnas = Array(repeating: GridItem(.flexible(), spacing: Diseno.hueco1, alignment: .top),
                             count: letra.isAccessibilitySize ? 2 : 4)
        return VStack(alignment: .leading, spacing: Diseno.hueco2) {
            Text(g.rawValue)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.top, Diseno.hueco2)
                .accessibilityAddTraits(.isHeader)
            LazyVGrid(columns: columnas, alignment: .leading, spacing: Diseno.hueco3) {
                ForEach(lista) { h in
                    VStack(spacing: Diseno.hueco1 + 2) {
                        Button { tocar(h) } label: {
                            Image(systemName: h.simbolo(activa: false))
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(Color.primary)
                                .frame(width: min(ladoCirculo, 72) - 22, height: min(ladoCirculo, 72) - 22)
                        }
                        .pieza(encendida: false, radio: nil, cristal: conFondo)
                        .accessibilityLabel(h.titulo)
                        .accessibilityHint(h.web != nil ? "Abre la web en Safari" : "")
                        Text(h.corto)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(Color.primary)
                            .lineLimit(letra.isAccessibilitySize ? 2 : 1)
                            .minimumScaleFactor(0.7)
                            .multilineTextAlignment(.center)
                            .accessibilityHidden(true)
                    }
                    .frame(maxWidth: .infinity)
                }
                if g == .gestionar { fondo }
            }
        }
    }

    private var fondo: some View {
        VStack(spacing: Diseno.hueco1 + 2) {
            Button { elegirFondo() } label: {
                Image(systemName: "photo.fill")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Color.primary)
                    .frame(width: min(ladoCirculo, 72) - 22, height: min(ladoCirculo, 72) - 22)
            }
            .pieza(encendida: false, radio: nil, cristal: conFondo)
            .contextMenu {
                if conFondo {
                    Button("Quitar el fondo", systemImage: "trash", role: .destructive) { quitarFondo() }
                }
            }
            .accessibilityLabel("Fondo")
            .accessibilityHint("Elige una imagen de Fotos para detrás del panel")
            .accessibilityActions {
                if conFondo { Button("Quitar el fondo") { quitarFondo() } }
            }
            Text("Fondo")
                .font(.caption.weight(.medium))
                .foregroundStyle(Color.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .accessibilityHidden(true)
        }
        .frame(maxWidth: .infinity)
    }
}

extension View {
    
    fileprivate func pieza(encendida: Bool, radio: CGFloat?, cristal: Bool) -> some View {
        buttonStyle(PiezaPlana(encendida: encendida, radio: radio, deCristal: cristal))
            
            .chocable(radio.map { .caja(radio: $0) } ?? .circulo, reacciona: true)
    }
}

private struct PiezaPlana: ButtonStyle {
    let encendida: Bool
    let radio: CGFloat?
    let deCristal: Bool
    @Environment(\.accessibilityReduceMotion) private var menosMovimiento
    
    @Environment(\.tema) private var tema

    @ViewBuilder
    func makeBody(configuration: Configuration) -> some View {
        let forma: AnyShape = radio.map { AnyShape(RoundedRectangle(cornerRadius: $0, style: .continuous)) }
            ?? AnyShape(Circle())
        if deCristal {
            configuration.label
                .padding(radio == nil ? 11 : 12)
                .background {
                    ZStack {
                        Color.clear
                            .cristal(encendida ? Glass.clear.tint(tema.relleno) : Glass.clear, en: forma)
                        forma.fill(Color.white.opacity(configuration.isPressed ? 0.14 : 0))
                    }
                }
                .contentShape(forma)
                .scaleEffect(configuration.isPressed && !menosMovimiento ? 0.96 : 1)
                .animation(.spring(response: 0.25, dampingFraction: 0.8), value: configuration.isPressed)
        } else {
            configuration.label
                .padding(radio == nil ? 11 : 12)
                .background(encendida ? tema.relleno : .white.opacity(configuration.isPressed ? 0.24 : 0.13),
                            in: forma)
                .contentShape(forma)
                .scaleEffect(configuration.isPressed && !menosMovimiento ? 0.96 : 1)
                .animation(.spring(response: 0.25, dampingFraction: 0.8), value: configuration.isPressed)
        }
    }
}
