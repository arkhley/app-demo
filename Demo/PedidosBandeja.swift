import SwiftUI

struct BandejaPedidos: View {
    @Environment(Sesion.self) private var sesion

    @State private var lista: [PantallaPedidos.Pedido] = []
    @State private var extras: [String: ExtraPedido] = [:]
    @State private var cuenta: [String: Int] = [:]
    @State private var nombres: [String: String] = [:]
    @State private var filtro = ""
    @State private var busca = ""
    @State private var estado: Carga<Bool> = .cargando
    @State private var aviso: (texto: String, bien: Bool)?
    @State private var haciendo: String?

    struct ExtraPedido: Equatable {
        let que: String
        let metodo: String
        let faltaPrecio: Bool
    }

    private var porHacer: [PantallaPedidos.Pedido] {
        lista.filter { $0.estado == "review" || $0.estado == "awaiting_payment_confirm" }
    }

    private var resto: [PantallaPedidos.Pedido] {
        lista.filter { $0.estado != "review" && $0.estado != "awaiting_payment_confirm" }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Diseno.hueco4) {
                if let aviso { Banda(aviso) }

                switch estado {
                case .cargando:
                    Tarjeta { Vacio(icono: "tray", titulo: "Cargando…") }
                        .redacted(reason: .placeholder)
                case .error(let qué):
                    Tarjeta { Vacio(icono: "wifi.exclamationmark",
                                    titulo: "No se ha podido cargar", detalle: qué) }
                default:
                    if filtro.isEmpty && busca.isEmpty {
                        seccionPorHacer
                    }
                    if !cuenta.isEmpty { filtros }
                    seccionesPorDia
                }
            }
            .padding(.horizontal, Diseno.margen)
            .padding(.vertical, Diseno.hueco2)
        }
        .fondoDePantalla()
        .navigationTitle("Pedidos")
        .searchable(text: $busca, prompt: "Buscar por cliente o número")
        .onChange(of: busca) { _, _ in Task { await cargar() } }
        .animation(Diseno.suave, value: lista)
        .animation(Diseno.suave, value: aviso?.texto)
        .task { await cargar() }
        .refreshable { await cargar() }
    }

    @ViewBuilder
    private var seccionPorHacer: some View {
        VStack(alignment: .leading, spacing: Diseno.hueco2) {
            HStack(spacing: 8) {
                Text("Te toca").font(.title3.weight(.semibold))
                if !porHacer.isEmpty {
                    Text("\(porHacer.count)")
                        .font(.subheadline.weight(.bold))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8).padding(.vertical, 2)
                        .background(Diseno.naranjaRelleno.gradient, in: .capsule)
                        .contentTransition(.numericText(value: Double(porHacer.count)))
                }
            }
            .padding(.leading, 4)

            if porHacer.isEmpty {
                Tarjeta {
                    Label("Nada pendiente", systemImage: "checkmark.seal.fill")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Diseno.verde)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .transition(.opacity)
            } else {
                ForEach(Array(porHacer.enumerated()), id: \.element.id) { i, p in
                    NavigationLink { PantallaPedido(id: p.id) } label: {
                        TarjetaPorHacer(pedido: p, extra: extras[p.id],
                                        trabajando: haciendo == p.id) {
                            await hacer(p)
                        }
                    }
                    .buttonStyle(.plain)
                    .aparicion(i)
                    .transition(.asymmetric(insertion: .opacity,
                                            removal: .scale(scale: 0.92).combined(with: .opacity)))
                }
            }
        }
    }

    @ViewBuilder
    private var seccionesPorDia: some View {
        let lista = (filtro.isEmpty && busca.isEmpty) ? resto : self.lista
        if lista.isEmpty {
            Tarjeta {
                Vacio(icono: "tray",
                      titulo: filtro.isEmpty && busca.isEmpty ? "Todavía no hay más pedidos"
                                                              : "Ninguno aquí",
                      detalle: filtro.isEmpty ? "" : "Prueba con otro estado.")
            }
        } else {
            ForEach(PedidosPorDia.agrupar(lista), id: \.dia) { grupo in
                VStack(alignment: .leading, spacing: Diseno.hueco1) {
                    Text(PedidosPorDia.titulo(grupo.dia))
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .padding(.leading, 4)
                    Tarjeta(relleno: 0) {
                        VStack(spacing: 0) {
                            ForEach(Array(grupo.pedidos.enumerated()), id: \.element.id) { i, p in
                                if i > 0 { Divider().padding(.leading, Diseno.sangriaFila) }
                                if p.aMano {
                                    FilaPedido(pedido: p, extra: extras[p.id])
                                } else {
                                    NavigationLink { PantallaPedido(id: p.id) } label: {
                                        FilaPedido(pedido: p, extra: extras[p.id])
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private var filtros: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            GlassEffectContainer(spacing: 6) {
                HStack(spacing: 6) {
                    pildora(clave: "", nombre: "Todos", n: cuenta.values.reduce(0, +))
                    ForEach(PantallaPedidos.ordenEstados.filter { cuenta[$0] != nil }, id: \.self) { e in
                        pildora(clave: e, nombre: nombres[e] ?? e, n: cuenta[e] ?? 0)
                    }
                }
                .padding(.horizontal, 2)
            }
        }
        .scrollClipDisabled()
        .animation(Diseno.suave, value: filtro)
        .sensoryFeedback(.selection, trigger: filtro)
    }

    private func pildora(clave: String, nombre: String, n: Int) -> some View {
        Button {
            guard filtro != clave else { return }
            filtro = clave
            Task { await cargar() }
        } label: {
            HStack(spacing: 5) {
                Text(nombre)
                Text("\(n)")
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 5).padding(.vertical, 1)
                    .background(.quaternary, in: .capsule)
            }
            .font(.footnote.weight(filtro == clave ? .semibold : .regular))
            .padding(.horizontal, 12).padding(.vertical, 8)
        }
        .buttonStyle(.plain)
        .foregroundStyle(filtro == clave ? Color.primary : .secondary)
        .cristal(filtro == clave ? .regular.interactive() : .identity, en: .capsule)
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
            let filas = (j["lista"] as? [[String: Any]]) ?? []
            var nuevos: [String: ExtraPedido] = [:]
            lista = filas.map { p in
                let id = p["id"] as? String ?? ""
                nuevos[id] = ExtraPedido(que: p["que"] as? String ?? "",
                                         metodo: p["metodo"] as? String ?? "",
                                         faltaPrecio: p["falta_precio"] as? Bool ?? false)
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

private struct TarjetaPorHacer: View {
    let pedido: PantallaPedidos.Pedido
    let extra: BandejaPedidos.ExtraPedido?
    let trabajando: Bool
    let accion: () async -> Bool

    @ScaledMetric(relativeTo: .title) private var tamImporte: CGFloat = 30

    private var revisar: Bool { pedido.estado == "review" }
    private var color: Color { revisar ? Diseno.naranjaRelleno : Diseno.azulRelleno }

    var body: some View {
        Tarjeta {
            VStack(alignment: .leading, spacing: Diseno.hueco2) {
                HStack(alignment: .firstTextBaseline) {
                    Label(revisar ? "Por revisar" : "Dice que ha pagado",
                          systemImage: revisar ? "doc.text.magnifyingglass" : "creditcard")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(color)
                    Spacer()
                    Text(PedidosPorDia.haceCuanto(pedido.creado))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(pedido.cliente)
                            .font(.headline)
                            .lineLimit(1)
                        Text(detalle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: Diseno.hueco2)
                    Text(Formato.importe(pedido.importe))
                        .font(.system(size: tamImporte, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                }

                if revisar && (extra?.faltaPrecio ?? false) {

                    Label("Ponle precio al extra que pide", systemImage: "exclamationmark.circle.fill")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Diseno.naranja)
                } else {
                    DeslizarParaConfirmar(
                        texto: revisar ? "Desliza para aprobar" : "Desliza: cobrado",
                        icono: revisar ? "checkmark" : "eurosign",
                        color: Diseno.verdeRelleno,
                        trabajando: trabajando,
                        accion: accion)
                }
            }
        }
        .accessibilityElement(children: .contain)
    }

    private var detalle: String {
        var trozos: [String] = []
        if let q = extra?.que, !q.isEmpty { trozos.append(q) }
        if let m = extra?.metodo, !m.isEmpty, !revisar { trozos.append(m) }
        return trozos.isEmpty ? pedido.estadoTxt : trozos.joined(separator: " · ")
    }
}

struct DeslizarParaConfirmar: View {
    let texto: String
    let icono: String
    let color: Color
    let trabajando: Bool

    var colorTexto: Color? = nil
    let accion: () async -> Bool

    @Environment(\.accessibilityReduceMotion) private var menosMovimiento
    @State private var avance: CGFloat = 0
    @State private var ancho: CGFloat = 1
    @State private var arrastrando = false
    @State private var hecho = false
    @State private var fallo = 0

    private let lado: CGFloat = 50
    private var recorrido: CGFloat { max(1, ancho - lado - 8) }
    private var fraccion: CGFloat { min(1, max(0, avance / recorrido)) }

    var body: some View {
        ZStack(alignment: .leading) {
            Capsule()
                .fill(color.opacity(0.14))
            
            Capsule()
                .fill(color.opacity(0.35).gradient)
                .frame(width: lado + 8 + avance)
            Text(trabajando ? "Un momento…" : texto)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(colorTexto ?? color)
                .opacity(1 - Double(fraccion) * 1.4)
                .frame(maxWidth: .infinity)
                .padding(.leading, lado)
            bola
                .offset(x: 4 + avance)
        }
        .frame(height: lado + 8)
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { ancho = max($0, 1) }
        .sensoryFeedback(.impact(weight: .medium), trigger: hecho) { _, nuevo in nuevo }
        .sensoryFeedback(.error, trigger: fallo)
        .accessibilityElement()
        .accessibilityLabel(texto)
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { Task { _ = await accion() } }
    }

    private var bola: some View {
        ZStack {
            if trabajando {
                ProgressView()
            } else {
                Image(systemName: hecho ? "checkmark" : icono)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
                    .contentTransition(.symbolEffect(.replace))
            }
        }
        .frame(width: lado, height: lado)
        .background(color.gradient, in: .circle)
        .cristal(arrastrando ? .regular.interactive() : .identity, en: .circle)
        .scaleEffect(arrastrando ? 1.08 : 1)
        .shadow(color: color.opacity(0.35), radius: 6, x: 0, y: 3)

        .highPriorityGesture(
            DragGesture(minimumDistance: 2)
                .onChanged { v in
                    guard !trabajando, !hecho else { return }
                    arrastrando = true
                    avance = min(recorrido, max(0, v.translation.width))
                }
                .onEnded { _ in
                    arrastrando = false
                    guard !trabajando, !hecho else { return }
                    if fraccion > 0.86 {
                        withAnimation(Diseno.suave) { avance = recorrido }
                        hecho = true
                        Task {
                            let ok = await accion()
                            if !ok {
                                fallo += 1
                                hecho = false
                                withAnimation(menosMovimiento ? nil : .spring(duration: 0.45, bounce: 0.35)) {
                                    avance = 0
                                }
                            }
                        }
                    } else {
                        withAnimation(menosMovimiento ? nil : .spring(duration: 0.45, bounce: 0.35)) {
                            avance = 0
                        }
                    }
                }
        )
        .animation(.spring(duration: 0.3, bounce: 0.3), value: arrastrando)
    }
}

private struct FilaPedido: View {
    let pedido: PantallaPedidos.Pedido
    let extra: BandejaPedidos.ExtraPedido?

    var body: some View {
        HStack(spacing: Diseno.hueco2) {
            FichaIcono(simbolo: PantallaPedidos.icono(pedido.estado),
                       color: PantallaPedidos.color(pedido.estado))
            VStack(alignment: .leading, spacing: 2) {
                Text(pedido.aMano ? (pedido.descripcion.isEmpty ? pedido.id : pedido.descripcion)
                                  : pedido.cliente)
                    .lineLimit(1)
                Text(subtitulo)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                if pedido.yaCobradoAMano {
                    Label("Ya lo habías cobrado a mano: no vuelve a sumar",
                          systemImage: "checkmark.circle")
                        .font(.caption2)
                        .foregroundStyle(Diseno.naranja)
                        .lineLimit(1)
                }
            }
            Spacer()
            Text(Formato.importe(pedido.importe))
                .font(.subheadline.weight(.medium))
                .monospacedDigit()
            if !pedido.aMano {
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(Diseno.hueco3)
        .contentShape(.rect)
    }

    private var subtitulo: String {

        let hora = pedido.creado.count >= 16 ? String(pedido.creado.suffix(5)) : ""
        if pedido.aMano {
            return "Cobrado a mano" + (pedido.plataforma.isEmpty ? "" : " por \(pedido.plataforma.capitalized)")
                + (hora.isEmpty ? "" : " · \(hora)")
        }
        let que = extra?.que ?? ""
        return [pedido.estadoTxt, que, hora].filter { !$0.isEmpty }.joined(separator: " · ")
    }
}

enum PedidosPorDia {
    struct Grupo { let dia: String; let pedidos: [PantallaPedidos.Pedido] }

    private static let madrid = TimeZone(identifier: "Europe/Madrid") ?? .current

    static func agrupar(_ lista: [PantallaPedidos.Pedido]) -> [Grupo] {
        var orden: [String] = []
        var por: [String: [PantallaPedidos.Pedido]] = [:]
        for p in lista.sorted(by: { $0.creado > $1.creado }) {
            let d = String(p.creado.prefix(10))
            if por[d] == nil { orden.append(d) }
            por[d, default: []].append(p)
        }
        return orden.map { Grupo(dia: $0, pedidos: por[$0] ?? []) }
    }

    private static var hoyISO: String {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = madrid
        let x = c.dateComponents([.year, .month, .day], from: Date())
        return String(format: "%04d-%02d-%02d", x.year ?? 0, x.month ?? 0, x.day ?? 0)
    }

    static func titulo(_ dia: String) -> String {
        let hoy = hoyISO
        if dia == hoy { return "Hoy" }
        if dia == Fechas.mas(hoy, -1) { return "Ayer" }
        return dia.isEmpty ? "Sin fecha" : Fechas.larga(dia)
    }

    static func haceCuanto(_ creado: String) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")   
        f.timeZone = madrid
        f.dateFormat = "yyyy-MM-dd HH:mm"
        guard let cuando = f.date(from: creado) else { return "" }
        let seg = max(0, Date().timeIntervalSince(cuando))
        if seg < 90 { return "ahora" }
        if seg < 3600 { return "hace \(Int(seg / 60)) min" }
        if seg < 86400 { return "hace \(Int(seg / 3600)) h" }
        let dia = String(creado.prefix(10))
        return dia == Fechas.mas(hoyISO, -1) ? "ayer" : Fechas.corta(dia)
    }
}
