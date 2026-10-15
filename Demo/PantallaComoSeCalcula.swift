import SwiftUI

struct PantallaComoSeCalcula: View {
    @Environment(Sesion.self) private var sesion
    @Environment(\.tema) private var tema
    let plataforma: String

    @State private var d: Cuentas?
    @State private var estado: Carga<Bool> = .cargando

    struct Cuentas: Equatable {
        let nombre: String
        let enDinero: Bool
        let usdPorToken: Double
        let eurPorUsd: Double
        let comisionPlataforma: Double
        let comisionMonedero: Double
        let costePorCobro: Double
        let ciclo: String
        
        let minimoCobro: Double
        
        let comisionRecibir: Double
        let comisionAdelanto: Double
        
        let metodo: String
        
        let porcentajeMercado: Double

        var conMonedero: Bool { metodo == "monedero" }
    }

    var body: some View {
        ScrollView {
            
            VStack(spacing: Diseno.hueco5) {
                switch estado {
                case .cargando:
                    Tarjeta { Vacio(icono: "function", titulo: "Cargando…") }
                        .redacted(reason: .placeholder)
                case .error(let qué):
                    Tarjeta { Vacio(icono: "wifi.exclamationmark",
                                    titulo: "No se ha podido cargar", detalle: qué) }
                default:
                    if let d { contenido(d) }
                }
            }
            .padding(.horizontal, Diseno.margen)
            .padding(.vertical, Diseno.hueco2)
        }
        
        .fondoDeCampo(.de(plataforma))
        .navigationTitle("Cómo se calcula")
        .navigationBarTitleDisplayMode(.inline)
        .task { await cargar() }
    }

    @ViewBuilder
    private func contenido(_ d: Cuentas) -> some View {
        if d.enDinero {
            Tarjeta {
                VStack(alignment: .leading, spacing: Diseno.hueco2) {
                    Text("\(d.nombre) paga en dinero").font(.headline)
                    Text("Lo que apuntas cada día son euros. No hay conversión de tokens ni "
                         + "comisión de transferencia: entra lo que pone.")
                        .font(.subheadline).foregroundStyle(.apoyo)
                }
            }
        } else {
            Tarjeta {
                VStack(alignment: .leading, spacing: Diseno.hueco3) {
                    Text("De token a euro").font(.headline)
                    paso("1", "Cada token", "\(Formato.ajuste(d.usdPorToken)) $",
                         "Lo que te paga \(d.nombre) por token.")
                    paso("2", "A euros", "× \(Formato.ajuste(d.eurPorUsd))", detalleCambio(d))
                }
            }

            Tarjeta {
                VStack(alignment: .leading, spacing: Diseno.hueco3) {
                    Text("Lo que cuesta cobrar").font(.headline)
                    if d.costePorCobro <= 0 {
                        
                        fila("Por cada transferencia", "0 $", destacado: true)
                    } else {
                        fila("Al enviarlo \(d.nombre)", "\(Formato.ajuste(d.comisionPlataforma)) $")
                        if d.comisionRecibir > 0 {
                            fila("Al recibirlo en Monedero", "\(Formato.ajuste(d.comisionRecibir)) $")
                        }
                        fila(d.conMonedero ? "De Monedero a tu banco" : "La transferencia",
                             "\(Formato.ajuste(d.comisionMonedero)) $")
                        Divider()
                        fila("Por cada transferencia", "\(Formato.ajuste(d.costePorCobro)) $",
                             destacado: true)
                        if d.comisionAdelanto > 0 && d.conMonedero {
                            fila("Si adelantas el cobro, además",
                                 "\(Formato.ajuste(d.comisionAdelanto)) $")
                        }

                        Text("**No se cobra por día ni por token: se cobra por transferencia.** Por eso cada día carga solo con la parte que le toca, y no con los \(Formato.ajuste(d.costePorCobro)) $ enteros.")
                            .font(.footnote).foregroundStyle(.apoyo)
                    }
                }
            }

            Tarjeta {
                VStack(alignment: .leading, spacing: Diseno.hueco3) {
                    Text("Cuándo te transfieren").font(.headline)
                    fila("Cada cuánto", Ciclos.nombre(d.ciclo))
                    if d.ciclo != "manual" {
                        fila("Mínimo", d.minimoCobro > 0 ? "\(Formato.ajuste(d.minimoCobro)) $"
                                                         : "Sin mínimo")
                    }
                    if d.minimoCobro > 0 {
                        Text("Si un periodo no llega a \(Formato.ajuste(d.minimoCobro)) $ no se "
                             + "transfiere, así que tampoco se descuenta comisión: ese dinero "
                             + "se junta con el del periodo siguiente.")
                            .font(.footnote).foregroundStyle(.apoyo)
                    } else if d.ciclo == "manual" {
                        Text("Al no haber transferencias periódicas, no se descuenta ninguna "
                             + "comisión automática.")
                            .font(.footnote).foregroundStyle(.apoyo)
                    }
                }
            }
        }

        Tarjeta {
            VStack(alignment: .leading, spacing: Diseno.hueco2) {
                Text("Tienda va aparte").font(.headline)

                Text("Lo de Tienda es lo que **facturas**, sin descontar nada. Lo de las plataformas de tokens ya viene limpio de comisiones. No son lo mismo y por eso no se comparan a ciegas.")
                    .font(.subheadline).foregroundStyle(.apoyo)
                Text("El IVA y el IRPF de cada trimestre, en Cuenta › Impuestos.")
                    .font(.footnote).foregroundStyle(AnyShapeStyle(.apoyo))
            }
        }
    }

    private func detalleCambio(_ d: Cuentas) -> String {
        let pct = d.porcentajeMercado > 0
            ? String(format: "%.1f", d.porcentajeMercado * 100).replacingOccurrences(of: ".", with: ",")
            : ""
        if d.conMonedero {
            return pct.isEmpty ? "El cambio de Monedero, que no es el del mercado."
                               : "El cambio de Monedero: el \(pct) % del BCE de cada día."
        }
        return pct.isEmpty || pct == "100,0" ? "Lo convierte tu banco al cambio del día."
                                             : "Al cambio del día: el \(pct) % del BCE."
    }

    private func paso(_ n: String, _ titulo: String, _ valor: String,
                      _ detalle: String) -> some View {
        HStack(alignment: .top, spacing: Diseno.hueco2) {
            Text(n)
                .font(.caption.weight(.bold))
                .foregroundStyle(tema.sobreRelleno)
                .frame(width: 22, height: 22)
                .background(tema.relleno, in: .circle)
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(titulo).font(.subheadline.weight(.medium))
                    Spacer()
                    Text(valor).font(.subheadline.weight(.semibold)).monospacedDigit()
                }
                Text(detalle).font(.caption).foregroundStyle(.apoyo)
            }
        }
    }

    private func fila(_ t: String, _ v: String, destacado: Bool = false) -> some View {
        HStack {

            Text(t).font(destacado ? .subheadline.weight(.semibold) : .subheadline)
                .foregroundStyle(destacado ? AnyShapeStyle(.primary) : AnyShapeStyle(.apoyo))
            Spacer()
            Text(v).font(destacado ? .subheadline.weight(.semibold) : .subheadline)
                .monospacedDigit()
        }
    }

    private func cargar() async {
        do {
            let j = try await API.pedir("api/como-se-calcula/\(plataforma)",
                                        testigo: sesion.testigo)
            d = Cuentas(nombre: j["nombre"] as? String ?? "",
                        enDinero: j["en_dinero"] as? Bool ?? false,
                        usdPorToken: (j["usd_por_token"] as? NSNumber)?.doubleValue ?? 0,
                        eurPorUsd: (j["eur_por_usd"] as? NSNumber)?.doubleValue ?? 0,
                        comisionPlataforma: (j["comision_plataforma"] as? NSNumber)?.doubleValue ?? 0,
                        comisionMonedero: (j["comision_monedero"] as? NSNumber)?.doubleValue ?? 0,
                        costePorCobro: (j["coste_por_cobro"] as? NSNumber)?.doubleValue ?? 0,
                        ciclo: j["ciclo"] as? String ?? "",
                        minimoCobro: (j["minimo_cobro"] as? NSNumber)?.doubleValue ?? 0,
                        comisionRecibir: (j["comision_recibir"] as? NSNumber)?.doubleValue ?? 0,
                        comisionAdelanto: (j["comision_adelanto"] as? NSNumber)?.doubleValue ?? 0,
                        metodo: j["metodo_pago"] as? String ?? "monedero",
                        porcentajeMercado: (j["porcentaje_mercado"] as? NSNumber)?.doubleValue ?? 0)
            estado = .listo(true)
        } catch {
            estado.fallar(error)
        }
    }
}
