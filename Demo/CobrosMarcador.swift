import SwiftUI

struct CobrosMarcador: View {
    let hoy: String
    let llegados: [Cobro]
    let proximos: [Cobro]
    
    let meses: [MesDeCobros]
    let faltaApartar: Double?
    @Binding var rastreando: Bool

    @State private var elegido: String?
    @State private var abiertos: Set<String> = []

    static func porDefecto(proximos: [Cobro], llegados: [Cobro]) -> Cobro? {
        
        proximos.first { !$0.fecha.isEmpty } ?? proximos.first ?? llegados.last
    }

    private var porDefecto: Cobro? { Self.porDefecto(proximos: proximos, llegados: llegados) }

    private var mostrado: Cobro? {
        if let e = elegido, let c = (llegados + proximos).first(where: { $0.id == e }) { return c }
        return porDefecto
    }

    private var enLaLinea: [Cobro] {
        let desde = Fechas.mas(hoy, -LineaDeCobros.diasAtras)
        
        return (llegados.filter { $0.fecha >= desde } + proximos.filter { !$0.fecha.isEmpty })
            .sorted { $0.fecha < $1.fecha }
    }

    private var mesEnCurso: MesDeCobros? { meses.first }
    private var anteriores: [MesDeCobros] { Array(meses.dropFirst()) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let c = mostrado {
                ElCobro(cobro: c, esElDeSiempre: c.id == porDefecto?.id,
                        previo: previo(de: c), hoy: hoy)
                    .padding(.horizontal, Diseno.margen)
                    .padding(.top, Diseno.hueco1)
            }

            LineaDeCobros(cobros: enLaLinea, hoy: hoy, porDefecto: porDefecto?.id,
                          elegido: $elegido, rastreando: $rastreando)
                .frame(height: 196)
                .padding(.top, Diseno.hueco2)

            accesos
                .padding(.top, Diseno.hueco2)

            if proximos.count > 1 {
                TituloDeSeccion(texto: "Después")
                    .padding(.horizontal, Diseno.margen)
                FilasDeCobros(cobros: proximos.filter { $0.id != porDefecto?.id }.map {
                    CobroQueLlega(id: $0.id, plataforma: $0.plataforma, nombre: $0.nombre,
                                  fecha: $0.fecha, euros: $0.euros, estimado: $0.estimado,
                                  faltaUSD: $0.faltaUSD)
                })
                .padding(.horizontal, Diseno.margen)
            }

            if let m = mesEnCurso { esteMes(m) }
            if !anteriores.isEmpty { historial }
        }
        .padding(.bottom, Diseno.hueco5)
        .sensoryFeedback(.selection, trigger: elegido)
        .sensoryFeedback(.selection, trigger: abiertos)
        
        .onDisappear { elegido = nil }
        #if MAQUETA
        .onAppear {
            if let n = Maqueta.cobroElegido, enLaLinea.indices.contains(n) { elegido = enLaLinea[n].id }
            if Maqueta.abrirMes, let m = anteriores.first { abiertos.insert(m.mes) }
        }
        #endif
    }

    private func previo(de c: Cobro) -> String? {
        llegados.last { $0.plataforma == c.plataforma && $0.fecha < c.fecha }?.fecha
    }

    private var accesos: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Diseno.hueco2) {
                if let f = faltaApartar {
                    if f > 0.004 {
                        AccesoHeroe(icono: "drop.fill", titulo: "Apartar \(Formato.euros(f))",
                                    aviso: true) { PantallaHuchaNueva() }
                    } else {
                        AccesoHeroe(icono: "checkmark", titulo: "Todo apartado") {
                            PantallaHuchaNueva()
                        }
                    }
                }
                AccesoHeroe(icono: "arrow.left.arrow.right", titulo: "Transferencias") {
                    PantallaTransferencias()
                }
            }
            .padding(.horizontal, Diseno.margen)
        }
        .scrollClipDisabled()
        .modifier(BordeQueSigue())
        
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
    }

    @ViewBuilder
    private func esteMes(_ m: MesDeCobros) -> some View {
        let llegadosDelMes = m.cobros.filter(\.llegado).count
        TituloDeSeccion(texto: "Este mes")
            .padding(.horizontal, Diseno.margen)
        VStack(alignment: .leading, spacing: Diseno.hueco2) {
            FilaDeMedias(medias: [
                
                .init(titulo: "Llegado", valor: m.llegado, tendencia: nil,
                      nota: llegadosDelMes == 0 ? nil
                          : llegadosDelMes == 1 ? "1 cobro" : "\(llegadosDelMes) cobros"),
                .init(titulo: "Por llegar", valor: m.porLlegar, tendencia: nil,
                      nota: m.porLlegar > 0.004 ? "estimado" : nil),
            ])
            BarraDelMes(llegado: m.llegado, porLlegar: m.porLlegar)
                .accessibilityHidden(true)
            if !m.cobros.isEmpty {
                plegable(m.mes) {
                    HStack {
                        Text("Cobros de \(CobrosHucha.nombreDelMes(m.mes))")
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        Text("\(m.cobros.count)")
                            .font(.subheadline.weight(.medium)).monospacedDigit()
                            .foregroundStyle(Marcador.apoyo)
                    }
                    .frame(minHeight: 44)
                } contenido: {
                    FilasDelMes(cobros: m.cobros)
                }
            }
        }
        .padding(.horizontal, Diseno.margen)
        .padding(.top, Diseno.hueco1)
    }

    @ViewBuilder
    private var historial: some View {
        TituloDeSeccion(texto: "Historial")
            .padding(.horizontal, Diseno.margen)
        VStack(spacing: 0) {
            ForEach(Array(anteriores.enumerated()), id: \.element.mes) { i, m in
                if i > 0 { Divider() }
                plegable(m.mes) {
                    CabeceraDeMes(mes: m)
                } contenido: {
                    FilasDelMes(cobros: m.cobros)
                }
            }
        }
        .padding(.horizontal, Diseno.margen)
        .padding(.top, Diseno.hueco1)
    }

    private func plegable<Cabecera: View, Contenido: View>(
        _ clave: String, @ViewBuilder cabecera: () -> Cabecera,
        @ViewBuilder contenido: () -> Contenido) -> some View {
        let cuerpo = contenido()
        let titulo = cabecera()
        return DisclosureGroup(isExpanded: Binding(
            get: { abiertos.contains(clave) },
            set: { abierto in
                withAnimation(Diseno.suave) {
                    if abierto { abiertos.insert(clave) } else { abiertos.remove(clave) }
                }
            })) {
            cuerpo
                .padding(.top, Diseno.hueco1)
        } label: {

            titulo
                .foregroundStyle(Color.primary)
                .contentShape(.rect)
        }
        .tint(Marcador.apoyo)
    }
}

private struct ElCobro: View {
    let cobro: Cobro
    
    let esElDeSiempre: Bool
    
    let previo: String?
    let hoy: String

    @Environment(\.dynamicTypeSize) private var letra
    @Environment(\.accessibilityReduceMotion) private var menosMovimiento

    @ScaledMetric(relativeTo: .headline) private var punto: CGFloat = 10

    private var faltan: Int { Fechas.dias(de: hoy, a: cobro.fecha) }

    private var hecho: Double {
        if cobro.llegado { return 1 }
        guard let previo else { return 0 }
        let total = max(Fechas.dias(de: previo, a: cobro.fecha), 1)
        return min(max(Double(Fechas.dias(de: previo, a: hoy)) / Double(total), 0), 1)
    }

    private var detalle: String? {
        if !cobro.detalle.isEmpty { return cobro.detalle }
        let partes = cobro.nombre.components(separatedBy: " · ")
        return partes.count > 1 ? partes.dropFirst().joined(separator: " · ").capitalizandoPrimera : nil
    }

    private var nombre: String {
        cobro.nombre.components(separatedBy: " · ").first ?? cobro.nombre
    }

    private var cuando: String {
        if cobro.fecha.isEmpty { return cobro.sinFecha.capitalizandoPrimera }
        let dia = Fechas.larga(cobro.fecha).capitalizandoPrimera
        if cobro.llegado { return dia + " · " + Fechas.cuando(cobro.fecha, hoy: hoy) }
        if faltan < 0 {
            
            let n = Int(cobro.fecha.suffix(2)) ?? 0
            return "Se esperaba el \(Fechas.diaDeLaSemana(cobro.fecha)) \(n) · aún no consta"
        }
        return dia
    }

    var body: some View {

        VStack(alignment: .leading, spacing: Diseno.hueco1) {
            if letra.isAccessibilitySize {
                identidad
                estimado
            } else {
                HStack(alignment: .center, spacing: 0) {
                    identidad
                    Spacer(minLength: Diseno.hueco2)
                    estimado
                }
            }
            HStack(alignment: .center, spacing: Diseno.hueco2) {
                VStack(alignment: .leading, spacing: 0) {
                    CifraMarcador(euros: cobro.euros)
                    Text(cuando)
                        .font(.subheadline)
                        .foregroundStyle(Marcador.apoyo)
                        .lineLimit(letra.isAccessibilitySize ? 3 : 1, reservesSpace: true)
                        .minimumScaleFactor(letra.isAccessibilitySize ? 1 : 0.75)
                        .contentTransition(.interpolate)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                RelojDelCobro(color: cobro.color, hecho: cobro.fecha.isEmpty ? 0 : hecho,
                              llegado: cobro.llegado, faltan: faltan,
                              sinFecha: cobro.fecha.isEmpty)
            }
        }
        .animation(menosMovimiento ? nil : .snappy(duration: 0.22), value: cobro.id)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(etiquetaAccesible)
    }

    @ViewBuilder
    private var estimado: some View {
        if cobro.estimado {
            PastillaDeCristal(texto: "estimado", icono: "plusminus")
                .transition(menosMovimiento ? .opacity
                                            : .opacity.combined(with: .scale(scale: 0.85)))
        } else {
            PastillaDeCristal(texto: "estimado", icono: "plusminus", hueco: true)
        }
    }

    private var identidad: some View {
        ZStack(alignment: .leading) {
            Group {
                if letra.isAccessibilitySize {
                    
                    VStack(alignment: .leading, spacing: 2) {
                        nombreConPunto
                        Text(detalle ?? "")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Marcador.apoyo)
                            .lineLimit(2, reservesSpace: true)
                    }
                } else {
                    HStack(alignment: .firstTextBaseline, spacing: Diseno.hueco1) {
                        nombreConPunto
                        if let detalle {
                            Text(detalle)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(Marcador.apoyo)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                    }
                }
            }
            .id(cobro.id)
            .transition(.opacity)
        }
    }

    private var nombreConPunto: some View {
        HStack(alignment: .center, spacing: Diseno.hueco1) {
            Circle().fill(cobro.color.gradient)
                .frame(width: min(punto, 22), height: min(punto, 22))
            Text(nombre)
                .font(.headline)
                .lineLimit(1)
                .fixedSize()
        }
    }

    private var etiquetaAccesible: String {
        let que = cobro.llegado ? "Llegó" : (esElDeSiempre ? "Próximo cobro" : "Por llegar")
        let espera: String
        if cobro.fecha.isEmpty {
            espera = cobro.sinFecha
        } else if cobro.llegado || faltan < 0 {
            espera = ""
        } else {
            espera = faltan == 0 ? "llega hoy" : faltan == 1 ? "falta 1 día" : "faltan \(faltan) días"
        }
        return [que, nombre, detalle ?? "", Formato.euros(cobro.euros), cuando, espera,
                cobro.estimado ? "estimado" : ""]
            .filter { !$0.isEmpty }.joined(separator: ", ")
    }
}

private struct RelojDelCobro: View {
    let color: Color
    let hecho: Double
    let llegado: Bool
    let faltan: Int
    
    var sinFecha = false

    @Environment(\.accessibilityReduceMotion) private var menosMovimiento
    @Environment(\.colorScheme) private var modo
    @State private var cerrado: Double = 0

    private static let lado: CGFloat = 92
    private static let grosor: CGFloat = 9

    private var atrasado: Bool { !llegado && !sinFecha && faltan < 0 }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Marcador.apoyo.opacity(0.16), lineWidth: Self.grosor)
            Circle()
                .trim(from: 0, to: atrasado ? min(cerrado, 0.88) : cerrado)
                .stroke(color.gradient,
                        style: StrokeStyle(lineWidth: Self.grosor, lineCap: .round))
                .rotationEffect(.degrees(-90))

                .shadow(color: modo == .dark ? color.opacity(0.5) : .black.opacity(0.28),
                        radius: modo == .dark ? 6 : 2.5, x: 0, y: modo == .dark ? 2 : 1.5)
            centro
        }
        .frame(width: Self.lado, height: Self.lado)
        .onAppear {
            if menosMovimiento { cerrado = hecho; return }
            withAnimation(.easeOut(duration: 1.1).delay(0.2)) { cerrado = hecho }
        }
        .onChange(of: hecho) { _, h in
            if menosMovimiento { cerrado = h } else { withAnimation(Diseno.suave) { cerrado = h } }
        }
        .accessibilityHidden(true)
    }

    private var centro: some View {
        Group {
            if llegado {
                Image(systemName: "checkmark")
                    .font(.title2.weight(.bold))
                    .transition(.scale.combined(with: .opacity))
            } else if sinFecha {
                Image(systemName: "dollarsign")
                    .font(.title2.weight(.bold))
            } else if atrasado {
                
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(.white, Diseno.naranjaRelleno)
                    .transition(.scale.combined(with: .opacity))
            } else if faltan == 0 {
                Text("hoy")
                    .font(.system(.title3, design: .rounded).weight(.bold))
            } else {
                VStack(spacing: -3) {
                    Text("\(faltan)")
                        .font(.system(.title, design: .rounded).weight(.bold))
                        .monospacedDigit()
                        .contentTransition(.numericText(value: Double(faltan)))
                    Text(faltan == 1 ? "día" : "días")
                        .font(.caption2.weight(.semibold))
                }
            }
        }
        .foregroundStyle(Color.primary)
        .minimumScaleFactor(0.6)
        .frame(width: Self.lado - 2 * Self.grosor - 8, height: Self.lado - 2 * Self.grosor - 8)
        
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
    }
}

struct LineaDeCobros: View {
    let cobros: [Cobro]
    let hoy: String
    let porDefecto: String?
    @Binding var elegido: String?
    @Binding var rastreando: Bool

    @Environment(\.accessibilityReduceMotion) private var menosMovimiento
    @Environment(\.accessibilityReduceTransparency) private var menosTransparencia
    @Environment(\.colorScheme) private var modo
    @State private var crecidas = false

    static let diasAtras = 62
    private static let arriba: CGFloat = 30
    private static let abajo: CGFloat = 26

    private var desde: String { Fechas.mas(hoy, -Self.diasAtras) }
    private var hasta: String { Fechas.mas(cobros.last.map { max($0.fecha, hoy) } ?? hoy, 6) }
    private var leido: String? { elegido ?? porDefecto }

    var body: some View {
        GeometryReader { g in grafica(g.size) }
            
            .dynamicTypeSize(...DynamicTypeSize.xxLarge)
            .onAppear {
                if menosMovimiento { crecidas = true } else { withAnimation { crecidas = true } }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Cobros de los dos últimos meses y los que vienen")
            .accessibilityValue(valorAccesible)
            .accessibilityAdjustableAction { d in
                guard let i = cobros.firstIndex(where: { $0.id == leido }) else { return }
                switch d {
                case .increment: elegido = cobros[min(i + 1, cobros.count - 1)].id
                case .decrement: elegido = cobros[max(i - 1, 0)].id
                @unknown default: break
                }
            }
            .accessibilityActions {
                if elegido != nil {
                    Button("Volver al próximo cobro") { elegido = nil }
                }
            }
    }

    private func grafica(_ tam: CGSize) -> some View {
        let m = Diseno.margen
        let rango = max(Fechas.dias(de: desde, a: hasta), 1)
        let tope = max(cobros.map(\.euros).max() ?? 1, 1)
        let alto = tam.height - Self.abajo - Self.arriba
        let base = Self.arriba + alto
        func x(_ f: String) -> CGFloat {
            m + (tam.width - 2 * m) * CGFloat(Fechas.dias(de: desde, a: f)) / CGFloat(rango)
        }
        func y(_ e: Double) -> CGFloat { base - max(14, alto * CGFloat((e / tope).squareRoot())) }

        var mismoDia: [String: Int] = [:]
        let pts: [CGPoint] = cobros.map { c in
            let n = cobros.filter { $0.fecha == c.fecha }.count
            let k = mismoDia[c.fecha, default: 0]
            mismoDia[c.fecha] = k + 1
            let separacion = n > 1 ? (CGFloat(k) - CGFloat(n - 1) / 2) * 9 : 0
            return CGPoint(x: x(c.fecha) + separacion, y: y(c.euros))
        }
        let xHoy = x(hoy)
        let i = cobros.firstIndex { $0.id == leido }

        return ZStack(alignment: .topLeading) {
            
            Path { c in
                c.move(to: CGPoint(x: 0, y: base)); c.addLine(to: CGPoint(x: xHoy, y: base))
            }
            .stroke(Marcador.apoyo.opacity(0.35), lineWidth: 1.5)
            Path { c in
                c.move(to: CGPoint(x: xHoy, y: base)); c.addLine(to: CGPoint(x: tam.width, y: base))
            }
            .stroke(Marcador.apoyo.opacity(0.35), style: StrokeStyle(lineWidth: 1.5, dash: [3, 4]))

            ForEach(inicios(), id: \.self) { f in
                Text(CobrosHucha.nombreDelMes(f).prefix(3).capitalized)
                    .font(.caption2.weight(.medium)).foregroundStyle(Marcador.apoyo)
                    .fixedSize()
                    .position(x: x(f) + 12, y: base + 14)
                    .opacity(abs(x(f) + 12 - xHoy) < 28 ? 0 : 1)

                if f.hasSuffix("-01") {
                    Rectangle().fill(Marcador.apoyo.opacity(0.12))
                        .frame(width: 1, height: alto + 10)
                        .offset(x: x(f), y: Self.arriba - 6)
                }
            }

            Rectangle().fill(Marcador.apoyo.opacity(0.45))
                .frame(width: 1.5, height: alto + 14)
                .offset(x: xHoy - 0.75, y: Self.arriba - 8)
            Text("hoy").font(.caption2.weight(.bold))
                .fixedSize().position(x: xHoy, y: base + 14)

            ForEach(Array(cobros.enumerated()), id: \.element.id) { n, c in
                let p = pts[n]
                let apagado = rastreando && i != n
                
                Path { k in k.move(to: CGPoint(x: p.x, y: base)); k.addLine(to: p) }
                    .stroke(c.color.opacity(apagado ? 0.25 : (modo == .dark ? 0.75 : 0.9)),
                            style: StrokeStyle(lineWidth: 2, lineCap: .round,
                                               dash: c.llegado ? [] : [3, 3]))
                    .scaleEffect(x: 1, y: crecidas ? 1 : 0.01,
                                 anchor: UnitPoint(x: 0.5, y: base / max(tam.height, 1)))
                    .animation(mov(.spring(duration: 0.6, bounce: 0.3)
                        .delay(Double(n) * 0.03)), value: crecidas)
            }

            if let i, cobros.indices.contains(i) {
                lente(cobros[i])
                    .position(pts[i])
                    .opacity(crecidas ? 1 : 0)
                    .animation(mov(.spring(duration: 0.28, bounce: 0.2)), value: i)
            }

            ForEach(Array(cobros.enumerated()), id: \.element.id) { n, c in
                let apagado = rastreando && i != n
                cabeza(c, tope: tope)
                    .scaleEffect(crecidas ? (i == n && rastreando ? 1.2 : 1) : 0.01)
                    .opacity(apagado ? 0.35 : 1)
                    .position(pts[n])
                    .animation(mov(.spring(duration: 0.6, bounce: 0.35)
                        .delay(crecidas ? 0 : Double(n) * 0.03)), value: crecidas)
                    .animation(.spring(duration: 0.25, bounce: 0.3), value: rastreando)
            }
        }
        .contentShape(.rect)
        .gesture(MantenerYDeslizar(
            espera: 0.15,
            alEmpezar: { q in
                rastreando = true
                mover(q.x, pts)
            },
            alMover: { q in mover(q.x, pts) },
            alAcabar: {
                rastreando = false
                withAnimation(.snappy(duration: 0.25)) { elegido = nil }
            }))
    }

    private func cabeza(_ c: Cobro, tope: Double) -> some View {
        let lado = Self.ladoDeCabeza(c.euros, tope: tope)

        let claro = modo != .dark
        return Group {
            if c.llegado {
                Circle().fill(c.color.gradient)
                    .overlay(Circle().strokeBorder(claro ? Color.black.opacity(0.6)
                                                         : Color.white.opacity(0.7),
                                                   lineWidth: 1.2))
            } else {
                Circle().fill(Diseno.superficie)
                    .overlay {
                        if claro { Circle().strokeBorder(Color.black.opacity(0.55), lineWidth: 1) }
                    }
                    .overlay(Circle().inset(by: claro ? 1 : 0)
                        .strokeBorder(c.color, style: StrokeStyle(lineWidth: 2, dash: [3, 2])))
            }
        }
        .frame(width: lado, height: lado)

        .shadow(color: modo == .dark ? c.color.opacity(0.35) : .black.opacity(0.25),
                radius: 2, x: 0, y: 1)
        .allowsHitTesting(false)
    }

    private static func ladoDeCabeza(_ euros: Double, tope: Double) -> CGFloat {
        10 + 12 * CGFloat((max(euros, 0) / tope).squareRoot())
    }

    @ViewBuilder
    private func lente(_ c: Cobro) -> some View {
        let tope = max(cobros.map(\.euros).max() ?? 1, 1)
        let lado = Self.ladoDeCabeza(c.euros, tope: tope) + 18
        Group {
            if menosTransparencia {
                Circle().strokeBorder(c.color, lineWidth: 2.5)
            } else {
                Color.clear.glassEffect(.regular.tint(c.color.opacity(0.35)), in: .circle)
            }
        }
        .frame(width: lado, height: lado)
        .scaleEffect(rastreando ? 1.3 : 1)
        .animation(.spring(duration: 0.3, bounce: 0.35), value: rastreando)
        .allowsHitTesting(false)
    }

    private func inicios() -> [String] {
        func siguiente(_ m: String) -> String { String(Fechas.mas(m, 32).prefix(7)) + "-01" }
        var salida: [String] = []
        var m = String(desde.prefix(7)) + "-01"
        if m < desde {
            
            if Fechas.dias(de: desde, a: siguiente(m)) >= 12 { salida.append(desde) }
            m = siguiente(m)
        }
        while m <= hasta {
            salida.append(m)
            m = siguiente(m)
        }
        return salida
    }

    private func cercano(_ x: CGFloat, _ pts: [CGPoint]) -> Int? {
        pts.indices.min { abs(pts[$0].x - x) < abs(pts[$1].x - x) }
    }

    private func mover(_ x: CGFloat, _ pts: [CGPoint]) {
        guard let n = cercano(x, pts), cobros[n].id != elegido else { return }
        withAnimation(.snappy(duration: 0.18)) { elegido = cobros[n].id }
    }

    private var valorAccesible: String {
        guard let c = cobros.first(where: { $0.id == leido }) else { return "" }
        return "\(c.nombre), \(Formato.euros(c.euros)), \(Formato.diaCorto(c.fecha))"
            + (c.llegado ? "" : ", por llegar")
    }

    private func mov(_ a: Animation) -> Animation? { menosMovimiento ? nil : a }
}

private struct BarraDelMes: View {
    let llegado: Double
    let porLlegar: Double

    @Environment(\.accessibilityReduceMotion) private var menosMovimiento
    @Environment(\.colorScheme) private var modo
    @State private var llena = false

    var body: some View {
        GeometryReader { g in
            let total = max(llegado + porLlegar, 0.01)
            let a = g.size.width * CGFloat(llegado / total)
            ZStack(alignment: .leading) {
                Capsule().fill(Marcador.apoyo.opacity(0.1))
                if porLlegar > 0.004 {

                    if modo == .light {
                        Capsule()
                            .strokeBorder(.black.opacity(0.6),
                                          style: StrokeStyle(lineWidth: 2.4, dash: [3, 3]))
                            .frame(width: llena ? g.size.width : 0)
                    }
                    Capsule()
                        .strokeBorder(Diseno.verdeRelleno.opacity(0.75),
                                      style: StrokeStyle(lineWidth: 1.2, dash: [3, 3]))
                        .frame(width: llena ? g.size.width : 0)
                }
                
                if llegado > 0.004 {
                    Capsule()
                        .fill(Diseno.verdeRelleno.gradient)
                        .frame(width: llena ? max(a, 12) : 0)
                        .shadow(color: Diseno.verdeRelleno.opacity(0.5), radius: 6, x: 0, y: 2)
                }
            }
        }
        .frame(height: 12)
        .onAppear {
            if menosMovimiento { llena = true; return }
            withAnimation(.smooth(duration: 1.0).delay(0.2)) { llena = true }
        }
    }
}

private struct CabeceraDeMes: View {
    let mes: MesDeCobros

    var body: some View {
        HStack(spacing: Diseno.hueco2) {
            HStack(spacing: -4) {
                ForEach(Array(Set(mes.cobros.map(\.plataforma))).sorted(), id: \.self) { p in
                    Circle().fill(Diseno.colorDePlataforma(p).gradient)
                        .overlay(Circle().strokeBorder(.white.opacity(0.8), lineWidth: 1.2))
                        .frame(width: 12, height: 12)
                }
            }
            .frame(width: 34, alignment: .leading)
            .accessibilityHidden(true)
            Text(CobrosHucha.nombreDelMes(mes.mes, conAño: true).capitalizandoPrimera)
                .font(.headline)
                .lineLimit(1)
            Spacer(minLength: Diseno.hueco1)
            VStack(alignment: .trailing, spacing: 1) {
                Text(Formato.euros(mes.llegado))
                    .font(.system(.headline, design: .rounded)).monospacedDigit()
                if mes.porLlegar > 0.004 {
                    Text("\(Formato.euros(mes.porLlegar)) por llegar")
                        .font(.caption2).monospacedDigit()
                        .foregroundStyle(Marcador.apoyo)
                }
            }
        }
        .padding(.vertical, 10)
    }
}

private struct FilasDelMes: View {
    let cobros: [Cobro]

    var body: some View {
        VStack(spacing: 0) {
            ForEach(cobros) { c in
                HStack(spacing: Diseno.hueco2) {
                    Circle().fill(c.color.gradient).frame(width: 8, height: 8)
                        .frame(width: 34, alignment: .leading)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(c.nombre).font(.subheadline)
                        
                        Text(pie(c))
                            .font(.caption).foregroundStyle(Marcador.apoyo).lineLimit(2)
                    }
                    Spacer(minLength: Diseno.hueco1)
                    VStack(alignment: .trailing, spacing: 1) {
                        Text(Formato.euros(c.euros))
                            .font(.subheadline.weight(.medium)).monospacedDigit()
                        if !c.llegado {
                            Text("por llegar").font(.caption2).foregroundStyle(Marcador.apoyo)
                        } else if c.estimado {
                            Text("estimado").font(.caption2).foregroundStyle(Marcador.apoyo)
                        }
                    }
                }
                .padding(.vertical, 7)
                .accessibilityElement(children: .combine)
            }
        }
    }

    private func pie(_ c: Cobro) -> String {
        ([Fechas.corta(c.fecha)]
         + (c.detalle.isEmpty ? [] : [c.detalle])
         + (c.total - c.euros > 0.004 ? ["parte de \(Formato.euros(c.total))"] : []))
            .joined(separator: " · ")
    }
}
