import SwiftUI

struct PantallaHuchaNueva: View {
    @Environment(Sesion.self) private var sesion
    @Environment(\.scenePhase) private var fase

    private static let cadaCuanto: Duration = .seconds(15)

    @ScaledMetric(relativeTo: .largeTitle) private var tamCifra: CGFloat = 40
    @Environment(\.dynamicTypeSize) private var tamLetra

    @State private var objetivo: Double = 0
    @State private var saldo: Double = 0
    @State private var ahorroPorcentaje: Double = 0
    @State private var ahorroHoy: Double = 0
    @State private var hoy: PantallaHucha.DiaHucha?
    @State private var ayer: PantallaHucha.DiaHucha?
    @State private var supone: PantallaHucha.Supone?
    @State private var mes: PantallaHucha.MesHucha?
    @State private var meses: [PantallaHucha.MesCerrado] = []
    @State private var jornada: String?
    
    @State private var dias: [String: PantallaHucha.DiaHucha] = [:]

    @State private var diasPedidos = ""
    @State private var estado: Carga<Bool> = .cargando
    @State private var ajustando = false
    @State private var aviso: (texto: String, bien: Bool)?

    @State private var cobros: CobrosHucha?

    @State private var cobrosPedidos = false
    @State private var mesCobros = ""
    @State private var plataformaCobros = "todo"
    @State private var marcando: String?
    @State private var avisoCobros: (texto: String, bien: Bool)?

    var body: some View {
        ScrollView {
            VStack(spacing: Diseno.hueco3) {
                switch estado {
                case .cargando:
                    heroe.redacted(reason: .placeholder)
                case .error(let qué):
                    Tarjeta { Vacio(icono: "wifi.exclamationmark",
                                    titulo: "No se ha podido cargar", detalle: qué) }
                default:
                    if objetivo <= 0 { sinObjetivo } else { contenido }
                }
                if let aviso { Banda(aviso) }
            }
            .padding(.horizontal, Diseno.margen)
            .padding(.vertical, Diseno.hueco2)
        }
        .fondoDePantalla()
        .navigationTitle("Reserva")

        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Ajustes", systemImage: "slider.horizontal.3") { ajustando = true }
                    .labelStyle(.iconOnly)
            }
        }
        .sheet(isPresented: $ajustando) {
            HojaAjustesHuchaNueva(objetivo: objetivo, ahorro: ahorroPorcentaje, saldo: saldo,
                                  supone: supone) { cuerpo in
                await guardar(cuerpo)
            }
        }
        .refreshable {
            diasPedidos = ""
            await cargar()
        }
        .task(id: fase) {
            guard fase == .active else { return }
            await vigilar()
        }
    }

    private var sinObjetivo: some View {
        Tarjeta {
            VStack(spacing: Diseno.hueco3) {
                Deposito(saldo: 0, unidad: 0)
                    .frame(width: 80, height: 150 + Deposito.cabeza)
                    .padding(.top, -Deposito.cabeza)
                Text("Sin objetivo").font(.headline)
                Button("Poner un objetivo") { ajustando = true }
                    .buttonStyle(.glassProminent)
                    .controlSize(.large)
                    .rellenoDelTema(nil)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Diseno.hueco3)
        }
    }

    private var contenido: some View {
        VStack(spacing: Diseno.hueco3) {
            heroe
            if let d = hoy { tarjetaHoy(d) }
            if let c = cobros, c.hayObjetivo {
                ApartarHucha(datos: c, plataforma: $plataformaCobros, marcando: marcando,
                             cambiarMes: { m in Task { await cambiarMesCobros(m) } },
                             marcar: { cobro in Task { await marcar(cobro) } },
                             completar: { cobro in Task { await marcar(cobro, apartado: true) } })
                    .padding(.top, Diseno.hueco2)
                if let avisoCobros { Banda(avisoCobros) }
            }
            if cobrosPedidos, !meses.isEmpty {
                MesesHucha(meses: meses).padding(.top, Diseno.hueco2)
            }
        }
    }

    private var nombreMes: String {
        CobrosHucha.nombreDelMes(mes?.mes ?? "").capitalized
    }

    private var reparto: AnyLayout {
        tamLetra.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: Diseno.hueco4))
            : AnyLayout(HStackLayout(alignment: .center, spacing: Diseno.hueco4))
    }

    private var heroe: some View {
        VStack(alignment: .leading, spacing: Diseno.hueco4) {
            reparto {

                Deposito(saldo: saldo, unidad: objetivo)
                    .frame(width: 96, height: 196 + Deposito.cabeza)
                    .padding(.top, -Deposito.cabeza)

                VStack(alignment: .leading, spacing: Diseno.hueco2) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(Formato.euros(saldo))
                            .font(.system(size: tamCifra, weight: .semibold, design: .rounded))
                            .foregroundStyle(saldo < 0 ? Diseno.rojo : Color.primary)
                            .monospacedDigit()
                            .contentTransition(.numericText(value: saldo))
                            .minimumScaleFactor(0.5)
                            .lineLimit(1)

                        if saldo < 0 {
                            Text("por debajo de tu objetivo")
                                .font(.caption).foregroundStyle(Diseno.rojo)
                        }
                    }
                    
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: Diseno.hueco2) {
                            Text(nombreMes).font(.headline)
                            chipDias
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text(nombreMes).font(.headline)
                            chipDias
                        }
                    }
                    if let m = mes {
                        let tope = max(m.ganado, m.objetivoHastaHoy)
                        BarraComparada(titulo: "Ganado", valor: m.ganado, maximo: tope,
                                       color: AnyShapeStyle(saldo < 0 ? Diseno.rojoRelleno
                                                                      : Diseno.verdeRelleno))
                        BarraComparada(titulo: "Tocaba", valor: m.objetivoHastaHoy, maximo: tope,
                                       color: AnyShapeStyle(Color.secondary.opacity(0.55)))
                    }
                }
                .animation(Diseno.cifra, value: saldo)
            }

            if let m = mes {
                NavigationLink {
                    PantallaCalendarioHuchaNueva()
                } label: {
                    HStack(spacing: Diseno.hueco2) {
                        TiraDelMes(mes: m.mes, dias: dias, hoy: jornada)
                        Image(systemName: "chevron.right")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                    
                    .frame(minHeight: 44)
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityHint("Abre el calendario")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Diseno.hueco4)
        .background(Diseno.superficie, in: .rect(cornerRadius: Diseno.radioHeroe))
    }

    @ViewBuilder
    private var chipDias: some View {
        if let m = mes {
            Group {
                if m.diasQueQuedan > 0 {
                    Label("\(m.diasQueQuedan) \(m.diasQueQuedan == 1 ? "día" : "días")",
                          systemImage: "hourglass")
                } else {
                    Label("Cerrado", systemImage: "lock.fill")
                }
            }
            .font(.caption.weight(.medium))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(.fill.tertiary, in: .capsule)
            .accessibilityLabel(m.diasQueQuedan > 0
                                ? "Quedan \(m.diasQueQuedan) días del mes"
                                : "Mes cerrado: este saldo va a tus ahorros")
        }
    }

    private func tarjetaHoy(_ d: PantallaHucha.DiaHucha) -> some View {
        Tarjeta {
            VStack(alignment: .leading, spacing: Diseno.hueco3) {
                reparto {
                    AnilloDia(dia: d, objetivoPorDefecto: objetivo, grosor: 13)
                        .frame(width: 88, height: 88)

                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {

                            Circle().fill(Diseno.verdeRelleno).frame(width: 7, height: 7)
                                .modifier(Latido(activo: !d.cerrado))
                            Text("Hoy").font(.subheadline.weight(.semibold))
                            Spacer()
                            Label("09:00", systemImage: "clock")
                                .font(.caption).foregroundStyle(.secondary)
                                .accessibilityLabel("Se cierra a las 09:00")
                        }
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text(Formato.euros(d.ganado))
                                .font(.system(.title2, design: .rounded).weight(.semibold))
                                .monospacedDigit()
                                .contentTransition(.numericText())
                            Text("/ \(Formato.eurosJustos(d.objetivo ?? objetivo))")
                                .font(.subheadline).foregroundStyle(.secondary)
                        }
                        estadoDeHoy(d)
                        if ahorroPorcentaje > 0, ahorroHoy > 0.004 {
                            Label("Ahorra \(Formato.euros(ahorroHoy))", systemImage: "banknote")
                                .font(.caption).foregroundStyle(.secondary)
                                .accessibilityLabel("Para ahorrar \(Formato.euros(ahorroHoy)), "
                                    + "el \(Formato.ajuste(ahorroPorcentaje)) % de lo de hoy")
                        }
                    }
                    .animation(Diseno.cifra, value: d)
                }

                if let a = ayer {
                    Divider()
                    HStack(spacing: Diseno.hueco2) {
                        AnilloDia(dia: a, objetivoPorDefecto: objetivo, grosor: 4.5)
                            .frame(width: 28, height: 28)
                        Text(Formato.diaSemana(a.fecha).capitalized)
                            .font(.subheadline).foregroundStyle(.secondary)
                        Spacer()
                        Text(Formato.euros(a.ganado))
                            .font(.subheadline).monospacedDigit()
                        efecto(a)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }

    @ViewBuilder
    private func estadoDeHoy(_ d: PantallaHucha.DiaHucha) -> some View {
        let falta = d.falta ?? max(0, (d.objetivo ?? objetivo) - d.ganado)
        if d.sinDirecto(objetivo: d.objetivo ?? objetivo) {

            Label("sin directo", systemImage: "video.slash.fill")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
        }
        if d.aporte > 0.004 {
            Label("+\(Formato.euros(d.aporte)) a la reserva", systemImage: "drop.fill")
                .font(.caption.weight(.medium))
                .foregroundStyle(Diseno.verde)
        } else if falta > 0.004 {
            Label("faltan \(Formato.euros(falta))", systemImage: "target")
                .font(.caption.weight(.medium))
                .foregroundStyle(Diseno.naranja)
        }
    }

    @ViewBuilder
    private func efecto(_ a: PantallaHucha.DiaHucha) -> some View {
        if a.aporte > 0.004 {
            Label("+\(Formato.eurosRedondos(a.aporte))", systemImage: "drop.fill")
                .foregroundStyle(Diseno.verde)
                .font(.caption.weight(.semibold))
                .accessibilityLabel("fueron \(Formato.euros(a.aporte)) a la reserva")
        } else if a.relleno > 0.004 {
            Label("−\(Formato.eurosRedondos(a.relleno))", systemImage: "tray.and.arrow.up.fill")
                .foregroundStyle(a.falto ? Diseno.rojo : Diseno.azul)
                .font(.caption.weight(.semibold))
                .accessibilityLabel("la reserva puso \(Formato.euros(a.relleno))")
        } else if a.falto {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(Diseno.rojo)
                .font(.caption)
                .accessibilityLabel("no llegó al objetivo")
        }
    }

    private func vigilar() async {
        await cargar()
        var seguidos = 0
        while !Task.isCancelled && fase == .active {
            try? await Task.sleep(for: Self.cadaCuanto)
            if Task.isCancelled { return }
            do {
                try await pedirYPintar()
                seguidos = 0
            } catch API.Fallo.sinTestigo {
                return
            } catch {
                seguidos += 1
                if seguidos >= 10 { return }
            }
        }
    }

    private func cargar() async {
        do {
            try await pedirYPintar()
        } catch is CancellationError {
            return
        } catch {
            if (error as NSError).code == NSURLErrorCancelled { return }
            estado.fallar(error)
        }
    }

    private func pedirYPintar() async throws {
        let j = try await API.pedir("api/hucha", testigo: sesion.testigo)
        objetivo = (j["objetivo"] as? Double) ?? 0
        saldo = (j["saldo"] as? Double) ?? 0
        ahorroPorcentaje = (j["ahorro_porcentaje"] as? Double) ?? 0
        ahorroHoy = (j["ahorro_hoy"] as? Double) ?? 0
        hoy = (j["hoy"] as? [String: Any]).flatMap(PantallaHucha.DiaHucha.init)
        ayer = (j["ayer"] as? [String: Any]).flatMap(PantallaHucha.DiaHucha.init)
        jornada = j["jornada"] as? String
        if let m = j["mes"] as? [String: Any] {
            mes = PantallaHucha.MesHucha(mes: m["mes"] as? String ?? "",
                                         diasHechos: m["dias_hechos"] as? Int ?? 0,
                                         diasQueQuedan: m["dias_que_quedan"] as? Int ?? 0,
                                         ganado: m["ganado"] as? Double ?? 0,
                                         objetivoHastaHoy: m["objetivo_hasta_hoy"] as? Double ?? 0,
                                         objetivoMes: m["objetivo_mes"] as? Double ?? 0)
        }
        meses = ((j["meses"] as? [[String: Any]]) ?? []).map {
            PantallaHucha.MesCerrado(mes: $0["mes"] as? String ?? "",
                                     saldoFinal: $0["saldo_final"] as? Double ?? 0,
                                     ganado: $0["ganado"] as? Double ?? 0,
                                     objetivoMes: $0["objetivo_mes"] as? Double ?? 0)
        }
        if let sp = j["supone"] as? [String: Any] {
            supone = PantallaHucha.Supone(alaSemana: sp["a_la_semana"] as? Double ?? 0,
                                          alMes: sp["al_mes"] as? Double ?? 0,
                                          diasDelMes: sp["dias_del_mes"] as? Int ?? 0,
                                          tokensDia: sp["tokens_dia"] as? Int,
                                          tokensMes: sp["tokens_mes"] as? Int)
        }
        estado = .listo(true)
        
        if let m = mes?.mes, diasPedidos != "\(m)|\(jornada ?? "")" {
            if (try? await pedirDias()) != nil { diasPedidos = "\(m)|\(jornada ?? "")" }
        }
        try? await pedirCobros()
        cobrosPedidos = true
    }

    private func pedirDias() async throws {
        guard let m = mes?.mes, let año = Int(m.prefix(4)) else { return }
        let j = try await API.pedir("api/hucha/calendario/\(año)", testigo: sesion.testigo)
        let lista = ((j["dias"] as? [[String: Any]]) ?? []).compactMap(PantallaHucha.DiaHucha.init)
        dias = Dictionary(lista.filter { $0.fecha.hasPrefix(m) }.map { ($0.fecha, $0) },
                          uniquingKeysWith: { _, b in b })
    }

    private func pedirCobros() async throws {

        let j = try await API.pedir("api/hucha/cobros?mes=\(mesCobros)&falta_mas=1",
                                    testigo: sesion.testigo)
        let c = CobrosHucha(j)
        cobros = c
        mesCobros = c.mes
    }

    private func cambiarMesCobros(_ m: String) async {
        mesCobros = m
        avisoCobros = nil
        try? await pedirCobros()
    }

    private func marcar(_ c: CobrosHucha.Cobro, apartado: Bool? = nil) async {
        marcando = c.id
        defer { marcando = nil }
        do {
            let r = try await API.pedir("api/hucha/apartar", metodo: "POST",
                                        cuerpo: ["id": c.id, "apartado": apartado ?? !c.apartado],
                                        testigo: sesion.testigo)
            let ok = r["ok"] as? Bool ?? false
            avisoCobros = ok ? nil : (r["mensaje"] as? String ?? "No se ha podido marcar.", false)
            try? await pedirCobros()
        } catch {
            avisoCobros = (error.localizedDescription, false)
        }
    }

    private func guardar(_ cuerpo: [String: any Sendable]) async {
        do {
            let r = try await API.pedir("api/hucha/ajustes", metodo: "POST",
                                        cuerpo: cuerpo, testigo: sesion.testigo)
            aviso = (r["mensaje"] as? String ?? "Guardado.", r["ok"] as? Bool ?? true)
            
            diasPedidos = ""
            await cargar()
        } catch {
            aviso = (error.localizedDescription, false)
        }
    }
}

struct HojaAjustesHuchaNueva: View {
    @Environment(\.dismiss) private var cerrar
    let objetivo: Double
    let ahorro: Double
    let saldo: Double
    let supone: PantallaHucha.Supone?
    let guardar: ([String: any Sendable]) async -> Void

    @State private var textoObjetivo = ""
    @State private var textoAhorro = ""
    @State private var textoSaldo = ""

    @State private var saldoAlAbrir = ""
    @State private var trabajando = false

    private var escrito: Double? {
        Double(textoObjetivo.replacingOccurrences(of: ",", with: ".")
            .trimmingCharacters(in: .whitespaces))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Objetivo") {
                    HStack {
                        TextField("0", text: $textoObjetivo)
                            .keyboardType(.decimalPad)
                        Text("€ al día").foregroundStyle(.secondary)
                    }
                    if let o = escrito, o > 0 { equivalencias(o) }
                    Text("Todas las plataformas juntas, Tienda y Pasarela incluidos.")
                        .font(.caption).foregroundStyle(.secondary)
                }

                Section("Ahorro") {
                    HStack {
                        TextField("0", text: $textoAhorro)
                            .keyboardType(.decimalPad)
                        Text("% de cada ganancia").foregroundStyle(.secondary)
                    }
                }

                Section("Saldo") {
                    HStack {
                        TextField("0", text: $textoSaldo)
                            .keyboardType(.decimalPad)
                        Text("€").foregroundStyle(.secondary)
                    }
                    
                    Text("Cámbialo solo para empezar con lo que ya tengas. Vacío, vuelve al calculado.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .fondoDePantalla()
            .navigationTitle("Ajustes de la reserva")
            .navigationBarTitleDisplayMode(.inline)
            .salidaDelTeclado()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { cerrar() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task {
                            trabajando = true
                            await guardar(["accion": "ajustes",
                                           "objetivo": textoObjetivo,
                                           "ahorro": textoAhorro])
                            if textoSaldo != saldoAlAbrir {
                                await guardar(["accion": "saldo", "saldo": textoSaldo])
                            }
                            trabajando = false
                            cerrar()
                        }
                    } label: {
                        MarcaConfirmar(trabajando: trabajando)
                    }
                    .disabled(trabajando)
                }
            }
            .onAppear {
                textoObjetivo = Formato.ajuste(objetivo)
                textoAhorro = Formato.ajuste(ahorro)
                textoSaldo = Formato.ajuste(saldo)
                saldoAlAbrir = textoSaldo
            }
        }
    }

    @ViewBuilder
    private func equivalencias(_ o: Double) -> some View {
        let igual = abs(o - objetivo) < 0.001
        let dias = (supone?.diasDelMes ?? 0) > 0 ? supone!.diasDelMes : 30
        let semana = igual ? (supone?.alaSemana ?? o * 7) : o * 7
        let alMes = igual ? (supone?.alMes ?? o * Double(dias)) : o * Double(dias)
        let tokensPorEuro: Double? = {
            guard let td = supone?.tokensDia, objetivo > 0 else { return nil }
            return Double(td) / objetivo
        }()
        fila("calendar.day.timeline.left", "A la semana", Formato.euros(semana))
        fila("calendar", "Al mes (\(dias) días)", Formato.euros(alMes))
        if let t = tokensPorEuro {
            let td = igual ? (supone?.tokensDia ?? Int((o * t).rounded())) : Int((o * t).rounded())
            let tm = igual ? (supone?.tokensMes ?? Int((o * t * Double(dias)).rounded()))
                           : Int((o * t * Double(dias)).rounded())
            fila("circle.hexagongrid.fill", "Tokens al día", Formato.tokens(td, unidad: ""))
            fila("circle.hexagongrid", "Tokens al mes", Formato.tokens(tm, unidad: ""))
        }
    }

    private func fila(_ icono: String, _ titulo: String, _ valor: String) -> some View {
        HStack {
            Label(titulo, systemImage: icono)
                .foregroundStyle(.secondary)
            Spacer()
            Text(valor).monospacedDigit().contentTransition(.numericText())
        }
        .font(.subheadline)
    }
}
