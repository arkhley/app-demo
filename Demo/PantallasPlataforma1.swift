import SwiftUI

struct PantallaAjustesP1: View {
    @Environment(Sesion.self) private var sesion

    var abrirEditando = false
    
    var alGuardar: (() async -> Void)?

    @State private var campos: [String: String] = [:]
    @State private var guardando = false
    @State private var aviso: (texto: String, bien: Bool)?
    @State private var avisoHistorico: (texto: String, bien: Bool)?
    @State private var estado: Carga<Bool> = .cargando
    
    @State private var editando = false
    
    @State private var camposOriginales: [String: String] = [:]
    @State private var origCiclo = "quincena"
    @State private var origMinimo = ""
    @State private var ciclo = "quincena"
    @State private var minimoCobro = ""

    @State private var cambioMonedero = ""
    @State private var origCambioMonedero = ""
    
    @State private var cambioEstimado = true
    
    @State private var ultimoMonedero: (fecha: String, cambio: Double)?
    
    @State private var porApuntar: (fecha: String, dolares: Double)?
    
    @State private var yaAbierto = false

    private let orden: [(leer: String, guardar: String, etiqueta: String)] = [
        ("usd_por_token", "por_token", "Dólares por token"),
        ("comision_plataforma", "comision_plataforma", "Comisión de Plataforma 1 por cobro ($)"),
        ("comision_adelanto", "comision_adelanto", "Extra de Plataforma 1 por adelantar ($)"),
        ("comision_recibir", "comision_recibir", "Comisión de Monedero al recibir ($)"),
        ("comision_monedero", "comision_monedero", "Comisión de Monedero al banco ($)"),
        ("club_tokens", "club", "Club (tokens al mes)"),
        ("encargo_tokens_min", "encargo_min", "Encargo normal (tokens/min)"),
        ("encargo_premium_tokens_min", "encargo_premium_min", "Encargo premium (tokens/min)"),
        ("observa_tokens_min", "observa_min", "Observar (tokens/min)"),
    ]

    private var pieAdelanto: String {
        func n(_ k: String) -> Double? {
            Double((campos[k] ?? "").replacingOccurrences(of: ",", with: "."))
        }
        let cobro = n("comision_plataforma") ?? 0
        let extra = n("comision_adelanto") ?? 0
        func d(_ x: Double) -> String { String(format: "%.2f", x).replacingOccurrences(of: ".", with: ",") }
        return "Un adelanto cuesta en total \(d(cobro)) + \(d(extra)) = \(d(cobro + extra)) $."
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
                    if let aviso {
                        Label(aviso.texto,
                              systemImage: aviso.bien ? "checkmark.circle.fill"
                                                      : "exclamationmark.triangle")
                            .font(.subheadline)
                            .foregroundStyle(aviso.bien ? Diseno.verde : Diseno.rojo)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(Diseno.hueco2)
                            .background((aviso.bien ? Diseno.verde : Diseno.rojo).opacity(0.10),
                                        in: .rect(cornerRadius: Diseno.radioCampo))
                    }

                    Tarjeta {
                        VStack(alignment: .leading, spacing: Diseno.hueco3) {
                            VStack(alignment: .leading, spacing: 6) {
                                Campo(titulo: "Euros por dólar (Monedero)", valor: $cambioMonedero,
                                      teclado: .decimalPad, pista: "0,85",
                                      enfocarAlAbrir: abrirEditando)
                                    .disabled(!editando)
                                
                                Text(pieCambio)
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            ForEach(orden, id: \.leer) { ajuste in
                                Campo(titulo: ajuste.etiqueta,
                                      valor: Binding(get: { campos[ajuste.leer] ?? "" },
                                                     set: { campos[ajuste.leer] = $0 }),
                                      teclado: .decimalPad, pista: "0")
                                    .disabled(!editando)
                                if ajuste.leer == "comision_adelanto" {
                                    Text(pieAdelanto)
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }

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

                    Tarjeta {
                        VStack(alignment: .leading, spacing: Diseno.hueco3) {

                            Text("Historial de Plataforma 1").font(.headline)
                            ImportarPlataforma1 { await cargar() }

                            Campo(titulo: "Seguidores que ya tenías",
                                  valor: Binding(get: { campos["seguidores"] ?? "" },
                                                 set: { campos["seguidores"] = $0 }),
                                  teclado: .numberPad, pista: "0")
                                .disabled(!editando)
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

    private var botonTitulo: String {
        if guardando { return "Guardando…" }
        if !editando { return "Editar" }
        return hayCambios ? "Guardar" : "Cancelar"
    }

    private var hayCambios: Bool {
        campos != camposOriginales || ciclo != origCiclo
            || minimoCobro != origMinimo || cambioMonedero != origCambioMonedero
    }

    private var pieCambio: String {
        if let p = porApuntar {
            
            let dolares = Formato.euros(p.dolares).replacingOccurrences(of: "€", with: "$")
            return "Pon el de Monedero para los \(dolares) que te llegaron el \(Formato.diaCorto(p.fecha))"
        }
        if !cambioEstimado { return "El que te ha dado Monedero hoy" }
        guard let u = ultimoMonedero else {
            return "Estimado para hoy · aún no has puesto ninguno de Monedero"
        }
        let valor = String(format: "%.4f", u.cambio).replacingOccurrences(of: ".", with: ",")
        return "Estimado para hoy · el último de Monedero fue \(valor) el \(Formato.diaCorto(u.fecha))"
    }

    private func pulsarBoton() {
        if !editando {
            editando = true
            return
        }
        guard hayCambios else {
            editando = false
            return
        }
        Task {
            await guardar()
            await guardarHistorico()
            if (aviso?.bien ?? true) && (avisoHistorico?.bien ?? true) { editando = false }
        }
    }

    private func cargar() async {
        do {
            let j = try await API.pedir("api/plataforma1/ajustes", testigo: sesion.testigo)
            if let h = j["historico"] as? [String: Any] {

                let tk = h["tokens"] as? Int ?? 0
                campos["hist_tokens"] = tk > 0 ? String(tk) : ""
                campos["hist_desde"] = h["desde"] as? String ?? ""
                let e = h["euros"] as? Double ?? 0
                campos["hist_euros"] = e > 0 ? String(e) : ""
                let ho = h["horas"] as? Double ?? 0
                campos["hist_horas"] = ho > 0 ? String(ho) : ""
                let sg = h["seguidores"] as? Int ?? 0
                campos["seguidores"] = sg > 0 ? String(sg) : ""
            }
            let c = (j["config"] as? [String: Any]) ?? [:]
            if let p = j["cambio_por_apuntar"] as? [String: Any],
               let f = p["fecha"] as? String, let v = p["llega_usd"] as? Double {
                porApuntar = (f, v)
            } else {
                porApuntar = nil
            }
            for ajuste in orden {
                campos[ajuste.leer] = Formato.ajuste(c[ajuste.leer])
            }
            ciclo = c["ciclo"] as? String ?? "quincena"
            minimoCobro = Formato.ajuste(c["minimo_cobro"])
            cambioMonedero = Formato.ajuste(c["eur_por_usd"])
            cambioEstimado = c["cambio_estimado"] as? Bool ?? true
            if let u = c["cambio_monedero_ultimo"] as? [String: Any],
               let f = u["fecha"] as? String, let v = u["cambio"] as? Double {
                ultimoMonedero = (f, v)
            } else {
                ultimoMonedero = nil
            }
            camposOriginales = campos
            origCiclo = ciclo; origMinimo = minimoCobro; origCambioMonedero = cambioMonedero
            if abrirEditando && !yaAbierto { editando = true }
            yaAbierto = true
            estado = .listo(true)
        } catch {
            estado.fallar(error)
        }
    }

    private func guardarHistorico() async {
        bajarTeclado()
        guardando = true
        do {
            let j = try await API.pedir("api/historico/plataforma1", metodo: "POST",
                                        cuerpo: ["tokens": campos["hist_tokens"] ?? "",
                                                 "euros": campos["hist_euros"] ?? "",
                                                 "desde": campos["hist_desde"] ?? "",
                                                 "horas": campos["hist_horas"] ?? ""],
                                        testigo: sesion.testigo)
            let ok = j["ok"] as? Bool ?? false
            avisoHistorico = (j["mensaje"] as? String ?? "Guardado.", ok)
            
            if ok { await cargar() }
        } catch {
            avisoHistorico = (error.localizedDescription, false)
        }
        guardando = false
    }

    private func guardar() async {
        bajarTeclado()
        guardando = true
        aviso = nil

        var cuerpo: [String: any Sendable] = ["ciclo": ciclo,
                                              "minimo": minimoCobro,
                                              "seguidores": campos["seguidores"] ?? ""]
        for ajuste in orden {
            cuerpo[ajuste.guardar] = campos[ajuste.leer] ?? ""
        }
        
        if cambioMonedero != origCambioMonedero && !cambioMonedero.isEmpty {
            cuerpo["cambio_monedero"] = cambioMonedero
        }
        do {
            let j = try await API.pedir("api/plataforma1/ajustes", metodo: "POST",
                                        cuerpo: cuerpo, testigo: sesion.testigo)
            let ok = j["ok"] as? Bool ?? false
            aviso = (j["mensaje"] as? String ?? "Guardado.", ok)
            
            if ok {
                await cargar()
                await alGuardar?()
            }
        } catch {
            aviso = (error.localizedDescription, false)
        }
        guardando = false
    }
}
