import SwiftUI

struct PantallaPedido: View {
    @Environment(Sesion.self) private var sesion
    @Environment(\.dismiss) private var cerrar
    let id: String

    @State private var p: [String: Any] = [:]
    @State private var estado: Sinopsis = .cargando
    @State private var trabajando: String?
    @State private var aviso: (texto: String, bien: Bool)?
    @State private var confirmando: Accion?
    @State private var pidiendoImporte: Accion?
    @State private var importe = ""
    @ScaledMetric(relativeTo: .largeTitle) private var tamCifra: CGFloat = 64

    enum Sinopsis { case cargando, listo, error(String) }

    enum Accion: String, Identifiable {
        case aprobar, rechazar, cancelar, pagado, noPagado, precioExtra, recargo

        var id: String { rawValue }
        var clave: String {
            switch self {
            case .noPagado: return "no_pagado"
            case .precioExtra: return "precio_extra"
            default: return rawValue
            }
        }
        var titulo: String {
            switch self {
            case .aprobar: return "Aprobar"
            case .rechazar: return "Rechazar"
            case .cancelar: return "Cancelar el pedido"
            case .pagado: return "Confirmar cobro"
            case .noPagado: return "No he recibido el pago"
            case .precioExtra: return "Precio del extra"
            case .recargo: return "Recargo"
            }
        }
        var icono: String {
            switch self {
            case .aprobar: return "checkmark.circle"
            case .rechazar: return "xmark.circle"
            case .cancelar: return "nosign"
            case .pagado: return "eurosign.circle"
            case .noPagado: return "exclamationmark.circle"
            case .precioExtra, .recargo: return "plusminus.circle"
            }
        }
        var color: Color {
            switch self {
            case .aprobar, .pagado: return Diseno.verde
            case .rechazar, .noPagado, .cancelar: return Diseno.rojo
            default: return Diseno.azul
            }
        }

        var iconoRelleno: String {
            switch self {
            case .cancelar: return "minus.circle.fill"
            default: return icono + ".fill"
            }
        }
        var relleno: Color {
            switch self {
            case .aprobar, .pagado: return Diseno.verdeRelleno
            case .rechazar, .noPagado, .cancelar: return Diseno.rojoRelleno
            default: return Diseno.azulRelleno
            }
        }
        
        var pideConfirmar: Bool {
            switch self {
            case .aprobar, .rechazar, .cancelar, .pagado, .noPagado: return true
            default: return false
            }
        }
        var pregunta: String {
            switch self {
            case .aprobar: return "Se le avisará al cliente de que puede pagar."
            case .rechazar: return "Se le avisará y, si usó un código, se le devuelve."

            case .cancelar: return "Se le avisará de que queda cancelado. Si ya estaba "
                + "cobrado, ese dinero deja de contar en tus cuentas."
            case .pagado: return "Se dará por cobrado y se le enviará el comprobante."
            case .noPagado: return "Se le avisará de que no te ha llegado el pago."
            default: return ""
            }
        }
    }

    var body: some View {
        Group {

            marcador
        }

        .navigationTitle("Pedido")
        .modifier(Subtitulo(texto: texto("_id")))
        .navigationBarTitleDisplayMode(.inline)

        .salidaDelTeclado()
        .animation(Diseno.suave, value: trabajando)
        .animation(Diseno.suave, value: estadoActual)
        .task { await cargar() }
        .refreshable { await cargar() }
        .confirmationDialog(confirmando?.titulo ?? "", isPresented: .init(
            get: { confirmando != nil }, set: { if !$0 { confirmando = nil } }
        ), titleVisibility: .visible) {
            if let a = confirmando {
                Button(a.titulo, role: a.color == Diseno.rojo ? .destructive : nil) {
                    Task { await hacer(a) }
                }
                Button("Cancelar", role: .cancel) {}
            }
        } message: {
            Text(confirmando?.pregunta ?? "")
        }
        .alert(pidiendoImporte?.titulo ?? "", isPresented: .init(
            get: { pidiendoImporte != nil }, set: { if !$0 { pidiendoImporte = nil } }
        )) {
            TextField("Importe en euros", text: $importe).keyboardType(.decimalPad)
            Button("Guardar") { if let a = pidiendoImporte { Task { await hacer(a) } } }
            Button("Cancelar", role: .cancel) {}
        }
    }

    private var marcador: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                switch estado {
                case .cargando:
                    Vacio(icono: "doc.text", titulo: "Cargando…")
                        .redacted(reason: .placeholder)
                        .padding(.top, Diseno.hueco5)
                case .error(let qué):
                    Vacio(icono: "wifi.exclamationmark", titulo: "No se ha podido cargar",
                          detalle: qué)
                        .padding(.top, Diseno.hueco5)
                case .listo:
                    cabeceraMarcador
                    if let aviso { bandaEnCampo(aviso).padding(.top, Diseno.hueco2) }
                    if !disponibles.isEmpty {
                        acciones.padding(.top, Diseno.hueco3)
                    }
                    datosMarcador
                    BotonPDF(ruta: "api/pedidos/\(id)/pdf", nombre: "\(id).pdf")
                        .padding(.top, Diseno.hueco4)
                }
            }
            .padding(.horizontal, Diseno.margen)
            .padding(.bottom, Diseno.hueco5)
        }
        .scrollEdgeEffectStyle(.soft, for: .top)
        .background { CampoJoya(joya: .tienda) }
    }

    private func bandaEnCampo(_ a: (texto: String, bien: Bool)) -> some View {
        Label {
            Text(a.texto).foregroundStyle(Color.primary)
        } icon: {
            Image(systemName: a.bien ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundStyle(a.bien ? Diseno.verdeRelleno : Diseno.rojoRelleno)
        }
        .font(.subheadline)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Diseno.hueco2)
        .background(.background.opacity(0.55), in: .rect(cornerRadius: Diseno.radioCampo))
        .transition(.opacity.combined(with: .move(edge: .top)))
        .sensoryFeedback(a.bien ? .success : .error, trigger: a.texto)
    }

    private var cabeceraMarcador: some View {
        VStack(alignment: .leading, spacing: Diseno.hueco1) {
            
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .center, spacing: Diseno.hueco2) {
                    nombreDelCliente
                    Spacer(minLength: 0)
                    pastillaDeEstado
                }
                VStack(alignment: .leading, spacing: Diseno.hueco1) {
                    nombreDelCliente
                    pastillaDeEstado
                }
            }
            Text(Formato.importe(texto("_importe")))
                .font(.system(size: min(tamCifra, 104), weight: .bold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.45)
                .contentTransition(.numericText())
            Text([texto("_tipo").isEmpty ? "Vídeo personalizado" : texto("_tipo"),
                  Self.fechaBonita(texto("_creado"))].filter { !$0.isEmpty }.joined(separator: " · "))
                .font(.subheadline)
                .foregroundStyle(Marcador.apoyo)
        }
        .padding(.top, Diseno.hueco1)
        .accessibilityElement(children: .combine)
    }

    private var nombreDelCliente: some View {
        Text(texto("username").isEmpty ? "Cliente" : texto("username"))
            .font(.title2.weight(.bold))
            .lineLimit(1)
            .minimumScaleFactor(0.7)
    }

    private var pastillaDeEstado: some View {
        PastillaDeCristal(texto: texto("_estado_txt"),
                          icono: PantallaPedidos.icono(estadoActual),
                          tinte: PantallaPedidos.color(estadoActual))
            .fixedSize()
    }

    @ViewBuilder
    private var datosMarcador: some View {
        TituloDeSeccion(texto: "El pedido")
        VStack(spacing: 0) {
            ForEach(Array(filasDelPedido.enumerated()), id: \.offset) { i, f in
                if i > 0 { Divider() }
                HStack(alignment: .firstTextBaseline) {
                    Text(f.0).foregroundStyle(Marcador.apoyo)
                    Spacer(minLength: Diseno.hueco2)
                    Text(f.1).multilineTextAlignment(.trailing)
                }
                .font(.subheadline)
                .padding(.vertical, Diseno.hueco2)
                .accessibilityElement(children: .combine)
            }
        }
        if !texto("_extra_libre").isEmpty {
            TituloDeSeccion(texto: "El extra que pide", dato: texto("_extra_libre_precio"))
            Text(texto("_extra_libre"))
                .font(.body)
                .textSelection(.enabled)
                .padding(.top, Diseno.hueco1)
        }
        if !texto("description").isEmpty {
            TituloDeSeccion(texto: "Lo que pide")
            Text(texto("description"))
                .font(.body)
                .textSelection(.enabled)
                .padding(.top, Diseno.hueco1)
        }
    }

    static func fechaBonita(_ s: String) -> String {
        guard s.count >= 10 else { return s }
        let dia = String(s.prefix(10))
        let hora = s.count >= 16 ? " · " + String(s.suffix(5)) : ""
        return "\(Fechas.diaDeLaSemana(dia)) \(Fechas.corta(dia))" + hora
    }

    private var filasDelPedido: [(String, String)] {
        var f: [(String, String)] = []
        if !texto("_duracion").isEmpty {
            f.append((texto("order_kind") == "prerecorded" ? "Categoría" : "Duración",
                      texto("_duracion")))
        }
        if !extras.isEmpty { f.append(("Extras", extras.joined(separator: ", "))) }
        if !texto("_recargo").isEmpty { f.append(("Recargo", texto("_recargo"))) }
        if !texto("_total").isEmpty && texto("_total") != texto("_importe") {
            f.append(("Antes del descuento", texto("_total")))
        }
        if !texto("promo_code").isEmpty { f.append(("Código", texto("promo_code"))) }
        if !texto("_metodo").isEmpty { f.append(("Método", texto("_metodo"))) }
        if !texto("_pagado").isEmpty { f.append(("Cobrado", Self.fechaBonita(texto("_pagado")))) }
        return f
    }

    private var acciones: some View {
        VStack(spacing: Diseno.hueco2) {
            ForEach(disponibles) { a in
                Button {
                    if a.pideConfirmar { confirmando = a }
                    else { importe = ""; pidiendoImporte = a }
                } label: {
                    HStack {
                        if trabajando == a.clave {
                            ProgressView().controlSize(.small)
                        } else {
                            Image(systemName: a.iconoRelleno)
                                .symbolRenderingMode(.palette)
                                .foregroundStyle(.white, a.relleno)
                                .font(.title3)
                        }
                        Text(a.titulo)
                            .foregroundStyle(Color.primary)
                        Spacer()
                    }
                    .font(.body.weight(.medium))
                    .padding(.vertical, 4)
                }
                .buttonStyle(.glass)
                .controlSize(.large)
                .tint(a.color)
                .disabled(trabajando != nil)
            }
        }
    }

    private var disponibles: [Accion] {
        switch estadoActual {
        case "review":  return [.aprobar, .precioExtra, .recargo, .rechazar, .cancelar]
        case "awaiting_payment_confirm": return [.pagado, .noPagado, .cancelar]

        case "approved", "price_proposed", "payment_selected", "confirmed":
                        return [.pagado, .rechazar, .cancelar]

        case "not_received": return [.pagado, .cancelar]

        case "paid":    return [.cancelar]
        default:        return []
        }
    }

    private var estadoActual: String { texto("status") }

    private func texto(_ clave: String) -> String {
        if let s = p[clave] as? String { return s }
        if let n = p[clave] as? Int { return String(n) }
        if let d = p[clave] as? Double { return String(d) }
        return ""
    }

    private var extras: [String] { (p["_extras"] as? [String]) ?? [] }

    private func cargar() async {
        do {
            p = try await API.pedir("api/pedidos/\(id)", testigo: sesion.testigo)
            estado = .listo
        } catch {
            estado = .error(error.localizedDescription)
        }
    }

    private func hacer(_ a: Accion) async {
        trabajando = a.clave
        aviso = nil
        var cuerpo: [String: any Sendable] = ["accion": a.clave]
        if !a.pideConfirmar { cuerpo["importe"] = importe }
        do {
            let r = try await API.pedir("api/pedidos/\(id)/accion", metodo: "POST",
                                        cuerpo: cuerpo, testigo: sesion.testigo)
            let ok = r["ok"] as? Bool ?? false
            aviso = (r["mensaje"] as? String ?? (ok ? "Hecho." : "No se ha podido."), ok)

            await cargar()
        } catch {
            aviso = (error.localizedDescription, false)
        }
        trabajando = nil
        confirmando = nil
        pidiendoImporte = nil
    }
}
