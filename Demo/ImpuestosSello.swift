import SwiftUI

struct ImpuestosSello: View {
    let d: DatosImpuestos
    let aviso: String?

    let trabajando: String?

    let notaExcel: (texto: String, bien: Bool)?
    let descargarExcel: () -> Void
    
    let preguntarGestoria: () -> Void
    
    let verDetalle: () -> Void
    let marcar: (DatosImpuestos.Cobro) -> Void
    let recargar: () async -> Void

    let datos: Binding<DatosImpuestos?>

    @ScaledMetric(relativeTo: .largeTitle) private var tamCifra: CGFloat = 64
    @Environment(\.colorScheme) private var modo

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            heroe
                .padding(.top, Diseno.hueco2)
            if let aviso {
                Label {
                    Text(aviso).foregroundStyle(Color.primary)
                } icon: {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(Diseno.rojoRelleno)
                }
                .font(.subheadline)
                .padding(.top, Diseno.hueco2)
            }
            if d.estado != "futuro" {
                SelloAsesoria(d: d, trabajando: trabajando, notaExcel: notaExcel,
                             descargarExcel: descargarExcel, preguntarGestoria: preguntarGestoria,
                             verDetalle: verDetalle)
                    .padding(.top, Diseno.hueco3)
            }
            if !d.cuotas.isEmpty { cuota }
            filas
                .padding(.top, Diseno.hueco4)
        }
    }

    private var presentado: Bool { d.estado == "presentado" || d.presentadoTotal != nil }

    private var heroe: some View {
        VStack(alignment: .leading, spacing: Diseno.hueco1) {

            ViewThatFits(in: .horizontal) {
                HStack(alignment: .center) {
                    lineaDeEstado.fixedSize()
                    Spacer(minLength: Diseno.hueco1)
                    pastilla
                }
                VStack(alignment: .leading, spacing: Diseno.hueco1) {
                    lineaDeEstado
                    pastilla
                }
            }
            Text(Formato.euros(d.presentadoTotal ?? d.total))
                .font(.system(size: min(tamCifra, 88), weight: .bold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.45)
                .contentTransition(.numericText(value: d.presentadoTotal ?? d.total))
                .accessibilityLabel("A pagar, \(Formato.euros(d.presentadoTotal ?? d.total))")

            if d.presentadoTotal == nil, let linea = composicion {
                Text(linea)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Marcador.apoyo)
                    .monospacedDigit()
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            if d.hayApartar && d.necesario > 0.004 && (!presentado || presentadoSinPagar) {
                apartadoParaPagar
            }
        }
    }

    private var composicion: String? {
        let r130 = d.m130["resultado"] ?? 0
        let r303 = d.m303["resultado"] ?? 0
        var pagas: [String] = []
        if r130 > 0.004 { pagas.append("IRPF \(Formato.euros(r130))") }
        if r303 > 0.004 { pagas.append("IVA \(Formato.euros(r303))") }
        var trozos = pagas.count > 1 || r303 < -0.004 ? [pagas.joined(separator: " + ")] : []
        if r303 < -0.004 {
            let acumulado = (d.m303["a_compensar"] ?? 0) + (d.m303["a_devolver"] ?? 0)
            let cifra = acumulado > 0.004 ? acumulado : -r303
            trozos.append(DatosImpuestos.corto(d.trimestre) == "4T"
                          ? "te devuelven \(Formato.euros(cifra)) de IVA"
                          : "\(Formato.euros(cifra)) de IVA a compensar")
        }
        let linea = trozos.filter { !$0.isEmpty }.joined(separator: " · ")
        return linea.isEmpty ? nil : linea
    }

    private var lineaDeEstado: some View {
        Label {
            Text(estado).foregroundStyle(Color.primary)
        } icon: {
            Image(systemName: estadoIcono).foregroundStyle(estadoColor)
        }
        .font(.subheadline.weight(.semibold))
    }

    @ViewBuilder
    private var pastilla: some View {
        if !presentado {
            PastillaDeCristal(texto: "previsión", icono: "plusminus")
        }
    }

    private var presentadoSinPagar: Bool { d.presentadoTotal != nil && d.estado == "por_presentar" }

    private var estado: String {
        if presentadoSinPagar { return "Presentado · se paga el \(Fechas.larga(d.plazo))" }
        switch d.estado {
        case "presentado": return "Presentado"
        case "futuro": return "Aún no ha empezado"
        default: return "A pagar el \(Fechas.larga(d.plazo))"
        }
    }

    private var estadoIcono: String {
        if presentadoSinPagar { return "checkmark.seal" }
        switch d.estado {
        case "presentado": return "checkmark.seal"
        case "por_presentar": return "calendar.badge.exclamationmark"
        default: return "calendar"
        }
    }

    private var estadoColor: Color {
        d.estado == "por_presentar" && !presentadoSinPagar ? Diseno.naranjaRelleno : Marcador.apoyo
    }

    private var apartadoParaPagar: some View {
        let total = max(d.necesario, 0.01)
        let verde = min(d.apartado, total)
        let azul = max(0, min(d.yaLlegado, total) - verde)
        let todo = d.apartado >= d.necesario - 0.005
        return VStack(alignment: .leading, spacing: 7) {
            GeometryReader { g in
                let w = g.size.width
                ZStack(alignment: .leading) {
                    Capsule().fill(Marcador.apoyo.opacity(0.16))
                    Capsule().fill(Diseno.azulRelleno)
                        .frame(width: max(0, w * CGFloat((verde + azul) / total)))
                        .opacity(azul > 0.004 ? 1 : 0)
                    Capsule().fill(Diseno.verdeRelleno.gradient)
                        .frame(width: max(0, w * CGFloat(verde / total)))
                        .opacity(verde > 0.004 ? 1 : 0)
                }

                .overlay {
                    if modo == .light {
                        Capsule().strokeBorder(.black.opacity(0.6), lineWidth: 0.75)
                    }
                }
            }
            .frame(height: 8)
            .animation(.smooth(duration: 0.6), value: d.apartado)
            .accessibilityHidden(true)
            Label {
                Text(todo ? "Todo apartado"
                     : d.apartado > 0.004 ? "\(Formato.euros(d.apartado)) apartados" : "Nada apartado")
                    .foregroundStyle(Color.primary)
            } icon: {
                if todo {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.white, Diseno.verdeRelleno)
                } else {
                    PuntoDeArea(color: d.apartado > 0.004 ? Diseno.verdeRelleno : Marcador.apoyo, lado: 8)
                }
            }
            .font(.footnote.weight(.medium))
            .monospacedDigit()
            .contentTransition(.numericText())
        }
        .padding(.top, Diseno.hueco1)
    }

    private var cuota: some View {
        VStack(alignment: .leading, spacing: 0) {
            TituloDeSeccion(texto: "Cuota de autónomo",
                            dato: "\(Formato.euros(d.cuotas.first?.cuota ?? 0)) al mes")
            HStack(alignment: .top, spacing: 0) {
                ForEach(d.cuotas) { c in
                    AnilloCuota(cuota: c, enTinta: true)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.top, Diseno.hueco2)
        }
    }

    private var filas: some View {
        VStack(spacing: 0) {
            NavigationLink {
                PantallaGastos(trimestre: d.trimestre, alCambiar: { await recargar() })
            } label: {
                filaAcceso("cart.fill", "Gastos", Formato.euros(d.gastos))
            }
            .buttonStyle(Hundirse())
            Divider().padding(.leading, 34)
            NavigationLink {
                PantallaIngresosImpuestos(datos: datos, marcar: marcar, recargar: recargar)
            } label: {
                filaAcceso("arrow.down.to.line", "Ingresos", Formato.euros(d.ingresos))
            }
            .buttonStyle(Hundirse())
            Divider().padding(.leading, 34)
            NavigationLink {
                PantallaPorQueImpuestos(d: d)
            } label: {
                filaAcceso("list.bullet.indent", "Por qué pagas esto", "")
            }
            .buttonStyle(Hundirse())
        }
    }

    private func filaAcceso(_ icono: String, _ titulo: String, _ valor: String) -> some View {
        HStack(spacing: Diseno.hueco2) {
            Image(systemName: icono)
                .font(.body)
                .foregroundStyle(Marcador.apoyo)
                .frame(width: 22)
            Text(titulo).foregroundStyle(Color.primary)
            Spacer(minLength: Diseno.hueco1)
            Text(valor)
                .font(.system(.subheadline, design: .rounded).weight(.medium))
                .monospacedDigit()
                .foregroundStyle(Marcador.apoyo)
                .contentTransition(.numericText())
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Marcador.apoyo)
        }
        .frame(minHeight: 48)
        .contentShape(.rect)
    }
}

struct SelloAsesoria: View {
    let d: DatosImpuestos
    let trabajando: String?
    let notaExcel: (texto: String, bien: Bool)?
    let descargarExcel: () -> Void
    let preguntarGestoria: () -> Void
    let verDetalle: () -> Void

    @Environment(\.accessibilityReduceMotion) private var menosMovimiento
    @State private var estampado = true

    enum Estado: Equatable {
        case cuadra, noCuadra, sinComprobar, igualQueLoPresentado, distintoDeLoPresentado, sinApuntar

        case enParte
    }

    private var conLoPresentado: Bool { d.gestoriaCoincide != nil }
    
    private var sinApuntar: Bool { !conLoPresentado && d.estado == "presentado" }
    
    private var abierto: Bool { d.abierto }

    private var app130: Double { d.m130["resultado"] ?? 0 }

    private var app303: Double {
        let r = d.m303["resultado"] ?? 0
        if conLoPresentado { return r }

        if d.asesoria303Que == "trimestre" { return d.app303Trimestre ?? r }
        return d.app303Acumulado ?? r
    }

    private var cuarto: Bool { DatosImpuestos.corto(d.trimestre) == "4T" }

    private var suyo130: Double? {
        guard conLoPresentado else { return d.asesoria130 }
        return d.gestoriaCoincide == true ? (d.gestoriaApp130 ?? app130) : d.gestoria130
    }

    private var suyo303: Double? {
        guard conLoPresentado else { return d.asesoria303 }
        return d.gestoriaCoincide == true ? (d.gestoriaApp303 ?? app303) : d.gestoria303
    }

    private var pares: [(Double, Double)] {
        [(app130, suyo130), (app303, suyo303)].compactMap { a, s in s.map { (a, $0) } }
    }

    private var iguales: Bool { pares.allSatisfy { abs($0.0 - $0.1) < 0.01 } }

    private var numerosMasNuevos: Bool {
        !d.asesoriaCuando.isEmpty && d.asesoriaCuando >= d.comprobadoCuando
    }

    private var cambiarDespues: Bool {
        d.ultimaVeredicto == "cambiar" && d.ultimaCuando > max(d.asesoriaCuando, d.comprobadoCuando)
    }

    var estado: Estado {
        if conLoPresentado { return iguales ? .igualQueLoPresentado : .distintoDeLoPresentado }
        if cambiarDespues { return .noCuadra }
        if !pares.isEmpty && numerosMasNuevos {
            
            let mismaVez = d.asesoriaCuando == d.comprobadoCuando
            if mismaVez && d.comprobadoVeredicto == "cambiar" { return .noCuadra }
            return iguales ? .cuadra : .noCuadra
        }
        switch d.comprobadoVeredicto {
        case "bien": return .cuadra
        case "cambiar": return .noCuadra
        default: break
        }
        
        switch d.ultimaVeredicto {
        case "bien": return .enParte
        case "cambiar": return .noCuadra
        default: return sinApuntar ? .sinApuntar : .sinComprobar
        }
    }

    private var cambioDesdeLaComprobacion: Bool {
        guard !conLoPresentado, numerosMasNuevos else { return false }
        let antes = [(app130, d.asesoriaApp130), (app303, d.asesoriaApp303)]
        return antes.contains { ahora, entonces in
            entonces.map { abs($0 - ahora) >= 0.01 } ?? false
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Diseno.hueco3) {
            cabecera
            tabla
            if let nota { notaAlPie(nota) }
            botones
        }
        .padding(Diseno.hueco3)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            Color.clear.cristal(.regular, en: .rect(cornerRadius: Diseno.radioHeroe))
        }
        .onChange(of: marca, estampar)
        .sensoryFeedback(.success, trigger: sellos)
    }

    private struct Marca: Equatable {
        let estado: Estado
        let trimestre: String
        let cuando: String
    }

    private var marca: Marca {
        Marca(estado: estado, trimestre: d.trimestre, cuando: max(d.comprobadoCuando, d.asesoriaCuando))
    }

    @State private var sellos = 0

    private static func pasaASellar(_ antes: Estado, _ ahora: Estado) -> Bool {
        antes != ahora && (ahora == Estado.cuadra || ahora == Estado.igualQueLoPresentado)
    }

    private func estampar(_ antes: Marca, _ ahora: Marca) {
        guard antes.trimestre == ahora.trimestre else { return }
        let otraVez = antes.estado == .cuadra && ahora.estado == .cuadra && ahora.cuando > antes.cuando
        guard Self.pasaASellar(antes.estado, ahora.estado) || otraVez else { return }
        sellos += 1
        
        AccessibilityNotification.Announcement(titulo).post()
        guard !menosMovimiento else { return }
        estampado = false
        withAnimation(.spring(duration: 0.45, bounce: 0.45)) { estampado = true }
    }

    @Environment(\.dynamicTypeSize) private var tamLetra

    @ViewBuilder
    private var cabecera: some View {
        if tamLetra.isAccessibilitySize {
            VStack(alignment: .leading, spacing: Diseno.hueco2) {
                sello
                textosDeCabecera
            }
        } else {
            HStack(alignment: .center, spacing: Diseno.hueco2) {
                sello
                textosDeCabecera
                Spacer(minLength: 0)
            }
        }
    }

    private var textosDeCabecera: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(titulo)
                .font(.title2.weight(.bold))
                .contentTransition(.opacity)
            if let sub = subtitulo {
                Text(sub)
                    .font(.footnote)
                    .foregroundStyle(Marcador.apoyo)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if hayQueMirar {
                Button(action: verDetalle) {
                    HStack(spacing: 3) {
                        Text("Ver el detalle")
                        Image(systemName: "chevron.right").imageScale(.small)
                    }
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color.primary)

                    .frame(minHeight: 44)
                    .contentShape(.rect)
                }
                .buttonStyle(Hundirse())
            }
        }
    }

    private var hayQueMirar: Bool {
        guard !conLoPresentado, subtitulo != nil else { return false }
        switch estado {
        case .noCuadra, .enParte: return true
        case .cuadra: return d.comprobadoAvisos > 0
        default: return false
        }
    }

    private var sello: some View {
        let (simbolo, color): (String, Color) = {
            switch estado {
            case .cuadra, .igualQueLoPresentado: return ("checkmark.seal.fill", Diseno.verdeRelleno)
            case .noCuadra: return ("exclamationmark.triangle.fill", Diseno.naranjaRelleno)
            
            case .distintoDeLoPresentado: return ("seal", Color.secondary)
            case .enParte: return ("checkmark.seal", Color.secondary)
            case .sinComprobar, .sinApuntar: return ("seal", Color.secondary)
            }
        }()
        let ganado = [Estado.cuadra, .igualQueLoPresentado, .noCuadra].contains(estado)
        return Image(systemName: simbolo)
            .font(.system(size: 44, weight: ganado ? .semibold : .regular))
            .foregroundStyle(color)
            .contentTransition(.symbolEffect(.replace))
            .scaleEffect(estampado ? 1 : 1.4)
            .opacity(estampado ? 1 : 0.3)
            .frame(width: 56, height: 56)
            .accessibilityHidden(true)
    }

    private var titulo: String {
        switch estado {
        case .cuadra: return "Cuadra con la gestoría"
        case .noCuadra: return "No cuadra con la gestoría"
        case .sinComprobar: return "Sin comprobar"
        case .igualQueLoPresentado: return "Igual que lo presentado"
        case .distintoDeLoPresentado: return "Distinto de lo presentado"
        case .sinApuntar: return "Sin apuntar lo presentado"
        case .enParte: return "Lo mirado cuadra"
        }
    }

    private var subtitulo: String? {
        guard !conLoPresentado else { return nil }
        let cuando = max(d.comprobadoCuando, d.asesoriaCuando, d.ultimaCuando)
        guard !cuando.isEmpty else { return nil }
        let dia = String(cuando.prefix(10))
        let hora = cuando.count >= 16 ? String(cuando.dropFirst(11).prefix(5)) : ""
        
        let momento = "\(Fechas.diaDeLaSemana(dia).prefix(3)) \(Fechas.corta(dia))"
            + (hora.isEmpty ? "" : ", \(hora)")

        if estado == .enParte { return "Sin los modelos · \(momento)" }
        return d.comprobadoFuente == "excel" && cuando == d.comprobadoCuando
            ? "Con el Excel · \(momento)" : "Comprobado el \(momento)"
    }

    private var nota: String? {
        if cambioDesdeLaComprobacion { return "La cuenta de la app ha cambiado desde entonces." }
        if estado == .cuadra, numerosMasNuevos, d.asesoriaCuando != d.comprobadoCuando {

            return "Las listas de las capturas no estaban enteras."
        }
        return nil
    }

    private func notaAlPie(_ texto: String) -> some View {
        Label {
            Text(texto).foregroundStyle(Color.primary)
        } icon: {
            Image(systemName: "info.circle").foregroundStyle(Marcador.apoyo)
        }
        .font(.footnote)
    }

    private var otro: String { conLoPresentado ? "Presentado" : "Gestoría" }

    private var nombre303: String {
        guard !conLoPresentado, app303 < 0, d.asesoria303Que != "trimestre" else { return "IVA" }
        return cuarto ? "IVA a devolver" : "IVA acumulado a compensar"
    }

    private var tabla: some View {
        ViewThatFits(in: .horizontal) {
            tablaEnColumnas
            tablaApilada
        }
    }

    private var tablaEnColumnas: some View {
        Grid(alignment: .trailing, horizontalSpacing: Diseno.hueco2, verticalSpacing: Diseno.hueco2) {
            GridRow {
                Color.clear.frame(width: 1, height: 1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .gridColumnAlignment(.leading)
                Text("La app")
                Text(otro)
                Color.clear.frame(width: 1, height: 1)
            }
            .font(.footnote.weight(.semibold))
            .foregroundStyle(Marcador.apoyo)
            Divider().gridCellUnsizedAxes(.horizontal)
            fila("130", "IRPF", app: app130, suyo: suyo130)
            fila("303", nombre303, app: app303, suyo: suyo303)
        }
    }

    private var tablaApilada: some View {
        VStack(alignment: .leading, spacing: Diseno.hueco2) {
            bloque("130", "IRPF", app: app130, suyo: suyo130)
            Divider()
            bloque("303", nombre303, app: app303, suyo: suyo303)
        }
    }

    private func bloque(_ modelo: String, _ nombre: String, app: Double, suyo: Double?) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text("\(modelo) · \(nombre)").font(.headline)
                Spacer(minLength: Diseno.hueco1)
                marca(app: app, suyo: suyo)
            }
            (Text("La app ").foregroundStyle(Marcador.apoyo)
             + Text(Formato.euros(limpio(app))).fontWeight(.semibold))
            (Text("\(otro) ").foregroundStyle(Marcador.apoyo)
             + Text(suyo.map { Formato.euros(limpio($0)) } ?? "—").fontWeight(.semibold))
        }
        .monospacedDigit()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(lecturaDeFila(modelo, nombre, app: app, suyo: suyo))
    }

    private func limpio(_ x: Double) -> Double { abs(x) < 0.005 ? 0 : x }

    private func fila(_ modelo: String, _ nombre: String, app: Double, suyo: Double?) -> some View {
        GridRow {
            VStack(alignment: .leading, spacing: 0) {
                Text(modelo).font(.system(.headline, design: .rounded)).monospacedDigit()
                Text(nombre).font(.caption).foregroundStyle(Marcador.apoyo)
            }
            .fixedSize()
            .frame(maxWidth: .infinity, alignment: .leading)
            .gridColumnAlignment(.leading)
            Text(Formato.euros(limpio(app)))
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                .monospacedDigit()
                .lineLimit(1).minimumScaleFactor(0.7)
                .contentTransition(.numericText(value: app))
            Text(suyo.map { Formato.euros(limpio($0)) } ?? "—")
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                .monospacedDigit()
                .lineLimit(1).minimumScaleFactor(0.7)
                .foregroundStyle(suyo == nil ? AnyShapeStyle(Marcador.apoyo) : AnyShapeStyle(Color.primary))
                .contentTransition(.numericText(value: suyo ?? 0))
            marca(app: app, suyo: suyo)
                .font(.body)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(lecturaDeFila(modelo, nombre, app: app, suyo: suyo))
    }

    @ViewBuilder
    private func marca(app: Double, suyo: Double?) -> some View {
        if let s = suyo {
            let igual = abs(app - s) < 0.01
            
            let color = igual ? Diseno.verdeRelleno
                              : (conLoPresentado ? Marcador.apoyo : Diseno.naranjaRelleno)
            Image(systemName: igual ? "checkmark.circle.fill" : "notequal.circle.fill")
                .foregroundStyle(.white, color)
                .contentTransition(.symbolEffect(.replace))
        } else {
            Image(systemName: "circle.dashed")
                .foregroundStyle(Marcador.apoyo)
        }
    }

    private func lecturaDeFila(_ modelo: String, _ nombre: String, app: Double, suyo: Double?) -> String {
        let quien = conLoPresentado ? "presentado" : "Gestoría"
        guard let s = suyo else {
            return "Modelo \(modelo), \(nombre): la app, \(Formato.euros(limpio(app))); \(quien), sin dato"
        }
        let igual = abs(app - s) < 0.01
        return "Modelo \(modelo), \(nombre): la app, \(Formato.euros(limpio(app))); \(quien), "
            + "\(Formato.euros(limpio(s))). " + (igual ? "Igual" : "Distinto")
    }

    private var sePuedePresentar: Bool { abierto && d.estado != "en_curso" }

    private var hayBotones: Bool {
        sinApuntar || (abierto && d.excelIVA != nil) || trabajando != nil || notaExcel != nil
            || sePuedePresentar
    }

    @ViewBuilder
    private var botones: some View {
        if hayBotones {
            VStack(alignment: .leading, spacing: Diseno.hueco1) {
                contenidoDeBotones
            }
            .buttonBorderShape(.capsule)
            .controlSize(.large)
        }
    }

    @ViewBuilder
    private var contenidoDeBotones: some View {
        if sinApuntar {
            Button(action: preguntarGestoria) {
                Text("Apuntar lo presentado").fontWeight(.semibold).frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .rellenoDelTema()
        }
        if abierto && d.excelIVA != nil {
            
            botonExcel.buttonStyle(.borderedProminent).rellenoDelTema()
        } else if let t = trabajando {
            
            HStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text(t).font(.subheadline.weight(.semibold))
            }
            .frame(minHeight: 44)
        }
        if let n = notaExcel {
            Label {
                Text(n.texto).foregroundStyle(Color.primary)
            } icon: {
                if n.bien {
                    Image(systemName: "info.circle").foregroundStyle(Marcador.apoyo)
                } else {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundStyle(.white, Diseno.naranjaRelleno)
                }
            }
            .font(.footnote)
            .fixedSize(horizontal: false, vertical: true)
            .transition(.opacity)
        }
        if sePuedePresentar {
            Button(action: preguntarGestoria) {
                Text("Ya está presentado")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.primary)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .contentShape(.rect)
            }
            .buttonStyle(Hundirse())
        }
    }

    private var botonExcel: some View {
        Button(action: descargarExcel) {

            ViewThatFits(in: .horizontal) {
                etiquetaExcel(trabajando ?? "Descargar Excel de la gestoría")
                etiquetaExcel(trabajando ?? "Descargar Excel")
            }
            .frame(maxWidth: .infinity)
        }
        .disabled(trabajando != nil)
    }

    private func etiquetaExcel(_ texto: String) -> some View {
        HStack(spacing: 8) {
            if trabajando != nil {
                ProgressView().controlSize(.small).tint(.white)
            } else {
                Image(systemName: "tablecells").fontWeight(.semibold)
            }
            Text(texto).fontWeight(.semibold).lineLimit(1)
        }
    }
}

struct PantallaPorQueImpuestos: View {
    let d: DatosImpuestos

    private var presentadoDistinto: Bool {
        guard let p = d.presentadoTotal else { return false }
        return abs(p - d.total) >= 0.01
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                irpf
                iva
                if d.ue > 0.004 { ue }
            }
            .padding(.horizontal, Diseno.margen)
            .padding(.bottom, Diseno.hueco3)
        }
        .scrollEdgeEffectStyle(.soft, for: .top)
        .background { CampoJoya(joya: .impuestos) }
        .navigationTitle("Por qué pagas esto")
        .navigationSubtitle(DatosImpuestos.nombre(d.trimestre, conAño: true))
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private var irpf: some View {
        let m = d.m130
        let escala = max(m["ingresos"] ?? 0, 0.01)

        TituloDeSeccion(texto: "IRPF · modelo 130",
                        dato: presentadoDistinto ? "la cuenta de la app" : "desde enero")
        VStack(spacing: 0) {
            LineaDeCuenta(texto: "Ingresos", valor: m["ingresos"] ?? 0, escala: escala)
            LineaDeCuenta(texto: "Gastos", valor: -(m["gastos"] ?? 0), escala: escala,
                          nota: (m["dificil_justificacion"] ?? 0) > 0.004
                              ? "con \(Formato.euros(m["dificil_justificacion"] ?? 0)) de difícil justificación"
                              : nil)
            LineaDeCuenta(texto: "Rendimiento", valor: m["rendimiento"] ?? 0, escala: escala,
                          fuerte: true)
            LineaDeCuenta(texto: "El 20 %", valor: m["cuota"] ?? 0, escala: escala)
            if (m["pagado_antes"] ?? 0) > 0.004 {
                LineaDeCuenta(texto: "Ya pagado este año", valor: -(m["pagado_antes"] ?? 0),
                              escala: escala)
            }
            if (m["deduccion"] ?? 0) > 0.004 {
                LineaDeCuenta(texto: "Deducción", valor: -(m["deduccion"] ?? 0), escala: escala)
            }
            if (m["negativos_antes"] ?? 0) > 0.004 {
                LineaDeCuenta(texto: "Negativos de antes", valor: -(m["negativos_antes"] ?? 0),
                              escala: escala)
            }
            LineaDeCuenta(texto: "A pagar", valor: m["resultado"] ?? 0, escala: escala,
                          fuerte: true, final: true)
        }
        .padding(.top, Diseno.hueco1)
        enlace("130")
    }

    @ViewBuilder
    private var iva: some View {
        let m = d.m303
        let devengado = m["devengado"] ?? 0
        let deducible = m["deducible"] ?? 0
        let compensado = m["compensado"] ?? 0
        let resultado = m["resultado"] ?? 0
        let escala = max(devengado, deducible, abs(resultado), 0.01)
        let cuarto = DatosImpuestos.corto(d.trimestre) == "4T"
        TituloDeSeccion(texto: "IVA · modelo 303")
        VStack(spacing: 0) {
            LineaDeCuenta(texto: "IVA de lo que cobraste", valor: devengado, escala: escala)
            LineaDeCuenta(texto: "IVA de tus gastos", valor: -deducible, escala: escala)
            if compensado > 0.004 {
                LineaDeCuenta(texto: "Compensado de antes", valor: -compensado, escala: escala)
            }
            if resultado < 0 {
                LineaDeCuenta(texto: cuarto ? "A devolver este trimestre" : "A compensar este trimestre",
                              valor: -resultado, escala: escala, fuerte: true, final: true)
            } else {
                LineaDeCuenta(texto: "A pagar", valor: resultado, escala: escala,
                              fuerte: true, final: true)
            }
        }
        .padding(.top, Diseno.hueco1)
        
        if let queda = m["queda_por_compensar"], queda > 0.004, !cuarto {
            Text("Quedan \(Formato.euros(queda)) por compensar en los siguientes trimestres")
                .font(.footnote)
                .foregroundStyle(Marcador.apoyo)
                .monospacedDigit()
                .padding(.top, Diseno.hueco1)
        } else if let total = m["a_devolver"], total > 0.004, cuarto {
            Text("Con lo de los trimestres anteriores, te devuelven \(Formato.euros(total))")
                .font(.footnote)
                .foregroundStyle(Marcador.apoyo)
                .monospacedDigit()
                .padding(.top, Diseno.hueco1)
        }
        enlace("303")
    }

    @ViewBuilder
    private var ue: some View {
        TituloDeSeccion(texto: "Modelo 349 · UE", dato: "informativo")
        LineaDeCuenta(texto: "Ventas a la UE", valor: d.ue, escala: max(d.ue, 0.01))
            .padding(.top, Diseno.hueco1)
        enlace("349")
    }

    private func enlace(_ modelo: String) -> some View {
        NavigationLink {
            PantallaModelo(datos: d, modelo: modelo)
        } label: {
            HStack {
                Text("Casilla a casilla").font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.primary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Marcador.apoyo)
            }
            .frame(minHeight: 44)
            .contentShape(.rect)
        }
        .buttonStyle(Hundirse())
        .accessibilityLabel("Modelo \(modelo), casilla a casilla")
    }
}

private struct LineaDeCuenta: View {
    let texto: String
    let valor: Double
    let escala: Double
    var nota: String? = nil
    var fuerte = false
    
    var final = false

    @Environment(\.accessibilityReduceMotion) private var menosMovimiento
    @State private var crecida = false

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline) {
                Text(texto)
                    .font(fuerte ? .subheadline.weight(.semibold) : .subheadline)
                    .foregroundStyle(Color.primary)
                Spacer(minLength: Diseno.hueco1)
                Text((valor < 0 ? ("\u{2212}") : "") + Formato.euros(abs(valor)))
                    .font(.system(final ? .title3 : .subheadline, design: .rounded)
                        .weight(fuerte ? .bold : .medium))
                    .monospacedDigit()
                    .foregroundStyle(Color.primary)
            }
            GeometryReader { g in
                let parte = min(1, abs(valor) / max(escala, 0.01))
                Capsule()
                    .fill(final ? AnyShapeStyle(Color.primary)
                                : AnyShapeStyle(Marcador.apoyo.opacity(valor < 0 ? 0.3 : 0.6)))
                    .frame(width: max(3, g.size.width * CGFloat(parte) * (crecida ? 1 : 0)))
            }
            .frame(height: final ? 6 : 4)
            .accessibilityHidden(true)
            if let nota {
                Text(nota).font(.caption).foregroundStyle(Marcador.apoyo)
            }
        }
        .padding(.vertical, 7)
        .onAppear {
            if menosMovimiento { crecida = true; return }
            withAnimation(.smooth(duration: 0.7).delay(0.1)) { crecida = true }
        }
        .accessibilityElement(children: .combine)
    }
}

struct TrimestreEnElTitulo: ViewModifier {
    let activo: Bool
    let datos: DatosImpuestos?
    let elegir: (String) -> Void

    func body(content: Content) -> some View {
        if activo, let d = datos, d.hayDatos {
            content
                .navigationSubtitle(DatosImpuestos.nombre(d.trimestre, conAño: true))
                .toolbarTitleMenu {
                    Picker("Trimestre", selection: Binding(get: { d.trimestre }, set: elegir)) {
                        ForEach(d.trimestres.reversed(), id: \.self) { t in
                            Label(DatosImpuestos.nombre(t, conAño: true),
                                  systemImage: d.presentados.contains(t) ? "checkmark.seal" : "calendar")
                                .tag(t)
                        }
                    }
                }
        } else {
            content
        }
    }
}
