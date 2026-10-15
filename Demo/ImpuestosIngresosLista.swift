import SwiftUI

struct PantallaIngresosImpuestos: View {
    
    @Binding var datos: DatosImpuestos?
    let marcar: (DatosImpuestos.Cobro) -> Void
    let recargar: () async -> Void

    @State private var plataforma = "todo"
    @State private var abierto: DatosImpuestos.Cobro?

    private static let filtros = [(clave: "todo", nombre: "Todo"),
                                  (clave: "plataforma1", nombre: "Plataforma 1"),
                                  (clave: "plataforma2", nombre: "Plataforma 2"),
                                  (clave: "tienda", nombre: "Pasarela")]

    private func filtros(_ d: DatosImpuestos) -> [(clave: String, nombre: String)] {
        let hay = Self.filtros.dropFirst().filter { f in !filtrar(d, f.clave).isEmpty }
        return hay.count > 1 ? [Self.filtros[0]] + hay : []
    }

    private func filtrar(_ d: DatosImpuestos, _ clave: String) -> [DatosImpuestos.Cobro] {
        switch clave {
        case "todo": return d.cobros
        case "tienda":
            return d.cobros.filter { !["plataforma1", "plataforma2"].contains($0.plataforma) }
        default: return d.cobros.filter { $0.plataforma == clave }
        }
    }

    var body: some View {
        ScrollView {
            if let d = datos { contenido(d) }
        }
        .refreshable { await recargar() }
        .scrollEdgeEffectStyle(.soft, for: .top)
        .background { CampoJoya(joya: .impuestos) }
        .navigationTitle("Ingresos")
        .navigationSubtitle(datos.map { DatosImpuestos.nombre($0.trimestre, conAño: true) } ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $abierto) { c in
            HojaIngreso(cobro: c, contactos: datos?.contactos ?? []) { await recargar() }
        }
    }

    private func contenido(_ d: DatosImpuestos) -> some View {
        let presentado = d.estado == "presentado" || d.presentadoTotal != nil
        let opciones = filtros(d)
        return VStack(alignment: .leading, spacing: 0) {
            if !opciones.isEmpty {
                SelectorDeslizante(opciones: opciones, elegida: $plataforma)
                    .accessibilityLabel("Plataforma")
                    .padding(.top, Diseno.hueco2)
            }
            let lista = filtrar(d, plataforma)
            if lista.isEmpty {
                Text("Nada en el \(DatosImpuestos.nombre(d.trimestre))")
                    .font(.subheadline)
                    .foregroundStyle(Marcador.apoyo)
                    .padding(.vertical, Diseno.hueco3)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(lista.enumerated()), id: \.element.id) { i, c in
                        if i > 0 { Divider().padding(.leading, 22) }
                        Button { abierto = c } label: {
                            FilaIngresoSello(cobro: c, historia: presentado)
                        }
                        .buttonStyle(Hundirse())
                        .contextMenu {
                            
                            if d.hayApartar, c.llegado, let x = c.apartar, x > 0.004 {
                                Button(c.apartado ? "Desmarcar apartado" : "Marcar como apartado",
                                       systemImage: c.apartado ? "arrow.uturn.backward" : "checkmark") {
                                    marcar(c)
                                }
                            }
                        }
                    }
                }
                .padding(.top, Diseno.hueco1)
                .animation(Diseno.suave, value: plataforma)
            }
        }
        .padding(.horizontal, Diseno.margen)
        .padding(.bottom, Diseno.hueco3)
    }
}

struct FilaIngresoSello: View {
    let cobro: DatosImpuestos.Cobro
    
    var historia = false
    @Environment(\.colorScheme) private var modo

    private var mirar: Color { historia ? Marcador.apoyo : Diseno.naranjaRelleno }

    private var nombre: String {
        
        ["plataforma1", "plataforma2"].contains(cobro.plataforma)
            ? Diseno.nombreDePlataforma(cobro.plataforma)
            : (cobro.clienteNombre.isEmpty ? "Pasarela" : cobro.clienteNombre)
    }

    var body: some View {
        HStack(alignment: .top, spacing: Diseno.hueco2) {
            punto
                .frame(width: 10)
                .padding(.top, 6)
            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline) {
                    Text(nombre).font(.headline).foregroundStyle(Color.primary)
                    Spacer(minLength: Diseno.hueco1)
                    Text((cobro.estimado && !cobro.llegado ? "≈ " : "") + Formato.euros(cobro.euros))
                        .font(.system(.headline, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(Color.primary)
                }
                Text("\(Formato.diaCorto(cobro.fecha)) · \(cobro.etiqueta)"
                     + (cobro.llegado ? "" : " · por llegar"))
                    .font(.footnote)
                    .foregroundStyle(Marcador.apoyo)
                    .lineLimit(1)
                if cobro.llegado { factura }
            }
        }
        .padding(.vertical, Diseno.hueco2)
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Abre el ingreso")
    }

    @ViewBuilder
    private var punto: some View {
        let color = Diseno.colorDePlataforma(cobro.plataforma)
        if cobro.llegado {
            PuntoDeArea(color: color)
        } else {
            Circle().strokeBorder(color, lineWidth: 2)
                .overlay {
                    if modo == .light {
                        Circle().strokeBorder(.black.opacity(0.6), lineWidth: 0.75)
                    }
                }
                .frame(width: 10, height: 10)
                .accessibilityHidden(true)
        }
    }

    @ViewBuilder
    private var factura: some View {
        if !cobro.facturaNumero.isEmpty {
            Label {
                Text(cobro.facturaNumero + (cobro.facturaPorCambiar ? " · cambio de otro día" : ""))
                    .foregroundStyle(Color.primary)
            } icon: {
                Image(systemName: "doc.text.fill")
                    .foregroundStyle(cobro.facturaPorCambiar ? mirar : Diseno.verdeRelleno)
            }
            .font(.caption.weight(.medium))
        } else {
            Label {
                Text("Sin factura · \(Formato.euros(cobro.paraFactura))")
                    .foregroundStyle(Color.primary)
                    .monospacedDigit()
            } icon: {
                Image(systemName: "doc.badge.plus").foregroundStyle(mirar)
            }
            .font(.caption.weight(.medium))
        }
    }
}

