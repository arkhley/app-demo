import SwiftUI
import CoreMotion

struct Deposito: View {
    let saldo: Double
    
    let unidad: Double

    static let cabeza: CGFloat = 26

    private static let margenRayas: CGFloat = 0.12
    private static let largoRaya: CGFloat = 12

    @Environment(\.accessibilityReduceMotion) private var menosMovimiento
    @Environment(\.accessibilityReduceTransparency) private var menosTransparencia
    @Environment(\.colorScheme) private var modo

    @State private var nivel: Double
    @State private var lo: Double
    @State private var hi: Double
    @State private var amplitud: Double = 2.4
    
    @State private var gotas = 0
    
    @State private var toques = 0
    @State private var chapoteos = 0
    
    @State private var destinoGota: CGFloat = 120
    
    @State private var altoTotal: CGFloat = 222
    @State private var colocado = false

    @State private var midiendo = false

    init(saldo: Double, unidad: Double) {
        self.saldo = saldo
        self.unidad = unidad
        let e = Self.escala(unidad > 0 ? saldo / unidad : 0)
        _nivel = State(initialValue: e.lo)
        _lo = State(initialValue: e.lo)
        _hi = State(initialValue: e.hi)
    }

    private var destino: Double { unidad > 0 ? saldo / unidad : Self.escala(0).lo }

    private var enUnidades: Double { unidad > 0 ? saldo / unidad : 0 }

    static func escala(_ u: Double) -> (lo: Double, hi: Double) {
        let hi = max(8, (max(u, 0) * 1.2).rounded(.up) + 2)
        let lo = min(-3, (min(u, 0) * 1.2).rounded(.down) - 2)
        return (lo, hi)
    }

    var body: some View {
        Button(action: chapotear) {
            GeometryReader { g in
                let w = g.size.width
                let alto = max(1, g.size.height - Self.cabeza)
                let tubo = RoundedRectangle(cornerRadius: w * 0.34, style: .continuous)
                
                let pivote = max(0.5, 1 - Self.margenRayas - Self.largoRaya / 2 / max(w, 1))
                ZStack(alignment: .top) {
                    resplandor(w: w, alto: alto)
                    agua(tubo: tubo, alto: alto, pivote: pivote)
                        .frame(width: w, height: alto)
                        .padding(.top, Self.cabeza)
                    cristal(tubo: tubo, w: w, alto: alto)
                    grabado(w: w, alto: alto, pivote: pivote)
                        .frame(width: w, height: alto)
                        .padding(.top, Self.cabeza)
                        .allowsHitTesting(false)
                }
                .frame(width: w, height: g.size.height, alignment: .top)
            }
        }
        .buttonStyle(Apretar())
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { altoTotal = $0 }
        .sensoryFeedback(.impact(weight: .light), trigger: toques)
        .sensoryFeedback(.impact(flexibility: .soft, intensity: 0.7), trigger: chapoteos)
        .task { await colocar() }
        .onAppear(perform: empezarAMedir)
        .onDisappear(perform: dejarDeMedir)
        .onChange(of: menosMovimiento) { _, menos in
            if menos { dejarDeMedir() } else { empezarAMedir() }
        }
        .onChange(of: saldo) { viejo, nuevo in mover(de: viejo, a: nuevo) }
        .onChange(of: unidad) { _, _ in mover(de: saldo, a: saldo) }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Reserva")
        .accessibilityValue(valorAccesible)

        .accessibilityRemoveTraits(.isButton)
    }

    private var valorAccesible: String {
        guard unidad > 0, saldo > 0 else { return Formato.euros(saldo) }
        let dias = Int((saldo / unidad).rounded(.down))
        return "\(Formato.euros(saldo)), \(dias) \(dias == 1 ? "día cubierto" : "días cubiertos")"
    }

    @ViewBuilder
    private func resplandor(w: CGFloat, alto: CGFloat) -> some View {
        let fuerza = min(1, abs(enUnidades) / 4)
        if modo == .dark, unidad > 0, fuerza > 0.05 {
            Capsule()
                .fill(saldo < 0 ? Diseno.rojoRelleno : Diseno.verdeRelleno)
                .frame(width: w * 0.95, height: alto * 0.55)
                .blur(radius: 24)
                .opacity(0.34 * fuerza)
                .padding(.top, Self.cabeza + alto * 0.45)
                .allowsHitTesting(false)
        }
    }

    private func agua(tubo: RoundedRectangle, alto: CGFloat, pivote: CGFloat) -> some View {
        ZStack {

            tubo.fill(LinearGradient(colors: [Color.secondary.opacity(0.16),
                                              Color.secondary.opacity(0.05),
                                              Color.secondary.opacity(0.16)],
                                     startPoint: .leading, endPoint: .trailing))
            TimelineView(.animation(minimumInterval: 1 / 30, paused: menosMovimiento)) { t in
                let fase = menosMovimiento ? 0 : t.date.timeIntervalSinceReferenceDate * 1.9
                let a = menosMovimiento ? 0 : amplitud
                let incl = menosMovimiento ? 0 : Inclinometro.compartido.angulo(t.date)
                ZStack {
                    Falta(nivel: nivel, lo: lo, hi: hi, amplitud: a, fase: fase,
                          inclinacion: incl, pivote: pivote)
                        .fill(Diseno.rojoRelleno.opacity(0.32))
                    Liquido(nivel: nivel, lo: lo, hi: hi, amplitud: a, fase: fase,
                            inclinacion: incl, pivote: pivote)
                        .fill(Color.secondary.opacity(0.28))

                    if saldo >= 0 {
                        Liquido(nivel: nivel, lo: lo, hi: hi, amplitud: a, fase: fase,
                                inclinacion: incl, pivote: pivote)
                            .fill(LinearGradient(colors: [Diseno.verdeRelleno,
                                                          Diseno.verdeRelleno.opacity(0.75)],
                                                 startPoint: .top, endPoint: .bottom))
                            .mask { PorEncimaDelCero(lo: lo, hi: hi) }
                    }
                }
            }
            
            if menosTransparencia && !menosMovimiento { gotaDibujada(alto: alto) }
        }
        .clipShape(tubo)
    }

    @ViewBuilder
    private func cristal(tubo: RoundedRectangle, w: CGFloat, alto: CGFloat) -> some View {
        if menosTransparencia {
            tubo.strokeBorder(Color.primary.opacity(0.22), lineWidth: 1.2)
                .frame(width: w, height: alto)
                .padding(.top, Self.cabeza)
        } else {

            GlassEffectContainer(spacing: 10) {
                ZStack(alignment: .top) {
                    Color.clear
                        .frame(width: w, height: alto)
                        .glassEffect(.clear, in: tubo)
                        .padding(.top, Self.cabeza)
                    if !menosMovimiento { perla(alto: alto) }
                }
                .frame(width: w, height: alto + Self.cabeza, alignment: .top)
            }
        }
    }

    private func perla(alto: CGFloat) -> some View {
        let lado: CGFloat = 14
        let aparcada = Self.cabeza + alto * 0.5 - lado / 2
        let hasta = max(Self.cabeza + 4, destinoGota - lado / 2)
        let verde = Diseno.verdeRelleno
        return Color.clear
            .frame(width: lado, height: lado)
            .keyframeAnimator(initialValue: Perla(y: aparcada, agua: 0, escala: 0.01),
                              trigger: gotas) { _, p in
                Circle()
                    .fill(verde)
                    .frame(width: lado * 0.58, height: lado * 0.58)
                    .opacity(p.agua)
                    .frame(width: lado, height: lado)
                    .glassEffect(.clear, in: .circle)
                    .scaleEffect(p.escala)
                    .offset(y: p.y)
            } keyframes: { _ in
                KeyframeTrack(\.y) {
                    MoveKeyframe(0)
                    LinearKeyframe(hasta, duration: 0.6, timingCurve: .easeIn)
                    MoveKeyframe(aparcada)
                }
                KeyframeTrack(\.escala) {
                    MoveKeyframe(1)
                    LinearKeyframe(1, duration: 0.6)
                    MoveKeyframe(0.01)
                }
                KeyframeTrack(\.agua) {
                    MoveKeyframe(1)
                    LinearKeyframe(1, duration: 0.54)
                    LinearKeyframe(0, duration: 0.06)
                }
            }
            .allowsHitTesting(false)
    }

    private func gotaDibujada(alto: CGFloat) -> some View {
        let hasta = max(8, destinoGota - Self.cabeza)
        let verde = Diseno.verdeRelleno
        return Image(systemName: "drop.fill")
            .font(.system(size: 17))
            .foregroundStyle(verde)
            .keyframeAnimator(initialValue: Perla(y: 0, agua: 0, escala: 1),
                              trigger: gotas) { vista, p in
                vista.opacity(p.agua).offset(y: p.y)
            } keyframes: { _ in
                KeyframeTrack(\.y) {
                    MoveKeyframe(4)
                    LinearKeyframe(hasta - 10, duration: 0.6, timingCurve: .easeIn)
                }
                KeyframeTrack(\.agua) {
                    MoveKeyframe(1)
                    LinearKeyframe(1, duration: 0.54)
                    LinearKeyframe(0, duration: 0.06)
                }
            }
            .frame(maxHeight: .infinity, alignment: .top)
            .allowsHitTesting(false)
    }

    private func grabado(w: CGFloat, alto: CGFloat, pivote: CGFloat) -> some View {
        let margenDerecho = w * Self.margenRayas
        let inicioRaya = w - margenDerecho - Self.largoRaya
        let r = CGRect(x: 0, y: 0, width: w, height: alto)
        let rayas = Graduacion(lo: lo, hi: hi, margen: w * 0.3)
        return ZStack {
            TimelineView(.animation(minimumInterval: 1 / 30, paused: menosMovimiento)) { t in
                let fase = menosMovimiento ? 0 : t.date.timeIntervalSinceReferenceDate * 1.9
                let a = menosMovimiento ? 0 : amplitud
                let incl = menosMovimiento ? 0 : Inclinometro.compartido.angulo(t.date)
                let verde = Liquido(nivel: nivel, lo: lo, hi: hi, amplitud: a, fase: fase,
                                    inclinacion: incl, pivote: pivote)
                ZStack {
                    rayas
                        .stroke(Color.primary.opacity(0.5), lineWidth: 1)
                        .padding(.trailing, margenDerecho)
                        .mask {
                            if saldo >= 0 {
                                ZStack {
                                    Rectangle()
                                    verde.mask { PorEncimaDelCero(lo: lo, hi: hi) }
                                        .blendMode(.destinationOut)
                                }
                                .compositingGroup()
                            } else {
                                Rectangle()
                            }
                        }
                    if saldo >= 0 {
                        rayas
                            .stroke(Color.black.opacity(0.5), lineWidth: 1)
                            .padding(.trailing, margenDerecho)
                            .mask { verde.mask { PorEncimaDelCero(lo: lo, hi: hi) } }
                    }
                }
            }
            LineaCero(lo: lo, hi: hi)
                .stroke(Color.primary.opacity(0.6),
                        style: StrokeStyle(lineWidth: 1.2, lineCap: .round, dash: [3, 3]))
                .padding(.horizontal, w * 0.08)

            if unidad > 0 {
                ForEach(Graduacion.numeradas(lo: lo, hi: hi, alto: alto, margen: w * 0.3),
                        id: \.self) { k in
                    Text(k < 0 ? "−\(Int(-k))" : "\(Int(k))")
                        .font(.system(.caption2, design: .rounded).weight(.semibold))
                        .monospacedDigit()

                        .foregroundStyle(Color.primary)
                        .dynamicTypeSize(...DynamicTypeSize.xLarge)
                        .padding(.horizontal, 3)
                        .background(Diseno.superficie.opacity(0.85), in: .capsule)
                        .fixedSize()
                        
                        .frame(width: 36, alignment: .trailing)
                        .position(x: inicioRaya - 4 - 18, y: alturaDe(k, lo: lo, hi: hi, en: r))
                }
            }
        }
    }

    private func colocar() async {
        guard !colocado else { return }
        colocado = true
        let e = Self.escala(enUnidades)
        if menosMovimiento {
            lo = e.lo; hi = e.hi; nivel = destino
            return
        }
        try? await Task.sleep(for: .milliseconds(120))
        withAnimation(.smooth(duration: 1.2)) {
            lo = e.lo; hi = e.hi; nivel = destino
        }
    }

    private func mover(de viejo: Double, a nuevo: Double) {
        guard colocado else { return }
        let e = Self.escala(unidad > 0 ? nuevo / unidad : 0)
        let d = destino
        guard !menosMovimiento, unidad > 0, nuevo >= viejo + 1 else {
            withAnimation(menosMovimiento ? nil : .smooth(duration: 0.8)) {
                lo = e.lo; hi = e.hi; nivel = d
            }
            return
        }
        
        let alto = max(1, altoTotal - Self.cabeza)
        let fraccion = max(0, min(1, (nivel - lo) / max(hi - lo, 0.001)))
        destinoGota = Self.cabeza + CGFloat(1 - fraccion) * alto
        gotas += 1
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(600))
            toques += 1
            withAnimation(.snappy(duration: 0.18)) { amplitud = 7 } completion: {
                withAnimation(.smooth(duration: 1.6)) { amplitud = 2.4 }
            }
            withAnimation(.smooth(duration: 0.9)) { lo = e.lo; hi = e.hi; nivel = d }
        }
    }

    private func chapotear() {
        chapoteos += 1
        guard !menosMovimiento else { return }
        withAnimation(.snappy(duration: 0.15)) { amplitud = 6.5 } completion: {
            withAnimation(.smooth(duration: 1.4)) { amplitud = 2.4 }
        }
    }

    private func empezarAMedir() {
        guard !menosMovimiento, !midiendo else { return }
        midiendo = true
        Inclinometro.compartido.empezar()
    }

    private func dejarDeMedir() {
        guard midiendo else { return }
        midiendo = false
        Inclinometro.compartido.parar()
    }
}

private struct Apretar: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var menosMovimiento

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !menosMovimiento ? 0.97 : 1)
            .animation(.spring(duration: 0.25, bounce: 0.3), value: configuration.isPressed)
    }
}

private struct Perla {
    var y: CGFloat
    var agua: Double
    var escala: CGFloat
}

@MainActor
final class Inclinometro {
    static let compartido = Inclinometro()
    private static let tope = 0.2

    private let gestor = CMMotionManager()
    private var suave: Double = 0
    private var ultima: Date = .distantPast
    private var usuarios = 0

    func empezar() {
        usuarios += 1
        guard gestor.isDeviceMotionAvailable, !gestor.isDeviceMotionActive else { return }
        gestor.deviceMotionUpdateInterval = 1.0 / 30
        gestor.startDeviceMotionUpdates()
    }

    func parar() {
        usuarios = max(0, usuarios - 1)
        guard usuarios == 0 else { return }
        gestor.stopDeviceMotionUpdates()
        suave = 0
        ultima = .distantPast
    }

    func angulo(_ ahora: Date) -> Double {
        let paso = ahora.timeIntervalSince(ultima)
        if abs(paso) < 1.0 / 120 { return suave }
        ultima = ahora
        var objetivo = 0.0
        if let g = gestor.deviceMotion?.gravity {
            let plano = (g.x * g.x + g.y * g.y).squareRoot()
            if plano > 0.3 {
                let a = atan2(g.x, -g.y)
                if abs(a) < .pi / 2 {
                    objetivo = max(-Self.tope, min(Self.tope, a)) * min(1, (plano - 0.3) / 0.3)
                }
            }
        }
        
        let k = 1 - exp(-min(max(paso, 0), 0.2) / 0.18)
        suave += (objetivo - suave) * k
        return suave
    }
}

private func alturaDe(_ v: Double, lo: Double, hi: Double, en r: CGRect) -> CGFloat {
    r.maxY - (v - lo) / max(hi - lo, 0.001) * r.height
}

private func superficie(_ t: Double, en r: CGRect, y0: CGFloat, amplitud: Double, fase: Double,
                        inclinacion: Double, pivote: CGFloat) -> CGFloat {
    let x = r.width * t
    return y0 + amplitud * sin(fase + t * 2 * .pi * 1.15)
        - CGFloat(tan(inclinacion)) * (x - r.width * pivote)
}

private struct Liquido: Shape {
    var nivel: Double
    var lo: Double
    var hi: Double
    var amplitud: Double
    var fase: Double
    var inclinacion: Double = 0
    var pivote: CGFloat = 0.5

    var animatableData: AnimatablePair<AnimatablePair<Double, Double>, AnimatablePair<Double, Double>> {
        get { AnimatablePair(AnimatablePair(nivel, lo), AnimatablePair(hi, amplitud)) }
        set {
            nivel = newValue.first.first; lo = newValue.first.second
            hi = newValue.second.first; amplitud = newValue.second.second
        }
    }

    func path(in r: CGRect) -> Path {
        let y0 = alturaDe(nivel, lo: lo, hi: hi, en: r)
        
        let vacio = y0 > r.maxY - 1
        let a = vacio ? 0 : amplitud
        let incl = vacio ? 0 : inclinacion
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.maxY))
        let pasos = 36
        for i in 0...pasos {
            let t = Double(i) / Double(pasos)
            p.addLine(to: CGPoint(x: r.minX + r.width * t,
                                  y: superficie(t, en: r, y0: y0, amplitud: a, fase: fase,
                                                inclinacion: incl, pivote: pivote)))
        }
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
        p.closeSubpath()
        return p
    }
}

private struct Falta: Shape {
    var nivel: Double
    var lo: Double
    var hi: Double
    var amplitud: Double
    var fase: Double
    var inclinacion: Double = 0
    var pivote: CGFloat = 0.5

    var animatableData: AnimatablePair<AnimatablePair<Double, Double>, AnimatablePair<Double, Double>> {
        get { AnimatablePair(AnimatablePair(nivel, lo), AnimatablePair(hi, amplitud)) }
        set {
            nivel = newValue.first.first; lo = newValue.first.second
            hi = newValue.second.first; amplitud = newValue.second.second
        }
    }

    func path(in r: CGRect) -> Path {
        guard nivel < 0 else { return Path() }
        let yCero = alturaDe(0, lo: lo, hi: hi, en: r)
        let y0 = alturaDe(nivel, lo: lo, hi: hi, en: r)
        var p = Path()
        p.move(to: CGPoint(x: r.maxX, y: yCero))
        p.addLine(to: CGPoint(x: r.minX, y: yCero))
        let pasos = 36
        for i in 0...pasos {
            let t = Double(i) / Double(pasos)
            let y = superficie(t, en: r, y0: y0, amplitud: amplitud, fase: fase,
                               inclinacion: inclinacion, pivote: pivote)
            p.addLine(to: CGPoint(x: r.minX + r.width * t, y: max(y, yCero)))
        }
        p.closeSubpath()
        return p
    }
}

private struct PorEncimaDelCero: Shape {
    var lo: Double
    var hi: Double

    var animatableData: AnimatablePair<Double, Double> {
        get { AnimatablePair(lo, hi) }
        set { lo = newValue.first; hi = newValue.second }
    }

    func path(in r: CGRect) -> Path {
        Path(CGRect(x: r.minX, y: r.minY, width: r.width,
                    height: alturaDe(0, lo: lo, hi: hi, en: r) - r.minY))
    }
}

private struct Graduacion: Shape {
    var lo: Double
    var hi: Double
    
    let margen: CGFloat

    static func numeradas(lo: Double, hi: Double, alto: CGFloat, margen: CGFloat) -> [Double] {
        let rango = max(hi - lo, 0.001)
        let paso: Double = rango > 40 ? 5 : 1
        var salida: [Double] = []
        var k = (lo / (paso * 5)).rounded(.up) * paso * 5
        while k <= hi {
            let y = alto - (k - lo) / rango * alto
            if k != 0, y > margen * 0.6, y < alto - margen * 0.6 { salida.append(k) }
            k += paso * 5
        }
        return salida
    }

    var animatableData: AnimatablePair<Double, Double> {
        get { AnimatablePair(lo, hi) }
        set { lo = newValue.first; hi = newValue.second }
    }

    func path(in r: CGRect) -> Path {
        var p = Path()
        let rango = max(hi - lo, 0.001)
        let paso: Double = rango > 40 ? 5 : 1
        var k = (lo / paso).rounded(.up) * paso
        while k <= hi {
            let y = r.maxY - (k - lo) / rango * r.height
            if k != 0, y > r.minY + margen * 0.6, y < r.maxY - margen * 0.6 {
                let larga = Int(k.rounded()) % Int(paso * 5) == 0
                let largo: CGFloat = larga ? 12 : 6
                p.move(to: CGPoint(x: r.maxX - largo, y: y))
                p.addLine(to: CGPoint(x: r.maxX, y: y))
            }
            k += paso
        }
        return p
    }
}

private struct LineaCero: Shape {
    var lo: Double
    var hi: Double

    var animatableData: AnimatablePair<Double, Double> {
        get { AnimatablePair(lo, hi) }
        set { lo = newValue.first; hi = newValue.second }
    }

    func path(in r: CGRect) -> Path {
        let y = alturaDe(0, lo: lo, hi: hi, en: r)
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: y))
        p.addLine(to: CGPoint(x: r.maxX, y: y))
        return p
    }
}

struct AnilloDia: View {
    let dia: PantallaHucha.DiaHucha
    
    var objetivoPorDefecto: Double = 0
    var grosor: CGFloat = 12

    var animado = true
    
    var espera: Double = 0.15

    @Environment(\.accessibilityReduceMotion) private var menosMovimiento

    @Environment(\.accessibilityDifferentiateWithoutColor) private var sinColor
    @State private var avance: Double = 0

    private var objetivo: Double { dia.objetivo ?? objetivoPorDefecto }

    private var partes: PartesDelAnillo {
        let o = max(objetivo, 0.0001)
        let falta = dia.falta ?? max(0, objetivo - dia.ganado)
        let propio = objetivo > 0 ? min(1, max(0, (objetivo - falta) / o)) : 0
        let reserva = dia.cerrado ? min(1 - propio, max(0, dia.relleno / o)) : 0
        let nadie = dia.cerrado ? min(1 - propio - reserva, max(0, (falta - dia.relleno) / o)) : 0
        return PartesDelAnillo(propio: propio, reserva: reserva, nadie: nadie,
                               extra: min(3, max(0, dia.aporte / o)))
    }

    var body: some View {
        let p = partes
        let k = animado ? avance : 1
        let trazo = StrokeStyle(lineWidth: grosor, lineCap: .round)
        ZStack {
            Circle().stroke(Diseno.verdeRelleno.opacity(0.2), lineWidth: grosor)
            tramo(.propio, p, k).stroke(Diseno.verdeRelleno, style: trazo)
            tramo(.reserva, p, k).stroke(Diseno.azulRelleno, style: trazo)
            tramo(.nadie, p, k).stroke(Diseno.rojoRelleno,
                                       style: sinColor ? AnilloDia.aRayas(grosor) : trazo)

            ForEach(0..<Int(p.extra.rounded(.up)), id: \.self) { vuelta in
                if grosor >= 8 {
                    tramo(.punta(vuelta), p, k)
                        .stroke(Diseno.verdeRelleno, style: trazo)
                        .shadow(color: .black.opacity(0.4), radius: grosor * 0.2, x: 0,
                                y: grosor * 0.15)
                }
                tramo(.vuelta(vuelta), p, k).stroke(Diseno.verdeRelleno, style: trazo)
            }
        }
        .rotationEffect(.degrees(-90))
        .padding(grosor / 2)
        .onAppear {
            guard animado else { return }
            if menosMovimiento { avance = 1; return }

            let duracion = (grosor < 6 ? 0.6 : 1.0) + 0.25 * p.extra
            withAnimation(.smooth(duration: duracion).delay(espera)) { avance = 1 }
        }
        .animation(menosMovimiento || !animado ? nil : .smooth(duration: 0.6), value: dia)
    }

    static func aRayas(_ grosor: CGFloat) -> StrokeStyle {
        StrokeStyle(lineWidth: grosor, lineCap: .butt, dash: [grosor * 0.7, grosor * 0.55])
    }

    private func tramo(_ cual: TramoDelAnillo.Cual, _ p: PartesDelAnillo,
                       _ k: Double) -> TramoDelAnillo {
        TramoDelAnillo(cual: cual, avance: k, propio: p.propio, reserva: p.reserva,
                       nadie: p.nadie, extra: p.extra)
    }
}

private struct PartesDelAnillo {
    let propio: Double
    let reserva: Double
    let nadie: Double
    let extra: Double
}

private struct TramoDelAnillo: Shape {
    enum Cual { case propio, reserva, nadie, vuelta(Int), punta(Int) }
    let cual: Cual
    
    var avance: Double
    var propio: Double
    var reserva: Double
    var nadie: Double
    var extra: Double

    var animatableData: AnimatablePair<Double, AnimatablePair<AnimatablePair<Double, Double>,
                                                             AnimatablePair<Double, Double>>> {
        get {
            AnimatablePair(avance, AnimatablePair(AnimatablePair(propio, reserva),
                                                  AnimatablePair(nadie, extra)))
        }
        set {
            avance = newValue.first
            propio = newValue.second.first.first
            reserva = newValue.second.first.second
            nadie = newValue.second.second.first
            extra = newValue.second.second.second
        }
    }

    func path(in r: CGRect) -> Path {
        let delDia = propio + reserva + nadie
        
        let punta = (delDia + extra) * avance
        switch cual {
        case .propio: return arco(0, min(punta, propio), en: r)
        case .reserva: return arco(propio, min(punta, propio + reserva), en: r)
        case .nadie: return arco(propio + reserva, min(punta, delDia), en: r)
        case .vuelta(let n): return arco(0, min(1, punta - delDia - Double(n)), en: r)
        case .punta(let n):
            let fin = min(1, punta - delDia - Double(n))
            return fin > 0.02 ? arco(fin - 0.012, fin, en: r) : Path()
        }
    }

    private func arco(_ desde: Double, _ hasta: Double, en r: CGRect) -> Path {
        guard hasta - desde > 0.002 else { return Path() }
        return Circle().trim(from: desde, to: hasta).path(in: r)
    }
}

struct TiraDelMes: View {
    
    let mes: String
    let dias: [String: PantallaHucha.DiaHucha]
    
    let hoy: String?

    private var cuantos: Int {
        let p = mes.split(separator: "-")
        guard p.count == 2, let a = Int(p[0]), let m = Int(p[1]),
              let fecha = DateComponents(calendar: .current, year: a, month: m, day: 1).date
        else { return 30 }
        return Calendar.current.range(of: .day, in: .month, for: fecha)?.count ?? 30
    }

    var body: some View {
        HStack(spacing: 3) {
            ForEach(1...max(1, cuantos), id: \.self) { d in
                segmento("\(mes)-" + String(format: "%02d", d))
            }
        }
        .frame(height: 18)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Días del mes")
        .accessibilityValue(resumen)
    }

    @ViewBuilder
    private func segmento(_ clave: String) -> some View {
        if clave == hoy {
            Capsule()
                .strokeBorder(Color.primary.opacity(0.7), lineWidth: 1.5)
                .modifier(Latido(activo: true))
        } else if let d = dias[clave], d.cerrado {
            Capsule().fill(PantallaHucha.DiaHucha.color(d))
        } else {
            Capsule().fill(.fill.tertiary)
        }
    }

    private var resumen: String {
        let cerrados = dias.values.filter { $0.cerrado && $0.fecha.hasPrefix(mes) }
        let rojos = cerrados.filter(\.falto).count
        let azules = cerrados.filter { !$0.falto && $0.relleno > 0.004 }.count
        return "\(cerrados.count - rojos - azules) llegaste, \(azules) los puso la reserva, "
            + "\(rojos) sin cubrir"
    }
}

struct BarraComparada: View {
    let titulo: String
    let valor: Double
    let maximo: Double
    let color: AnyShapeStyle

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(titulo).font(.caption).foregroundStyle(.secondary)
                Spacer(minLength: 4)
                Text(Formato.eurosRedondos(valor))
                    .font(.caption.weight(.semibold))
                    .monospacedDigit()
                    .contentTransition(.numericText(value: valor))
            }
            GeometryReader { g in
                Capsule().fill(.fill.tertiary)
                    .overlay(alignment: .leading) {
                        Capsule().fill(color).frame(width: g.size.width * fraccion)
                    }
            }
            .frame(height: 6)
            .animation(Diseno.suave, value: fraccion)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(titulo)
        .accessibilityValue(Formato.euros(valor))
    }

    private var fraccion: Double {
        maximo > 0 ? max(0, min(1, valor / maximo)) : 0
    }
}

extension PantallaHucha.DiaHucha {
    
    static func color(_ d: PantallaHucha.DiaHucha) -> Color {
        if d.falto { return Diseno.rojoRelleno }
        if d.relleno > 0.004 { return Diseno.azulRelleno }
        return Diseno.verdeRelleno
    }

    func sinDirecto(objetivo o: Double) -> Bool {
        guard let falta, o > 0 else { return false }
        return ganado > 0.004 && falta >= o - 0.005
    }
}

extension Formato {

    static func eurosRedondos(_ valor: Double) -> String {
        if Privacidad.compartida.oculta { return "••• €" }      
        return Formato.conMenos(valor.formatted(.currency(code: "EUR").precision(.fractionLength(0))
            .locale(Locale(identifier: "es_ES"))))
    }

    static func eurosJustos(_ valor: Double) -> String {
        abs(valor - valor.rounded()) < 0.005 ? eurosRedondos(valor) : euros(valor)
    }

    static func diaSemana(_ iso: String) -> String {
        let p = iso.split(separator: "-")
        guard p.count == 3, let a = Int(p[0]), let m = Int(p[1]), let d = Int(p[2]),
              let fecha = DateComponents(calendar: .current, year: a, month: m, day: d).date
        else { return iso }
        let dias = ["dom", "lun", "mar", "mié", "jue", "vie", "sáb"]
        return "\(dias[Calendar.current.component(.weekday, from: fecha) - 1]) \(d)"
    }
}
