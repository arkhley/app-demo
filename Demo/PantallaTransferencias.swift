import SwiftUI

struct PantallaTransferencias: View {
    @Environment(Sesion.self) private var sesion

    var abrir: String? = nil
    var plataformaAbrir: String? = nil
    
    var alGuardar: (() async -> Void)? = nil

    @State private var yaAbierta = false
    @State private var meses: [Mes] = []
    @State private var abiertos: Set<String> = []
    @State private var estado: Carga<Bool> = .cargando
    
    @State private var apuntando: Transferencia?

    struct Mes: Identifiable, Equatable {
        let mes: String
        let nombre: String
        let euros: Double
        let netoUSD: Double
        let lista: [Transferencia]
        var id: String { mes }
    }

    struct Transferencia: Identifiable, Equatable {
        let fecha: String
        let nombre: String
        let tokens: Int
        let brutoUSD: Double
        let comisionUSD: Double
        let netoUSD: Double
        let euros: Double
        let enDinero: Bool
        
        var detalle: String = ""

        var plataforma: String = ""
        
        var euros_reales: Bool = false

        var eurosMercado: Double = 0

        var metodo: String = ""
        
        var cambio: Double = 0
        var cambioReal: Bool = false
        
        var cambioMinimo: Bool = false
        var convertido: String = ""
        var id: String { "\(fecha)|\(nombre)" }
    }

    @State private var elegido: String?

    var body: some View {
        Group {

            marcador
        }
        .sheet(item: $apuntando) { t in
            HojaCobroReal(transferencia: t) {
                await cargar()
                await alGuardar?()
            }
        }
        .navigationTitle("Transferencias")
        .task { await cargar() }
    }

    private var marcador: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                switch estado {
                case .cargando:
                    Vacio(icono: "arrow.left.arrow.right", titulo: "Cargando…")
                        .redacted(reason: .placeholder)
                        .padding(.top, Diseno.hueco5)
                case .error(let qué):
                    Vacio(icono: "wifi.exclamationmark", titulo: "No se ha podido cargar", detalle: qué)
                        .padding(.top, Diseno.hueco5)
                case .vacio:
                    Vacio(icono: "arrow.left.arrow.right", titulo: "Ninguna todavía",
                          detalle: "Aquí aparecerán los cobros de tus plataformas.")
                        .padding(.top, Diseno.hueco5)
                default:
                    if let m = mesElegido {
                        cabeceraDelMes(m)
                            .padding(.horizontal, Diseno.margen)
                    }
                    if meses.count > 1 {
                        ColumnasEnCampo(meses: meses, elegido: mesElegido?.mes) { mes in
                            withAnimation(Diseno.suave) {
                                elegido = mes
                                abiertos.insert(mes)
                            }
                        }
                        .padding(.horizontal, Diseno.margen)
                        .padding(.top, Diseno.hueco3)
                    }
                    TituloDeSeccion(texto: "Mes a mes")
                        .padding(.horizontal, Diseno.margen)
                    VStack(spacing: 0) {
                        ForEach(Array(meses.enumerated()), id: \.element.id) { i, m in
                            if i > 0 { Divider() }
                            mesPlegable(m)
                        }
                    }
                    .padding(.horizontal, Diseno.margen)
                    .padding(.top, Diseno.hueco1)
                    
                    Text("Los últimos 24 meses.")
                        .font(.footnote).foregroundStyle(Marcador.apoyo)
                        .padding(.horizontal, Diseno.margen)
                        .padding(.top, Diseno.hueco3)
                }
            }
            .padding(.bottom, Diseno.hueco5)
        }
        .scrollEdgeEffectStyle(.soft, for: .top)
        .background { CampoJoya(joya: .cobros) }
        .refreshable { await cargar() }
        .sensoryFeedback(.selection, trigger: abiertos)
    }

    private var mesElegido: Mes? { meses.first { $0.mes == elegido } ?? meses.first }

    private func cabeceraDelMes(_ m: Mes) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Llegó en \(CobrosHucha.nombreDelMes(m.mes, conAño: m.mes != meses.first?.mes))")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Marcador.apoyo)
                .contentTransition(.interpolate)
            CifraMarcador(euros: m.euros)
            Text(m.lista.count == 1 ? "1 transferencia" : "\(m.lista.count) transferencias")
                .font(.subheadline)
                .foregroundStyle(Marcador.apoyo)
                .monospacedDigit()
                .contentTransition(.numericText())
        }
        .animation(Diseno.cifra, value: m.mes)
        .accessibilityElement(children: .combine)
    }

    private func mesPlegable(_ m: Mes) -> some View {
        DisclosureGroup(isExpanded: Binding(
            get: { abiertos.contains(m.mes) },
            set: { abierto in
                withAnimation(Diseno.suave) {
                    if abierto { abiertos.insert(m.mes); elegido = m.mes } else { abiertos.remove(m.mes) }
                }
            })) {
            VStack(spacing: 0) {
                ForEach(Array(m.lista.enumerated()), id: \.element.id) { j, t in
                    if j > 0 { Divider().padding(.leading, 22) }
                    filaEnCampo(t)
                }
            }
            .padding(.top, Diseno.hueco1)
        } label: {

            HStack(spacing: Diseno.hueco2) {
                HStack(spacing: -4) {
                    ForEach(Array(Set(m.lista.map(\.plataforma))).sorted(), id: \.self) { p in
                        Circle().fill(Diseno.colorDePlataforma(p).gradient)
                            .overlay(Circle().strokeBorder(.white.opacity(0.8), lineWidth: 1.2))
                            .frame(width: 12, height: 12)
                    }
                }
                .frame(width: 34, alignment: .leading)
                .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 1) {
                    Text(CobrosHucha.nombreDelMes(m.mes, conAño: true).capitalizandoPrimera)
                        .font(.headline)
                        .lineLimit(1)
                    Text(m.lista.count == 1 ? "1 transferencia" : "\(m.lista.count) transferencias")
                        .font(.caption).foregroundStyle(Marcador.apoyo)
                }
                Spacer(minLength: Diseno.hueco1)
                Text(Formato.euros(m.euros))
                    .font(.system(.headline, design: .rounded)).monospacedDigit()
            }
            .padding(.vertical, 10)
            .foregroundStyle(Color.primary)
            .contentShape(.rect)
        }
        .tint(Marcador.apoyo)
    }

    @ViewBuilder
    private func filaEnCampo(_ t: Transferencia) -> some View {
        let fila = HStack(alignment: .top, spacing: Diseno.hueco2) {
            PuntoDeArea(color: Diseno.colorDePlataforma(t.plataforma))
                .frame(width: 12)
                .padding(.top, 5)
            VStack(alignment: .leading, spacing: 2) {
                Text(t.nombre)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.primary)
                Text(pieDe(t))
                    .font(.footnote)
                    .foregroundStyle(Marcador.apoyo)
                    .lineLimit(2)
            }
            Spacer(minLength: Diseno.hueco1)
            VStack(alignment: .trailing, spacing: 2) {
                HStack(spacing: 4) {
                    if t.euros_reales {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.caption)
                            .foregroundStyle(.white, Diseno.verdeRelleno)
                            .accessibilityLabel("Lo que llegó al banco")
                    }
                    Text(Formato.euros(t.euros))
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(Color.primary)
                }
                if !t.enDinero {
                    Text(Formato.dolares(t.netoUSD))
                        .font(.caption).monospacedDigit()
                        .foregroundStyle(Marcador.apoyo)
                }
            }
        }
        .padding(.vertical, 10)
        .contentShape(.rect)
        if t.enDinero {
            fila.accessibilityElement(children: .combine)
        } else {
            Button { apuntando = t } label: { fila }
                .buttonStyle(Hundirse())
                .accessibilityHint("Apuntar lo que llegó al banco")
        }
    }

    private func pieDe(_ t: Transferencia) -> String {
        var partes = [Fechas.corta(t.fecha)]
        if t.enDinero {
            if !t.detalle.isEmpty { partes.append(t.detalle) }
        } else {
            partes.append(Formato.tokens(t.tokens))
            partes.append("bruto " + Formato.dolares(t.brutoUSD))
            if t.comisionUSD > 0 {
                partes.append("−" + Formato.dolares(t.comisionUSD) + " de comisión")
            }
        }
        return partes.joined(separator: " · ")
    }

    private func fila(_ t: Transferencia) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                
                Circle().fill(Diseno.colorDePlataforma(t.plataforma).gradient)
                    .frame(width: 10, height: 10)
                VStack(alignment: .leading, spacing: 2) {
                    Text(t.nombre).font(.subheadline.weight(.medium))
                    Text(bonita(t.fecha)).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    HStack(spacing: 4) {

                        if t.euros_reales {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.caption2).foregroundStyle(Diseno.verde)
                        }
                        Text(Formato.euros(t.euros))
                            .font(.subheadline.weight(.semibold)).monospacedDigit()
                    }
                    
                    if !t.enDinero {
                        Text(Formato.dolares(t.netoUSD))
                            .font(.caption).foregroundStyle(.secondary).monospacedDigit()
                    }
                }
            }

            if !t.detalle.isEmpty {
                
                Text(t.detalle)
                    .font(.caption2).foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            if !t.enDinero {
                HStack(spacing: 10) {
                    Text(Formato.tokens(t.tokens))
                    
                    Text("bruto " + Formato.dolares(t.brutoUSD))
                    if t.comisionUSD > 0 {
                        
                        Text("−" + Formato.dolares(t.comisionUSD) + " de comisión")
                            .foregroundStyle(AnyShapeStyle(.secondary))
                    }
                }
                .font(.caption2).foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, Diseno.hueco3)
        .padding(.vertical, 8)
    }

    private func bonita(_ iso: String) -> String {
        let p = iso.split(separator: "-")
        guard p.count == 3, let m = Int(p[1]), let d = Int(p[2]) else { return iso }
        let meses = ["enero", "febrero", "marzo", "abril", "mayo", "junio", "julio",
                     "agosto", "septiembre", "octubre", "noviembre", "diciembre"]
        return "\(d) de \(meses[m - 1])"
    }

    private func cargar() async {
        do {

            let j = try await API.pedir("api/transferencias?meses=24", testigo: sesion.testigo)
            meses = ((j["meses"] as? [[String: Any]]) ?? []).map { m in
                Mes(mes: m["mes"] as? String ?? "",
                    nombre: m["nombre"] as? String ?? "",
                    euros: m["euros"] as? Double ?? 0,
                    netoUSD: m["neto_usd"] as? Double ?? 0,
                    lista: ((m["lista"] as? [[String: Any]]) ?? []).map {
                        Transferencia(fecha: $0["fecha"] as? String ?? "",
                                      nombre: $0["nombre"] as? String ?? "",
                                      tokens: $0["tokens"] as? Int ?? 0,
                                      brutoUSD: $0["bruto_usd"] as? Double ?? 0,
                                      comisionUSD: $0["comision_usd"] as? Double ?? 0,
                                      netoUSD: $0["neto_usd"] as? Double ?? 0,
                                      euros: $0["euros"] as? Double ?? 0,
                                      enDinero: $0["en_dinero"] as? Bool ?? false,
                                      detalle: $0["detalle"] as? String ?? "",
                                      plataforma: $0["plataforma"] as? String ?? "",
                                      euros_reales: $0["euros_reales"] as? Bool ?? false,
                                      eurosMercado: $0["euros_mercado"] as? Double ?? 0,
                                      metodo: $0["metodo"] as? String ?? "",
                                      cambio: $0["cambio"] as? Double ?? 0,
                                      cambioReal: $0["cambio_real"] as? Bool ?? false,
                                      cambioMinimo: $0["cambio_minimo"] as? Bool ?? false,
                                      convertido: $0["convertido"] as? String ?? "")
                    })
            }
            
            if let primero = meses.first, abiertos.isEmpty { abiertos = [primero.mes] }
            
            if let f = abrir, !yaAbierta,
               let m = meses.first(where: { $0.lista.contains { $0.fecha == f } }),
               let t = m.lista.first(where: {
                   $0.fecha == f && (plataformaAbrir == nil || $0.plataforma == plataformaAbrir)
               }) {
                yaAbierta = true
                abiertos.insert(m.mes)
                apuntando = t
            }
            estado = meses.isEmpty ? .vacio : .listo(true)
        } catch {
            estado.fallar(error)
        }
    }
}

private struct HojaCobroReal: View {
    let transferencia: PantallaTransferencias.Transferencia
    let alGuardar: () async -> Void

    @Environment(Sesion.self) private var sesion
    @Environment(\.dismiss) private var cerrar
    @State private var importe = ""
    @State private var guardando = false
    @State private var aviso: (texto: String, bien: Bool)?

    private var esMonedero: Bool { transferencia.metodo == "monedero" }

    private func linea(_ titulo: String, _ valor: String, fuerte: Bool = false,
                       gris: Bool = false) -> some View {
        HStack {
            Text(titulo).font(fuerte ? .subheadline.weight(.semibold) : .subheadline)
            Spacer()
            Text(valor)
                .font(fuerte ? .subheadline.weight(.semibold) : .subheadline)
                .foregroundStyle(gris ? .secondary : .primary)
                .monospacedDigit()
        }
    }

    private func dolares(_ v: Double) -> String {
        Formato.euros(v).replacingOccurrences(of: "€", with: "$")
    }

    private var cadenaMonedero: some View {
        Tarjeta {
            VStack(alignment: .leading, spacing: 6) {
                Text(transferencia.nombre).font(.headline)
                Text(bonita(transferencia.fecha))
                    .font(.subheadline).foregroundStyle(.secondary)
                Divider()
                linea("\(Formato.tokens(transferencia.tokens, unidad: "tokens"))",
                      dolares(transferencia.brutoUSD))
                linea("Comisiones", "−" + dolares(transferencia.comisionUSD), gris: true)
                linea("Neto", dolares(transferencia.netoUSD))
                linea(transferencia.cambioReal
                        ? "Cambio de Monedero el \(Formato.diaCorto(transferencia.convertido))"
                        : transferencia.cambioMinimo ? "Cambio de Monedero (mínimo)"
                        : "Cambio de Monedero (estimado)",
                      String(format: "%.4f", transferencia.cambio).replacingOccurrences(of: ".", with: ","),
                      gris: !transferencia.cambioReal)
                Divider()
                linea(transferencia.cambioMinimo ? "Recibido, como mínimo" : "Recibido",
                      Formato.euros(transferencia.euros), fuerte: true)
                if transferencia.cambioMinimo {
                    Text("Faltan los céntimos que dejaste en Monedero: el extracto no dice cuántos "
                         + "dólares costó la transferencia.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Text("Como si lo transfirieras todo: lo que dejes en Monedero también es tuyo.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Diseno.hueco3) {
                    if esMonedero {
                        cadenaMonedero
                    } else {
                    Tarjeta {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(transferencia.nombre).font(.headline)
                            Text(bonita(transferencia.fecha))
                                .font(.subheadline).foregroundStyle(.secondary)
                            Divider()
                            HStack {
                                Text("La plataforma te mandó").font(.subheadline)
                                Spacer()
                                Text(Formato.dolares(transferencia.netoUSD))
                                    .font(.subheadline.weight(.medium)).monospacedDigit()
                            }
                            HStack {
                                Text("La app calcula").font(.subheadline)
                                Spacer()
                                Text(Formato.euros(transferencia.euros))
                                    .font(.subheadline).foregroundStyle(.secondary)
                                    .monospacedDigit()
                            }
                        }
                    }

                    Tarjeta {
                        VStack(alignment: .leading, spacing: Diseno.hueco2) {
                            Campo(titulo: "Lo que llegó a tu banco (€)", valor: $importe,
                                  teclado: .decimalPad, pista: "0,00")
                            Text("Con esto la app aprende qué parte del cambio de mercado te "
                                 + "llega de verdad, y lo aplica sola a partir de ahora.")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }

                    if let aviso { Banda(texto: aviso.texto, bien: aviso.bien) }
                    }
                }
                .padding(Diseno.margen)
            }
            .fondoDePantalla()
            .salidaDelTeclado()
            .navigationTitle(esMonedero ? "Detalle" : "Lo que te llegó")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button(role: .close) { cerrar() } }
                if !esMonedero { ToolbarItem(placement: .topBarTrailing) {

                    Button {
                        Task { await guardar() }
                    } label: {
                        MarcaConfirmar(trabajando: guardando)
                    }
                    .disabled(importe.isEmpty || guardando)
                } }
            }
        }
    }

    private func bonita(_ iso: String) -> String {
        let p = iso.split(separator: "-")
        guard p.count == 3, let d = Int(p[2]), let m = Int(p[1]) else { return iso }
        let meses = ["enero","febrero","marzo","abril","mayo","junio","julio","agosto",
                     "septiembre","octubre","noviembre","diciembre"]
        return "\(d) de \(meses[max(0, min(11, m - 1))]) de \(p[0])"
    }

    private func guardar() async {
        guardando = true
        defer { guardando = false }
        do {
            let j = try await API.pedir("api/transferencias/real", metodo: "POST",
                                        cuerpo: ["plataforma": transferencia.plataforma,
                                                 "fecha": transferencia.fecha,
                                                 "euros": importe],
                                        testigo: sesion.testigo)
            let ok = j["ok"] as? Bool ?? false
            aviso = (j["mensaje"] as? String ?? "Apuntado.", ok)
            if ok {
                await alGuardar()
                try? await Task.sleep(for: .seconds(1.2))
                cerrar()
            }
        } catch {
            aviso = (error.localizedDescription, false)
        }
    }
}

private struct ColumnasEnCampo: View {
    let meses: [PantallaTransferencias.Mes]
    let elegido: String?
    let elegir: (String) -> Void

    @Environment(\.accessibilityReduceMotion) private var menosMovimiento
    @Environment(\.colorScheme) private var modo
    @State private var crecidas = false

    private static let alto: CGFloat = 96

    private var orden: [PantallaTransferencias.Mes] { Array(meses.prefix(12).reversed()) }
    private var tope: Double { max(orden.map(\.euros).max() ?? 0, 0.01) }

    var body: some View {
        HStack(alignment: .bottom, spacing: 6) {
            ForEach(Array(orden.enumerated()), id: \.element.id) { i, m in
                columna(m, i)
            }
        }
        .frame(height: Self.alto + 22, alignment: .bottom)
        .onAppear { crecidas = true }
        .sensoryFeedback(.selection, trigger: elegido)
    }

    private func columna(_ m: PantallaTransferencias.Mes, _ i: Int) -> some View {
        let mejor = m.euros >= tope - 0.005 && m.euros > 0
        let este = m.mes == elegido
        let forma = RoundedRectangle(cornerRadius: 6, style: .continuous)
        return Button { elegir(m.mes) } label: {
            VStack(spacing: 5) {
                ZStack(alignment: .bottom) {
                    forma.fill(Marcador.apoyo.opacity(0.10))
                    forma
                        .fill(LinearGradient(colors: [Diseno.verdeRelleno, Diseno.verdeRelleno.opacity(0.7)],
                                             startPoint: .top, endPoint: .bottom))
                        .overlay {
                            if modo == .light { forma.strokeBorder(.black.opacity(0.6), lineWidth: 0.75) }
                        }
                        .frame(height: max(6, Self.alto * CGFloat(m.euros / tope)))
                        .scaleEffect(x: 1, y: crecidas || menosMovimiento ? 1 : 0.04, anchor: .bottom)
                        .opacity(este ? 1 : 0.5)
                        .shadow(color: este && modo == .dark ? Diseno.verdeRelleno.opacity(0.5) : .clear,
                                radius: 6, x: 0, y: 2)
                        .animation(menosMovimiento ? nil
                                   : .spring(duration: 0.6, bounce: 0.2).delay(Double(i) * 0.03),
                                   value: crecidas)
                        .overlay(alignment: .top) {
                            if mejor {
                                Image(systemName: "star.fill")
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(.white)
                                    .padding(.top, 4)
                            }
                        }
                }
                .frame(height: Self.alto)
                Text(CobrosHucha.nombreDelMes(m.mes).prefix(3))
                    .font(.caption2.weight(este ? .bold : .regular))
                    .foregroundStyle(este ? Color.primary : Marcador.apoyo)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(CobrosHucha.nombreDelMes(m.mes, conAño: true)), \(Formato.euros(m.euros))"
                            + (mejor ? ", el mejor" : ""))
        .accessibilityAddTraits(este ? .isSelected : [])
    }
}

