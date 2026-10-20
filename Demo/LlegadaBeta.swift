import SwiftUI
import UIKit

enum Llegada {
    
    static let tamano: Double = 2.922
    
    static let separacion: Double = 3.677
    static let amortiguacion: Double = 0.85
    
    static let ritmoDelSitio: Double = 0.9458
    
    static let distanciaMaxima: CGFloat = 372

    static func respuesta(distancia d: CGFloat) -> Double {
        0.2297 + 0.007325 * pow(Double(min(d, distanciaMaxima)) / 100, 3.4838)
    }

    static let fin: Double = 1.6
    
    static let salida: Double = 0.2
    
    static let fondo: Double = 0.4

    static func muelle(_ t: Double, respuesta: Double) -> Double {
        guard t > 0 else { return 1 }
        let z = amortiguacion
        let w0 = 2 * Double.pi / respuesta
        let wd = w0 * (1 - z * z).squareRoot()
        return exp(-z * w0 * t) * (cos(wd * t) + z * w0 / wd * sin(wd * t))
    }

    static func queda(_ t: Double, de duracion: Double) -> Double {
        min(max(1 - t / duracion, 0), 1)
    }

    @MainActor static var terminaEn = Date.distantPast

    @MainActor static func esperarQueAcabe() async {
        let falta = terminaEn.timeIntervalSinceNow
        if falta > 0 { try? await Task.sleep(for: .seconds(falta)) }
    }

    @MainActor
    static var centroDeLaPantalla: CGPoint {
        let pantalla = UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.screen.bounds }.first
            ?? CGRect(x: 0, y: 0, width: 440, height: 956)
        return CGPoint(x: pantalla.midX, y: pantalla.midY)
    }
}

private struct RelojDeLaLlegada: EnvironmentKey {
    static let defaultValue = Llegada.fin
}

private struct BajoElCerrojo: EnvironmentKey {
    static let defaultValue = false
}

private struct FondoDelCerrojoDetras: EnvironmentKey {
    static let defaultValue: Double? = nil
}

private struct CerrojoSaliendo: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {

    var llegada: Double {
        get { self[RelojDeLaLlegada.self] }
        set { self[RelojDeLaLlegada.self] = newValue }
    }

    var bajoElCerrojo: Bool {
        get { self[BajoElCerrojo.self] }
        set { self[BajoElCerrojo.self] = newValue }
    }

    var fondoDelCerrojoDetras: Double? {
        get { self[FondoDelCerrojoDetras.self] }
        set { self[FondoDelCerrojoDetras.self] = newValue }
    }

    var cerrojoSaliendo: Bool {
        get { self[CerrojoSaliendo.self] }
        set { self[CerrojoSaliendo.self] = newValue }
    }
}

struct CaraDelCerrojo: View {
    let conCodigo: Bool
    let imagen: UIImage?
    let empanado: Bool

    @MainActor
    static func ahora(empanado: Bool = FondoDelCerrojo.empanadoAhora) -> CaraDelCerrojo {
        CaraDelCerrojo(conCodigo: PantallaBloqueo.hayCodigoPuesto(),
                       imagen: FondoDelCerrojo.recordado, empanado: empanado)
    }

    var body: some View {
        if conCodigo {
            FondoDelCerrojo(imagen: imagen, empanado: empanado)
        } else {
            FondoDeEntrada()
        }
    }
}

extension View {

    func llegaComoElIPhone() -> some View {
        modifier(LlegaComoElIPhone())
    }
}

private struct LlegaComoElIPhone: ViewModifier {
    @Environment(\.llegada) private var reloj
    @Environment(\.accessibilityReduceMotion) private var sinMovimiento
    
    @State private var centro: CGPoint?

    func body(content: Content) -> some View {
        let enCurso = !sinMovimiento && centro != nil
        let c = Llegada.centroDeLaPantalla
        let desde = CGVector(dx: (centro?.x ?? c.x) - c.x, dy: (centro?.y ?? c.y) - c.y)
        content
            .modifier(EfectoDeLlegada(
                t: enCurso ? reloj : Llegada.fin,
                desdeElCentro: desde,
                respuesta: Llegada.respuesta(distancia: hypot(desde.dx, desde.dy))))

            .onGeometryChange(for: CGPoint.self) { g in
                let f = g.frame(in: .global)
                return CGPoint(x: f.midX, y: f.midY)
            } action: { nuevo in
                if reloj < Llegada.fin { centro = nuevo }
            }
    }
}

private struct EfectoDeLlegada: GeometryEffect {
    var t: Double
    
    let desdeElCentro: CGVector
    let respuesta: Double

    var animatableData: Double {
        get { t }
        set { t = newValue }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        guard t < Llegada.fin else { return ProjectionTransform() }
        let s = 1 + (Llegada.tamano - 1) * Llegada.muelle(t, respuesta: respuesta)
        let p = (Llegada.separacion - 1) * Llegada.muelle(t, respuesta: respuesta * Llegada.ritmoDelSitio)
        
        let cx = size.width / 2, cy = size.height / 2
        return ProjectionTransform(CGAffineTransform(
            a: s, b: 0, c: 0, d: s,
            tx: cx - s * cx + p * desdeElCentro.dx,
            ty: cy - s * cy + p * desdeElCentro.dy))
    }
}
