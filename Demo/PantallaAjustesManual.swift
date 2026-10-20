import SwiftUI

struct PantallaAjustesManual: View {
    @Environment(Sesion.self) private var sesion
    let clave: String

    @State private var nombre = ""
    @State private var campos: [String: String] = [:]
    @State private var histTokens = ""
    @State private var histEuros = ""
    @State private var histDesde = ""
    @State private var histHoras = ""
    @State private var guardando = false
    @State private var aviso: (texto: String, bien: Bool)?
    @State private var avisoHistorico: (texto: String, bien: Bool)?
    @State private var estado: Carga<Bool> = .cargando
    
    @State private var editando = false
    
    @State private var enDinero = false
    
    @State private var camposOriginales: [String: String] = [:]
    @State private var origHist = ("", "", "", "")
    @State private var origCiclo = "quincena"
    @State private var origMinimo = ""
    @State private var origInmediato = false
    @State private var ciclo = "quincena"
    @State private var metodo = "monedero"
    @State private var metodos: [MetodoPago] = []
    @State private var cambioMercado: Double = 0

    struct MetodoPago: Identifiable, Equatable {
        let clave: String
        let nombre: String
        let enVivo: Bool
        var id: String { clave }
    }
    @State private var minimoCobro = ""
    @State private var inmediato = false

    private var orden: [(leer: String, guardar: String, etiqueta: String)] {
        [("usd_por_token", "por_token", "Dólares por token"),
         ("eur_por_usd", "cambio", "Euros por dólar (\(quienCambia))"),
         ("comision_plataforma", "comision_plataforma", "Comisión de \(nombre) ($)"),
         ("comision_monedero", "comision_monedero", "Comisión de \(quienTransfiere) ($)")]
    }

    private var quienTransfiere: String {
        switch metodo {
        case "sepa":    return "la transferencia"
        case "tarjeta": return "la tarjeta"
        default:        return "Monedero"
        }
    }

    private var quienCambia: String {
        metodo == "monedero" ? "Monedero" : "el banco"
    }

    private var cambioEnVivo: Bool {
        metodos.first(where: { $0.clave == metodo })?.enVivo ?? false
    }

    private var sinComisiones: Bool { metodo == "sepa" || metodo == "tarjeta" }

    private var nombreMetodo: String {
        switch metodo {
        case "sepa":    return "la transferencia SEPA"
        case "tarjeta": return "la tarjeta bancaria"
        default:        return "Monedero"
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Diseno.hueco3) {
                switch estado {
                case .cargando:
                    Tarjeta { Vacio(icono: "slider.horizontal.3", titulo: "Cargando…") }
                        .redacted(reason: .placeholder)
                case .error(let qué):
                    Tarjeta { Vacio(icono: "wifi.exclamationmark",
                                    titulo: "No se ha podido cargar", detalle: qué) }
                default:

                    Tarjeta {
                        VStack(alignment: .leading, spacing: Diseno.hueco3) {
                            Text("Dinero").font(.headline)

                            Toggle("Se apunta en euros", isOn: Binding(
                                get: { enDinero },
                                set: { nuevo in
                                    enDinero = nuevo
                                    Task { await guardarUnidad(nuevo) }
                                }))
                            if enDinero {
                                Text("Lo que apuntes cada día son euros. Sin conversión de "
                                     + "tokens y sin comisión de transferencia.")
                                    .font(.caption).foregroundStyle(.secondary)
                            } else {

                                ForEach(orden.filter { $0.leer != "eur_por_usd" || !cambioEnVivo },
                                        id: \.leer) { ajuste in
                                    Campo(titulo: ajuste.etiqueta,
                                          valor: Binding(get: { campos[ajuste.leer] ?? "" },
                                                         set: { campos[ajuste.leer] = $0 }),
                                          teclado: .decimalPad,

                                          pista: ajuste.leer.hasPrefix("comision") ? "0" : "")
                                        .disabled(!editando)
                                }
                                if sinComisiones {

                                    Text("Con \(nombreMetodo) no te cobran por transferir: "
                                         + "esos dos van a cero.")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                            }
                            if let aviso { Banda(aviso) }
                        }
                    }

                    if !enDinero, !metodos.isEmpty {
                        Tarjeta {
                            VStack(alignment: .leading, spacing: Diseno.hueco3) {
                                Text("Cómo te pagan").font(.headline)

                                Picker("Método", selection: Binding(
                                    get: { metodo },
                                    set: { nuevo in
                                        metodo = nuevo
                                        Task { await guardarMetodo(nuevo) }
                                    })) {

                                    ForEach(metodos) { m in
                                        Text(m.nombre
                                                .replacingOccurrences(of: "Transferencia ", with: "")
                                                .replacingOccurrences(of: " bancaria", with: ""))
                                            .tag(m.clave)
                                    }
                                }
                                .pickerStyle(.segmented)
                                .disabled(!editando)

                                if let m = metodos.first(where: { $0.clave == metodo }),
                                   m.enVivo {
                                    if cambioMercado > 0 {
                                        Label("Hoy: 1 $ = \(Formato.euros(cambioMercado)). Se "
                                              + "actualiza solo.",
                                              systemImage: "arrow.triangle.2.circlepath")
                                            .font(.caption).foregroundStyle(.secondary)
                                    } else {
                                        Label("Todavía no se ha podido consultar el cambio de "
                                              + "hoy; se usa el último que hubiera.",
                                              systemImage: "exclamationmark.triangle")
                                            .font(.caption).foregroundStyle(Diseno.naranja)
                                    }
                                }
                            }
                        }
                    }

                    if !enDinero {
                    Tarjeta {
                        VStack(alignment: .leading, spacing: Diseno.hueco3) {
                            Text("Cuándo te pagan").font(.headline)
                            Picker("Cada cuánto", selection: $ciclo) {
                                ForEach(Ciclos.todos, id: \.clave) { c in
                                    Text(c.nombre).tag(c.clave)
                                }
                            }
                            .pickerStyle(.menu)
                            .disabled(!editando)

                            if ciclo != "manual" {

                                Campo(titulo: "Mínimo para que te transfieran ($)",
                                      valor: $minimoCobro, teclado: .decimalPad, pista: "0")
                                    .disabled(!editando)

                                Text("Si no se llega, no hay transferencia y no se descuenta "
                                     + "ninguna comisión: se junta con el periodo siguiente.")
                                    .font(.caption).foregroundStyle(.secondary)
                            }

                        }
                    }
                    }

                    if !enDinero {
                        Tarjeta {
                            VStack(alignment: .leading, spacing: Diseno.hueco3) {
                                Text("Importar tus ganancias").font(.headline)
                                ImportarPlataforma1(clave: clave) { await cargar() }
                            }
                        }
                    }

                    Tarjeta {
                        VStack(alignment: .leading, spacing: Diseno.hueco3) {
                            Text("Antes de empezar a apuntar").font(.headline)
                            
                            if !enDinero {
                                Campo(titulo: "Tokens", valor: $histTokens, teclado: .decimalPad)
                                    .disabled(!editando)
                            }
                            Campo(titulo: enDinero ? "Euros" : "Euros (si los sabes)",
                                  valor: $histEuros, teclado: .decimalPad)
                                .disabled(!editando)
                            Campo(titulo: "Desde", valor: $histDesde, pista: "AAAA-MM-DD")
                                    .disabled(!editando)
                            
                            if !enDinero {
                                Campo(titulo: "Horas emitidas", valor: $histHoras,
                                      teclado: .decimalPad)
                                    .disabled(!editando)
                            }
                            
                            Text("Solo suma en el periodo «Todo».")
                                .font(.caption).foregroundStyle(.secondary)
                            if let avisoHistorico { Banda(avisoHistorico) }
                        }
                    }
                }
            }
            .padding(.horizontal, Diseno.margen)
            .padding(.vertical, Diseno.hueco2)
        }
        .fondoDePantalla()
        .navigationTitle("Ajustes")

        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                
                BotonEditar(editando: $editando, hayCambios: hayCambios,
                            trabajando: guardando) { pulsarBoton() }
            }
        }
        .salidaDelTeclado()
        .animation(Diseno.suave, value: aviso?.texto)
        .animation(Diseno.suave, value: avisoHistorico?.texto)
        .task { await cargar() }
    }

    private func guardarMetodo(_ nuevo: String) async {
        do {
            let j = try await API.pedir("api/metodo-pago/\(clave)", metodo: "POST",
                                        cuerpo: ["metodo": nuevo], testigo: sesion.testigo)
            aviso = (j["mensaje"] as? String ?? "Guardado.", j["ok"] as? Bool ?? false)
            await cargar()
        } catch {
            aviso = (error.localizedDescription, false)
        }
    }

    private func cargar() async {
        do {
            let j = try await API.pedir("api/manual/\(clave)", testigo: sesion.testigo)
            nombre = j["nombre"] as? String ?? clave.capitalized
            enDinero = j["en_dinero"] as? Bool ?? false
            let c = (j["config"] as? [String: Any]) ?? [:]
            ciclo = c["ciclo"] as? String ?? "quincena"
            metodo = c["metodo_pago"] as? String ?? "monedero"
            metodos = ((j["metodos_pago"] as? [[String: Any]]) ?? []).map {
                MetodoPago(clave: $0["clave"] as? String ?? "",
                           nombre: $0["nombre"] as? String ?? "",
                           enVivo: $0["cambio_en_vivo"] as? Bool ?? false)
            }
            cambioMercado = j["cambio_mercado"] as? Double ?? 0
            minimoCobro = Formato.ajuste(c["minimo_cobro"])
            inmediato = c["cobro_inmediato"] as? Bool ?? false
            for ajuste in orden {
                campos[ajuste.leer] = Formato.ajuste(c[ajuste.leer])
            }

            camposOriginales = campos
            origCiclo = ciclo; origMinimo = minimoCobro; origInmediato = inmediato
            leerHistorico(j["historico"] as? [String: Any])
            estado = .listo(true)
        } catch {
            estado.fallar(error)
        }
    }

    private func leerHistorico(_ h: [String: Any]?) {
        guard let h else { return }
        let tk = h["tokens"] as? Int ?? 0
        histTokens = tk > 0 ? String(tk) : ""
        histDesde = h["desde"] as? String ?? ""
        let e = h["euros"] as? Double ?? 0
        histEuros = e > 0 ? String(e) : ""
        let ho = h["horas"] as? Double ?? 0
        histHoras = ho > 0 ? String(ho) : ""
        origHist = (histTokens, histEuros, histDesde, histHoras)
    }

    private var botonTitulo: String {
        if guardando { return "Guardando…" }
        if !editando { return "Editar" }
        return hayCambios ? "Guardar" : "Cancelar"
    }

    private var hayCambios: Bool {
        campos != camposOriginales
            || histTokens != origHist.0 || histEuros != origHist.1
            || histDesde != origHist.2 || histHoras != origHist.3
            || ciclo != origCiclo || minimoCobro != origMinimo || inmediato != origInmediato
    }

    private func pulsarBoton() {
        if !editando {
            editando = true
            return
        }
        if hayCambios {
            Task { await guardarTodo() }
        } else {
            editando = false        
        }
    }

    private func guardarUnidad(_ dinero: Bool) async {
        do {
            let j = try await API.pedir("api/plataformas", metodo: "POST",
                                        cuerpo: ["accion": "en_dinero", "clave": clave,
                                                 "en_dinero": dinero],
                                        testigo: sesion.testigo)
            aviso = (j["mensaje"] as? String ?? "Guardado.", j["ok"] as? Bool ?? true)
            await cargar()
        } catch {
            aviso = (error.localizedDescription, false)
            enDinero = !dinero      
        }
    }

    private func guardarTodo() async {
        await guardarAjustes()
        await guardarHistorico()

        if (aviso?.bien ?? true) && (avisoHistorico?.bien ?? true) {
            editando = false
        }
    }

    private func guardarAjustes() async {
        bajarTeclado()
        guardando = true
        aviso = nil
        do {
            var cuerpo: [String: any Sendable] = ["ciclo": ciclo,
                                                  "minimo": minimoCobro,
                                                  "inmediato": inmediato]
            for ajuste in orden {
                cuerpo[ajuste.guardar] = campos[ajuste.leer] ?? ""
            }
            let j = try await API.pedir("api/manual/\(clave)/ajustes", metodo: "POST",
                                        cuerpo: cuerpo, testigo: sesion.testigo)
            let ok = j["ok"] as? Bool ?? false
            aviso = (j["mensaje"] as? String ?? "Guardado.", ok)

            if ok { await cargar() }
        } catch {
            aviso = (error.localizedDescription, false)
        }
        guardando = false
    }

    private func guardarHistorico() async {
        bajarTeclado()
        guardando = true
        avisoHistorico = nil
        do {
            let j = try await API.pedir("api/historico/\(clave)", metodo: "POST",
                                        cuerpo: ["tokens": histTokens, "euros": histEuros,
                                                 "desde": histDesde, "horas": histHoras],
                                        testigo: sesion.testigo)
            let ok = j["ok"] as? Bool ?? false
            avisoHistorico = (j["mensaje"] as? String ?? "Guardado.", ok)

            if ok { await cargar() }
        } catch {
            avisoHistorico = (error.localizedDescription, false)
        }
        guardando = false
    }
}
