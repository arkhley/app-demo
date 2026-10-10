import SwiftUI

struct SerieCobrado: Equatable {
    struct Punto: Equatable {
        let fecha: String
        let euros: Double
    }
    let paso: String
    let puntos: [Punto]

    init?(_ json: Any?) {
        guard let j = json as? [String: Any],
              let lista = j["puntos"] as? [[String: Any]], lista.count >= 2 else { return nil }
        paso = j["paso"] as? String ?? "dia"
        puntos = lista.map {
            Punto(fecha: $0["f"] as? String ?? "",
                  euros: ($0["e"] as? Double) ?? Double($0["e"] as? Int ?? 0))
        }
    }

    func nombre(_ i: Int) -> String {
        guard puntos.indices.contains(i) else { return "" }
        let d = Formato.diaCorto(puntos[i].fecha).replacingOccurrences(of: " de ", with: " ")
        let corto = d.split(separator: " ").enumerated()
            .map { $0.offset == 1 ? String($0.element.prefix(3)) : String($0.element) }
            .joined(separator: " ")
        return paso == "semana" ? "Semana del \(corto)" : diaDeLaSemana(puntos[i].fecha) + " " + corto
    }

    private func diaDeLaSemana(_ iso: String) -> String {
        let p = iso.split(separator: "-").compactMap { Int($0) }
        guard p.count == 3 else { return "" }
        
        var (a, m) = (p[0], p[1])
        if m < 3 { m += 12; a -= 1 }
        let h = (p[2] + (13 * (m + 1)) / 5 + a % 100 + (a % 100) / 4 + (a / 100) / 4 + 5 * (a / 100)) % 7
        return ["Sáb", "Dom", "Lun", "Mar", "Mié", "Jue", "Vie"][h]
    }
}

struct MantenerYDeslizar: UIGestureRecognizerRepresentable {
    var espera: TimeInterval = 0.15
    var alEmpezar: (CGPoint) -> Void
    var alMover: (CGPoint) -> Void
    var alAcabar: () -> Void

    func makeUIGestureRecognizer(context: Context) -> UILongPressGestureRecognizer {
        let r = UILongPressGestureRecognizer()
        r.minimumPressDuration = espera
        r.allowableMovement = 8
        return r
    }

    func updateUIGestureRecognizer(_ r: UILongPressGestureRecognizer, context: Context) {
        r.minimumPressDuration = espera
    }

    func handleUIGestureRecognizerAction(_ r: UILongPressGestureRecognizer, context: Context) {
        let p = context.converter.localLocation
        switch r.state {
        case .began: alEmpezar(p)
        case .changed: alMover(p)
        case .ended, .cancelled, .failed: alAcabar()
        default: break
        }
    }
}

enum LuzDeLinea {
    static func alta(_ m: ColorScheme) -> Color { .white.opacity(m == .dark ? 0.16 : 0.45) }
    static func base(_ m: ColorScheme) -> Color { .white.opacity(m == .dark ? 0.05 : 0.18) }
    static func suelo(_ m: ColorScheme) -> Color { .black.opacity(m == .dark ? 0.22 : 0.06) }
}

struct EjeDeDias: Equatable {
    
    let casillas: Int
    
    let espacio: CGFloat
    
    let casillaDe: [Int]

    func centro(_ c: Int, en r: CGRect) -> CGFloat {
        let n = CGFloat(max(casillas, 1))
        let ancho = max(0, (r.width - espacio * (n - 1)) / n)
        return r.minX + CGFloat(c) * (ancho + espacio) + ancho / 2
    }
}

struct LineaCobrado: View {
    let serie: SerieCobrado
    let color: Color

    let margen: CGFloat
    
    var activa: Bool = true
    
    var conLuz: Bool = true

    var eje: EjeDeDias? = nil
    @Binding var elegido: Int?
    @Binding var rastreando: Bool

    @Environment(\.accessibilityReduceMotion) private var menosMovimiento
    @Environment(\.accessibilityReduceTransparency) private var menosTransparencia
    @Environment(\.colorScheme) private var modo
    @State private var dibujada = false

    private static let radioLente: CGFloat = 12
    private static let arriba: CGFloat = 16
    private static let abajo: CGFloat = 12

    var body: some View {
        GeometryReader { g in
            let r = CGRect(x: margen, y: Self.arriba,
                           width: max(1, g.size.width - 2 * margen),
                           height: max(1, g.size.height - Self.arriba - Self.abajo))
            let pts = puntos(en: r)
            let bordes = conBordes(pts, ancho: g.size.width)
            let i = elegido ?? (pts.count - 1)
            let p = pts.indices.contains(i) ? pts[i] : .zero
            let fondo = g.size.height

            let finLuz = ejeUsado != nil ? (pts.last?.x ?? g.size.width) : g.size.width

            ZStack(alignment: .topLeading) {

                if conLuz {
                    ZStack(alignment: .topLeading) {
                        Curva(puntos: bordes, base: fondo, cerrada: true)
                            .fill(LinearGradient(colors: [LuzDeLinea.base(modo),
                                                          LuzDeLinea.base(modo).opacity(0)],
                                                 startPoint: UnitPoint(x: 0.5, y: r.minY / fondo),
                                                 endPoint: .bottom))
                        Curva(puntos: bordes, base: fondo, cerrada: true)
                            .fill(LuzDeLinea.alta(modo))
                            .mask {
                                Curva(puntos: bordes, base: fondo, cerrada: false)
                                    .stroke(style: StrokeStyle(lineWidth: 34, lineCap: .round,
                                                               lineJoin: .round))
                                    .offset(y: 13)
                                    .blur(radius: 13)
                            }
                    }
                    .modifier(ApagarAlFinal(hasta: ejeUsado != nil ? finLuz : nil, ancho: g.size.width))
                    .drawingGroup()
                    .mask(alignment: .leading) {
                        Rectangle().frame(width: dibujada ? g.size.width : 0)
                    }
                }

                linea(bordes, fondo: fondo, opacidad: elegido == nil ? 1 : 0.3)
                    
                    .background { Color.clear.chocable(.linea(bordes)) }
                if elegido != nil {
                    
                    linea(bordes, fondo: fondo, opacidad: 1)
                        .mask(alignment: .leading) { Rectangle().frame(width: max(p.x, 0)) }
                }

                if elegido != nil {
                    Capsule()
                        .fill(LinearGradient(colors: [color.opacity(0), color, color.opacity(0)],
                                             startPoint: .top, endPoint: .bottom))
                        .frame(width: 2.5, height: g.size.height)
                        .shadow(color: color.opacity(0.7), radius: 5, x: 0, y: 0)
                        .offset(x: p.x - 1.25)
                        .transition(.opacity)
                }

                if elegido == nil && !menosMovimiento && activa {
                    AroLatido(color: color)
                        .position(p)
                        .opacity(dibujada ? 1 : 0)
                }

                lente
                    .position(p)
                    .scaleEffect(dibujada ? 1 : 0.01, anchor: UnitPoint(
                        x: p.x / max(g.size.width, 1), y: p.y / max(fondo, 1)))
                    .animation(menosMovimiento || !activa ? nil
                               : .spring(duration: 0.28, bounce: 0.2), value: i)
            }
            .contentShape(.rect)
            .gesture(MantenerYDeslizar(
                alEmpezar: { q in
                    rastreando = true
                    elegir(q.x, r: r, pts: pts)
                },
                alMover: { q in elegir(q.x, r: r, pts: pts) },
                alAcabar: {
                    rastreando = false
                    withAnimation(.snappy(duration: 0.25)) { elegido = nil }
                }))
        }
        .sensoryFeedback(.selection, trigger: elegido)
        .task(id: serie) { await dibujar() }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(serie.paso == "semana" ? "Cobrado semana a semana"
                                                   : "Cobrado día a día")
        .accessibilityValue(valorAccesible)
        .accessibilityAdjustableAction { d in
            let ultimo = serie.puntos.count - 1
            let actual = elegido ?? ultimo
            switch d {
            case .increment: elegido = min(ultimo, actual + 1)
            case .decrement: elegido = max(0, actual - 1)
            @unknown default: break
            }
        }
    }

    private func linea(_ bordes: [CGPoint], fondo: CGFloat, opacidad: Double) -> some View {
        Curva(puntos: bordes, base: fondo, cerrada: false)
            .trim(from: 0, to: dibujada ? 1 : 0)
            .stroke(color.opacity(opacidad),
                    style: StrokeStyle(lineWidth: 2.6, lineCap: .round, lineJoin: .round))
            .shadow(color: color.opacity(0.5 * opacidad), radius: 3, x: 0, y: 2)
    }

    @ViewBuilder
    private var lente: some View {
        Group {
            if menosTransparencia {
                Circle()
                    .fill(color)
                    .overlay(Circle().strokeBorder(Color.white, lineWidth: 2))
                    .frame(width: 16, height: 16)
            } else {
                Circle()
                    .fill(.white)
                    .frame(width: 6, height: 6)
                    .shadow(color: color, radius: 3, x: 0, y: 0)
                    .frame(width: 2 * Self.radioLente, height: 2 * Self.radioLente)
                    .glassEffect(.regular.tint(color.opacity(0.35)), in: .circle)
            }
        }
        .scaleEffect(rastreando ? 1.35 : 1)
        .animation(.spring(duration: 0.3, bounce: 0.35), value: rastreando)
        .allowsHitTesting(false)
    }

    private var valorAccesible: String {
        let i = elegido ?? (serie.puntos.count - 1)
        guard serie.puntos.indices.contains(i) else { return "" }
        return "\(serie.nombre(i)), \(Formato.euros(serie.puntos[i].euros))"
    }

    private var ejeUsado: EjeDeDias? {
        guard let e = eje, e.casillaDe.count == serie.puntos.count else { return nil }
        return e
    }

    private func puntos(en r: CGRect) -> [CGPoint] {
        let n = serie.puntos.count
        let tope = max(serie.puntos.map(\.euros).max() ?? 0, 0.01)
        return serie.puntos.enumerated().map { i, p in
            let x = ejeUsado.map { $0.centro($0.casillaDe[i], en: r) }
                ?? r.minX + r.width * CGFloat(i) / CGFloat(max(n - 1, 1))
            return CGPoint(x: x, y: r.maxY - r.height * CGFloat(max(p.euros, 0) / tope))
        }
    }

    private func conBordes(_ pts: [CGPoint], ancho: CGFloat) -> [CGPoint] {
        guard let a = pts.first, let z = pts.last else { return pts }
        if ejeUsado != nil { return [CGPoint(x: 0, y: a.y)] + pts }
        return [CGPoint(x: 0, y: a.y)] + pts + [CGPoint(x: ancho, y: z.y)]
    }

    private func dibujar() async {
        var sin = Transaction(); sin.disablesAnimations = true

        if menosMovimiento || !activa {
            withTransaction(sin) { dibujada = true; elegido = nil }
            return
        }
        withTransaction(sin) { dibujada = false; elegido = nil }
        try? await Task.sleep(for: .milliseconds(60))
        withAnimation(.easeOut(duration: 0.9)) { dibujada = true }
    }

    private func elegir(_ x: CGFloat, r: CGRect, pts: [CGPoint]) {
        let cuantos = pts.count
        guard cuantos > 1 else { return }
        let i: Int
        if ejeUsado != nil {
            
            i = pts.indices.min { abs(pts[$0].x - x) < abs(pts[$1].x - x) } ?? cuantos - 1
        } else {
            let t = (x - r.minX) / max(r.width, 1)
            i = max(0, min(cuantos - 1, Int((t * CGFloat(cuantos - 1)).rounded())))
        }
        if i != elegido { elegido = i }
    }
}

private struct ApagarAlFinal: ViewModifier {
    let hasta: CGFloat?
    let ancho: CGFloat

    func body(content: Content) -> some View {
        if let x = hasta {
            let w = max(ancho, 1)
            content.mask {
                LinearGradient(stops: [
                    .init(color: .black, location: 0),
                    .init(color: .black, location: max(0, (x - 10) / w)),
                    .init(color: .clear, location: min(1, x / w)),
                ], startPoint: .leading, endPoint: .trailing)
            }
        } else {
            content
        }
    }
}

private struct AroLatido: View {
    let color: Color
    @State private var abierto = false

    var body: some View {
        Circle()
            .stroke(color.opacity(abierto ? 0 : 0.55), lineWidth: 1.5)
            .frame(width: 22, height: 22)
            .scaleEffect(abierto ? 1.9 : 0.8)
            .animation(.easeOut(duration: 1.8).repeatForever(autoreverses: false), value: abierto)
            .onAppear { abierto = true }
            .allowsHitTesting(false)
    }
}

private struct Curva: Shape {
    let puntos: [CGPoint]
    let base: CGFloat
    let cerrada: Bool

    func path(in rect: CGRect) -> Path {
        var c = Path()
        guard let primero = puntos.first else { return c }
        c.move(to: primero)

        let m = Self.pendientes(puntos)
        for i in 0..<(puntos.count - 1) {
            let a = puntos[i], b = puntos[i + 1]
            let dx = (b.x - a.x) / 3
            c.addCurve(to: b, control1: CGPoint(x: a.x + dx, y: a.y + dx * m[i]),
                       control2: CGPoint(x: b.x - dx, y: b.y - dx * m[i + 1]))
        }
        if cerrada, let ultimo = puntos.last {
            c.addLine(to: CGPoint(x: ultimo.x, y: base))
            c.addLine(to: CGPoint(x: primero.x, y: base))
            c.closeSubpath()
        }
        return c
    }

    static func pendientes(_ p: [CGPoint]) -> [CGFloat] {
        let n = p.count
        guard n > 1 else { return [CGFloat](repeating: 0, count: n) }
        var tramo = [CGFloat](repeating: 0, count: n - 1)
        for i in 0..<(n - 1) {
            let h = p[i + 1].x - p[i].x
            tramo[i] = h > 0 ? (p[i + 1].y - p[i].y) / h : 0
        }
        func signo(_ v: CGFloat) -> CGFloat { v > 0 ? 1 : v < 0 ? -1 : 0 }
        var m = [CGFloat](repeating: 0, count: n)
        if n > 2 {
            for i in 1..<(n - 1) {
                let h0 = p[i].x - p[i - 1].x, h1 = p[i + 1].x - p[i].x
                guard h0 + h1 > 0 else { continue }
                let media = (tramo[i - 1] * h1 + tramo[i] * h0) / (h0 + h1)
                m[i] = (signo(tramo[i - 1]) + signo(tramo[i]))
                    * min(abs(tramo[i - 1]), abs(tramo[i]), 0.5 * abs(media))
            }
            m[0] = (3 * tramo[0] - m[1]) / 2
            m[n - 1] = (3 * tramo[n - 2] - m[n - 2]) / 2
        } else {
            m[0] = tramo[0]
            m[1] = tramo[0]
        }
        return m
    }
}

struct ColumnasSemana: View {
    let dias: [PantallaInicio.DiaSemana]
    let tinte: Color

    @Environment(\.accessibilityReduceMotion) private var menosMovimiento
    @State private var crecidas = false

    static let alto: CGFloat = 168
    private static let altoBarra: CGFloat = 78

    var body: some View {
        HStack(alignment: .bottom, spacing: 0) {
            ForEach(Array(dias.enumerated()), id: \.element.id) { i, d in
                VStack(spacing: 7) {
                    ZStack(alignment: .bottom) {
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(Color.primary.opacity(0.06))
                        if d.veces > 0 {
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .fill(LinearGradient(colors: [tinte, tinte.opacity(0.62)],
                                                     startPoint: .top, endPoint: .bottom))
                                .overlay(alignment: .top) {
                                    
                                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                                        .strokeBorder(LinearGradient(
                                            colors: [.white.opacity(0.55), .white.opacity(0)],
                                            startPoint: .top, endPoint: .center), lineWidth: 1)
                                }
                                .frame(height: max(14, Self.altoBarra * d.relativo))
                                .shadow(color: d.mejor ? tinte.opacity(0.55) : .clear,
                                        radius: 7, x: 0, y: 3)
                                .scaleEffect(x: 1, y: crecidas ? 1 : 0.04, anchor: .bottom)
                                .animation(menosMovimiento ? nil
                                           : .spring(duration: 0.65, bounce: 0.22)
                                               .delay(Double(i) * 0.05), value: crecidas)
                        }
                    }
                    .frame(width: 22, height: Self.altoBarra)
                    .overlay(alignment: .top) {
                        if d.mejor {
                            Image(systemName: "star.fill")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.top, 6)
                                .opacity(crecidas ? 1 : 0)
                                .animation(Diseno.suave.delay(0.5), value: crecidas)
                        }
                    }

                    VStack(spacing: 2) {
                        Text(d.nombre)
                            .font(.caption2.weight(d.mejor ? .bold : .medium))
                            .foregroundStyle(.primary)
                        Text(d.veces > 0 ? Formato.eurosRedondos(d.euros) : "—")
                            .font(.caption2.weight(d.mejor ? .semibold : .regular))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)

                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                    }
                }
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(d.veces == 0 ? "\(d.nombre), sin datos"
                                                 : "\(d.nombre), \(Formato.euros(d.euros))"
                                                   + (d.mejor ? ", el mejor" : ""))
            }
        }
        .frame(height: Self.alto - 2 * Diseno.hueco3, alignment: .bottom)
        .onAppear { crecidas = true }
    }
}

struct PilotoRadar: View {
    let color: Color
    let activo: Bool
    var lado: CGFloat = 8

    @Environment(\.accessibilityReduceMotion) private var menosMovimiento
    @State private var abierto = false

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: lado, height: lado)
            .background {
                if activo && !menosMovimiento {
                    Circle()
                        .fill(color.opacity(abierto ? 0 : 0.5))
                        .scaleEffect(abierto ? 2.8 : 1)
                        .animation(.easeOut(duration: 1.4).repeatForever(autoreverses: false),
                                   value: abierto)
                }
            }
            .shadow(color: activo ? color.opacity(0.6) : .clear, radius: 3, x: 0, y: 1)
            .onAppear { abierto = true }
            .accessibilityHidden(true)
    }
}

struct BarraReparto: View {
    let partes: [(clave: String, euros: Double)]

    @Environment(\.accessibilityReduceMotion) private var menosMovimiento
    @State private var llena = false

    var body: some View {
        let validas = partes.filter { $0.euros > 0 }
        let total = max(validas.reduce(0) { $0 + $1.euros }, 0.01)
        GeometryReader { g in
            let hueco: CGFloat = 3
            let util = max(0, g.size.width - hueco * CGFloat(max(validas.count - 1, 0)))
            HStack(spacing: hueco) {
                ForEach(validas, id: \.clave) { p in
                    Capsule()
                        .fill(Diseno.colorDePlataforma(p.clave).gradient)
                        .frame(width: max(6, util * CGFloat(p.euros / total)))
                }
            }
            .frame(width: g.size.width, alignment: .leading)
            .overlay(alignment: .top) {
                Capsule().fill(.white.opacity(0.3)).frame(height: 2).padding(.horizontal, 4)
                    .padding(.top, 1.5)
            }
            .mask(alignment: .leading) {
                Capsule().frame(width: llena ? g.size.width : 0)
            }
        }
        .frame(height: 12)
        .onAppear {
            if menosMovimiento { llena = true; return }
            withAnimation(.smooth(duration: 1.0).delay(0.15)) { llena = true }
        }
        .accessibilityHidden(true)
    }
}

struct Aparicion: ViewModifier {
    let orden: Int
    @Environment(\.accessibilityReduceMotion) private var menosMovimiento
    @State private var vista = false

    func body(content: Content) -> some View {
        content
            .opacity(vista ? 1 : 0)
            .offset(y: vista ? 0 : 12)
            .onAppear {
                if menosMovimiento { vista = true; return }
                withAnimation(.smooth(duration: 0.45).delay(0.05 + Double(orden) * 0.07)) {
                    vista = true
                }
            }
    }
}

extension View {
    func aparicion(_ orden: Int) -> some View { modifier(Aparicion(orden: orden)) }
}
