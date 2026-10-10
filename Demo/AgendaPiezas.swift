import SwiftUI

enum AgendaColor {

    static func de(_ t: Tarea) -> Color {
        if t.tipo == "factura", !t.plataforma.isEmpty {
            return Diseno.colorDePlataforma(t.plataforma)
        }
        switch t.area {
        case "hacienda", "asesoria", "tuya": return Marcador.apoyo
        default: return Diseno.colorDePlataforma(t.plataforma.isEmpty ? t.area : t.plataforma)
        }
    }

    static func deParte(_ para: String) -> Color {
        para == "reserva" ? Diseno.azulRelleno : Marcador.apoyo
    }

    static func luz(cuantas: Int, atrasadas: Int) -> (clave: String, luz: Color?) {
        if cuantas == 0 { return ("calma", Joya.luzAlDia) }
        if atrasadas > 0 { return ("atrasada", Joya.luzAtrasada) }
        return ("toca", nil)
    }
}

enum AgendaSimbolo {
    static func de(_ t: Tarea) -> String {
        switch t.tipo {
        case "apartar": return "tray.and.arrow.down.fill"
        case "plataforma2_noche": return "square.and.pencil"
        case "plataforma2_llegado": return "building.columns.fill"
        case "plataforma1_llegado", "cobro": return "arrow.down.circle.fill"
        case "monedero": return "dollarsign.arrow.circlepath"
        case "cuota_asesoria", "gasto_asesoria": return "arrow.up.doc.fill"
        case "factura": return "doc.text.fill"
        case "excel_asesoria": return "tablecells.fill"
        case "revision_asesoria": return "exclamationmark.magnifyingglass"
        case "pedido_revisar": return "doc.text.magnifyingglass"
        case "pedido_cobro": return "eurosign.circle.fill"
        case "pedido_aviso": return "bell.slash.fill"
        case "trimestre": return "building.columns.fill"
        case "cuota_cargo": return "calendar.badge.clock"
        case "gasto_mes": return "repeat"
        case "propia": return "person.fill"
        default: return "checklist"
        }
    }

    static func fondo(_ t: Tarea) -> Color {
        if t.tipo == "factura", !t.plataforma.isEmpty { return Diseno.colorDePlataforma(t.plataforma) }
        switch t.area {
        case "hacienda", "asesoria", "tuya": return Color(.systemGray)
        default: return Diseno.colorDePlataforma(t.plataforma.isEmpty ? t.area : t.plataforma)
        }
    }
}

struct PuntoDeArea: View {
    let color: Color
    var lado: CGFloat = 10
    @Environment(\.colorScheme) private var modo

    @ScaledMetric(relativeTo: .body) private var escala: CGFloat = 1
    private var ladoReal: CGFloat { lado * min(max(escala, 1), 2) }

    var body: some View {
        Circle()
            .fill(color.gradient)
            .overlay {
                if modo == .light {
                    Circle().strokeBorder(.black.opacity(0.6), lineWidth: 1)
                }
            }
            .frame(width: ladoReal, height: ladoReal)
            .accessibilityHidden(true)
    }
}

enum AgendaCuando {
    
    static func de(_ t: Tarea, hoy: String) -> String {
        switch t.tipo {
        case "apartar", "plataforma2_llegado", "factura":
            return "llegó " + relativo(t.fecha, hoy: hoy)
        case "plataforma2_noche":
            switch Fechas.dias(de: t.fecha, a: hoy) {
            case 0: return "esta noche"
            case 1: return "anoche"
            default: return "la noche del \(Formato.diaSemana(t.fecha))"
            }
        case "monedero":
            let quedan = Fechas.dias(de: hoy, a: t.vence)
            return quedan <= 0 ? "último día" : "llegó \(relativo(t.fecha, hoy: hoy))"
        case "excel_asesoria":
            return "del \(AgendaTexto.trimestreBonito(t.trimestre))"
        case "revision_asesoria":
            return t.fecha.isEmpty ? "" : "revisado \(relativo(t.fecha, hoy: hoy))"
        case "plataforma1_llegado":
            
            let n = Fechas.dias(de: hoy, a: t.fecha)
            return n == 0 ? "previsto hoy" : n > 0 ? "previsto el \(Formato.diaSemana(t.fecha))"
                : "se esperaba el \(Formato.diaSemana(t.fecha))"
        case "cuota_asesoria":
            return "se cobró el \(Fechas.corta(t.fecha))"
        case "gasto_asesoria":
            return "del \(Fechas.corta(t.fecha))"
        case "pedido_revisar", "pedido_cobro", "pedido_aviso":
            return haceCuanto(t)
        case "trimestre":
            let quedan = Fechas.dias(de: hoy, a: t.vence)
            return quedan == 0 ? "vence hoy" : quedan == 1 ? "vence mañana"
                : "vence el \(Formato.diaSemana(t.vence))"
        case "propia":
            if t.fecha.isEmpty { return "" }
            let n = Fechas.dias(de: hoy, a: t.fecha)
            return n == 0 ? "para hoy" : n < 0 ? "era para el \(Formato.diaSemana(t.fecha))"
                : "para el \(Formato.diaSemana(t.fecha))"
        default:
            return t.fecha.isEmpty ? "" : Fechas.cuando(t.fecha, hoy: hoy)
        }
    }

    static func relativo(_ fecha: String, hoy: String) -> String {
        switch Fechas.dias(de: fecha, a: hoy) {
        case 0: return "hoy"
        case 1: return "ayer"
        default: return "el \(Formato.diaSemana(fecha))"
        }
    }

    private static func haceCuanto(_ t: Tarea) -> String {
        guard let iso = t.pedido?.creado, !iso.isEmpty else { return "" }
        
        let limpio = iso.replacingOccurrences(of: #"\.\d+"#, with: "", options: .regularExpression)
        
        guard let cuando = ISO8601DateFormatter().date(from: limpio) else {
            return iso.count == 16 ? PedidosPorDia.haceCuanto(iso) : ""
        }
        let seg = max(0, Date().timeIntervalSince(cuando))
        if seg < 90 { return "ahora" }
        if seg < 3600 { return "hace \(Int(seg / 60)) min" }
        if seg < 86400 { return "hace \(Int(seg / 3600)) h" }
        let d = Int(seg / 86400)
        return d == 1 ? "ayer" : "hace \(d) días"
    }
}

struct LosaDeTarea: View {
    let t: Tarea
    let hoy: String
    let trabajando: Bool
    let marcar: () -> Void
    let descartar: () -> Void
    let abrir: () -> Void
    
    let deslizar: () async -> Bool
    
    var espacio: Namespace.ID? = nil

    var hacer: () -> Void = {}
    
    var otroDia: () -> Void = {}

    var solida = false

    @ScaledMetric(relativeTo: .largeTitle) private var tamCifra: CGFloat = 44
    @Environment(\.dynamicTypeSize) private var letra

    private var color: Color { AgendaColor.de(t) }

    var body: some View {
        VStack(alignment: .leading, spacing: Diseno.hueco2) {

            HStack(alignment: .top, spacing: Diseno.hueco2) {
                FichaIcono(simbolo: AgendaSimbolo.de(t), color: AgendaSimbolo.fondo(t), lado: 40)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text(AgendaTexto.frase(t))
                        .font(.title2.weight(.bold))
                        .fixedSize(horizontal: false, vertical: true)
                    cabecera
                }
            }
            cifra
            detalle
            accion
                .padding(.top, Diseno.hueco1)
        }
        .padding(Diseno.hueco3)
        .frame(maxWidth: .infinity, alignment: .leading)

        .background {
            if solida {
                RoundedRectangle(cornerRadius: Diseno.radioTarjeta).fill(Diseno.superficie)
            } else {
                Color.clear
                    .cristal(.regular, en: .rect(cornerRadius: Diseno.radioHeroe))
                    .emparejado("losa-" + t.id, en: espacio)
            }
        }
        .accessibilityElement(children: .contain)
    }

    private var cabecera: some View {
        let cuando = AgendaCuando.de(t, hoy: hoy)
        
        let area = HStack(alignment: .firstTextBaseline, spacing: 7) {
            Text(AgendaTexto.area(t))
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .fixedSize()
        }

        let atrasada = Label {
            Text("Atrasada").foregroundStyle(Color.primary)
        } icon: {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(.white, Diseno.rojoRelleno)
        }
        .font(.footnote.weight(.semibold))
        return ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline, spacing: 7) {
                area
                if !cuando.isEmpty {
                    Text("· " + cuando)
                        .font(.subheadline)
                        .foregroundStyle(Marcador.apoyo)
                        .lineLimit(1)
                        .fixedSize()
                }
                Spacer(minLength: 0)
                if t.atrasada { atrasada.fixedSize() }
            }
            VStack(alignment: .leading, spacing: 2) {
                area
                if !cuando.isEmpty {
                    Text(cuando)
                        .font(.subheadline)
                        .foregroundStyle(Marcador.apoyo)
                }
                if t.atrasada { atrasada }
            }
        }
    }

    @ViewBuilder
    private var cifra: some View {
        if let p = t.pedido, !p.importe.isEmpty {
            
            Text(Formato.importe(p.importe))
                .font(.system(size: min(tamCifra, 60), weight: .bold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1).minimumScaleFactor(0.5)
        } else if let usd = t.usd, t.tipo == "monedero" || t.tipo == "plataforma1_llegado" {
            Text(Formato.dolares(usd))
                .font(.system(size: min(tamCifra, 60), weight: .bold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1).minimumScaleFactor(0.5)
        } else if let e = t.euros, e > 0 {
            Text((t.aprox ? "≈ " : "") + Formato.euros(e))
                .font(.system(size: min(tamCifra, 60), weight: .bold, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText(value: e))
                .lineLimit(1).minimumScaleFactor(0.5)
        }
    }

    @ViewBuilder
    private var detalle: some View {
        switch t.tipo {
        case "apartar":
            VStack(alignment: .leading, spacing: 6) {
                if t.partes.count == 1, let p = t.partes.first {
                    Label(textoParte(p), systemImage: simboloParte(p.para))
                        .foregroundStyle(Color.primary)
                } else {
                    
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: Diseno.hueco2) { partes }
                        VStack(alignment: .leading, spacing: 4) { partes }
                    }
                }
                if let c = t.cobroEuros {
                    Text("De los \(Formato.euros(c)) que llegaron"
                         + (t.cobroEtiqueta.isEmpty ? "" : " · \(t.cobroEtiqueta.lowercasedPrimera)"))
                        .foregroundStyle(Marcador.apoyo)
                }
            }
            .font(.subheadline)
        case "plataforma2_noche":
            if t.nocheMinutos > 0 {
                Label("En Plataforma 1 emitiste \(Formato.duracion(Double(t.nocheMinutos) / 60))",
                      systemImage: "video.fill")
                    .font(.subheadline).foregroundStyle(Marcador.apoyo)
            }
        case "plataforma2_llegado":
            Text("Hasta que lo apuntes, Impuestos cuenta con lo estimado.")
                .font(.subheadline).foregroundStyle(Marcador.apoyo)
        case "excel_asesoria":
            
            Text("Al subirlo, la app lo revisa todo y mete en Impuestos los gastos que falten.")
                .font(.subheadline).foregroundStyle(Marcador.apoyo)
        case "revision_asesoria":
            let partes = [t.errores > 0 ? "\(t.errores) \(t.errores == 1 ? "cosa no cuadra" : "cosas no cuadran")" : "",
                          t.avisos > 0 ? "\(t.avisos) por subir o sin factura" : ""].filter { !$0.isEmpty }
            Text(partes.joined(separator: " · "))
                .font(.subheadline).foregroundStyle(Marcador.apoyo)
        case "plataforma1_llegado":
            
            Text((t.detalle.isEmpty ? "" : "\(t.detalle) · ")
                 + "La factura va con el cambio del día en que llegó: la app hace el borrador "
                 + "en cuanto el BCE lo publica.")
                .font(.subheadline).foregroundStyle(Marcador.apoyo)
        case "pedido_revisar", "pedido_cobro", "pedido_aviso":
            VStack(alignment: .leading, spacing: 4) {
                let trozos = [t.pedido?.que ?? "", t.tipo == "pedido_revisar" ? "" : t.pedido?.metodo ?? ""]
                    .filter { !$0.isEmpty }
                if !trozos.isEmpty {
                    Text(trozos.joined(separator: " · "))
                        .foregroundStyle(Marcador.apoyo)
                }
                if t.pedido?.faltaPrecio ?? false {
                    Label {
                        Text("Ponle precio al extra que pide").foregroundStyle(Color.primary)
                    } icon: {
                        Image(systemName: "exclamationmark.circle.fill")
                            .foregroundStyle(.white, Diseno.naranjaRelleno)
                    }
                }
                if t.tipo == "pedido_aviso" {
                    Text("El bot no puede escribirle: escríbele tú.")
                        .foregroundStyle(Marcador.apoyo)
                }
            }
            .font(.subheadline)
        case "trimestre":
            VStack(alignment: .leading, spacing: 4) {
                Text(modelos).foregroundStyle(Marcador.apoyo)
                listo
                comprobadoConAsesoria
            }
            .font(.subheadline)
        case "factura":
            if let c = t.cobroEuros {
                Text("Del cobro de \(Formato.euros(c))"
                     + (t.cobroEtiqueta.isEmpty ? "" : " · \(t.cobroEtiqueta.lowercasedPrimera)"))
                    .font(.subheadline).foregroundStyle(Marcador.apoyo)
            }
        default:
            EmptyView()
        }
    }

    @ViewBuilder
    private var partes: some View {
        ForEach(t.partes) { p in
            HStack(spacing: 5) {
                PuntoDeArea(color: AgendaColor.deParte(p.para), lado: 7)
                Text("\(Formato.euros(p.euros)) \(nombreParte(p))")
                    .monospacedDigit()
            }
            .fixedSize()
        }
    }

    private func nombreParte(_ p: Tarea.Parte) -> String {
        switch p.para {
        case "hacienda": return "Hacienda"
        case "cuota": return "cuota"
        default: return "Reserva"
        }
    }

    private func textoParte(_ p: Tarea.Parte) -> String {
        switch p.para {
        case "hacienda": return "Para Hacienda"
        case "cuota": return "Para la cuota de \(AgendaTexto.nombreDelMes(p.mes))"
        default: return "Para la Reserva"
        }
    }

    private func simboloParte(_ para: String) -> String {
        para == "reserva" ? "drop.fill" : "building.columns.fill"
    }

    private var modelos: String {
        var trozos: [String] = []
        if let m = t.m130 { trozos.append(m > 0 ? "130: \(Formato.euros(m))" : "130: nada") }
        if let m = t.m303 {
            trozos.append(m > 0 ? "303: \(Formato.euros(m))" : m < 0 ? "303: a compensar" : "303: nada")
        }
        return trozos.joined(separator: " · ")
    }

    @ViewBuilder
    private var listo: some View {
        if let n = t.necesario, n > 0.004 {
            let a = t.apartado ?? 0
            if a + 0.005 >= n {
                Label {
                    Text("Lo de Hacienda, apartado entero").foregroundStyle(Color.primary)
                } icon: {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.white, Diseno.verdeRelleno)
                }
            } else {
                Label {
                    Text("Llevas apartados \(Formato.euros(a)) de \(Formato.euros(n))")
                        .foregroundStyle(Color.primary)
                } icon: {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundStyle(.white, Diseno.naranjaRelleno)
                }
            }
        }
    }

    @ViewBuilder
    private var comprobadoConAsesoria: some View {
        let (texto, simbolo, color): (String, String, Color) = {
            switch t.comprobado {
            case "bien": return ("Comprobado con la gestoría: cuadra", "checkmark.seal.fill",
                                 Diseno.verdeRelleno)
            case "cambiar": return ("Comprobado con la gestoría: hay que cambiar algo",
                                    "exclamationmark.triangle.fill", Diseno.naranjaRelleno)
            default: return ("Sin comprobar con la gestoría", "seal", Marcador.apoyo)
            }
        }()
        Label {
            Text(texto).foregroundStyle(Color.primary)
        } icon: {
            Image(systemName: simbolo).foregroundStyle(color)
        }
    }

    @ViewBuilder
    private var accion: some View {
        if let a = t.accion {
            switch a.tipo {
            case "deslizar":
                DeslizarParaConfirmar(texto: a.texto,
                                      icono: a.pedido == "aprobar" ? "checkmark" : "eurosign",
                                      color: Diseno.verdeRelleno, trabajando: trabajando,
                                      colorTexto: Color.primary,
                                      accion: deslizar)

                    .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                if let o = t.otra {
                    
                    Button { abrir() } label: {
                        HStack(spacing: 4) {
                            Text(o.destino == "pedido" ? "Ver el pedido" : o.texto)
                            Image(systemName: "chevron.right").imageScale(.small)
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.primary)
                        .frame(minHeight: 44)
                        .contentShape(.rect)
                    }
                    .buttonStyle(Hundirse())
                    .disabled(trabajando)
                }
            default:
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: Diseno.hueco2) { botones(a) }
                    VStack(alignment: .leading, spacing: Diseno.hueco2) { botones(a) }
                }
            }
        }
    }

    @ViewBuilder
    private func botones(_ a: Tarea.Accion) -> some View {
        Button {
            switch a.tipo {
            case "marcar": marcar()
            case "excel", "presentado": hacer()
            default: abrir()
            }
        } label: {
            HStack(spacing: 7) {
                if trabajando {
                    ProgressView().controlSize(.small).tint(.white)
                } else {
                    Image(systemName: Self.simbolo(a.tipo))
                        .fontWeight(.bold)
                }
                Text(a.texto)
            }
            .font(.body.weight(.semibold))
            .padding(.horizontal, 6)
        }

        .buttonStyle(.borderedProminent)
        .buttonBorderShape(.capsule)
        .controlSize(.large)
        .rellenoDelTema()
        .disabled(trabajando)
        if let o = t.otra { secundario(o) }
        if t.tipo == "factura", let e = t.euros, e > 0 { CopiarCifra(valor: e) }
    }

    private static func simbolo(_ tipo: String) -> String {
        switch tipo {
        case "marcar": return "checkmark"
        case "excel": return "arrow.down"
        case "presentado": return "checkmark.seal"
        default: return "arrow.right"
        }
    }

    private func secundario(_ o: Tarea.Accion) -> some View {
        Button(o.texto) {
            switch o.tipo {
            case "descartar": descartar()
            case "fecha": otroDia()
            default: abrir()
            }
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.capsule)
        .controlSize(.large)
        .tint(Color.primary)
        .disabled(trabajando)
    }
}

struct LosaAlDia: View {
    let siguiente: Tarea?
    let hoy: String
    @Environment(\.accessibilityReduceMotion) private var menosMovimiento
    @Environment(\.tema) private var tema
    @State private var dibujada = false

    var body: some View {
        HStack(alignment: .center, spacing: Diseno.hueco3) {
            ZStack {
                Circle().fill(tema.relleno.gradient)
                if dibujada || menosMovimiento {
                    Image(systemName: "checkmark")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(tema.sobreRelleno)
                        .transition(.symbolEffect(.drawOn))
                }
            }
            .frame(width: 64, height: 64)
            .shadow(color: tema.relleno.opacity(0.45), radius: 8, x: 0, y: 3)
            .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text("Al día").font(.title2.weight(.bold))
                if let s = siguiente {
                    Text("Lo siguiente: \(AgendaTexto.frase(s).lowercasedPrimera), "
                         + Fechas.cuando(s.fecha, hoy: hoy)
                         + (s.euros.map { " · " + (s.aprox ? "≈ " : "") + Formato.euros($0) } ?? ""))
                        .font(.subheadline)
                        .foregroundStyle(Marcador.apoyo)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text("Nada pendiente")
                        .font(.subheadline)
                        .foregroundStyle(Marcador.apoyo)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(Diseno.hueco3)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cristal(.regular, en: .rect(cornerRadius: Diseno.radioHeroe))

        .onAppear {
            if menosMovimiento { dibujada = true; return }
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(250))
                withAnimation(.smooth(duration: 0.6)) { dibujada = true }
            }
        }
        .accessibilityElement(children: .combine)
    }
}

struct FilaDeTarea: View {
    let t: Tarea
    let hoy: String
    let trabajando: Bool
    let elegir: () -> Void
    let marcar: () -> Void
    var espacio: Namespace.ID? = nil

    @State private var tocado = false
    @Environment(\.tema) private var tema

    var body: some View {
        HStack(spacing: Diseno.hueco2) {
            Button(action: elegir) {
                HStack(spacing: Diseno.hueco2) {
                    FichaIcono(simbolo: AgendaSimbolo.de(t), color: AgendaSimbolo.fondo(t), lado: 30)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(AgendaTexto.frase(t))
                            .font(.headline)
                            .foregroundStyle(Color.primary)
                            .lineLimit(2)
                        HStack(spacing: 4) {
                            if t.atrasada {
                                Image(systemName: "exclamationmark.circle.fill")
                                    .foregroundStyle(.white, Diseno.rojoRelleno)
                                    .accessibilityHidden(true)
                            }
                            Text(pie)
                                .foregroundStyle(Marcador.apoyo)
                                .lineLimit(1)
                        }
                        .font(.footnote)
                    }
                    Spacer(minLength: Diseno.hueco1)
                    if let e = t.euros, e > 0 {
                        Text((t.aprox ? "≈ " : "") + Formato.eurosJustos(e))
                            .font(.system(.headline, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(Color.primary)
                    }
                }
                .padding(.vertical, Diseno.hueco2)
                .contentShape(.rect)
            }
            .buttonStyle(Hundirse())
            .accessibilityHint("La pone arriba")

            if t.accion?.tipo == "marcar" {
                Button {
                    tocado = true
                    marcar()
                } label: {
                    ZStack {
                        if trabajando {
                            ProgressView().controlSize(.small)
                        } else {
                            Image(systemName: tocado ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 26))
                                .foregroundStyle(tocado ? AnyShapeStyle(tema.relleno)
                                                        : AnyShapeStyle(Marcador.apoyo))
                                .contentTransition(.symbolEffect(.replace))
                        }
                    }
                    .frame(width: 44, height: 44)
                    .contentShape(.rect)
                }
                .buttonStyle(.borderless)
                .disabled(trabajando)
                .accessibilityLabel(t.accion?.texto ?? "Hecho")
            }
        }
        .background {
            
            Color.clear.emparejado("losa-" + t.id, en: espacio)
        }
        .onChange(of: trabajando) { _, ahora in if !ahora { tocado = false } }
    }

    private var pie: String {
        let cuando = AgendaCuando.de(t, hoy: hoy)
        let area = AgendaTexto.area(t)
        if t.atrasada { return "Atrasada · " + cuando }
        return cuando.isEmpty ? area : "\(area) · \(cuando)"
    }
}

struct FilaQueViene: View {
    let t: Tarea
    let hoy: String
    
    var conFlecha = false

    var body: some View {
        HStack(spacing: Diseno.hueco2) {
            AnilloDeDias(dias: t.dias ?? Fechas.dias(de: hoy, a: t.fecha), color: AgendaColor.de(t))
            VStack(alignment: .leading, spacing: 2) {
                Text(AgendaTexto.frase(t))
                    .font(.headline)
                    .foregroundStyle(Color.primary)
                    .lineLimit(2)
                Text(pie)
                    .font(.footnote)
                    .foregroundStyle(Marcador.apoyo)
                    .lineLimit(2)
            }
            Spacer(minLength: Diseno.hueco1)
            if let e = t.euros, e > 0 {
                Text((t.aprox ? "≈ " : "") + Formato.eurosJustos(e))
                    .font(.system(.headline, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Color.primary)
            }
            if conFlecha {
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Marcador.apoyo)
            }
        }
        .padding(.vertical, Diseno.hueco2)
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
    }

    private var pie: String {
        var trozos = [Fechas.larga(t.fecha).capitalizandoPrimera]
        switch t.tipo {
        case "cobro": if !t.detalle.isEmpty { trozos.append(t.detalle) }
        case "trimestre": trozos.append("el plazo")
        case "propia": trozos.append("tuya")
        default: break
        }
        return trozos.joined(separator: " · ")
    }
}

struct AnilloDeDias: View {
    let dias: Int
    let color: Color

    @Environment(\.accessibilityReduceMotion) private var menosMovimiento
    @Environment(\.colorScheme) private var modo
    @ScaledMetric(relativeTo: .headline) private var lado: CGFloat = 40
    @State private var cerrado: Double = 0

    private var hecho: Double { min(1, max(0.06, 1 - Double(max(dias, 0)) / 30)) }

    var body: some View {
        ZStack {
            Circle().stroke(Marcador.apoyo.opacity(0.16), lineWidth: 4)

            if modo == .light {
                Circle()
                    .trim(from: 0, to: cerrado)
                    .stroke(.black.opacity(0.6), style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
            Circle()
                .trim(from: 0, to: cerrado)
                .stroke(color.gradient, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .shadow(color: modo == .dark ? color.opacity(0.5) : .clear,
                        radius: 3, x: 0, y: 1)
            Group {
                if dias <= 0 {
                    Text("hoy").font(.system(.caption2, design: .rounded).weight(.bold))
                } else {
                    Text("\(dias)")
                        .font(.system(.callout, design: .rounded).weight(.bold))
                        .monospacedDigit()
                }
            }
            .minimumScaleFactor(0.6)
            .padding(5)
        }
        .frame(width: lado, height: lado)
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
        .onAppear {
            if menosMovimiento { cerrado = hecho; return }
            withAnimation(.easeOut(duration: 0.9).delay(0.15)) { cerrado = hecho }
        }
        .accessibilityLabel(dias <= 0 ? "hoy" : dias == 1 ? "falta 1 día" : "faltan \(dias) días")
    }
}

struct BandaDeshacer: View {
    let texto: String
    let deshacer: (() -> Void)?

    var body: some View {
        HStack(spacing: Diseno.hueco2) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Diseno.verde)
            Text(texto)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
            Spacer(minLength: Diseno.hueco1)
            if let deshacer {

                Button(action: deshacer) {
                    Text("Deshacer").underline()
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.primary)
                .frame(minHeight: 44)
            }
        }
        .padding(.leading, Diseno.hueco3)
        .padding(.trailing, Diseno.hueco2)
        .frame(minHeight: 52)
        .cristal(.regular, en: .capsule)
        .padding(.horizontal, Diseno.margen)
        .accessibilityElement(children: .contain)
    }
}

struct HojaDiaDeLlegada: View {
    let tarea: Tarea
    let confirmar: (_ dia: String) async -> Void

    @Environment(\.dismiss) private var cerrar
    @State private var dia = Date()
    @State private var trabajando = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("Llegó el", selection: $dia, in: ...Date(), displayedComponents: .date)
                        .datePickerStyle(.compact)
                } footer: {
                    if !tarea.fecha.isEmpty {
                        Text("Se esperaba el \(Fechas.corta(tarea.fecha)). La factura y el cambio de "
                             + "Monedero van con el día que pongas.")
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .navigationTitle("¿Qué día llegó?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .close) { cerrar() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task {
                            trabajando = true
                            await confirmar(HojaTareaPropia.iso(dia))
                            trabajando = false
                            cerrar()
                        }
                    } label: { MarcaConfirmar(trabajando: trabajando) }
                    .disabled(trabajando)
                }
            }
        }
        .onAppear {
            if let previsto = Fechas.fecha(tarea.fecha), previsto <= Date() { dia = previsto }
        }
    }
}

struct HojaTareaPropia: View {
    
    var existente: Tarea?
    let guardar: (_ texto: String, _ fecha: String) async -> (ok: Bool, mensaje: String)
    var borrar: (() async -> Void)?

    @Environment(\.dismiss) private var cerrar
    @State private var texto = ""
    @State private var conFecha = false
    @State private var fecha = Date()
    @State private var guardando = false
    @State private var fallo: String?
    @State private var preguntarBorrar = false
    @FocusState private var escribiendo: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("¿Qué tienes que hacer?",
                              text: $texto, axis: .vertical)
                        .lineLimit(1...4)
                        .focused($escribiendo)
                        .submitLabel(.done)
                }
                Section {
                    Toggle("Para un día", isOn: $conFecha.animation(Diseno.suave))
                    if conFecha {
                        
                        DatePicker("Día", selection: $fecha, in: Date()..., displayedComponents: .date)
                            .datePickerStyle(.compact)
                    }
                } footer: {
                    if let fallo {
                        Text(fallo).foregroundStyle(Diseno.rojo)
                    }
                }
                if borrar != nil, existente != nil {
                    Section {

                        Button("Borrar", role: .destructive) { preguntarBorrar = true }
                    }
                }
            }
            .scrollContentBackground(.hidden)

            .salidaDelTeclado()
            .confirmationDialog("¿Borrar esta tarea?", isPresented: $preguntarBorrar,
                                titleVisibility: .visible) {
                Button("Borrar", role: .destructive) {
                    Task { await borrar?(); cerrar() }
                }
            } message: {
                Text("Se borra de la Agenda y no vuelve.")
            }
            .navigationTitle(existente == nil ? "Nueva" : "Cambiar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .close) { cerrar() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button { Task { await confirmar() } } label: {
                        MarcaConfirmar(trabajando: guardando)
                    }
                    .disabled(texto.trimmingCharacters(in: .whitespaces).isEmpty || guardando)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .onAppear {
            if let t = existente {
                texto = t.titulo
                if !t.fecha.isEmpty, let f = Fechas.fecha(t.fecha) {
                    conFecha = true
                    fecha = f
                }
            }
            escribiendo = existente == nil
        }
    }

    private func confirmar() async {
        guardando = true
        defer { guardando = false }
        let iso = conFecha ? Self.iso(fecha) : ""
        let r = await guardar(texto, iso)
        if r.ok { cerrar() } else { fallo = r.mensaje }
    }

    static func iso(_ f: Date) -> String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: f)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }
}

extension View {

    @ViewBuilder
    func emparejado(_ id: String, en espacio: Namespace.ID?) -> some View {
        if let espacio {
            matchedGeometryEffect(id: id, in: espacio)
        } else {
            self
        }
    }
}

struct CopiarCifra: View {
    let valor: Double
    @State private var copiado = false

    var body: some View {
        Button {
            #if canImport(UIKit)
            UIPasteboard.general.string = CuentaIVA.paraPegar(valor)
            #endif
            copiado = true
            Task {
                try? await Task.sleep(for: .seconds(1.8))
                copiado = false
            }
        } label: {
            Label(copiado ? "Copiada" : "Copiar la cifra",
                  systemImage: copiado ? "checkmark" : "doc.on.doc")
                .contentTransition(.symbolEffect(.replace))
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.capsule)
        .controlSize(.large)
        .tint(Color.primary)
        .sensoryFeedback(.success, trigger: copiado) { _, nuevo in nuevo }
        .accessibilityLabel(copiado ? "Copiada" : "Copiar \(CuentaIVA.paraPegar(valor)) euros")
    }
}
