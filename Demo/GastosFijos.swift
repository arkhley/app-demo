import SwiftUI

struct PantallaGastosFijos: View {
    @Environment(Sesion.self) private var sesion
    @State private var datos = EstadoGastosFijos()
    @State private var nuevo = false
    @State private var abierto: GastosFijos.Gasto?
    @ScaledMetric(relativeTo: .largeTitle) private var tamCifra: CGFloat = 64
    @Environment(\.colorScheme) private var modo

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                contenido
            }
            .padding(.horizontal, Diseno.margen)
            .padding(.bottom, Diseno.hueco5)
        }
        .scrollEdgeEffectStyle(.soft, for: .top)
        .background { CampoJoya(joya: .gastos) }
        .navigationTitle("Gastos fijos")
        
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { nuevo = true } label: {
                    Label("Nuevo gasto", systemImage: "plus")
                }
            }
        }
        .refreshable { await datos.cargar(testigo: sesion.testigo) }
        .task { await datos.cargar(testigo: sesion.testigo) }
        .sheet(isPresented: $nuevo) {
            HojaEditarGastoFijo(datos: datos)
                .hojaQueChoca()
        }
        .sheet(item: $abierto) { g in
            HojaGastoFijo(id: g.id, datos: datos)
                .hojaQueChoca()
        }
        #if MAQUETA
        
        .onAppear { if Maqueta.hojaDeGasto == "nueva" { nuevo = true } }
        .onChange(of: datos.estado.listos) { _, g in
            if Maqueta.hojaDeGasto == "ficha", abierto == nil {
                abierto = g?.gastos.first { $0.cuotas != nil } ?? g?.gastos.first
            }
        }
        #endif
    }

    @ViewBuilder
    private var contenido: some View {
        switch datos.estado {
        case .cargando:
            Vacio(icono: "creditcard", titulo: "Cargando…")
                .redacted(reason: .placeholder)
                .padding(.top, Diseno.hueco5)
        case .error(let qué):
            Vacio(icono: "wifi.exclamationmark", titulo: "No se ha podido cargar", detalle: qué)
                .padding(.top, Diseno.hueco5)
        case .vacio:
            sinGastos
        case .listo(let g):
            if g.gastos.isEmpty {
                sinGastos
            } else {
                lleno(g)
            }
        }
    }

    private var sinGastos: some View {
        VStack(spacing: Diseno.hueco3) {
            Vacio(icono: "creditcard", titulo: "Sin gastos fijos")
            Button { nuevo = true } label: {
                Label("Añadir un gasto", systemImage: "plus")
                    .font(.headline)
            }
            .buttonStyle(.glassProminent)
            .tint(Diseno.azulRelleno)
            .controlSize(.large)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, Diseno.hueco5)
    }

    private func lleno(_ g: GastosFijos) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            heroe(g)
                .padding(.top, Diseno.hueco2)
            if let media = g.sueldo.media, media > 0 {
                LoQueGanas(g: g, media: media)
                    .padding(.top, Diseno.hueco3)
            }
            EscaleraDeGastos(g: g)
                .padding(.top, Diseno.hueco3)
            lista(g)
                .padding(.top, Diseno.hueco3)
        }
    }

    private func heroe(_ g: GastosFijos) -> some View {
        VStack(alignment: .leading, spacing: Diseno.hueco1) {
            if let linea = proximo(g) {
                Label {
                    Text(linea).foregroundStyle(Color.primary)
                } icon: {
                    Image(systemName: "calendar").foregroundStyle(Marcador.apoyo)
                }
                .font(.subheadline.weight(.semibold))
            }
            Text(Formato.euros(g.esteMes.total))
                .font(.system(size: min(tamCifra, 88), weight: .bold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.45)
                .contentTransition(.numericText(value: g.esteMes.total))
                .accessibilityLabel("En \(MesesGasto.nombre(g.mes, hoy: g.hoy)), \(Formato.euros(g.esteMes.total))")
            Text("en \(MesesGasto.nombre(g.mes, hoy: g.hoy)) · \(cuantos(g))")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Marcador.apoyo)
            if g.esteMes.total > 0.004 {
                apartado(g.esteMes, hoy: g.hoy)
            }
        }
    }

    private func proximo(_ g: GastosFijos) -> String? {
        let siguientes = g.gastos.filter { !$0.proximoPago.isEmpty && $0.proximoPago >= g.hoy }
        guard let p = siguientes.min(by: { ($0.proximoPago, $0.nombre) < ($1.proximoPago, $1.nombre) })
        else { return nil }
        let mismos = siguientes.filter { $0.proximoPago == p.proximoPago }
        let quien = mismos.count > 1 ? "\(p.nombre) y \(mismos.count - 1) más" : p.nombre
        if p.proximoPago == g.hoy { return "Hoy: \(quien)" }
        let dia = Int(p.proximoPago.suffix(2)) ?? 0
        let cuando = Fechas.dias(de: g.hoy, a: p.proximoPago) == 1
            ? "mañana" : "el \(Fechas.diaDeLaSemana(p.proximoPago)) \(dia)"
        return "Próximo: \(quien), \(cuando)"
    }

    private func cuantos(_ g: GastosFijos) -> String {
        let n = g.gastos.filter { $0.importe > 0 }.count
        return n == 1 ? "1 gasto" : "\(n) gastos"
    }

    private func apartado(_ m: GastosFijos.EsteMes, hoy: String) -> some View {
        let total = max(m.total, 0.01)
        let verde = min(m.apartado, total)
        let azul = max(0, min(m.apartado + m.porApartar, total) - verde)
        let todo = m.apartado >= m.total - 0.005
        return VStack(alignment: .leading, spacing: 7) {
            GeometryReader { geo in
                let w = geo.size.width
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
            .animation(.smooth(duration: 0.6), value: m.apartado)
            .accessibilityHidden(true)
            Label {
                Text(todo ? "Todo apartado"
                     : m.apartado > 0.004 ? "\(Formato.euros(m.apartado)) apartados" : "Nada apartado")
                    .foregroundStyle(Color.primary)
            } icon: {
                if todo {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.white, Diseno.verdeRelleno)
                } else {
                    PuntoDeArea(color: m.apartado > 0.004 ? Diseno.verdeRelleno : Marcador.apoyo, lado: 8)
                }
            }
            .font(.footnote.weight(.medium))
            .monospacedDigit()
            .contentTransition(.numericText())
            
            if m.falta > 0.5 {
                Label {
                    Text("Los cobros de \(MesesGasto.nombre(m.mes, hoy: hoy)) no llegan: faltan \(Formato.euros(m.falta))")
                        .foregroundStyle(Color.primary)
                } icon: {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundStyle(.white, Diseno.naranjaRelleno)
                }
                .font(.footnote.weight(.medium))
                .monospacedDigit()
            }
        }
        .padding(.top, Diseno.hueco1)
    }

    private func lista(_ g: GastosFijos) -> some View {
        let vivos = g.gastos.filter { $0.estado != "terminado" }
        let acabados = g.gastos.filter { $0.estado == "terminado" }
        return VStack(alignment: .leading, spacing: 0) {
            TituloDeSeccion(texto: "Tus gastos",
                            dato: g.faltaTotal > 0.004 ? "\(Formato.euros(g.faltaTotal)) en cuotas" : nil)
            ForEach(Array(vivos.enumerated()), id: \.element.id) { i, x in
                if i > 0 { Divider().padding(.leading, Diseno.ladoIcono + Diseno.hueco2) }
                fila(x, hoy: g.hoy)
            }
            if !acabados.isEmpty {
                TituloDeSeccion(texto: "Ya pagados")
                ForEach(Array(acabados.enumerated()), id: \.element.id) { i, x in
                    if i > 0 { Divider().padding(.leading, Diseno.ladoIcono + Diseno.hueco2) }
                    fila(x, hoy: g.hoy)
                }
            }
        }
    }

    private func fila(_ x: GastosFijos.Gasto, hoy: String) -> some View {
        Button { abierto = x } label: {
            FilaGastoFijo(g: x, hoy: hoy)
        }
        .buttonStyle(.plain)
    }
}

struct FilaGastoFijo: View {
    let g: GastosFijos.Gasto
    let hoy: String

    var body: some View {
        HStack(alignment: .center, spacing: Diseno.hueco2) {
            FichaIcono(simbolo: g.simbolo, color: TipoDeGasto.de(simbolo: g.simbolo).color)
                .opacity(g.estado == "terminado" ? 0.5 : 1)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(g.nombre)
                    .font(.headline)
                    .foregroundStyle(Color.primary)
                    .lineLimit(2)
                Text(pie)
                    .font(.footnote)
                    .foregroundStyle(Marcador.apoyo)
                    .monospacedDigit()
                    .fixedSize(horizontal: false, vertical: true)
                if let c = g.cuotas, g.estado == "activo" {
                    BarraDeCuotas(cuotas: c)
                        .frame(maxWidth: 160)
                        .padding(.top, 2)
                }
            }
            Spacer(minLength: Diseno.hueco1)
            VStack(alignment: .trailing, spacing: 2) {
                Text(Formato.euros(g.importeVisible))
                    .font(.system(.headline, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Color.primary)
                if let c = g.cambio {
                    Text("\(Formato.euros(c.euros)) en \(MesesGasto.corto(c.desde, conAño: c.desde.prefix(4) != hoy.prefix(4)))")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(Marcador.apoyo)
                        .monospacedDigit()
                }
            }
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
        }
        .padding(.vertical, Diseno.hueco2)
        .frame(minHeight: 44)
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Abre el gasto")
    }

    private var pie: String {
        switch g.estado {
        case "empieza":
            return "Empieza en \(MesesGasto.nombre(g.desde, hoy: hoy))"
        case "terminado":
            return "Última cuota en \(MesesGasto.nombre(g.hasta, hoy: hoy))"
        default:
            if let c = g.cuotas {
                let quedan = c.quedan == 1 ? "queda 1 de \(c.total) cuotas"
                    : "quedan \(c.quedan) de \(c.total) cuotas"
                return "Día \(g.dia) · \(quedan)"
            }
            return "Día \(g.dia) · sin fecha de fin"
        }
    }
}

struct BarraDeCuotas: View {
    let cuotas: GastosFijos.Cuotas
    var alto: CGFloat = 4

    var body: some View {
        GeometryReader { geo in
            let parte = CGFloat(cuotas.pagadas) / CGFloat(max(cuotas.total, 1))
            ZStack(alignment: .leading) {
                Capsule().fill(Marcador.apoyo.opacity(0.16))
                Capsule().fill(Color.primary.opacity(0.75))
                    .frame(width: max(cuotas.pagadas > 0 ? alto : 0, geo.size.width * parte))
            }
        }
        .frame(height: alto)
        .accessibilityHidden(true)
    }
}

struct LoQueGanas: View {
    let g: GastosFijos
    let media: Double

    @Environment(\.colorScheme) private var modo
    @Environment(\.accessibilityReduceMotion) private var menosMovimiento
    @State private var lleno = false

    private var gastos: Double { g.esteMes.total }
    private var parte: Double { gastos / max(media, 0.01) }

    var body: some View {
        VStack(alignment: .leading, spacing: Diseno.hueco2) {
            TituloDeSeccion(texto: "De lo que ganas")
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(parte.formatted(.percent.precision(.fractionLength(0))))
                    .font(.system(.largeTitle, design: .rounded).weight(.bold))
                    .monospacedDigit()
                    .contentTransition(.numericText(value: parte))
                Text("se va en gastos fijos")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Marcador.apoyo)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)
            barra
            HStack(alignment: .top, spacing: Diseno.hueco4) {
                dato("Ganas al mes", media, color: Diseno.verdeRelleno, pie: periodo)
                dato("Gastos fijos", gastos, color: Color.primary.opacity(0.85), pie: nil)
            }
            if gastos > media + 0.5 {
                Label {
                    Text("Los gastos pasan de lo que ganas: faltan \(Formato.euros(gastos - media)) al mes")
                        .foregroundStyle(Color.primary)
                } icon: {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundStyle(.white, Diseno.rojoRelleno)
                }
                .font(.footnote.weight(.medium))
                .monospacedDigit()
            }
        }
        .onAppear {
            if menosMovimiento { lleno = true } else {
                withAnimation(.smooth(duration: 0.8).delay(0.15)) { lleno = true }
            }
        }
    }

    private var periodo: String? {
        let m = g.sueldo.meses
        guard let primero = m.first else { return nil }
        return m.count == 1 ? "en \(MesesGasto.nombre(primero, hoy: g.hoy))"
                            : "media de los últimos \(m.count) meses"
    }

    private var barra: some View {
        GeometryReader { geo in
            let w = geo.size.width
            ZStack(alignment: .leading) {
                Capsule().fill(Diseno.verdeRelleno.gradient)
                Capsule().fill(Color.primary.opacity(0.85))
                    .frame(width: max(0, w * CGFloat(min(parte, 1)) * (lleno ? 1 : 0)))
            }
            .overlay {
                if modo == .light {
                    Capsule().strokeBorder(.black.opacity(0.6), lineWidth: 0.75)
                }
            }
        }
        .frame(height: 14)
        .accessibilityHidden(true)
    }

    private func dato(_ nombre: String, _ euros: Double, color: Color, pie: String?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 5) {
                PuntoDeArea(color: color, lado: 8)
                Text(nombre).font(.caption.weight(.medium)).foregroundStyle(Marcador.apoyo)
            }
            Text(Formato.euros(euros))
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                .monospacedDigit()
            if let pie {
                Text(pie).font(.caption2).foregroundStyle(Marcador.apoyo)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

struct EscaleraDeGastos: View {
    let g: GastosFijos

    @Environment(\.colorScheme) private var modo
    @Environment(\.accessibilityReduceMotion) private var menosMovimiento
    @Environment(\.accessibilityReduceTransparency) private var menosTransparencia
    @State private var elegido: Int?
    @State private var rastreando = false
    @State private var crecidas = false
    
    @ScaledMetric(relativeTo: .subheadline) private var altoLectura: CGFloat = 42

    private static let alto: CGFloat = 150
    private static let espacio: CGFloat = 3

    private var meses: [GastosFijos.Mes] { g.proyeccion }

    private var cambia: Bool {
        guard let primero = meses.first?.total else { return false }
        return meses.contains { abs($0.total - primero) > 0.004 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Diseno.hueco2) {
            TituloDeSeccion(texto: "Lo que viene")
            lectura
            if cambia {
                grafica
                    .frame(height: Self.alto + 22)
                    .padding(.top, Diseno.hueco1)
            }
        }
        .sensoryFeedback(.selection, trigger: elegido)
        .onAppear {
            if menosMovimiento { crecidas = true } else {
                withAnimation(.spring(duration: 0.7, bounce: 0.15)) { crecidas = true }
            }
        }
    }

    private var lectura: some View {
        VStack(alignment: .leading, spacing: 2) {
            if let i = elegido, meses.indices.contains(i) {
                let m = meses[i]
                Text("\(MesesGasto.nombre(m.mes, hoy: g.hoy).capitalizandoPrimera) · \(Formato.euros(m.total))")
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                Text(partes(m))
                    .font(.footnote)
                    .foregroundStyle(Marcador.apoyo)
                    .monospacedDigit()
            } else {
                Text(resumen)
                    .font(.subheadline.weight(.semibold))
                if let segunda = resumenDespues {
                    Text(segunda)
                        .font(.footnote)
                        .foregroundStyle(Marcador.apoyo)
                        .monospacedDigit()
                }
            }
        }
        .frame(minHeight: altoLectura, alignment: .topLeading)
        .accessibilityElement(children: .combine)
    }

    private var resumen: String {
        guard !g.libreDesde.isEmpty else { return "Ninguno tiene fecha de fin" }
        let ultimo = MesesGasto.sumar(g.libreDesde, -1)
        return g.hayIndefinidos
            ? "La última cuota, en \(MesesGasto.nombre(ultimo, hoy: g.hoy))"
            : "En \(MesesGasto.nombre(ultimo, hoy: g.hoy)) terminas de pagarlo todo"
    }

    private var resumenDespues: String? {
        guard !g.libreDesde.isEmpty, g.hayIndefinidos, let d = g.despues else { return nil }
        return "Después, \(Formato.euros(d)) al mes"
    }

    private func partes(_ m: GastosFijos.Mes) -> String {
        g.gastos.compactMap { x in
            guard let e = m.partes[x.id], e > 0.004 else { return nil }
            return "\(x.nombre) \(Formato.euros(e))"
        }.joined(separator: " · ")
    }

    private var grafica: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let n = max(meses.count, 1)
            let ancho = max(2, (w - Self.espacio * CGFloat(n - 1)) / CGFloat(n))
            let tope = max(meses.map(\.total).max() ?? 1, 1)
            let x = { (i: Int) in CGFloat(i) * (ancho + Self.espacio) }
            ZStack(alignment: .topLeading) {
                
                if let i = elegido, meses.indices.contains(i) {
                    lente(alto: altura(meses[i].total, tope) + 16, ancho: ancho + 10)
                        .offset(x: x(i) - 5, y: Self.alto - altura(meses[i].total, tope) - 8)
                        .animation(.spring(duration: 0.28, bounce: 0.2), value: i)
                }
                ForEach(Array(meses.enumerated()), id: \.element.id) { i, m in
                    barra(m, tope: tope, ancho: ancho)
                        .opacity(rastreando && elegido != i ? 0.32 : 1)
                        .scaleEffect(x: 1, y: crecidas ? 1 : 0.02, anchor: .bottom)
                        .animation(menosMovimiento ? nil
                                   : .spring(duration: 0.6, bounce: 0.2).delay(Double(i) * 0.012),
                                   value: crecidas)
                        .offset(x: x(i), y: Self.alto - altura(m.total, tope))
                }
                
                ForEach(bajadas, id: \.self) { i in
                    Text("−\(Formato.eurosRedondos(meses[i - 1].total - meses[i].total))")
                        .font(.caption2.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(Marcador.apoyo)
                        .fixedSize()
                        .position(x: x(i) - Self.espacio / 2,
                                  y: Self.alto - altura(meses[i - 1].total, tope) - 10)
                        .opacity(rastreando || !crecidas ? 0 : 1)
                }
                
                ForEach(Array(meses.enumerated()), id: \.element.id) { i, m in
                    if i == 0 || m.mes.hasSuffix("-01") {
                        Text(i == 0 ? "hoy" : MesesGasto.corto(m.mes, conAño: true))
                            .font(.caption2.weight(i == 0 ? .bold : .medium))
                            .foregroundStyle(i == 0 ? Color.primary : Marcador.apoyo)
                            .fixedSize()
                            .position(x: x(i) + ancho / 2 + (i == 0 ? 8 : 0), y: Self.alto + 12)
                    }
                }
            }
            .contentShape(.rect)
            .gesture(MantenerYDeslizar(
                espera: 0.15,
                alEmpezar: { p in
                    rastreando = true
                    elegir(p.x, ancho: ancho)
                },
                alMover: { p in elegir(p.x, ancho: ancho) },
                alAcabar: {
                    rastreando = false
                    withAnimation(.snappy(duration: 0.25)) { elegido = nil }
                }))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Lo que viene, mes a mes")
        .accessibilityValue(([resumen] + [resumenDespues].compactMap { $0 }).joined(separator: ". "))
    }

    private func elegir(_ px: CGFloat, ancho: CGFloat) {
        let i = Int((px / (ancho + Self.espacio)).rounded(.down))
        let j = min(max(i, 0), meses.count - 1)
        if j != elegido { elegido = j }
    }

    private func altura(_ total: Double, _ tope: Double) -> CGFloat {
        total <= 0.004 ? 0 : max(3, Self.alto * CGFloat(total / tope))
    }

    private var bajadas: [Int] {
        let todas = meses.indices.dropFirst().filter { meses[$0 - 1].total - meses[$0].total > 0.5 }
        return Array(todas.sorted { meses[$0 - 1].total - meses[$0].total > meses[$1 - 1].total - meses[$1].total }
            .prefix(3)).sorted()
    }

    private func barra(_ m: GastosFijos.Mes, tope: Double, ancho: CGFloat) -> some View {
        let trozos = g.gastos.compactMap { x -> Double? in
            guard let e = m.partes[x.id], e > 0.004 else { return nil }
            return e
        }
        let alto = altura(m.total, tope)
        let primero = m.mes == g.mes
        return VStack(spacing: 1) {
            ForEach(Array(trozos.reversed().enumerated()), id: \.offset) { _, e in
                Rectangle()
                    .fill(Color.primary.opacity(primero ? 0.88 : 0.62))
                    .frame(height: max(1, (alto - CGFloat(trozos.count - 1)) * CGFloat(e / max(m.total, 0.01))))
            }
        }
        .frame(width: ancho, height: alto, alignment: .bottom)
        .clipShape(UnevenRoundedRectangle(topLeadingRadius: min(4, ancho / 2),
                                          topTrailingRadius: min(4, ancho / 2)))
    }

    @ViewBuilder
    private func lente(alto: CGFloat, ancho: CGFloat) -> some View {
        Group {
            if menosTransparencia {
                RoundedRectangle(cornerRadius: 9).strokeBorder(Color.primary, lineWidth: 2)
            } else {
                Color.clear.glassEffect(.regular, in: .rect(cornerRadius: 9))
            }
        }
        .frame(width: ancho, height: max(alto, 20))
        .scaleEffect(rastreando ? 1.06 : 1)
        .animation(.spring(duration: 0.3, bounce: 0.35), value: rastreando)
        .allowsHitTesting(false)
    }
}

extension Carga where T == GastosFijos {
    
    var listos: GastosFijos? {
        if case .listo(let g) = self { return g }
        return nil
    }
}
