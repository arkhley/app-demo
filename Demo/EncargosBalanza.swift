import SwiftUI

struct DatosReservado: Equatable {
    struct Noche: Identifiable, Equatable {
        let fecha: String
        let tokens: Int
        let euros: Double
        let esClub: Bool
        let altas: Int
        let minutosMax: Double
        var id: String { fecha }
    }

    struct Tarifa: Equatable {
        let tokens: Int
        let eurosMinuto: Double
        let eurosHora: Double
    }

    let desde: String
    let desdeApp: String
    
    let recortado: Bool
    let salaTokens: Int
    let salaEuros: Double
    let salaHora: Double?
    let reservadoTokens: Int
    let reservadoEuros: Double
    let veces: Double?
    let noches: [Noche]
    let encargo: Tarifa?
    let premium: Tarifa?
    let observar: Tarifa?
    let clubTokens: Int
    let clubMes: Double
    let clubAno: Double

    init(_ j: [String: Any]) {
        func n(_ v: Any?) -> Double { (v as? NSNumber)?.doubleValue ?? 0 }
        func o(_ v: Any?) -> Double? { (v as? NSNumber)?.doubleValue }
        func tarifa(_ v: Any?) -> Tarifa? {
            guard let t = v as? [String: Any] else { return nil }
            return Tarifa(tokens: Int(n(t["tokens"])), eurosMinuto: n(t["euros_min"]),
                          eurosHora: n(t["euros_hora"]))
        }
        desde = j["desde"] as? String ?? ""
        desdeApp = j["desde_app"] as? String ?? ""
        recortado = j["recortado"] as? Bool ?? false
        let sala = j["sala"] as? [String: Any] ?? [:]
        salaTokens = Int(n(sala["tokens"]))
        salaEuros = n(sala["euros"])
        salaHora = o(sala["euros_hora"])
        let res = j["reservado"] as? [String: Any] ?? [:]
        reservadoTokens = Int(n(res["tokens"]))
        reservadoEuros = n(res["euros"])
        veces = o(j["veces"])
        noches = ((j["noches"] as? [[String: Any]]) ?? []).map {
            Noche(fecha: $0["fecha"] as? String ?? "", tokens: Int(n($0["tokens"])),
                  euros: n($0["euros"]), esClub: ($0["tipo"] as? String) == "club",
                  altas: Int(n($0["altas"])), minutosMax: n($0["minutos_max"]))
        }
        let t = j["tarifas"] as? [String: Any] ?? [:]
        encargo = tarifa(t["encargo"])
        premium = tarifa(t["premium"])
        observar = tarifa(t["observar"])
        let club = j["club"] as? [String: Any] ?? [:]
        clubTokens = Int(n(club["precio"]))
        clubMes = n(club["euros_mes"])
        clubAno = n(club["euros_ano"])
    }
}

struct PantallaEncargosBalanza: View {
    @Environment(Sesion.self) private var sesion

    @State private var periodo = "mes"

    @State private var periodoCargado = "mes"
    @State private var datos: DatosReservado?
    @State private var fallo: String?

    private static let periodos = [(clave: "mes", nombre: "Este mes"),
                                   (clave: "anterior", nombre: "Mes pasado"),
                                   (clave: "todo", nombre: "Todo")]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                SelectorDeslizante(opciones: Self.periodos, elegida: $periodo)
                    .accessibilityLabel("Periodo")
                    .padding(.top, Diseno.hueco2)
                if let d = datos {
                    contenido(d)
                } else if let fallo {
                    ContentUnavailableView("No se ha podido cargar", systemImage: "wifi.exclamationmark",
                                           description: Text(fallo))
                        .padding(.top, Diseno.hueco5)
                } else {
                    ProgressView().frame(maxWidth: .infinity).padding(.top, 80)
                }
            }
            .padding(.horizontal, Diseno.margen)
            .padding(.bottom, Diseno.hueco5)
            .animation(Diseno.suave, value: datos)
        }
        .scrollEdgeEffectStyle(.soft, for: .top)
        .background { CampoJoya(joya: .plataforma1) }
        .navigationTitle("Encargos y club")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await cargar() }
        .task(id: periodo) { await cargar() }
    }

    @ViewBuilder
    private func contenido(_ d: DatosReservado) -> some View {

        if d.recortado && !d.desdeApp.isEmpty {
            Text("Desde el \(Fechas.corta(d.desdeApp)), cuando la app empezó a escuchar")
                .font(.footnote)
                .foregroundStyle(Marcador.apoyo)
                .padding(.top, Diseno.hueco2)
        }
        Balanza(sala: d.salaEuros, reservado: d.reservadoEuros,
                salaTokens: d.salaTokens, reservadoTokens: d.reservadoTokens)
            .padding(.top, Diseno.hueco3)
        lineaDeLaHora(d)
            .padding(.top, Diseno.hueco2)
        noches(d)
        tarifas(d)
        
        Text("Plataforma 1 no dice quién ni cuánto duró cada encargo: aquí es lo que no fueron "
             + "propinas, noche a noche. \(d.clubTokens > 0 ? "Las de \(d.clubTokens), \(d.clubTokens * 2) o \(d.clubTokens * 3) tk justos se cuentan como club." : "")")
            .font(.footnote)
            .foregroundStyle(Marcador.apoyo)
            .padding(.top, Diseno.hueco4)
    }

    @ViewBuilder
    private func lineaDeLaHora(_ d: DatosReservado) -> some View {
        if let p = d.encargo {
            Label {
                if let v = d.veces, v >= 1.05 {

                    Text("Una hora de encargo te deja **\(Formato.euros(p.eurosHora))**: **al menos \(Self.veces(v)) veces** lo que dejan las propinas en una hora de sala.")
                } else {
                    Text("Una hora de encargo te deja **\(Formato.euros(p.eurosHora))**.")
                }
            } icon: {
                Image(systemName: "clock.fill").foregroundStyle(Marcador.apoyo)
            }
            .font(.subheadline)
            .foregroundStyle(Color.primary)
            .monospacedDigit()
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    static func veces(_ v: Double) -> String {
        let abajo = (v * 10).rounded(.down) / 10
        return abajo >= 10 || abajo == abajo.rounded(.down) ? String(Int(abajo.rounded(.down)))
            : String(format: "%.1f", abajo).replacingOccurrences(of: ".", with: ",")
    }

    @ViewBuilder
    private func noches(_ d: DatosReservado) -> some View {
        TituloDeSeccion(texto: "Noches", dato: d.noches.isEmpty ? nil : "\(d.noches.count)")
            .padding(.top, Diseno.hueco2)
        if d.noches.isEmpty {
            Text("Ninguna noche con encargo ni con altas del club")
                .font(.subheadline)
                .foregroundStyle(Marcador.apoyo)
                .padding(.vertical, Diseno.hueco2)
        } else {
            VStack(spacing: 0) {
                ForEach(Array(d.noches.enumerated()), id: \.element.id) { i, n in
                    if i > 0 { Divider().padding(.leading, 34) }
                    filaNoche(n)
                }
            }
            .padding(.top, Diseno.hueco1)
        }
    }

    private func filaNoche(_ n: DatosReservado.Noche) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Diseno.hueco2) {
            Image(systemName: n.esClub ? "star.fill" : "video.fill")
                .font(.subheadline)
                .foregroundStyle(Marcador.apoyo)
                .frame(width: 22)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(Self.mayuscula(Fechas.larga(n.fecha)))
                    .font(.headline)
                Text(n.esClub
                     ? (n.altas == 1 ? "Seguramente 1 alta o renovación del club"
                                     : "Seguramente \(n.altas) altas o renovaciones del club")
                     : "Encargo o observar · como mucho \(Formato.duracion(n.minutosMax / 60)) de encargo")
                    .font(.footnote)
                    .foregroundStyle(Marcador.apoyo)
            }
            Spacer(minLength: Diseno.hueco1)
            VStack(alignment: .trailing, spacing: 2) {
                Text(Formato.euros(n.euros))
                    .font(.system(.headline, design: .rounded))
                    .monospacedDigit()
                Text(Formato.tokens(n.tokens))
                    .font(.footnote)
                    .monospacedDigit()
                    .foregroundStyle(Marcador.apoyo)
            }
        }
        .padding(.vertical, Diseno.hueco2)
        .accessibilityElement(children: .combine)
    }

    static func mayuscula(_ s: String) -> String { s.prefix(1).uppercased() + s.dropFirst() }

    @ViewBuilder
    private func tarifas(_ d: DatosReservado) -> some View {
        TituloDeSeccion(texto: "Tus tarifas")
            .padding(.top, Diseno.hueco3)
        VStack(spacing: 0) {
            if let t = d.encargo { filaTarifa("Encargo", t) }
            if let t = d.premium { Divider().padding(.leading, 34); filaTarifa("Premium", t) }
            if let t = d.observar { Divider().padding(.leading, 34); filaTarifa("Observar", t) }
            if d.clubTokens > 0 {
                Divider().padding(.leading, 34)
                fila(simbolo: "star.fill", titulo: "Club",
                     detalle: "\(Formato.euros(d.clubMes)) al mes por socio · \(Formato.euros(d.clubAno)) al año",
                     valor: "\(d.clubTokens) tk/mes")
            }
            Divider().padding(.leading, 34)
            
            NavigationLink {
                PantallaAjustesP1()
            } label: {
                HStack(spacing: Diseno.hueco2) {
                    Image(systemName: "slider.horizontal.3")
                        .foregroundStyle(Marcador.apoyo)
                        .frame(width: 22)
                    Text("Cambiar las tarifas").foregroundStyle(Color.primary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Marcador.apoyo)
                }
                .frame(minHeight: 48)
                .contentShape(.rect)
            }
            .buttonStyle(Hundirse())
        }
        .padding(.top, Diseno.hueco1)
    }

    private func filaTarifa(_ titulo: String, _ t: DatosReservado.Tarifa) -> some View {
        fila(simbolo: titulo == "Observar" ? "eye.fill" : "video.fill", titulo: titulo,
             detalle: "\(Formato.euros(t.eurosMinuto)) el minuto · \(Formato.euros(t.eurosHora)) la hora",
             valor: "\(t.tokens) tk/min")
    }

    private func fila(simbolo: String, titulo: String, detalle: String, valor: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Diseno.hueco2) {
            Image(systemName: simbolo)
                .font(.subheadline)
                .foregroundStyle(Marcador.apoyo)
                .frame(width: 22)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(titulo).font(.headline)
                Text(detalle)
                    .font(.footnote)
                    .monospacedDigit()
                    .foregroundStyle(Marcador.apoyo)
            }
            Spacer(minLength: Diseno.hueco1)
            Text(valor)
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                .monospacedDigit()
        }
        .padding(.vertical, Diseno.hueco2)
        .accessibilityElement(children: .combine)
    }

    private func cargar() async {
        let pedido = periodo
        do {
            let j = try await API.pedir("api/plataforma1/reservado?periodo=\(pedido)",
                                        testigo: sesion.testigo)
            guard pedido == periodo else { return }      
            datos = DatosReservado(j)
            periodoCargado = pedido
            fallo = nil
        } catch is CancellationError {
        } catch {
            if (error as NSError).code == NSURLErrorCancelled { return }
            if datos == nil {
                fallo = error.localizedDescription
            } else {

                periodo = periodoCargado
                NotificationCenter.default.post(name: .recargaFallida, object: nil)
            }
        }
    }
}

struct Balanza: View {
    let sala: Double
    let reservado: Double
    let salaTokens: Int
    let reservadoTokens: Int

    @Environment(\.accessibilityReduceMotion) private var menosMovimiento
    @Environment(\.dynamicTypeSize) private var letra
    @ScaledMetric(relativeTo: .title2) private var alto: CGFloat = 250
    
    @State private var asentada = false

    private var angulo: Double {
        let total = sala + reservado
        guard total > 0.004 else { return 0 }
        return (reservado - sala) / total * 12
    }

    private var mostrado: Double { asentada || menosMovimiento ? angulo : 0 }

    private var cifrasAparte: Bool { letra.isAccessibilitySize }

    var body: some View {
        VStack(spacing: Diseno.hueco3) {
            DibujoBalanza(angulo: mostrado, sala: sala, reservado: reservado,
                          salaTokens: salaTokens, reservadoTokens: reservadoTokens,
                          conCifras: !cifrasAparte)
                .frame(height: cifrasAparte ? 190 : min(alto, 320))
            if cifrasAparte {
                VStack(alignment: .leading, spacing: Diseno.hueco2) {
                    filaCifras("Sala", sala, salaTokens)
                    filaCifras("Encargos y club", reservado, reservadoTokens)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .animation(menosMovimiento ? nil : .spring(duration: 1.0, bounce: 0.38), value: mostrado)
        .sensoryFeedback(.impact(flexibility: .soft, intensity: 0.6), trigger: mostrado)
        .onAppear {
            guard !asentada else { return }
            Task {
                try? await Task.sleep(for: .milliseconds(150))
                asentada = true
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Sala, \(Formato.euros(sala)). Encargos y club, \(Formato.euros(reservado)). "
                            + (abs(angulo) < 0.01 ? "Pesan lo mismo."
                               : angulo > 0 ? "Pesan más los encargos y el club." : "Pesa más la sala."))
    }

    private func filaCifras(_ nombre: String, _ euros: Double, _ tokens: Int) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(nombre).font(.footnote.weight(.semibold))
            Text(Formato.euros(euros))
                .font(.system(.title3, design: .rounded).weight(.bold))
                .monospacedDigit()
            Text(Formato.tokens(tokens))
                .font(.caption)
                .monospacedDigit()
                .foregroundStyle(Marcador.apoyo)
        }
        .foregroundStyle(Color.primary)
    }
}

private struct DibujoBalanza: View, @preconcurrency Animatable {
    var angulo: Double
    let sala: Double
    let reservado: Double
    let salaTokens: Int
    let reservadoTokens: Int
    let conCifras: Bool

    var animatableData: Double {
        get { angulo }
        set { angulo = newValue }
    }

    @Environment(\.colorScheme) private var modo

    var body: some View {
        GeometryReader { g in
            let w = g.size.width
            let h = g.size.height

            let pivote = CGPoint(x: w / 2, y: 44)
            let brazo = min(w * 0.36, 170)
            let rad = angulo * .pi / 180
            let izq = CGPoint(x: pivote.x - brazo * cos(rad), y: pivote.y - brazo * sin(rad))
            let der = CGPoint(x: pivote.x + brazo * cos(rad), y: pivote.y + brazo * sin(rad))
            let cuelga: CGFloat = 52
            let tinta = Color.primary
            ZStack {
                
                Path { p in
                    p.move(to: CGPoint(x: pivote.x, y: pivote.y))
                    p.addLine(to: CGPoint(x: pivote.x, y: h - 10))
                }
                .stroke(tinta.opacity(0.55), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                Capsule()
                    .fill(tinta.opacity(0.55))
                    .frame(width: 64, height: 5)
                    .position(x: pivote.x, y: h - 10)
                
                plato(en: izq, cuelga: cuelga, nombre: "Sala", euros: sala, tokens: salaTokens)
                plato(en: der, cuelga: cuelga, nombre: "Encargos y club", euros: reservado,
                      tokens: reservadoTokens)
                
                Path { p in
                    p.move(to: izq)
                    p.addLine(to: der)
                }
                .stroke(tinta, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                
                Circle()
                    .fill(tinta)
                    .frame(width: 12, height: 12)
                    .position(pivote)
            }
        }
    }

    private func plato(en punta: CGPoint, cuelga: CGFloat, nombre: String, euros: Double,
                       tokens: Int) -> some View {
        let ancho: CGFloat = 86
        let fondo = CGPoint(x: punta.x, y: punta.y + cuelga)
        return ZStack {
            Path { p in
                
                p.move(to: punta)
                p.addLine(to: CGPoint(x: fondo.x - ancho / 2 + 6, y: fondo.y))
                p.move(to: punta)
                p.addLine(to: CGPoint(x: fondo.x + ancho / 2 - 6, y: fondo.y))
            }
            .stroke(Color.primary.opacity(0.6), lineWidth: 1.5)
            
            Path { p in
                p.move(to: CGPoint(x: fondo.x - ancho / 2, y: fondo.y))
                p.addQuadCurve(to: CGPoint(x: fondo.x + ancho / 2, y: fondo.y),
                               control: CGPoint(x: fondo.x, y: fondo.y + 26))
                p.closeSubpath()
            }
            .fill(Color.primary.opacity(modo == .dark ? 0.22 : 0.16))
            .overlay {
                Path { p in
                    p.move(to: CGPoint(x: fondo.x - ancho / 2, y: fondo.y))
                    p.addQuadCurve(to: CGPoint(x: fondo.x + ancho / 2, y: fondo.y),
                                   control: CGPoint(x: fondo.x, y: fondo.y + 26))
                    p.closeSubpath()
                }
                .stroke(Color.primary, lineWidth: 2)
            }
            if conCifras {
                VStack(spacing: 1) {
                    Text(nombre)
                        .font(.footnote.weight(.semibold))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                    Text(Formato.euros(euros))
                        .font(.system(.title3, design: .rounded).weight(.bold))
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Text(Formato.tokens(tokens))
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(Marcador.apoyo)
                }
                .foregroundStyle(Color.primary)
                
                .frame(width: 120)
                .position(x: fondo.x, y: fondo.y + 64)
            }
        }
    }
}
