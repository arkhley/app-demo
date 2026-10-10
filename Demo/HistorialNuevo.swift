import SwiftUI

struct HistorialNuevo: View {
    @Environment(Sesion.self) private var sesion
    let plataforma: String

    typealias Mes = PantallaHistorial.Mes

    enum Medida: String, CaseIterable, Identifiable {
        case total = "Total", dia = "Al día", hora = "Por hora"
        var id: String { rawValue }
    }

    @State private var meses: [Mes] = []          
    @State private var estado: Carga<Bool> = .cargando
    @State private var medida: Medida = .total
    @State private var elegido: String?

    private var tinte: Color { Diseno.colorDePlataforma(plataforma) }
    private var hayHoras: Bool { meses.contains { $0.porHora != nil } }
    private var mes: Mes? { meses.first { $0.clave == elegido } ?? meses.last }

    var body: some View {
        Group {

            lista
                .scrollEdgeEffectStyle(.soft, for: .top)
                .background { CampoJoya(joya: .de(plataforma)) }
                .environment(\.enCampo, true)
                .navigationSubtitle(Diseno.nombreDePlataforma(plataforma))
        }
        .navigationTitle("Historial")
        .task { await cargar() }
        .refreshable { await cargar() }
    }

    private var lista: some View {
        ScrollViewReader { lector in
        ScrollView {
            VStack(spacing: Diseno.hueco4) {
                switch estado {
                case .cargando:
                    Tarjeta { Vacio(icono: "chart.bar", titulo: "Cargando…") }
                        .redacted(reason: .placeholder)
                case .error(let qué):
                    Tarjeta { Vacio(icono: "wifi.exclamationmark",
                                    titulo: "No se ha podido cargar", detalle: qué) }
                case .vacio:
                    Tarjeta { Vacio(icono: "calendar", titulo: "Todavía no hay meses") }
                default:
                    grafica.id("grafica").aparicion(0)
                    if let m = mes {
                        FichaDelMes(mes: m, meses: meses, tinte: tinte)
                            .id(m.clave)
                            .transition(.opacity.combined(with: .offset(y: 10)))
                            .aparicion(1)
                    }
                    if meses.count > 1 {
                        
                        Records(meses: meses, tinte: tinte) { clave in
                            withAnimation(.smooth(duration: 0.45)) {
                                lector.scrollTo("grafica", anchor: .top)
                            }
                            withAnimation(.spring(duration: 0.45, bounce: 0.25).delay(0.2)) {
                                elegido = clave
                            }
                        }
                        .aparicion(2)
                    } else {
                        Text("Con un solo mes todavía no hay con qué comparar.")
                            .font(.footnote).foregroundStyle(.apoyo)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 0)
                    }
                }
            }
            .padding(.horizontal, Diseno.margen)
            .padding(.vertical, Diseno.hueco2)
            .animation(.smooth(duration: 0.3), value: mes?.clave)
        }
        }
    }

    private var grafica: some View {
        Tarjeta(relleno: 0) {
            VStack(alignment: .leading, spacing: Diseno.hueco3) {
                Picker("Medida", selection: $medida.animation(.spring(duration: 0.55, bounce: 0.2))) {
                    ForEach(Medida.allCases.filter { $0 != .hora || hayHoras }) { m in
                        Text(m.rawValue).tag(m)
                    }
                }
                .pickerStyle(.segmented)
                .sensoryFeedback(.selection, trigger: medida)

                ColumnasDeMeses(meses: meses, medida: medida, tinte: tinte,
                                todo: plataforma == "todo", elegido: $elegido)
                    .frame(height: 236)
            }
            
            .padding(0)
        }
    }

    private func cargar() async {
        do {
            let j = try await API.pedir("api/historial/\(plataforma)", testigo: sesion.testigo)
            meses = PantallaHistorial.leerMeses(j["meses"]).reversed()
            estado = meses.isEmpty ? .vacio : .listo(true)
        } catch {
            if (error as NSError).code == NSURLErrorCancelled || error is CancellationError { return }
            estado.fallar(error)
        }
    }
}

extension PantallaHistorial.Mes {
    
    func valor(_ m: HistorialNuevo.Medida) -> Double? {
        switch m {
        case .total: return euros
        case .dia: return porDia
        case .hora: return porHora
        }
    }

    var diasDelMes: Int {
        let p = clave.split(separator: "-").compactMap { Int($0) }
        guard p.count == 2 else { return 30 }
        var c = DateComponents(); c.year = p[0]; c.month = p[1]
        let cal = Calendar(identifier: .gregorian)
        guard let f = cal.date(from: c), let r = cal.range(of: .day, in: .month, for: f) else {
            return 30
        }
        return r.count
    }

    var aEsteRitmo: Double? {
        guard enCurso, dias >= 7, dias < diasDelMes else { return nil }
        return porDia * Double(diasDelMes)
    }

    var pronto: Bool { enCurso && dias < 7 }

    var titulo: String { nombre.capitalized(with: Locale(identifier: "es_ES")) }
    var corto: String { String(nombre.prefix(3)) }
}

private struct ColumnasDeMeses: View {
    typealias Mes = PantallaHistorial.Mes
    let meses: [Mes]
    let medida: HistorialNuevo.Medida
    let tinte: Color
    let todo: Bool
    @Binding var elegido: String?

    @Environment(\.accessibilityReduceMotion) private var menosMovimiento
    @Environment(\.accessibilityReduceTransparency) private var menosTransparencia
    @Environment(\.enCampo) private var enCampo
    @Environment(\.colorScheme) private var modo
    @Environment(\.tema) private var tema
    @State private var crecidas = false
    
    private var conFilo: Bool { enCampo && modo == .light }
    
    private var bordeFantasma: Color { enCampo ? Color.primary.opacity(0.5) : tinte.opacity(0.7) }
    private var fondoFantasma: Color { enCampo ? Marcador.apoyo.opacity(0.08) : tinte.opacity(0.1) }
    
    @ScaledMetric(relativeTo: .caption2) private var tamAnio: CGFloat = 9

    private static let abajo: CGFloat = 34      
    private static let arriba: CGFloat = 40     

    private var indice: Int { meses.firstIndex { $0.clave == elegido } ?? (meses.count - 1) }

    private var media: Double? {
        let vs = meses.filter { !$0.enCurso }.compactMap { $0.valor(medida) }
        return vs.isEmpty ? nil : vs.reduce(0, +) / Double(vs.count)
    }

    var body: some View {
        GeometryReader { g in
            let n = max(meses.count, 1)
            let hueco = g.size.width / CGFloat(n)
            let ancho = min(hueco * 0.58, 24)
            let alto = g.size.height - Self.abajo - Self.arriba
            let ritmo = medida == .total ? meses.last?.aEsteRitmo : nil
            let tope = max(meses.compactMap { $0.valor(medida) }.max() ?? 0, ritmo ?? 0, 0.01)
            let yBase = Self.arriba + alto

            ZStack(alignment: .topLeading) {
                
                Rectangle().fill(enCampo ? Marcador.apoyo.opacity(0.3) : Color.primary.opacity(0.1))
                    .frame(width: g.size.width, height: 1)
                    .offset(y: yBase)

                if let media, meses.count > 2 {
                    let y = yBase - alto * CGFloat(media / tope)
                    Path { c in
                        c.move(to: CGPoint(x: 0, y: y))
                        c.addLine(to: CGPoint(x: g.size.width, y: y))
                    }
                    .stroke(enCampo ? Marcador.apoyo.opacity(0.8) : Color.secondary.opacity(0.7),
                            style: StrokeStyle(lineWidth: 1, dash: [3, 4]))
                    Text("normal · \(Formato.eurosRedondos(media))")
                        .font(.caption2.weight(.semibold)).monospacedDigit()
                        .foregroundStyle(.apoyo)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        
                        .background(enCampo ? tema.colorDeFondo.opacity(0.85) : Diseno.tarjetaConTema(Diseno.superficie, tema),
                                    in: Capsule())
                        .fixedSize()
                        .offset(x: 0, y: y - 18)
                        .animation(.spring(duration: 0.55, bounce: 0.2), value: medida)
                }

                ForEach(Array(meses.enumerated()), id: \.element.id) { i, m in
                    let x = hueco * (CGFloat(i) + 0.5)
                    let v = m.valor(medida)
                    let h = v.map { max(6, alto * CGFloat($0 / tope)) } ?? 4
                    let esta = i == indice

                    if m.enCurso, let r = ritmo {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(bordeFantasma, style: StrokeStyle(lineWidth: 1.2, dash: [3, 3]))
                            .background(fondoFantasma, in: .rect(cornerRadius: 8, style: .continuous))
                            .frame(width: ancho, height: alto * CGFloat(r / tope))
                            .scaleEffect(x: 1, y: crecidas ? 1 : 0.02, anchor: .bottom)
                            .position(x: x, y: yBase - alto * CGFloat(r / tope) / 2)
                            .animation(mov(.spring(duration: 0.8, bounce: 0.2).delay(0.5)),
                                       value: crecidas)
                    }

                    columna(m, alto: h, ancho: ancho, esta: esta, sinDato: v == nil)
                        .scaleEffect(x: 1, y: crecidas ? 1 : 0.02, anchor: .bottom)
                        .position(x: x, y: yBase - h / 2)
                        .animation(mov(.spring(duration: 0.7, bounce: 0.25)
                            .delay(Double(i) * 0.045)), value: crecidas)
                        .animation(mov(.spring(duration: 0.55, bounce: 0.2)), value: medida)
                        .animation(mov(.smooth(duration: 0.25)), value: esta)

                    let cabe = hueco >= 22 || esta || (meses.count - 1 - i) % 2 == 0
                    VStack(spacing: 1) {
                        Text(cabe ? m.corto : " ")
                            .font(.caption2.weight(esta ? .bold : .regular))
                            .foregroundStyle(esta ? AnyShapeStyle(Color.primary) : AnyShapeStyle(.apoyo))
                        if i == 0 || meses[i - 1].anio != m.anio {
                            Text(String(m.anio))
                                .font(.system(size: tamAnio, weight: .medium))
                                .foregroundStyle(AnyShapeStyle(.apoyo))
                        }
                    }
                    .dynamicTypeSize(...DynamicTypeSize.xLarge)
                    .fixedSize()
                    .position(x: x, y: yBase + 14)
                }

                if meses.indices.contains(indice) {
                    let m = meses[indice]
                    let v = m.valor(medida)
                    let h = v.map { max(6, alto * CGFloat($0 / tope)) } ?? 4
                    let xEtiqueta = min(max(hueco * (CGFloat(indice) + 0.5), 44), g.size.width - 44)

                    let tapada = meses.indices
                        .filter { abs(hueco * (CGFloat($0) + 0.5) - xEtiqueta) < 44 + ancho / 2 }
                        .map { j -> CGFloat in
                            let hj = meses[j].valor(medida).map { max(6, alto * CGFloat($0 / tope)) } ?? 4
                            let fantasma = meses[j].enCurso ? ritmo.map { alto * CGFloat($0 / tope) } ?? 0 : 0
                            return max(hj, fantasma)
                        }
                        .max() ?? h
                    etiqueta(v)
                        .fixedSize()
                        .position(x: xEtiqueta, y: max(yBase - max(h, tapada) - 20, 12))
                        .opacity(crecidas ? 1 : 0)
                        .animation(mov(.spring(duration: 0.4, bounce: 0.3)), value: indice)
                        .animation(mov(.spring(duration: 0.55, bounce: 0.2)), value: medida)
                        .animation(mov(.smooth(duration: 0.3).delay(0.6)), value: crecidas)
                }
            }
            .contentShape(.rect)
            .onTapGesture(coordinateSpace: .local) { p in elegir(p.x, hueco: hueco) }
            .gesture(MantenerYDeslizar(
                espera: 0.12,
                alEmpezar: { p in elegir(p.x, hueco: hueco) },
                alMover: { p in elegir(p.x, hueco: hueco) },
                alAcabar: {}))
        }
        .sensoryFeedback(.selection, trigger: elegido)
        .onAppear { crecidas = true }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Meses, \(medida.rawValue.lowercased())")
        .accessibilityValue(meses.indices.contains(indice)
            ? "\(meses[indice].titulo), \(meses[indice].valor(medida).map(Formato.euros) ?? "sin horas medidas")"
            : "")
        .accessibilityAdjustableAction { d in
            let i = indice + (d == .increment ? 1 : -1)
            if meses.indices.contains(i) { elegido = meses[i].clave }
        }
    }

    @ViewBuilder
    private func columna(_ m: Mes, alto h: CGFloat, ancho: CGFloat, esta: Bool,
                         sinDato: Bool) -> some View {
        let forma = RoundedRectangle(cornerRadius: 8, style: .continuous)
        Group {
            if sinDato {
                forma.fill(enCampo ? Marcador.apoyo.opacity(0.14) : Color.primary.opacity(0.08))
            } else if todo && medida == .total && !m.partes.isEmpty {
                let total = max(m.partes.reduce(0) { $0 + $1.euros }, 0.01)
                VStack(spacing: 1.5) {
                    ForEach(m.partes.reversed(), id: \.clave) { p in
                        Rectangle()
                            .fill(Diseno.colorDePlataforma(p.clave).gradient)
                            .frame(height: max(0, (h - 1.5 * CGFloat(m.partes.count - 1))
                                                  * CGFloat(p.euros / total)))
                    }
                }
                .clipShape(forma)
            } else {
                forma.fill(LinearGradient(colors: [tinte, tinte.opacity(0.6)],
                                          startPoint: .top, endPoint: .bottom))
            }
        }
        .overlay {
            
            forma.strokeBorder(LinearGradient(colors: [.white.opacity(0.5), .white.opacity(0)],
                                              startPoint: .top, endPoint: .center),
                               lineWidth: 1)
        }
        .overlay {
            if conFilo && !sinDato { forma.strokeBorder(.black.opacity(0.6), lineWidth: 0.75) }
        }
        .frame(width: ancho, height: h)
        .opacity(esta || sinDato ? 1 : 0.42)
        .shadow(color: esta && !sinDato ? tinte.opacity(0.5) : .clear, radius: 8, x: 0, y: 4)
    }

    @ViewBuilder
    private func etiqueta(_ v: Double?) -> some View {
        let texto = Text(v.map(Formato.eurosRedondos) ?? "sin horas")
            .font(.caption.weight(.bold)).monospacedDigit()
            .contentTransition(.numericText(value: v ?? 0))
            .padding(.horizontal, 10).padding(.vertical, 5)
        if menosTransparencia {
            texto.background(Diseno.superficie, in: Capsule())
                .overlay(Capsule().strokeBorder(tinte, lineWidth: 1))
        } else {
            texto.glassEffect(.regular.tint(tinte.opacity(0.25)), in: Capsule())
        }
    }

    private func elegir(_ x: CGFloat, hueco: CGFloat) {
        guard !meses.isEmpty, hueco > 0 else { return }
        let i = max(0, min(meses.count - 1, Int(x / hueco)))
        if meses[i].clave != elegido {
            withAnimation(.spring(duration: 0.4, bounce: 0.25)) { elegido = meses[i].clave }
        }
    }

    private func mov(_ a: Animation) -> Animation? { menosMovimiento ? nil : a }
}

private struct FichaDelMes: View {
    typealias Mes = PantallaHistorial.Mes
    let mes: Mes
    let meses: [Mes]
    let tinte: Color

    @ScaledMetric(relativeTo: .largeTitle) private var tamCifra: CGFloat = 40
    @Environment(\.enCampo) private var enCampo

    private var anterior: Mes? {
        guard let i = meses.firstIndex(of: mes), i > 0 else { return nil }
        return meses[i - 1]
    }

    private var frente: (porcentaje: Int, sube: Bool)? {
        guard let a = anterior, a.porDia > 0 else { return nil }
        let r = (mes.porDia - a.porDia) / a.porDia * 100
        return (Int(abs(r).rounded()), r >= 0)
    }

    private var puesto: Int {
        let comparables = meses.filter { !$0.pronto }
        return (comparables.sorted { $0.porDia > $1.porDia }.firstIndex(of: mes) ?? 0) + 1
    }
    private var comparables: Int { meses.filter { !$0.pronto }.count }

    var body: some View {
        Tarjeta(relleno: Diseno.hueco4) {
            VStack(alignment: .leading, spacing: Diseno.hueco3) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(mes.titulo).font(.title3.weight(.semibold))
                    Text(String(mes.anio)).font(.subheadline).foregroundStyle(AnyShapeStyle(.apoyo))
                    if mes.enCurso {

                        Text("en curso")
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 7).padding(.vertical, 2)
                            .background(tinte.opacity(0.15), in: Capsule())
                            .foregroundStyle(AnyShapeStyle(.primary))
                    }
                    Spacer()
                    if comparables > 1 && !mes.pronto { medalla }
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(Formato.euros(mes.euros))
                        .font(.system(size: tamCifra, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .contentTransition(.numericText(value: mes.euros))
                        .minimumScaleFactor(0.6).lineLimit(1)
                    if let f = frente, let a = anterior {
                        let color = f.sube ? Diseno.verde : Diseno.rojo

                        Label {
                            Text("\(f.sube ? "+" : "−")\(f.porcentaje) % al día frente a \(a.nombre)")
                        } icon: {
                            Image(systemName: f.sube ? "arrow.up.right" : "arrow.down.right")
                                .foregroundStyle(color)
                        }
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(color.opacity(0.12), in: Capsule())
                    }
                    if mes.enCurso && mes.dias < 7 {
                        Text("El mes acaba de empezar: un solo día bueno mueve mucho esta cifra.")
                            .font(.footnote).foregroundStyle(.apoyo)
                    }
                    if let r = mes.aEsteRitmo {
                        Label("A este ritmo, \(Formato.eurosRedondos(r)) a fin de mes",
                              systemImage: "arrow.forward.to.line")
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(.apoyo)
                    }
                }

                Grid(horizontalSpacing: Diseno.hueco2,
                     verticalSpacing: Diseno.hueco3) {
                    GridRow {
                        dato("sun.max.fill", "Al día", Formato.euros(mes.porDia))
                        dato("clock.fill", mes.horaParcial ? "Por hora · lo medido" : "Por hora",
                             mes.porHora.map(Formato.euros) ?? "sin horas medidas")
                    }
                    GridRow {
                        dato("video.fill", "Emitidas",
                             mes.horas > 0 ? Formato.duracion(mes.horas) : "sin medir")
                        dato("circle.hexagongrid.fill", "Tokens", Formato.tokens(mes.tokens, unidad: ""))
                    }
                }

                if !mes.partes.isEmpty { partes }

                Text(mes.enCurso ? "\(mes.dias) días de \(mes.diasDelMes)"
                                 : "\(mes.dias) días")
                    .font(.caption).foregroundStyle(.apoyo)
            }
        }
    }

    private var medalla: some View {
        let color: Color = puesto == 1 ? .yellow : (puesto == 2 ? Color(.systemGray) : (puesto == 3 ? .orange : .secondary))

        return Label {
            Text("\(puesto).º de \(comparables)")
                .foregroundStyle(AnyShapeStyle(.primary))
        } icon: {
            Image(systemName: puesto <= 3 ? "medal.fill" : "number").foregroundStyle(color)
        }
            .font(.caption.weight(.semibold)).monospacedDigit()
            .symbolEffect(.bounce, value: mes.clave)
            .padding(.horizontal, 9).padding(.vertical, 4)
            .background(color.opacity(0.13), in: Capsule())
            .accessibilityLabel("Puesto \(puesto) de \(comparables), por lo que entra al día")
    }

    private func dato(_ icono: String, _ titulo: String, _ valor: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(titulo, systemImage: icono)
                .font(.caption.weight(.medium))
                .foregroundStyle(.apoyo)
                
                .labelStyle(DatoIconoTinte(tinte: enCampo ? Marcador.apoyo : tinte))
            Text(valor)
                .font(.system(.headline, design: .rounded)).monospacedDigit()
                .contentTransition(.numericText())
                .lineLimit(1).minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)

        .padding(0)
        .background(Color.clear,
                    in: .rect(cornerRadius: 14, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private var partes: some View {
        let total = max(mes.partes.reduce(0) { $0 + $1.euros }, 0.01)
        return VStack(alignment: .leading, spacing: 8) {
            BarraReparto(partes: mes.partes.map { (clave: $0.clave, euros: $0.euros) })
            ForEach(mes.partes, id: \.clave) { p in
                HStack(spacing: 8) {
                    Circle().fill(Diseno.colorDePlataforma(p.clave).gradient)
                        .frame(width: 8, height: 8)
                    Text(p.nombre).font(.footnote)
                    Spacer()
                    Text(Formato.euros(p.euros)).font(.footnote.weight(.medium)).monospacedDigit()
                    Text("\(Int((p.euros / total * 100).rounded())) %")
                        .font(.caption).monospacedDigit().foregroundStyle(.apoyo)
                        .frame(width: 38, alignment: .trailing)
                }
            }
        }
    }
}

private struct DatoIconoTinte: LabelStyle {
    let tinte: Color
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 4) {
            configuration.icon.foregroundStyle(tinte)
            configuration.title
        }
    }
}

private struct Records: View {
    typealias Mes = PantallaHistorial.Mes
    let meses: [Mes]
    let tinte: Color
    let ir: (String) -> Void

    private var cerrados: [Mes] { meses.filter { !$0.enCurso } }
    @Environment(\.enCampo) private var enCampo

    var body: some View {
        VStack(alignment: .leading, spacing: Diseno.hueco2) {
            if enCampo {
                TituloDeSeccion(texto: "Récords")
            } else {
                Text("Récords").font(.headline).padding(.leading, 4)
            }
            Grupo {
                if let m = meses.max(by: { $0.euros < $1.euros }) {
                    fila("trophy.fill", .yellow, "Mejor mes", m.titulo + " \(m.anio)",
                         Formato.euros(m.euros), ir: m.clave)
                }
                if let m = meses.filter({ !$0.pronto }).max(by: { $0.porDia < $1.porDia }) {
                    fila("sun.max.fill", .orange, "Mejor media al día", m.titulo + " \(m.anio)",
                         Formato.euros(m.porDia), ir: m.clave)
                }
                if let m = meses.filter({ $0.porHora != nil && !$0.pronto })
                    .max(by: { ($0.porHora ?? 0) < ($1.porHora ?? 0) }) {
                    fila("clock.fill", .blue, "Mejor por hora", m.titulo + " \(m.anio)",
                         Formato.euros(m.porHora ?? 0), ir: m.clave)
                }
                
                if cerrados.count > 1, let m = cerrados.min(by: { $0.euros < $1.euros }) {
                    fila("arrow.down.right", .red, "Mes más flojo", m.titulo + " \(m.anio)",
                         Formato.euros(m.euros), ir: m.clave)
                }
                if !cerrados.isEmpty {
                    let media = cerrados.reduce(0) { $0 + $1.euros } / Double(cerrados.count)
                    fila("equal.circle.fill", .gray, "Un mes normal",
                         "media de \(cerrados.count) " + (cerrados.count == 1 ? "mes" : "meses"),
                         Formato.euros(media), ir: nil)
                }
                fila("sum", .green, "En total",
                     "\(meses.count) " + (meses.count == 1 ? "mes" : "meses"),
                     Formato.euros(meses.reduce(0) { $0 + $1.euros }), ir: nil)
            }
        }
    }

    @ViewBuilder
    private func fila(_ icono: String, _ color: Color, _ titulo: String, _ detalle: String,
                      _ valor: String, ir clave: String?) -> some View {
        let contenido = HStack(spacing: Diseno.hueco2) {
            FichaIcono(simbolo: icono, color: color)
            VStack(alignment: .leading, spacing: 1) {
                Text(titulo).foregroundStyle(.primary)
                Text(detalle).font(.footnote).foregroundStyle(.apoyo)
            }
            Spacer()
            Text(valor).font(.subheadline.weight(.semibold)).monospacedDigit()
                .foregroundStyle(.primary)
            if clave != nil {
                Image(systemName: "chart.bar.fill")
                    .font(.caption).foregroundStyle(.tertiary)
            }
        }
        .padding(Diseno.hueco3)
        .contentShape(.rect)

        if let clave {
            Button { ir(clave) } label: { contenido }
                .buttonStyle(.plain)
                .accessibilityHint("Lleva la gráfica a ese mes")
        } else {
            contenido
        }
    }
}
