import SwiftUI

struct PantallaManual: View {
    @Environment(Sesion.self) private var sesion
    let clave: String

    var recibidoEn: Date? = nil

    @State private var nombre = ""
    @State private var euros: Double = 0
    @State private var tokens = 0

    @State private var enDinero = false
    @State private var horas: Double = 0
    @State private var horasHeredadas = 0
    @State private var dias: [Dia] = []

    @State private var fecha = Date()
    
    @State private var horaPuesta = false

    @State private var reemplaza: String?
    @State private var tokensHoy = ""
    @State private var horasHoy = ""
    @State private var guardando = false
    @State private var aviso: (texto: String, bien: Bool)?
    @State private var estado: Carga<Bool> = .cargando
    @State private var rastreando = false

    struct Dia: Identifiable, Equatable {
        let fecha: String
        let tokens: Int
        let horas: Double
        var recibido: String = ""
        var hora: String = ""
        var id: String { fecha }
    }

    var body: some View {
        Group {

            marcador
        }
        .navigationTitle(nombre)
        .salidaDelTeclado()
        .scrollDisabled(rastreando)
        .animation(Diseno.suave, value: dias)
        .animation(Diseno.suave, value: aviso?.texto)
        .task {
            if let r = recibidoEn, !horaPuesta {
                fecha = r
                horaPuesta = true
            }
            await cargar()
        }
        .refreshable { await cargar() }
    }

    private var marcador: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                switch estado {
                case .cargando:
                    Vacio(icono: "square.and.pencil", titulo: "Cargando…")
                        .redacted(reason: .placeholder)
                        .padding(.top, Diseno.hueco5)
                case .error(let qué):
                    Vacio(icono: "wifi.exclamationmark", titulo: "No se ha podido cargar", detalle: qué)
                        .padding(.top, Diseno.hueco5)
                default:
                    delMes
                        .padding(.horizontal, Diseno.margen)
                    losa
                        .padding(.horizontal, Diseno.margen)
                        .padding(.top, Diseno.hueco3)

                    if horasHeredadas > 0 {
                        Text("Las horas vienen de Plataforma 1. Si apuntas horas de un día, mandan las tuyas.")
                            .font(.footnote).foregroundStyle(Marcador.apoyo)
                            .padding(.horizontal, Diseno.margen)
                            .padding(.top, Diseno.hueco2)
                    }
                    if !dias.isEmpty { diasEnCampo }
                    accesos
                        .padding(.top, Diseno.hueco4)
                }
            }
            .padding(.bottom, Diseno.hueco5)
        }
        .scrollEdgeEffectStyle(.soft, for: .top)
        .background { CampoJoya(joya: .de(clave)) }
    }

    private var delMes: some View {
        VStack(alignment: .leading, spacing: 2) {

            Text(enDinero ? "Este mes" : "Este mes · ya sin comisiones")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Marcador.apoyo)
            CifraMarcador(euros: euros)
            if !enDinero {
                Text("\(Formato.tokens(tokens, unidad: "tokens")) · \(Formato.duracion(horas))")
                    .font(.subheadline)
                    .foregroundStyle(Marcador.apoyo)
                    .monospacedDigit()
                    .contentTransition(.numericText())
            }
        }
        .animation(Diseno.cifra, value: euros)
        .accessibilityElement(children: .combine)
    }

    private var losa: some View {
        VStack(alignment: .leading, spacing: Diseno.hueco2) {
            Text(reemplaza == nil ? "Apuntar un día" : "Corregir el \(Formato.diaCorto(reemplaza ?? ""))")
                .font(.title2.weight(.bold))
                .contentTransition(.interpolate)
            DatePicker("Recibidos", selection: $fecha, in: ...Date(),
                       displayedComponents: [.date, .hourAndMinute])
                .environment(\.timeZone, Self.madrid)
            Text("Lo de antes de las 09:00 cuenta en el día anterior.")
                .font(.footnote).foregroundStyle(Marcador.apoyo)
            HStack(spacing: Diseno.hueco2) {
                Campo(titulo: enDinero ? "Euros" : "Tokens", valor: $tokensHoy,
                      teclado: enDinero ? .decimalPad : .numberPad, pista: "0")
                Campo(titulo: "Horas", valor: $horasHoy, teclado: .decimalPad, pista: "0")
            }
            Button {
                Task { await guardar() }
            } label: {
                Group {
                    if guardando {
                        ProgressView().controlSize(.small).tint(.white)
                    } else {
                        
                        Image(systemName: "checkmark").fontWeight(.bold)
                    }
                }
                .frame(maxWidth: .infinity)
            }
            
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .controlSize(.large)
            .rellenoDelTema()
            .disabled(guardando)
            .accessibilityLabel("Apuntar el día")
            if let aviso { Banda(aviso) }
            Text("Guardar otra vez el mismo día lo reemplaza.")
                .font(.footnote).foregroundStyle(Marcador.apoyo)
        }
        .padding(Diseno.hueco3)
        .background {
            Color.clear.cristal(.regular, en: .rect(cornerRadius: Diseno.radioHeroe))
        }
    }

    private var diasEnCampo: some View {
        VStack(alignment: .leading, spacing: 0) {
            TituloDeSeccion(texto: "Días apuntados")
            ForEach(Array(dias.prefix(30).enumerated()), id: \.element.id) { i, d in
                if i > 0 { Divider() }
                HStack(spacing: Diseno.hueco2) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(Formato.diaCorto(d.fecha).capitalizandoPrimera)
                            .font(.headline)
                            .foregroundStyle(Color.primary)
                        if !d.hora.isEmpty {
                            Text("Recibidos el \(Formato.diaCorto(d.recibido)), \(d.hora)")
                                .font(.footnote).foregroundStyle(Marcador.apoyo)
                        }
                    }
                    Spacer(minLength: Diseno.hueco1)
                    BarraDia(fraccion: Double(d.tokens) / Double(max(maxTokens, 1)),
                             color: Diseno.colorDePlataforma(clave),
                             reemplazando: reemplaza == d.fecha, conFilo: true)
                    VStack(alignment: .trailing, spacing: 1) {
                        Text(enDinero ? Formato.euros(Double(d.tokens)) : Formato.tokens(d.tokens))
                            .font(.system(.headline, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(Color.primary)
                        if d.horas > 0 {
                            Text(Formato.duracion(d.horas))
                                .font(.caption).foregroundStyle(Marcador.apoyo)
                        }
                    }
                }
                .padding(.vertical, 10)
                .contentShape(.rect)
                
                .onTapGesture { recuperar(d) }
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(.isButton)
                .accessibilityHint("Llevarlo al formulario para corregirlo")
            }
        }
        .padding(.horizontal, Diseno.margen)
    }

    private var accesos: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Diseno.hueco2) {
                AccesoHeroe(icono: "list.bullet.rectangle", titulo: "Detalle") {
                    PantallaDetalleP1(periodo: "mes", plataforma: clave)
                }
                AccesoHeroe(icono: "chart.line.uptrend.xyaxis", titulo: "Historial") {
                    PantallaHistorial(plataforma: clave)
                }
                AccesoHeroe(icono: "slider.horizontal.3", titulo: "Ajustes") {
                    PantallaAjustesManual(clave: clave)
                }
            }
            .padding(.horizontal, Diseno.margen)
        }
        .scrollClipDisabled()
        .modifier(BordeQueSigue())
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
    }

    private var formulario: some View {
        Tarjeta {
            VStack(alignment: .leading, spacing: Diseno.hueco2) {
                Text("Apuntar un día").font(.headline)

                DatePicker("Recibidos", selection: $fecha, in: ...Date(),
                           displayedComponents: [.date, .hourAndMinute])
                    .environment(\.timeZone, Self.madrid)
                Text("Lo de antes de las 09:00 cuenta en el día anterior.")
                    .font(.caption).foregroundStyle(.secondary)

                HStack(spacing: Diseno.hueco2) {
                    Campo(titulo: enDinero ? "Euros" : "Tokens", valor: $tokensHoy,
                          teclado: enDinero ? .decimalPad : .numberPad, pista: "0")
                    Campo(titulo: "Horas", valor: $horasHoy, teclado: .decimalPad, pista: "0")
                }

                Button {
                    Task { await guardar() }
                } label: {

                    Group {
                        if guardando {
                            ProgressView().controlSize(.small).tint(.white)
                        } else {
                            
                            Image(systemName: "checkmark").fontWeight(.semibold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
                }
                .buttonStyle(.glassProminent)
                .controlSize(.large)
                .rellenoDelTema(Diseno.azul)
                .disabled(guardando)
                .accessibilityLabel("Apuntar el día")

                if let aviso { Banda(aviso) }

                Text("Guardar otra vez el mismo día lo reemplaza.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private static let madrid = TimeZone(identifier: "Europe/Madrid") ?? .current

    private var maxTokens: Int { dias.prefix(30).map(\.tokens).max() ?? 1 }

    private func recuperar(_ d: Dia) {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")   
        f.timeZone = Self.madrid
        f.dateFormat = "yyyy-MM-dd HH:mm"
        
        let texto = d.hora.isEmpty ? "\(d.fecha) 12:00" : "\(d.recibido) \(d.hora)"
        if let fecha_ = f.date(from: texto) { fecha = min(fecha_, Date()) }
        reemplaza = d.fecha
        tokensHoy = String(d.tokens)
        horasHoy = d.horas > 0 ? String(d.horas) : ""
        aviso = nil
    }

    private func cargar() async {
        do {
            let j = try await API.pedir("api/manual/\(clave)?periodo=mes", testigo: sesion.testigo)
            nombre = j["nombre"] as? String ?? clave.capitalized
            let r = (j["resumen"] as? [String: Any]) ?? [:]
            euros = r["euros"] as? Double ?? 0
            tokens = r["tokens"] as? Int ?? 0
            enDinero = r["en_dinero"] as? Bool ?? false
            horas = r["horas"] as? Double ?? 0
            horasHeredadas = r["horas_de_plataforma1"] as? Int ?? 0
            dias = ((j["dias"] as? [[String: Any]]) ?? []).map {
                Dia(fecha: $0["fecha"] as? String ?? "",
                    tokens: $0["tokens"] as? Int ?? 0,
                    horas: $0["horas"] as? Double ?? 0,
                    recibido: $0["recibido"] as? String ?? "",
                    hora: $0["hora"] as? String ?? "")
            }
            estado = .listo(true)
        } catch {
            estado.fallar(error)
        }
    }

    private func guardar() async {
        bajarTeclado()          
        guardando = true
        aviso = nil
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")   
        f.timeZone = Self.madrid
        f.dateFormat = "yyyy-MM-dd"
        let h = DateFormatter()
        h.locale = Locale(identifier: "en_US_POSIX")   
        h.timeZone = Self.madrid
        h.dateFormat = "HH:mm"
        do {
            let j = try await API.pedir("api/manual/\(clave)/dia", metodo: "POST",
                                        cuerpo: ["fecha": f.string(from: fecha),
                                                 "hora": h.string(from: fecha),
                                                 "reemplaza": reemplaza ?? "",
                                                 "tokens": tokensHoy, "horas": horasHoy],
                                        testigo: sesion.testigo)
            let ok = j["ok"] as? Bool ?? false
            aviso = (j["mensaje"] as? String ?? "", ok)
            if ok {
                tokensHoy = ""; horasHoy = ""
                reemplaza = nil
                fecha = Date()
                await cargar()
            }
        } catch {
            aviso = (error.localizedDescription, false)
        }
        guardando = false
    }
}

private struct BarraDia: View {
    let fraccion: Double
    let color: Color
    let reemplazando: Bool
    
    var conFilo = false

    @Environment(\.accessibilityReduceMotion) private var menosMovimiento
    @Environment(\.colorScheme) private var modo
    @State private var llena = false

    var body: some View {
        ZStack(alignment: .leading) {
            Capsule().fill(conFilo ? Marcador.apoyo.opacity(0.16) : Color.primary.opacity(0.06))
            Capsule()
                .fill(color.gradient)
                .overlay {
                    if conFilo && modo == .light {
                        Capsule().strokeBorder(.black.opacity(0.6), lineWidth: 0.75)
                    }
                }
                .frame(width: 70 * CGFloat(llena ? max(0.04, min(1, fraccion)) : 0))
                .opacity(reemplazando ? 0.55 : 1)
        }
        .frame(width: 70, height: 8)
        .onAppear {
            if menosMovimiento { llena = true; return }
            withAnimation(.spring(duration: 0.7, bounce: 0.2).delay(0.1)) { llena = true }
        }
        .animation(Diseno.suave, value: fraccion)
        .accessibilityHidden(true)
    }
}
