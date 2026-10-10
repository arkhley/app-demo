import SwiftUI

struct PantallaAjustesTienda: View {
    @Environment(Sesion.self) private var sesion

    @State private var activo = true
    @State private var confirmados = 0
    @State private var estado: Carga<Bool> = .cargando
    @State private var cargado = false
    @State private var aviso: (texto: String, bien: Bool)?
    @State private var suscriptores: Int?

    @State private var activoLeido: Bool?

    var body: some View {
        ScrollView {
            VStack(spacing: Diseno.hueco3) {
                if let aviso { Banda(aviso) }

                switch estado {
                case .cargando:
                    Tarjeta { Vacio(icono: "paperplane", titulo: "Cargando…") }
                        .redacted(reason: .placeholder)
                case .error(let qué):
                    Tarjeta { Vacio(icono: "wifi.exclamationmark",
                                    titulo: "No se ha podido cargar", detalle: qué) }
                default:
                    Tarjeta {
                        VStack(alignment: .leading, spacing: Diseno.hueco2) {
                            Toggle("Comprobar los pagos en tokens", isOn: $activo)

                            Text("Confirma el cobro cuando llega la propina por Plataforma 1. "
                                 + "Aprobar el pedido sigue siendo cosa tuya.")
                                .font(.footnote).foregroundStyle(.secondary)
                            if confirmados > 0 {
                                Divider()
                                HStack {
                                    Text("Cobros confirmados solos")
                                        .font(.subheadline).foregroundStyle(.secondary)
                                    Spacer()
                                    Text("\(confirmados)").font(.subheadline)
                                }
                            }
                        }
                    }

                    Grupo {
                        NavigationLink { PantallaCanal() } label: {
                            HStack(spacing: Diseno.hueco2) {
                                FichaIcono(simbolo: "megaphone.fill", color: .orange)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text("Canal").foregroundStyle(.primary)
                                    Text(suscriptores.map { "\(Formato.numero($0)) suscriptores" }
                                         ?? "Avisos de directo y bienvenida")
                                        .font(.footnote).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(Diseno.hueco3)
                            .contentShape(.rect)
                        }
                        .buttonStyle(.plain)
                    }

                    Text("Los vídeos se suben desde el bot de Tienda.")
                        .font(.footnote).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, Diseno.hueco3)
                        .padding(.top, -Diseno.hueco1)
                }
            }
            .padding(.horizontal, Diseno.margen)
            .padding(.vertical, Diseno.hueco2)
        }
        .fondoDePantalla()
        .navigationTitle("Tienda")
        .navigationBarTitleDisplayMode(.inline)

        .onChange(of: activo) { _, nuevo in
            guard cargado, nuevo != activoLeido else { return }
            Task { await guardar(nuevo) }
        }
        .task { await cargar() }
    }

    private func cargar() async {
        do {
            let j = try await API.pedir("api/inicio?plataforma=tienda&periodo=mes",
                                        testigo: sesion.testigo)
            let t = (j["tienda"] as? [String: Any]) ?? [:]
            let c = (t["cobros_auto"] as? [String: Any]) ?? [:]
            activo = c["activo"] as? Bool ?? true
            activoLeido = activo
            confirmados = c["confirmados"] as? Int ?? 0
            estado = .listo(true)
            cargado = true
            if let c = try? await API.pedir("api/canal", testigo: sesion.testigo) {
                suscriptores = c["suscriptores"] as? Int
            }
        } catch {
            estado.fallar(error)
        }
    }

    private func guardar(_ nuevo: Bool) async {
        do {
            _ = try await API.pedir("api/canal/accion", metodo: "POST",
                                    cuerpo: ["accion": "cobros_auto", "activo": nuevo],
                                    testigo: sesion.testigo)
            activoLeido = nuevo
            aviso = (nuevo ? "Comprobación encendida." : "Comprobación apagada.", true)
        } catch {
            aviso = (error.localizedDescription, false)
            activo = !nuevo        
        }
    }
}
