import SwiftUI

struct DetalleNuevo: View {
    @Environment(Sesion.self) private var sesion
    let periodo: String
    let plataforma: String

    @State private var clases: [PantallaDetalleP1.Linea] = []
    @State private var conceptos: [PantallaDetalleP1.Linea] = []
    @State private var dias: [PantallaDetalleP1.DiaDetalle] = []
    @State private var euros: Double = 0
    @State private var tokens = 0
    @State private var estado: Carga<Bool> = .cargando

    private var tinte: Color { Diseno.colorDePlataforma(plataforma) }

    var body: some View {
        lista

            .fondoDeCampo(.de(plataforma))
            .navigationTitle(PantallaDetalleP1.titulo(periodo))
            .task { await cargar() }
            .refreshable { await cargar() }
    }

    private var lista: some View {
        ScrollView {
            VStack(spacing: Diseno.hueco4) {
                switch estado {
                case .cargando:
                    Tarjeta { Vacio(icono: "chart.pie", titulo: "Cargando…") }
                        .redacted(reason: .placeholder)
                case .error(let qué):
                    Tarjeta { Vacio(icono: "wifi.exclamationmark",
                                    titulo: "No se ha podido cargar", detalle: qué) }
                case .vacio:
                    Tarjeta { Vacio(icono: "eurosign.circle", titulo: "Nada en este periodo") }
                default:
                    ComposicionDelDinero(partes: partes, euros: euros, tokens: tokens)
                        .aparicion(0)
                    if !dias.isEmpty {
                        DiaADia(dias: dias, tinte: tinte).aparicion(1)
                    }
                    if !conceptos.isEmpty {
                        ImportesDePropinas(conceptos: conceptos, tinte: tinte,
                                           nota: plataforma == "plataforma1")
                            .aparicion(2)
                    }
                    
                    AccesoHeroe(icono: "function", titulo: "Comisiones y cambio") {
                        PantallaComoSeCalcula(plataforma: plataforma)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .aparicion(3)
                }
            }
            .padding(.horizontal, Diseno.margen)
            .padding(.vertical, Diseno.hueco2)
        }
    }

    private var partes: [ComposicionDelDinero.Parte] {
        clases.filter { $0.euros > 0 || $0.tokens > 0 }.map {
            .init(clave: $0.clave, nombre: $0.nombre, euros: $0.euros, tokens: $0.tokens,
                  veces: $0.veces, color: Self.colorDeClase($0.clave, tinte: tinte))
        }
    }

    static func colorDeClase(_ clave: String, tinte: Color) -> Color {
        switch clave {
        case "propina": return tinte
        case "sin_detalle": return .purple
        case "menu": return .teal
        case "encargo": return .pink
        case "observar": return .indigo
        case "club": return .yellow
        case "sin_desglose": return Color(.systemGray2)
        default: return .mint
        }
    }

    private func cargar() async {
        do {
            let j = try await API.pedir(
                "api/detalle/\(plataforma)?periodo=\(periodo)", testigo: sesion.testigo)
            clases = PantallaDetalleP1.lineas(j["clases"])
            conceptos = PantallaDetalleP1.lineas(j["conceptos"])
            dias = PantallaDetalleP1.dias(j["dias"])
            euros = j["euros"] as? Double ?? 0
            tokens = j["tokens"] as? Int ?? 0
            estado = (clases.isEmpty && conceptos.isEmpty) ? .vacio : .listo(true)
        } catch {
            if (error as NSError).code == NSURLErrorCancelled || error is CancellationError { return }
            estado.fallar(error)
        }
    }
}

struct ComposicionDelDinero: View {
    struct Parte: Identifiable, Equatable {
        let clave: String
        let nombre: String
        let euros: Double
        let tokens: Int
        let veces: Int
        let color: Color
        var id: String { clave }
    }
    let partes: [Parte]
    let euros: Double
    let tokens: Int

    @Environment(\.accessibilityReduceMotion) private var menosMovimiento
    @Environment(\.enCampo) private var enCampo
    @Environment(\.colorScheme) private var modo
    @State private var progreso: Double = 0
    @State private var elegida: String?

    private var total: Double { max(partes.reduce(0) { $0 + $1.euros }, 0.01) }

    private var conFilo: Bool { enCampo && modo == .light }

    private var tramos: [(parte: Parte, desde: Double, hasta: Double)] {
        var acumulado = 0.0
        return partes.map { p in
            let d = acumulado
            acumulado += p.euros / total
            return (p, d, acumulado)
        }
    }

    private var laElegida: Parte? { partes.first { $0.clave == elegida } }

    var body: some View {
        Tarjeta(relleno: Diseno.hueco4) {
            VStack(spacing: Diseno.hueco4) {

                anillo
                    .frame(width: enCampo ? 244 : 216, height: enCampo ? 244 : 216)
                    .frame(maxWidth: .infinity)
                    .padding(.top, enCampo ? Diseno.hueco2 : 0)
                leyenda
            }
        }
        .sensoryFeedback(.selection, trigger: elegida)
        .onAppear {
            if menosMovimiento { progreso = 1; return }
            withAnimation(.easeOut(duration: 1.1).delay(0.15)) { progreso = 1 }
        }
    }

    private var anillo: some View {
        GeometryReader { g in
            let lado = min(g.size.width, g.size.height)
            let hueco = partes.count > 1 ? 0.012 : 0
            ZStack {
                Circle()
                    .stroke(enCampo ? Marcador.apoyo.opacity(0.16) : Color.primary.opacity(0.06),
                            lineWidth: 22)
                    .padding(15)
                ForEach(tramos, id: \.parte.id) { t in
                    let esta = t.parte.clave == elegida
                    let apagada = elegida != nil && !esta
                    if conFilo {
                        
                        Arco(desde: t.desde + hueco / 2, hasta: t.hasta - hueco / 2,
                             progreso: progreso)
                            .stroke(.black.opacity(0.6),
                                    style: StrokeStyle(lineWidth: (esta ? 30 : 22) + 2, lineCap: .butt))
                            .padding(15)
                            .opacity(apagada ? 0.35 : 1)
                            .animation(.spring(duration: 0.35, bounce: 0.3), value: elegida)
                    }
                    Arco(desde: t.desde + hueco / 2, hasta: t.hasta - hueco / 2,
                         progreso: progreso)
                        .stroke(t.parte.color.gradient,
                                style: StrokeStyle(lineWidth: esta ? 30 : 22, lineCap: .butt))
                        .padding(15)
                        .opacity(apagada ? 0.35 : 1)
                        .shadow(color: esta ? t.parte.color.opacity(0.55) : .clear,
                                radius: 8, x: 0, y: 3)
                        .animation(.spring(duration: 0.35, bounce: 0.3), value: elegida)
                }
                centro
            }
            .frame(width: lado, height: lado)
            .contentShape(.circle)
            .onTapGesture(coordinateSpace: .local) { p in
                tocar(en: p, lado: lado)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("De dónde sale el dinero")
        .accessibilityValue(partes.map {
            "\($0.nombre), \(Formato.euros($0.euros))" }.joined(separator: "; "))
    }

    private var centro: some View {
        VStack(spacing: 2) {
            Text(laElegida?.nombre ?? "Total")
                .font(.caption.weight(.medium))
                .foregroundStyle(.apoyo)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .frame(maxWidth: 130)
            Text(Formato.euros(laElegida?.euros ?? euros))
                .font(.system(.title2, design: .rounded).weight(.bold))
                .monospacedDigit()
                .contentTransition(.numericText(value: laElegida?.euros ?? euros))
                .minimumScaleFactor(0.6)
                .lineLimit(1)
                .frame(maxWidth: 140)
            Text(pieCentro)
                .font(.caption.weight(.semibold))
                .monospacedDigit()
                
                .foregroundStyle(enCampo ? AnyShapeStyle(.apoyo)
                                         : AnyShapeStyle(laElegida?.color ?? .secondary))
                .contentTransition(.numericText())
        }
        .animation(.snappy(duration: 0.25), value: elegida)
    }

    private var pieCentro: String {
        if let p = laElegida {
            return "\(Int((p.euros / total * 100).rounded())) % · \(Formato.tokens(p.tokens))"
        }
        return "\(Formato.tokens(tokens, unidad: "tokens"))"
    }

    private var leyenda: some View {
        VStack(spacing: 4) {
            ForEach(partes) { p in
                Button {
                    withAnimation(.spring(duration: 0.35, bounce: 0.3)) {
                        elegida = elegida == p.clave ? nil : p.clave
                    }
                } label: {
                    HStack(spacing: Diseno.hueco2) {
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(p.color.gradient)
                            .overlay {
                                if conFilo {
                                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                                        .strokeBorder(.black.opacity(0.6), lineWidth: 0.75)
                                }
                            }
                            .frame(width: 12, height: 12)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(p.nombre).font(.subheadline.weight(.medium))
                                .foregroundStyle(.primary)
                            
                            Text(p.veces > 0
                                 ? "\(p.veces) " + (p.veces == 1 ? "vez" : "veces")
                                 : "\(Formato.tokens(p.tokens, unidad: "tokens"))")
                                .font(.caption).foregroundStyle(.apoyo)
                        }
                        Spacer(minLength: 8)
                        VStack(alignment: .trailing, spacing: 1) {
                            Text(Formato.euros(p.euros))
                                .font(.subheadline.weight(.semibold)).monospacedDigit()
                                .foregroundStyle(.primary)
                            Text("\(Int((p.euros / total * 100).rounded())) %")
                                .font(.caption).monospacedDigit().foregroundStyle(.apoyo)
                        }
                    }
                    .padding(.horizontal, Diseno.hueco2)
                    .padding(.vertical, 9)
                    
                    .background((enCampo ? Marcador.apoyo : p.color)
                                    .opacity(elegida == p.clave ? (enCampo ? 0.1 : 0.14) : 0),
                                in: .rect(cornerRadius: Diseno.radioCampo, style: .continuous))
                    .contentShape(.rect)

                    .padding(.horizontal, enCampo ? -Diseno.hueco2 : 0)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(elegida == p.clave ? .isSelected : [])
            }
        }
    }

    private func tocar(en p: CGPoint, lado: CGFloat) {
        let c = CGPoint(x: lado / 2, y: lado / 2)
        let dx = p.x - c.x, dy = p.y - c.y
        let r = (dx * dx + dy * dy).squareRoot()
        
        guard r > lado / 2 - 50 else {
            withAnimation(.spring(duration: 0.35, bounce: 0.3)) { elegida = nil }
            return
        }
        var a = atan2(dx, -dy) / (2 * .pi)
        if a < 0 { a += 1 }
        if let t = tramos.first(where: { a >= $0.desde && a < $0.hasta }) {
            withAnimation(.spring(duration: 0.35, bounce: 0.3)) {
                elegida = elegida == t.parte.clave ? nil : t.parte.clave
            }
        }
    }
}

private struct Arco: Shape {
    let desde: Double
    let hasta: Double
    var progreso: Double
    var animatableData: Double {
        get { progreso }
        set { progreso = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var c = Path()
        let fin = min(hasta, progreso)
        guard fin > desde else { return c }
        let r = min(rect.width, rect.height) / 2
        c.addArc(center: CGPoint(x: rect.midX, y: rect.midY), radius: r,
                 startAngle: .degrees(-90 + desde * 360), endAngle: .degrees(-90 + fin * 360),
                 clockwise: false)
        return c
    }
}

struct DiaADia: View {
    let dias: [PantallaDetalleP1.DiaDetalle]
    let tinte: Color

    @Namespace private var lente
    @State private var elegido: String?
    @State private var hoja: PantallaDetalleP1.DiaDetalle?
    @Environment(\.accessibilityReduceTransparency) private var menosTransparencia
    @Environment(\.enCampo) private var enCampo
    @Environment(\.colorScheme) private var modo

    private var ordenados: [PantallaDetalleP1.DiaDetalle] { dias.sorted { $0.fecha < $1.fecha } }
    private var tope: Double { max(dias.map(\.euros).max() ?? 0, 0.01) }
    private var dia: PantallaDetalleP1.DiaDetalle? {
        dias.first { $0.fecha == elegido } ?? ordenados.last
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Diseno.hueco2) {
            if enCampo {
                TituloDeSeccion(texto: "Día a día")
            } else {
                Text("Día a día").font(.headline).padding(.leading, 4)
            }
            Tarjeta(relleno: 0) {
                VStack(alignment: .leading, spacing: 0) {
                    tira
                        .padding(.top, enCampo ? 0 : Diseno.hueco3)
                    
                    if !enCampo { Divider().padding(.horizontal, Diseno.hueco3) }
                    if let d = dia {
                        PanelDelDia(dia: d, tinte: tinte) { hoja = d }
                            .id(d.fecha)
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .offset(y: 8)),
                                removal: .opacity))
                    }
                }
            }
            .animation(.smooth(duration: 0.3), value: dia?.fecha)
        }
        .sensoryFeedback(.selection, trigger: elegido)
        .sheet(item: $hoja) { d in HojaPropinas(dia: d).hojaQueChoca() }
    }

    private var tira: some View {
        ScrollView(.horizontal) {
            LazyHStack(alignment: .bottom, spacing: 2) {
                ForEach(ordenados) { d in
                    let esta = d.fecha == dia?.fecha
                    Button {
                        withAnimation(.spring(duration: 0.4, bounce: 0.25)) { elegido = d.fecha }
                    } label: {
                        VStack(spacing: 5) {
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(d.euros > 0 ? AnyShapeStyle(tinte.gradient)
                                                  : AnyShapeStyle(enCampo ? Marcador.apoyo.opacity(0.16)
                                                                          : Color.primary.opacity(0.1)))
                                .overlay {
                                    
                                    if enCampo && modo == .light && d.euros > 0 {
                                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                                            .strokeBorder(.black.opacity(0.6), lineWidth: 0.75)
                                    }
                                }
                                .frame(width: 10, height: max(4, 46 * d.euros / tope))
                                .opacity(esta ? 1 : 0.55)
                            Text(numeroDelDia(d.fecha))
                                .font(.footnote.weight(esta ? .bold : .medium))
                                .monospacedDigit()
                                .foregroundStyle(esta ? AnyShapeStyle(Color.primary) : AnyShapeStyle(.apoyo))
                            Text(inicialDelDia(d.fecha))
                                .font(.caption2)
                                .foregroundStyle(.apoyo)
                        }
                        .frame(width: 38, height: 94, alignment: .bottom)
                        .padding(.bottom, 8)
                        .background {
                            if esta {
                                lenteDia.matchedGeometryEffect(id: "lente", in: lente)
                            }
                        }
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .id(d.fecha)
                    .accessibilityLabel("\(Formato.diaCorto(d.fecha)), \(Formato.euros(d.euros))")
                    .accessibilityAddTraits(esta ? .isSelected : [])
                }
            }
            
            .padding(.horizontal, enCampo ? Diseno.margen : Diseno.hueco3)
            .padding(.bottom, Diseno.hueco2)
        }
        .scrollIndicators(.hidden)
        .defaultScrollAnchor(.trailing)
        .padding(.horizontal, enCampo ? -Diseno.margen : 0)
    }

    @ViewBuilder
    private var lenteDia: some View {
        let forma = RoundedRectangle(cornerRadius: 16, style: .continuous)
        if menosTransparencia {
            forma.fill(tinte.opacity(0.18))
        } else {
            Color.clear.glassEffect(.regular.tint(tinte.opacity(0.22)), in: forma)
        }
    }

    private func numeroDelDia(_ iso: String) -> String {
        String(Int(iso.split(separator: "-").last ?? "") ?? 0)
    }

    private func inicialDelDia(_ iso: String) -> String {
        let p = iso.split(separator: "-").compactMap { Int($0) }
        guard p.count == 3 else { return "" }
        var (a, m) = (p[0], p[1])
        if m < 3 { m += 12; a -= 1 }
        let h = (p[2] + (13 * (m + 1)) / 5 + a % 100 + (a % 100) / 4 + (a / 100) / 4
                 + 5 * (a / 100)) % 7
        return ["S", "D", "L", "M", "X", "J", "V"][h]
    }
}

private struct PanelDelDia: View {
    let dia: PantallaDetalleP1.DiaDetalle
    let tinte: Color
    let verTodas: () -> Void

    @Environment(\.enCampo) private var enCampo

    var body: some View {
        VStack(alignment: .leading, spacing: Diseno.hueco3) {
            HStack(alignment: .firstTextBaseline) {
                
                Text(Formato.diaCorto(dia.fecha).capitalizandoPrimera)
                    .font(.headline)
                Spacer()
                Text(Formato.euros(dia.euros))
                    .font(.system(.title2, design: .rounded).weight(.bold))
                    .monospacedDigit()
            }

            HStack(spacing: 6) {
                ficha("circle.hexagongrid.fill", "\(Formato.tokens(dia.tokens, unidad: "tokens"))")
                if dia.cuantas > 0 {
                    ficha("gift.fill", dia.cuantas == 1 ? "1 propina" : "\(dia.cuantas) propinas")
                }
                if dia.horas > 0 { ficha("clock.fill", Formato.duracion(dia.horas)) }
            }

            if !dia.propinas.isEmpty {
                NocheDePropinas(propinas: dia.propinas, tinte: tinte)
                    .frame(height: 170)
                QuienDioMas(propinas: dia.propinas, tinte: tinte)
            }

            if dia.sinDetalle > 0 {
                Label("\(Formato.tokens(dia.sinDetalle, unidad: "tokens")) de encargos, club y otros",
                      systemImage: "lock.fill")
                    .font(.footnote).foregroundStyle(.apoyo)
            } else if dia.propinas.isEmpty && dia.tokens > 0 {
                Label("Sin desglose por propina", systemImage: "square.stack")
                    .font(.footnote).foregroundStyle(.apoyo)
            }

            if !dia.propinas.isEmpty {
                Button(action: verTodas) {
                    Label("Todas las propinas · \(dia.propinas.count)",
                          systemImage: "list.bullet")
                        .font(.subheadline.weight(.medium))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glass)
                .controlSize(.large)
            }
        }
        .padding(.vertical, Diseno.hueco3)
        .padding(.horizontal, enCampo ? 0 : Diseno.hueco3)
    }

    private func ficha(_ icono: String, _ texto: String) -> some View {
        Label {
            Text(texto).monospacedDigit()
        } icon: {
            
            Image(systemName: icono)
                .foregroundStyle(enCampo ? AnyShapeStyle(.apoyo) : AnyShapeStyle(tinte))
        }
        .font(.footnote.weight(.medium))
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(enCampo ? Marcador.apoyo.opacity(0.12) : Color.primary.opacity(0.05), in: Capsule())
    }
}

private struct NocheDePropinas: View {
    let propinas: [PantallaDetalleP1.DiaDetalle.Propina]
    let tinte: Color

    @Environment(\.accessibilityReduceMotion) private var menosMovimiento
    @Environment(\.enCampo) private var enCampo
    @Environment(\.colorScheme) private var modo
    @State private var elegida: Int?
    @State private var encendidas = false

    private static let abajo: CGFloat = 22
    private static let arriba: CGFloat = 16

    private var filoDelPunto: Color {
        enCampo && modo == .light ? Color.black.opacity(0.6) : Color.white.opacity(0.5)
    }

    private func minutos(_ hora: String) -> Double {
        let p = hora.split(separator: ":").compactMap { Int($0) }
        guard p.count >= 2 else { return 0 }
        return Double((p[0] * 60 + p[1] - 540 + 1440) % 1440)
    }

    var body: some View {
        GeometryReader { g in
            let ms = propinas.map { minutos($0.hora) }
            let lo = max(0, (ms.min() ?? 0) - 20), hi = min(1440, (ms.max() ?? 60) + 20)
            let rango = max(hi - lo, 60)
            let tks = propinas.map { log(Double(max($0.tokens, 1))) }
            let tkLo = tks.min() ?? 0, tkHi = max(tks.max() ?? 1, tkLo + 0.01)
            let maxTk = Double(propinas.map(\.tokens).max() ?? 1)
            let alto = g.size.height - Self.abajo - Self.arriba
            let pts: [CGPoint] = propinas.indices.map { i in
                CGPoint(x: 8 + (g.size.width - 16) * CGFloat((ms[i] - lo) / rango),
                        y: Self.arriba + alto * CGFloat(1 - (tks[i] - tkLo) / (tkHi - tkLo)))
            }
            
            let porHora = propinas.indices.sorted { ms[$0] < ms[$1] }

            ZStack(alignment: .topLeading) {
                
                ForEach(marcas(lo: lo, hi: lo + rango), id: \.self) { m in
                    let x = 8 + (g.size.width - 16) * CGFloat((m - lo) / rango)
                    Rectangle()
                        .fill(enCampo ? Marcador.apoyo.opacity(0.14) : Color.primary.opacity(0.07))
                        .frame(width: 1, height: alto + 6)
                        .offset(x: x, y: Self.arriba - 3)
                    Text(etiquetaHora(m))
                        .font(.caption2).monospacedDigit()
                        .foregroundStyle(.apoyo)
                        .fixedSize()
                        .position(x: x, y: g.size.height - 7)
                }

                ForEach(Array(porHora.enumerated()), id: \.element) { orden, i in
                    let lado = 6 + 16 * CGFloat((Double(propinas[i].tokens) / maxTk).squareRoot())
                    let esta = elegida == i
                    Circle()
                        .fill(tinte.gradient)
                        .overlay(Circle().strokeBorder(filoDelPunto, lineWidth: 0.6))
                        .frame(width: lado, height: lado)
                        .shadow(color: tinte.opacity(lado > 14 || esta ? 0.5 : 0), radius: 5,
                                x: 0, y: 2)
                        .scaleEffect(esta ? 1.5 : (encendidas ? 1 : 0.01))
                        .opacity(elegida == nil || esta ? 0.9 : 0.3)
                        .position(pts[i])
                        .animation(menosMovimiento ? nil
                                   : .spring(duration: 0.45, bounce: 0.4)
                                       .delay(encendidas ? 0 : min(Double(orden) * 0.012, 0.9)),
                                   value: encendidas)
                        .animation(.spring(duration: 0.25, bounce: 0.3), value: elegida)
                }

                if let i = elegida {
                    Rectangle()
                        .fill(enCampo ? Color.primary.opacity(0.45) : tinte.opacity(0.5))
                        .frame(width: 1.5, height: alto + 6)
                        .offset(x: pts[i].x - 0.75, y: Self.arriba - 3)
                    burbuja(propinas[i])
                        .fixedSize()
                        .position(x: min(max(pts[i].x, 80), g.size.width - 80),
                                  y: max(pts[i].y - 30, 12))
                        .transition(.scale(scale: 0.6).combined(with: .opacity))
                }
            }
            .contentShape(.rect)
            .gesture(MantenerYDeslizar(
                espera: 0.12,
                alEmpezar: { p in elegir(p, pts) },
                alMover: { p in elegir(p, pts) },
                alAcabar: { withAnimation(.snappy(duration: 0.2)) { elegida = nil } }))
        }
        .sensoryFeedback(.selection, trigger: elegida)
        .onAppear { encendidas = true }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Propinas de la noche, por hora")
        .accessibilityValue(propinas.prefix(12).map { "\($0.hora), \($0.tokens) tokens" }
            .joined(separator: "; "))
    }

    private func burbuja(_ p: PantallaDetalleP1.DiaDetalle.Propina) -> some View {
        HStack(spacing: 6) {
            Text(p.hora).monospacedDigit().foregroundStyle(.apoyo)
            Text(p.de.isEmpty ? "Anónimo" : p.de).lineLimit(1)
            
            Text(Formato.tokens(p.tokens)).monospacedDigit()
                .foregroundStyle(enCampo ? AnyShapeStyle(Color.primary) : AnyShapeStyle(tinte))
        }
        .font(.caption.weight(.semibold))
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .cristal(.regular, en: Capsule())
        .allowsHitTesting(false)
    }

    private func elegir(_ p: CGPoint, _ pts: [CGPoint]) {
        guard !pts.isEmpty else { return }
        let i = pts.indices.min { hypot(pts[$0].x - p.x, (pts[$0].y - p.y) * 0.35)
                                  < hypot(pts[$1].x - p.x, (pts[$1].y - p.y) * 0.35) }
        if i != elegida { withAnimation(.snappy(duration: 0.18)) { elegida = i } }
    }

    private func marcas(lo: Double, hi: Double) -> [Double] {
        let paso = Double(max(60, Int(((hi - lo) / 6 / 60).rounded(.up)) * 60))
        var m = (lo / 60).rounded(.up) * 60
        var salida: [Double] = []
        while m <= hi { salida.append(m); m += paso }
        return salida
    }

    private func etiquetaHora(_ m: Double) -> String {
        let h = (Int(m) / 60 + 9) % 24
        return String(format: "%02d h", h)
    }
}

private struct QuienDioMas: View {
    let propinas: [PantallaDetalleP1.DiaDetalle.Propina]
    let tinte: Color

    @Environment(\.enCampo) private var enCampo
    @Environment(\.colorScheme) private var modo
    @State private var crecidas = false

    private var filas: [(nombre: String, tokens: Int, veces: Int)] {
        Dictionary(grouping: propinas) { $0.de.isEmpty ? "Anónimo" : $0.de }
            .map { (nombre: $0.key, tokens: $0.value.reduce(0) { $0 + $1.tokens },
                    veces: $0.value.count) }
            .sorted { $0.tokens > $1.tokens }
            .prefix(5)
            .map { $0 }
    }

    var body: some View {
        let tope = Double(max(filas.first?.tokens ?? 1, 1))
        VStack(alignment: .leading, spacing: 10) {
            Text("Quién dio más").font(.subheadline.weight(.semibold))
            ForEach(Array(filas.enumerated()), id: \.element.nombre) { i, f in
                HStack(spacing: Diseno.hueco2) {
                    Text(f.nombre)
                        .font(.footnote.weight(i == 0 ? .semibold : .regular))
                        .lineLimit(1)
                        .frame(width: 110, alignment: .leading)
                    GeometryReader { g in
                        Capsule()
                            .fill(tinte.opacity(i == 0 ? 1 : 0.55).gradient)
                            .overlay {
                                if enCampo && modo == .light {
                                    Capsule().strokeBorder(.black.opacity(0.6), lineWidth: 0.75)
                                }
                            }
                            .frame(width: crecidas ? max(6, g.size.width * Double(f.tokens) / tope)
                                                   : 6)
                            .frame(maxHeight: .infinity)
                            .animation(.spring(duration: 0.6, bounce: 0.2).delay(Double(i) * 0.06),
                                       value: crecidas)
                    }
                    .frame(height: 8)
                    Text(Formato.tokens(f.tokens))
                        .font(.footnote.weight(.medium)).monospacedDigit()
                        .frame(width: 64, alignment: .trailing)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(f.nombre), \(f.tokens) tokens en \(f.veces) propinas")
            }
        }
        .onAppear { crecidas = true }
    }
}

private struct HojaPropinas: View {
    let dia: PantallaDetalleP1.DiaDetalle
    @Environment(\.dismiss) private var cerrar

    var body: some View {
        NavigationStack {

            List(Array(dia.propinas.enumerated()), id: \.offset) { _, p in
                HStack(spacing: Diseno.hueco2) {
                    Text(p.hora)
                        .font(.footnote).monospacedDigit().foregroundStyle(.apoyo)
                        .frame(width: 44, alignment: .leading)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(p.concepto.isEmpty ? (p.de.isEmpty ? "Anónimo" : p.de) : p.concepto)
                            .lineLimit(2)
                        if !p.concepto.isEmpty && !p.de.isEmpty {
                            Text(p.de).font(.caption).foregroundStyle(.apoyo)
                        }
                    }
                    Spacer()
                    Text(Formato.tokens(p.tokens))
                        .font(.subheadline.weight(.semibold)).monospacedDigit()
                }
            }
            .navigationTitle(Formato.diaCorto(dia.fecha))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button(role: .close) { cerrar() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

private struct ImportesDePropinas: View {
    let conceptos: [PantallaDetalleP1.Linea]
    let tinte: Color
    let nota: Bool

    @State private var todas = false
    @State private var crecidas = false
    @Environment(\.enCampo) private var enCampo
    @Environment(\.colorScheme) private var modo

    private static let primeras = 8

    var body: some View {
        let lista = todas ? conceptos : Array(conceptos.prefix(Self.primeras))
        let tope = max(conceptos.map(\.euros).max() ?? 0, 0.01)
        VStack(alignment: .leading, spacing: Diseno.hueco2) {
            if enCampo {
                TituloDeSeccion(texto: "Propinas por importe")
            } else {
                Text("Propinas por importe").font(.headline).padding(.leading, 4)
            }
            Tarjeta {
                VStack(spacing: 14) {
                    ForEach(Array(lista.enumerated()), id: \.element.id) { i, c in
                        fila(c, i: i, tope: tope)
                    }
                    if conceptos.count > Self.primeras {
                        Button {
                            withAnimation(.spring(duration: 0.45, bounce: 0.15)) { todas.toggle() }
                        } label: {
                            Label(todas ? "Ver menos" : "Ver las \(conceptos.count)",
                                  systemImage: todas ? "chevron.up" : "chevron.down")
                                .font(.subheadline.weight(.medium))
                                .contentTransition(.symbolEffect(.replace))
                        }
                        .buttonStyle(.glass)
                        .padding(.top, 4)
                        .sensoryFeedback(.impact(weight: .light), trigger: todas)
                    }
                }
            }
            if nota {

                Text("Plataforma 1 no dice qué se pidió: las propinas sin mensaje se agrupan por importe.")
                    .font(.footnote).foregroundStyle(.apoyo)
                    .padding(.horizontal, enCampo ? 0 : 4)
            }
        }
        .onAppear { crecidas = true }
    }

    private func fila(_ c: PantallaDetalleP1.Linea, i: Int, tope: Double) -> some View {
        HStack(spacing: Diseno.hueco2) {
            etiqueta(c.nombre)
                .frame(width: 84, alignment: .leading)
            VStack(alignment: .leading, spacing: 4) {
                GeometryReader { g in
                    ZStack(alignment: .leading) {
                        Capsule().fill(enCampo ? Marcador.apoyo.opacity(0.16) : Color.primary.opacity(0.06))
                        Capsule()
                            .fill(LinearGradient(colors: [tinte.opacity(0.55), tinte],
                                                 startPoint: .leading, endPoint: .trailing))
                            .overlay {
                                if enCampo && modo == .light {
                                    Capsule().strokeBorder(.black.opacity(0.6), lineWidth: 0.75)
                                }
                            }
                            .frame(width: crecidas ? max(8, g.size.width * c.euros / tope) : 8)
                            .animation(.spring(duration: 0.7, bounce: 0.2)
                                .delay(Double(min(i, 12)) * 0.04), value: crecidas)
                    }
                }
                .frame(height: 10)
                Text(c.veces > 0 ? "×\(c.veces) · \(Formato.tokens(c.tokens))"
                                 : "\(Formato.tokens(c.tokens))")
                    .font(.caption2).monospacedDigit().foregroundStyle(.apoyo)
            }
            Text(Formato.euros(c.euros))
                .font(.subheadline.weight(.semibold)).monospacedDigit()
                .frame(minWidth: 72, alignment: .trailing)
        }
        .transition(.opacity.combined(with: .move(edge: .top)))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(c.nombre), \(Formato.euros(c.euros))")
    }

    @ViewBuilder
    private func etiqueta(_ nombre: String) -> some View {
        if nombre.hasPrefix("Propina de "), nombre.hasSuffix(" tokens"),
           let n = Int(nombre.dropFirst(11).dropLast(7).replacingOccurrences(of: ".", with: "")) {
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(Formato.numero(n))
                    .font(.system(.headline, design: .rounded).weight(.bold))
                    .monospacedDigit()
                Text("tk").font(.caption2.weight(.semibold)).foregroundStyle(.apoyo)
            }
        } else {
            Text(nombre).font(.footnote.weight(.medium)).lineLimit(2)
        }
    }
}
