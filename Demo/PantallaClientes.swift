import SwiftUI

struct PantallaClientes: View {
    @Environment(Sesion.self) private var sesion

    @State private var lista: [Cliente] = []
    @State private var estado: Carga<Bool> = .cargando

    struct Cliente: Identifiable, Equatable {
        let id: String
        let usuario: String
        let desde: String
        let ultima: String
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Diseno.hueco3) {
                switch estado {
                case .cargando:
                    Tarjeta { Vacio(icono: "person.2", titulo: "Cargando…") }
                        .redacted(reason: .placeholder)
                case .error(let qué):
                    Tarjeta { Vacio(icono: "wifi.exclamationmark",
                                    titulo: "No se ha podido cargar", detalle: qué) }
                case .vacio:
                    Tarjeta { Vacio(icono: "person.2.slash", titulo: "Nadie todavía",
                                    detalle: "Aquí aparece quien abra el bot.") }
                default:
                    Tarjeta(relleno: 0) {
                        VStack(spacing: 0) {
                            ForEach(Array(lista.enumerated()), id: \.element.id) { i, c in
                                if i > 0 { Divider().padding(.leading, Diseno.hueco3) }
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(c.usuario).fontWeight(.medium)
                                        Text(detalle(c))
                                            .font(.footnote).foregroundStyle(.apoyo)
                                    }
                                    Spacer()
                                }
                                .padding(Diseno.hueco3)
                            }
                        }

                        .padding(.horizontal, -Diseno.hueco3)
                    }
                    Text("Solo quien haya abierto el bot desde que la app lo apunta.")
                        .font(.caption).foregroundStyle(.apoyo)
                        .padding(.horizontal, 0)
                }
            }
            .padding(.horizontal, Diseno.margen)
            .padding(.vertical, Diseno.hueco2)
        }
        
        .fondoDeCampo(.tienda)
        .navigationTitle("Clientes")
        .task { await cargar() }
        .refreshable { await cargar() }
    }

    private func detalle(_ c: Cliente) -> String {

        func dia(_ iso: String) -> String { Formato.diaCorto(iso) }
        if c.desde == c.ultima || c.ultima.isEmpty { return "Llegó el \(dia(c.desde))" }
        return "Llegó el \(dia(c.desde)) · volvió el \(dia(c.ultima))"
    }

    private func cargar() async {
        do {
            let j = try await API.pedir("api/usuarios", testigo: sesion.testigo)

            lista = ((j["usuarios"] as? [[String: Any]]) ?? []).map {
                Cliente(id: $0["id"] as? String ?? UUID().uuidString,
                        usuario: $0["usuario"] as? String ?? "sin nombre",
                        desde: $0["desde"] as? String ?? "",
                        ultima: $0["ultima"] as? String ?? "")
            }
            estado = lista.isEmpty ? .vacio : .listo(true)
        } catch {
            estado.fallar(error)
        }
    }
}
