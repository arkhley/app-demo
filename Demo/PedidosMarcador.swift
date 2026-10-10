import SwiftUI

struct PedidosMarcador: View {
    @Environment(Sesion.self) private var sesion
    @Environment(\.accessibilityReduceMotion) private var menosMovimiento

    @State private var lista: [PantallaPedidos.Pedido] = []
    @State private var extras: [String: Extra] = [:]
    @State private var cuenta: [String: Int] = [:]
    @State private var nombres: [String: String] = [:]
    @State private var filtro = ""
    @State private var busca = ""
    @State private var estado: Carga<Bool> = .cargando
    @State private var aviso: (texto: String, bien: Bool)?
    @State private var haciendo: String?
    @State private var abierto: String?

    @State private var aMano = 0

    struct Extra: Equatable {
        let que: String
        let metodo: String
        let faltaPrecio: Bool
        let euros: Double?
    }

    private static let cerrados: Set<String> = ["paid", "rejected", "idle_expired", "cancelled"]

    private var porHacer: [PantallaPedidos.Pedido] {
        lista.filter { $0.estado == "review" || $0.estado == "awaiting_payment_confirm" }
    }

    private var resto: [PantallaPedidos.Pedido] {
        (filtro.isEmpty && busca.isEmpty) ? lista.filter { !porHacer.contains($0) } : lista
    }

    private var cuentaConAMano: [String: Int] {
        var c = cuenta
        if aMano > 0 { c["paid", default: 0] += aMano }
        return c
    }

    private var enMarcha: Int {
        cuenta.filter { !Self.cerrados.contains($0.key) }.values.reduce(0, +)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                switch estado {
                case .cargando:
                    Vacio(icono: "tray", titulo: "Cargando…")
                        .redacted(reason: .placeholder)
                        .padding(.top, Diseno.hueco5)
                case .error(let qué):
                    Vacio(icono: "wifi.exclamationmark", titulo: "No se ha podido cargar", detalle: qué)
                        .padding(.top, Diseno.hueco5)
                default:
                    lineaDeApoyo
                        .padding(.horizontal, Diseno.margen)
                    if let aviso {
                        Banda(aviso)
                            .padding(.horizontal, Diseno.margen)
                            .padding(.top, Diseno.hueco2)
                    }
                    if filtro.isEmpty && busca.isEmpty { teToca }
                    if !cuenta.isEmpty {
                        filtros
                            .padding(.top, Diseno.hueco4)
                    }
                    porDias
                }
            }
            .padding(.bottom, Diseno.hueco5)
        }
        .scrollEdgeEffectStyle(.soft, for: .top)
        .background { CampoJoya(joya: .tienda) }
        .navigationTitle("Pedidos")
        .searchable(text: $busca, prompt: "Buscar por cliente o número")
        .onChange(of: busca) { _, _ in Task { await cargar() } }
        .animation(menosMovimiento ? nil : .spring(duration: 0.45, bounce: 0.2), value: lista)
        .animation(Diseno.suave, value: aviso?.texto)
        .navigationDestination(item: $abierto) { id in
            PantallaPedido(id: id)
                .onDisappear { Task { await cargar() } }
        }
        .task { await cargar() }
        .refreshable { await cargar() }
        #if MAQUETA
        .defaultScrollAnchor(Maqueta.anclaSala)
        .onChange(of: lista) { _, nueva in
            if Maqueta.abrirPedido, abierto == nil,
               let p = nueva.first(where: { !$0.aMano && $0.estado != "review" }) ?? nueva.first {
                abierto = p.id
            }
        }
        #endif
    }

    private var lineaDeApoyo: some View {
        HStack(spacing: 6) {
            if enMarcha == 0 {
                Text("Ninguno en marcha")
            } else {
                Text("\(enMarcha) en marcha").monospacedDigit()
                    .contentTransition(.numericText(value: Double(enMarcha)))
            }
            if !porHacer.isEmpty {
                Text("·")
                
                Circle().fill(Diseno.naranjaRelleno).frame(width: 8, height: 8)
                Text(porHacer.count == 1 ? "1 te toca" : "\(porHacer.count) te tocan")
            }
        }
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(Marcador.apoyo)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var teToca: some View {
        if porHacer.isEmpty {
            
            if enMarcha > 0 {
                PastillaDeCristal(texto: "Nada pendiente", icono: "checkmark.seal.fill", tinte: .green)
                    .padding(.horizontal, Diseno.margen)
                    .padding(.top, Diseno.hueco2)
            }
        } else {
            VStack(spacing: Diseno.hueco2) {
                ForEach(porHacer) { p in
                    let t = tarea(p)
                    LosaDeTarea(t: t, hoy: "", trabajando: haciendo == p.id,
                                marcar: {}, descartar: {},
                                abrir: { abierto = p.id },
                                deslizar: { await hacer(p) })
                        .transition(.asymmetric(insertion: .opacity,
                                                removal: .scale(scale: 0.94).combined(with: .opacity)))
                }
            }
            .padding(.horizontal, Diseno.margen)
            .padding(.top, Diseno.hueco2)
        }
    }

    private func tarea(_ p: PantallaPedidos.Pedido) -> Tarea {
        let x = extras[p.id]
        let revisar = p.estado == "review"
        let falta = x?.faltaPrecio ?? false
        let pedido: [String: Any] = ["id": p.id, "quien": p.cliente, "importe": p.importe,
                                     "que": x?.que ?? "", "metodo": x?.metodo ?? "",
                                     "falta_precio": falta, "creado": p.creado]
        let accion: [String: Any] = revisar && falta
            ? ["tipo": "abrir", "texto": "Ponle precio", "destino": "pedido"]
            : ["tipo": "deslizar", "texto": revisar ? "Desliza para aprobar" : "Desliza: cobrado",
               "pedido": revisar ? "aprobar" : "pagado"]
        let otra: [String: Any] = ["tipo": "abrir", "texto": "Abrir", "destino": "pedido"]
        var j: [String: Any] = ["id": "pedido:\(p.id)",
                                "tipo": revisar ? "pedido_revisar" : "pedido_cobro",
                                "area": "tienda", "plataforma": "tienda", "titulo": "",
                                "pedido": pedido, "accion": accion, "otra": otra]
        if let e = x?.euros { j["euros"] = e }
        return Tarea(j)
    }

    private var filtros: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            GlassEffectContainer(spacing: 8) {
                HStack(spacing: 8) {
                    chip(clave: "", nombre: "Todos", n: cuentaConAMano.values.reduce(0, +),
                         color: .gray)
                    ForEach(PantallaPedidos.ordenEstados.filter { cuentaConAMano[$0] != nil },
                            id: \.self) { e in
                        chip(clave: e, nombre: nombres[e] ?? (e == "paid" ? "Pagado" : e),
                             n: cuentaConAMano[e] ?? 0, color: PantallaPedidos.color(e))
                    }
                }
                .padding(.horizontal, Diseno.margen)
                .padding(.vertical, 2)
            }
        }
        .scrollClipDisabled()
        .modifier(BordeQueSigue())
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        .sensoryFeedback(.selection, trigger: filtro)
    }

    private func chip(clave: String, nombre: String, n: Int, color: Color) -> some View {
        let esta = filtro == clave
        return Button {
            guard filtro != clave else { return }
            filtro = clave
            Task { await cargar() }
        } label: {
            HStack(spacing: 7) {
                if !clave.isEmpty {
                    PuntoDeArea(color: color, lado: 9)
                }
                Text(nombre)
                    .font(.subheadline.weight(esta ? .semibold : .medium))
                    .lineLimit(1)
                Text("\(n)")
                    .font(.footnote.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(Marcador.apoyo)
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 44)
            .foregroundStyle(esta ? AnyShapeStyle(.primary) : AnyShapeStyle(Marcador.apoyo))
            .cristal(.regular.tint(esta ? color.opacity(0.32) : .clear).interactive(), en: .capsule)
            .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(nombre), \(n)")
        .accessibilityAddTraits(esta ? .isSelected : [])
    }

    @ViewBuilder
    private var porDias: some View {
        if resto.isEmpty {
            Text(filtro.isEmpty && busca.isEmpty ? "No hay más pedidos" : "Ninguno aquí")
                .font(.subheadline)
                .foregroundStyle(Marcador.apoyo)
                .padding(.horizontal, Diseno.margen)
                .padding(.top, Diseno.hueco4)
        } else {
            ForEach(PedidosPorDia.agrupar(resto), id: \.dia) { grupo in
                VStack(alignment: .leading, spacing: 0) {
                    Text(PedidosPorDia.titulo(grupo.dia))
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Marcador.apoyo)
                        .textCase(.uppercase)
                        .padding(.top, Diseno.hueco4)
                        .padding(.bottom, Diseno.hueco1)
                        .accessibilityAddTraits(.isHeader)
                    ForEach(Array(grupo.pedidos.enumerated()), id: \.element.id) { i, p in
                        if i > 0 { Divider().padding(.leading, 22) }
                        if p.aMano {
                            FilaPedidoMarcador(pedido: p, extra: extras[p.id])
                        } else {
                            Button { abierto = p.id } label: {
                                FilaPedidoMarcador(pedido: p, extra: extras[p.id])
                            }
                            .buttonStyle(Hundirse())
                        }
                    }
                }
                .padding(.horizontal, Diseno.margen)
            }
        }
    }

    private func cargar() async {
        do {
            var ruta = "api/pedidos?estado=\(filtro)"
            if !busca.isEmpty,
               let q = busca.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
                ruta += "&busca=\(q)"
            }
            let j = try await API.pedir(ruta, testigo: sesion.testigo)
            cuenta = (j["cuenta"] as? [String: Int]) ?? [:]
            nombres = (j["nombres"] as? [String: String]) ?? [:]
            var nuevos: [String: Extra] = [:]
            lista = ((j["lista"] as? [[String: Any]]) ?? []).map { p in
                let id = p["id"] as? String ?? ""
                nuevos[id] = Extra(que: p["que"] as? String ?? "",
                                   metodo: p["metodo"] as? String ?? "",
                                   faltaPrecio: p["falta_precio"] as? Bool ?? false,
                                   euros: (p["importe_eur"] as? NSNumber)?.doubleValue)
                return PantallaPedidos.Pedido(
                    id: id,
                    cliente: p["cliente"] as? String ?? "",
                    tipo: p["tipo"] as? String ?? "",
                    estado: p["estado"] as? String ?? "",
                    estadoTxt: p["estado_txt"] as? String ?? "",
                    importe: p["importe"] as? String ?? "",
                    creado: p["creado"] as? String ?? "",
                    aMano: p["a_mano"] as? Bool ?? false,
                    plataforma: p["plataforma"] as? String ?? "",
                    descripcion: p["descripcion"] as? String ?? "",
                    yaCobradoAMano: p["ya_cobrado_a_mano"] as? Bool ?? false)
            }
            extras = nuevos
            if filtro.isEmpty && busca.isEmpty { aMano = lista.filter(\.aMano).count }
            estado = .listo(true)
        } catch {
            estado.fallar(error)
        }
    }

    private func hacer(_ p: PantallaPedidos.Pedido) async -> Bool {
        haciendo = p.id
        defer { haciendo = nil }
        let accion = p.estado == "review" ? "aprobar" : "pagado"
        do {
            let r = try await API.pedir("api/pedidos/\(p.id)/accion", metodo: "POST",
                                        cuerpo: ["accion": accion], testigo: sesion.testigo)
            let ok = r["ok"] as? Bool ?? false
            aviso = (r["mensaje"] as? String ?? (ok ? "Hecho." : "No se ha podido."), ok)
            await cargar()
            return ok
        } catch {
            aviso = (error.localizedDescription, false)
            return false
        }
    }
}

struct FilaPedidoMarcador: View {
    let pedido: PantallaPedidos.Pedido
    let extra: PedidosMarcador.Extra?

    var body: some View {
        HStack(spacing: Diseno.hueco2) {
            PuntoDeArea(color: PantallaPedidos.color(pedido.estado))
                .frame(minWidth: 10)
            VStack(alignment: .leading, spacing: 2) {
                Text(pedido.aMano ? (pedido.descripcion.isEmpty ? pedido.id : pedido.descripcion)
                                  : pedido.cliente)
                    .font(.headline)
                    .foregroundStyle(Color.primary)
                    .lineLimit(2)
                Text(subtitulo)
                    .font(.footnote)
                    .foregroundStyle(Marcador.apoyo)
                    .lineLimit(1)
                if pedido.yaCobradoAMano {
                    Label {
                        Text("Ya lo habías cobrado a mano: no vuelve a sumar")
                            .foregroundStyle(Color.primary)
                    } icon: {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.white, Diseno.naranjaRelleno)
                    }
                    .font(.caption)
                    .lineLimit(2)
                }
            }
            Spacer(minLength: Diseno.hueco1)
            Text(Formato.importe(pedido.importe))
                .font(.system(.headline, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Color.primary)
            if !pedido.aMano {
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Marcador.apoyo)
            }
        }
        .padding(.vertical, Diseno.hueco2)
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
    }

    private var subtitulo: String {
        
        let hora = pedido.creado.count >= 16 ? String(pedido.creado.suffix(5)) : ""
        if pedido.aMano {
            return "Cobrado a mano"
                + (pedido.plataforma.isEmpty ? "" : " por \(pedido.plataforma.capitalized)")
                + (hora.isEmpty ? "" : " · \(hora)")
        }
        return [pedido.estadoTxt, extra?.que ?? "", hora].filter { !$0.isEmpty }
            .joined(separator: " · ")
    }
}
