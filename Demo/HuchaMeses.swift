import SwiftUI

struct MesesHucha: View {
    let meses: [PantallaHucha.MesCerrado]

    @Environment(\.accessibilityReduceMotion) private var menosMovimiento
    @State private var elegido: String?
    @State private var crecidas = false
    
    @State private var aLaVista = false

    private var enOrden: [PantallaHucha.MesCerrado] { meses.reversed() }

    private var actual: PantallaHucha.MesCerrado? {
        meses.first { $0.mes == elegido } ?? meses.first
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Diseno.hueco3) {
            Text("Meses").font(.title3.weight(.semibold)).padding(.leading, 4)
            Tarjeta {
                VStack(alignment: .leading, spacing: Diseno.hueco4) {
                    if let m = actual { cabecera(m) }
                    ColumnasDeMeses(meses: enOrden, elegido: actual?.mes,
                                    crecidas: crecidas) { mes in
                        if mes != elegido { elegido = mes }
                    }
                    .frame(height: 196)
                }
            }
        }

        .onScrollVisibilityChange(threshold: 0.35) { aLaVista = $0 }
        .onGeometryChange(for: Bool.self) { g in
            guard let visto = g.bounds(of: .scrollView) else { return false }
            let comun = CGRect(origin: .zero, size: g.size).intersection(visto)
            return !comun.isNull && comun.height >= g.size.height * 0.35
        } action: { aLaVista = $0 }
        .task(id: aLaVista) {
            guard aLaVista, !crecidas else { return }
            try? await Task.sleep(for: .milliseconds(300))
            if !Task.isCancelled { crecer() }
        }
    }

    private func crecer() {
        guard !crecidas else { return }
        if menosMovimiento {
            crecidas = true
        } else {

            let orden = enOrden
            let i = orden.firstIndex { $0.mes == actual?.mes } ?? max(0, orden.count - 1)
            let espera = ColumnasDeMeses.retraso(i, total: orden.count) + 0.55
            withAnimation(.spring(duration: 0.45, bounce: 0.3).delay(espera)) { crecidas = true }
        }
    }

    private func cabecera(_ m: PantallaHucha.MesCerrado) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(nombre(m.mes, año: true))
                .font(.subheadline).foregroundStyle(.secondary)
            Text(Formato.euros(m.saldoFinal))
                .font(.system(.title2, design: .rounded).weight(.semibold))
                .foregroundStyle(m.saldoFinal < 0 ? Diseno.rojo : Diseno.verde)
                .monospacedDigit()
                .contentTransition(.numericText(value: m.saldoFinal))
            
            Text("\(Formato.eurosRedondos(m.ganado)) de \(Formato.eurosRedondos(m.objetivoMes))")
                .font(.caption).foregroundStyle(.secondary).monospacedDigit()
        }
        .animation(Diseno.cifra, value: m)
        .accessibilityElement(children: .combine)
    }

    private func nombre(_ iso: String, año: Bool = false) -> String {
        let n = CobrosHucha.nombreDelMes(iso).capitalized
        return año ? "\(n) \(iso.prefix(4))" : n
    }
}

private struct ColumnasDeMeses: View {
    
    let meses: [PantallaHucha.MesCerrado]
    let elegido: String?
    let crecidas: Bool
    let elegir: (String) -> Void

    @Environment(\.accessibilityReduceMotion) private var menosMovimiento
    @ScaledMetric(relativeTo: .caption2) private var altoEtiquetasEscalado: CGFloat = 22

    private enum Direccion { case nada, horizontal, vertical }
    @GestureState private var direccion: Direccion = .nada
    private var tocando: Bool { direccion == .horizontal }

    private var altoEtiquetas: CGFloat { min(altoEtiquetasEscalado, 30) }
    
    private static let margen: CGFloat = 16
    static let maxVisibles = 12

    static func retraso(_ i: Int, total: Int) -> Double {
        let primera = max(0, total - maxVisibles)
        return Double(min(max(0, i - primera), 20)) * 0.04
    }

    private var indice: Int? { meses.firstIndex { $0.mes == elegido } }

    var body: some View {
        GeometryReader { g in
            let visibles = min(max(meses.count, 1), Self.maxVisibles)
            let hueco = g.size.width / CGFloat(visibles)
            if meses.count > Self.maxVisibles {
                ScrollView(.horizontal, showsIndicators: false) {
                    lienzo(hueco: hueco, alto: g.size.height)
                        .contentShape(.rect)
                        .onTapGesture(coordinateSpace: .local) { p in
                            seleccionar(en: p.x, hueco: hueco)
                        }
                }
                .defaultScrollAnchor(.trailing)
            } else {
                lienzo(hueco: hueco, alto: g.size.height)
                    .contentShape(.rect)
                    .simultaneousGesture(arrastre(hueco: hueco))
            }
        }
        .sensoryFeedback(.selection, trigger: elegido)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Meses")
        .accessibilityValue(valorAccesible)
        .accessibilityAdjustableAction { direccion in
            guard let i = indice else { return }
            switch direccion {
            case .increment: if i + 1 < meses.count { elegir(meses[i + 1].mes) }
            case .decrement: if i > 0 { elegir(meses[i - 1].mes) }
            @unknown default: break
            }
        }
    }

    private var valorAccesible: String {
        guard let i = indice else { return "" }
        let m = meses[i]
        return "\(CobrosHucha.nombreDelMes(m.mes, conAño: true)), \(Formato.euros(m.saldoFinal))"
    }

    private func lienzo(hueco: CGFloat, alto: CGFloat) -> some View {
        let altoGrafica = max(40, alto - altoEtiquetas)
        let valores = meses.map(\.saldoFinal)
        let tope = max(valores.max() ?? 0, 0)
        let suelo = min(valores.min() ?? 0, 0)
        let rango = max(tope - suelo, 1)
        let util = altoGrafica - 2 * Self.margen
        let yCero = Self.margen + CGFloat(tope / rango) * util
        let ancho = min(hueco * 0.46, 18)

        return ZStack(alignment: .topLeading) {
            
            Rectangle()
                .fill(Color.primary.opacity(0.18))
                .frame(width: hueco * CGFloat(meses.count), height: 1)
                .offset(y: yCero)

            if crecidas, let i = indice {
                let c = color(meses[i])
                Capsule()
                    .fill(LinearGradient(colors: [c.opacity(0), c.opacity(0.9), c.opacity(0)],
                                         startPoint: .top, endPoint: .bottom))
                    .frame(width: 3, height: altoGrafica)
                    .shadow(color: c.opacity(0.55), radius: 5)
                    .offset(x: hueco * (CGFloat(i) + 0.5) - 1.5)
                    .animation(movimiento(.spring(duration: 0.35, bounce: 0.15)), value: i)
            }

            ForEach(Array(meses.enumerated()), id: \.element.id) { i, m in
                columna(m, i: i, hueco: hueco, ancho: ancho, yCero: yCero,
                        largo: largo(m, ancho: ancho, rango: rango, util: util))
            }

            if crecidas, let i = indice {
                let m = meses[i]
                let l = largo(m, ancho: ancho, rango: rango, util: util)
                let px = hueco * (CGFloat(i) + 0.5)
                let py = m.saldoFinal < 0 ? yCero + l : yCero - l
                let anchoTotal = max(hueco * CGFloat(meses.count), 1)
                Lente(color: color(m), tocando: tocando)
                    .position(x: px, y: py)
                    .animation(movimiento(.spring(duration: 0.4, bounce: 0.25)), value: i)
                    .transition(.scale(scale: 0.2,
                                       anchor: UnitPoint(x: px / anchoTotal, y: py / max(alto, 1))))
            }

            ForEach(Array(meses.enumerated()), id: \.element.id) { i, m in
                Text(CobrosHucha.nombreDelMes(m.mes).capitalized.prefix(3))
                    .font(.caption2.weight(i == indice ? .semibold : .regular))
                    .foregroundStyle(i == indice ? Color.primary : Color.secondary)
                    .dynamicTypeSize(...DynamicTypeSize.xLarge)
                    .fixedSize()
                    .position(x: hueco * (CGFloat(i) + 0.5),
                              y: altoGrafica + altoEtiquetas / 2)
            }
        }
        .frame(width: hueco * CGFloat(meses.count), height: alto, alignment: .topLeading)
    }

    private func largo(_ m: PantallaHucha.MesCerrado, ancho: CGFloat, rango: Double,
                       util: CGFloat) -> CGFloat {
        max(CGFloat(abs(m.saldoFinal) / rango) * util, ancho)
    }

    private func columna(_ m: PantallaHucha.MesCerrado, i: Int, hueco: CGFloat, ancho: CGFloat,
                         yCero: CGFloat, largo: CGFloat) -> some View {
        let arriba = m.saldoFinal >= 0
        let c = color(m)
        let elegida = (i == indice)
        return Capsule()
            .fill(LinearGradient(colors: arriba ? [c, c.opacity(0.45)] : [c.opacity(0.45), c],
                                 startPoint: .top, endPoint: .bottom))
            .frame(width: ancho, height: largo)
            .scaleEffect(x: 1, y: crecidas ? 1 : 0.02, anchor: arriba ? .bottom : .top)
            
            .opacity(elegida || !tocando ? 1 : 0.38)
            .position(x: hueco * (CGFloat(i) + 0.5),
                      y: arriba ? yCero - largo / 2 : yCero + largo / 2)
            .animation(movimiento(.spring(duration: 0.7, bounce: 0.28)
                .delay(Self.retraso(i, total: meses.count))), value: crecidas)
            .animation(movimiento(.smooth(duration: 0.25)), value: elegida)
            .animation(movimiento(.smooth(duration: 0.2)), value: tocando)
    }

    private func color(_ m: PantallaHucha.MesCerrado) -> Color {
        m.saldoFinal < 0 ? Diseno.rojoRelleno : Diseno.verdeRelleno
    }

    private func movimiento(_ a: Animation) -> Animation? { menosMovimiento ? nil : a }

    private func arrastre(hueco: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .updating($direccion) { v, estado, _ in
                guard estado == .nada else { return }
                let dx = abs(v.translation.width), dy = abs(v.translation.height)
                if dx + dy >= 6 { estado = dx > dy ? .horizontal : .vertical }
            }
            .onChanged { v in
                let dx = abs(v.translation.width), dy = abs(v.translation.height)
                let horizontal = direccion == .horizontal
                    || (direccion == .nada && dx + dy >= 6 && dx > dy)
                if horizontal { seleccionar(en: v.location.x, hueco: hueco) }
            }
            .onEnded { v in
                
                if abs(v.translation.width) + abs(v.translation.height) < 6 {
                    seleccionar(en: v.location.x, hueco: hueco)
                }
            }
    }

    private func seleccionar(en x: CGFloat, hueco: CGFloat) {
        guard !meses.isEmpty, hueco > 0 else { return }
        let i = max(0, min(meses.count - 1, Int(x / hueco)))
        elegir(meses[i].mes)
    }
}

private struct Lente: View {
    let color: Color
    let tocando: Bool

    @Environment(\.accessibilityReduceTransparency) private var menosTransparencia

    var body: some View {
        Group {
            if menosTransparencia {
                Circle()
                    .fill(color)
                    .overlay(Circle().strokeBorder(Color.white, lineWidth: 2))
                    .frame(width: 18, height: 18)
            } else {
                Color.clear
                    .frame(width: 20, height: 20)
                    .glassEffect(.regular.tint(color), in: .circle)
            }
        }
        .scaleEffect(tocando ? 1.3 : 1)
        .animation(.spring(duration: 0.3, bounce: 0.35), value: tocando)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
