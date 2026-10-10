import SwiftUI

struct PantallaCalendarioHuchaNueva: View {
    @Environment(Sesion.self) private var sesion
    @Environment(\.accessibilityDifferentiateWithoutColor) private var sinColor

    @State private var año = Calendar.current.component(.year, from: Date())
    @State private var dias: [String: PantallaHucha.DiaHucha] = [:]
    @State private var estado: Carga<Bool> = .cargando
    @State private var elegido: String?
    @State private var jornada: String?

    private var años: [Int] {
        let hoy = Calendar.current.component(.year, from: Date())
        return [hoy - 1, hoy]
    }

    var body: some View {
        ScrollView {

            LazyVStack(spacing: Diseno.hueco3) {
                Picker("Año", selection: $año) {
                    ForEach(años, id: \.self) { Text(String($0)).tag($0) }
                }
                .pickerStyle(.segmented)

                switch estado {
                case .cargando:
                    Tarjeta { Vacio(icono: "calendar", titulo: "Cargando…") }
                        .redacted(reason: .placeholder)
                case .error(let qué):
                    Tarjeta { Vacio(icono: "wifi.exclamationmark",
                                    titulo: "No se ha podido cargar", detalle: qué) }
                case .vacio:
                    Tarjeta { Vacio(icono: "calendar", titulo: "Nada en \(año)") }
                default:
                    leyenda
                    
                    ForEach(mesesConDatos.reversed(), id: \.self) { mes in
                        Tarjeta(relleno: 0) {
                            MesConAnillos(año: año, mes: mes, dias: dias,
                                          elegido: elegido, hoy: jornada) { fecha in
                                withAnimation(Diseno.suave) {
                                    elegido = (elegido == fecha) ? nil : fecha
                                }
                            }
                            .padding(.horizontal, Diseno.hueco3)
                        }

                        if let elegido, elegido.hasPrefix(String(format: "%04d-%02d", año, mes)),
                           let dia = dias[elegido] {
                            TarjetaDelDiaNueva(dia: dia)
                                .transition(.asymmetric(
                                    insertion: .push(from: .top).combined(with: .opacity),
                                    removal: .opacity))
                        }
                    }
                }
            }
            .padding(.horizontal, Diseno.margen)
            .padding(.vertical, Diseno.hueco2)
        }
        .fondoDePantalla()
        .navigationTitle("Calendario")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: año) { await cargar() }
    }

    private var leyenda: some View {
        HStack(spacing: Diseno.hueco3) {
            muestra(Diseno.verdeRelleno, "tú")
            muestra(Diseno.azulRelleno, "la reserva")
            muestra(Diseno.rojoRelleno, "sin cubrir")
            Spacer()
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 4)
        .accessibilityElement(children: .combine)
    }

    private func muestra(_ color: Color, _ texto: String) -> some View {
        HStack(spacing: 5) {
            Circle().trim(from: 0, to: 0.75)
                
                .stroke(color, style: sinColor && color == Diseno.rojoRelleno
                        ? AnilloDia.aRayas(2.5) : StrokeStyle(lineWidth: 2.5, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .frame(width: 11, height: 11)
            Text(texto)
        }
    }

    private var mesesConDatos: [Int] {
        Set(dias.keys.compactMap { Int($0.dropFirst(5).prefix(2)) }).sorted()
    }

    private func cargar() async {
        estado = .cargando
        do {
            let j = try await API.pedir("api/hucha/calendario/\(año)", testigo: sesion.testigo)
            jornada = j["hoy"] as? String
            let lista = ((j["dias"] as? [[String: Any]]) ?? [])
                .compactMap(PantallaHucha.DiaHucha.init)
            dias = Dictionary(lista.map { ($0.fecha, $0) }, uniquingKeysWith: { _, b in b })
            estado = dias.isEmpty ? .vacio : .listo(true)
        } catch {
            estado.fallar(error)
        }
    }
}

private struct MesConAnillos: View {
    let año: Int
    let mes: Int
    let dias: [String: PantallaHucha.DiaHucha]
    var elegido: String?
    var hoy: String?
    let tocado: (String) -> Void

    @ScaledMetric(relativeTo: .title3) private var altoCelda: CGFloat = 66
    @ScaledMetric(relativeTo: .callout) private var ladoNumero: CGFloat = 26

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(CobrosHucha.nombreDelMes(String(format: "%04d-%02d", año, mes)).capitalized)
                .font(.title3.weight(.semibold))
                .foregroundStyle(Diseno.rojoRelleno)
                .padding(.leading, 4)
                .padding(.bottom, Diseno.hueco3)

            HStack(spacing: 0) {
                ForEach(Array(["L", "M", "X", "J", "V", "S", "D"].enumerated()), id: \.offset) { i, d in
                    Text(d)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.bottom, Diseno.hueco2)

            Divider()

            ForEach(Array(semanas.enumerated()), id: \.offset) { i, semana in
                if i > 0 { Divider() }
                HStack(spacing: 0) {
                    ForEach(semana, id: \.self) { d in celda(d) }
                }
            }
        }
        .padding(.vertical, Diseno.hueco2)
    }

    private var semanas: [[Int]] {
        var celdas = Array(repeating: 0, count: huecosIniciales) + Array(1...diasDelMes)
        while celdas.count % 7 != 0 { celdas.append(0) }
        return stride(from: 0, to: celdas.count, by: 7).map { Array(celdas[$0..<($0 + 7)]) }
    }

    @ViewBuilder
    private func celda(_ d: Int) -> some View {
        if d == 0 {
            Color.clear.frame(maxWidth: .infinity).frame(height: altoCelda)
        } else {
            let clave = String(format: "%04d-%02d-%02d", año, mes, d)
            let dia = dias[clave]
            let marcado = (elegido == clave)
            let esHoy = (hoy == clave)
            Button {
                if dia != nil { tocado(clave) }
            } label: {
                VStack(spacing: 4) {

                    Text("\(d)")
                        .font(esHoy ? .callout.weight(.semibold) : .callout)
                        .foregroundStyle(marcado || esHoy ? .white : .primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .frame(width: ladoNumero, height: ladoNumero)
                        .background(esHoy ? Diseno.rojoRelleno : (marcado ? Color.primary : .clear),
                                    in: .circle)
                    if let dia {

                        AnilloDia(dia: dia, grosor: 3.5, animado: marcado, espera: 0)
                            .id(marcado)
                            .transition(.identity)
                            .frame(width: 24, height: 24)
                    } else {
                        Color.clear.frame(width: 24, height: 24)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: altoCelda)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)

            .disabled(dia == nil && !(esHoy))
            .accessibilityLabel(etiqueta(d, dia))
            .accessibilityAddTraits(marcado ? [.isSelected] : [])
            .animation(Diseno.suave, value: marcado)
        }
    }

    private func etiqueta(_ d: Int, _ dia: PantallaHucha.DiaHucha?) -> String {
        guard let dia else { return "\(d), sin datos" }
        if !dia.cerrado { return "\(d), abierto, \(Formato.euros(dia.ganado)) ganado" }
        let como = dia.falto ? "no llegó al objetivo"
            : (dia.relleno > 0 ? "completado con la reserva" : "llegó al objetivo")
        return "\(d), \(Formato.euros(dia.total)), \(como)"
    }

    private var primerDia: Date {
        DateComponents(calendar: .current, year: año, month: mes, day: 1).date ?? Date()
    }

    private var huecosIniciales: Int {
        (Calendar.current.component(.weekday, from: primerDia) + 5) % 7
    }

    private var diasDelMes: Int {
        Calendar.current.range(of: .day, in: .month, for: primerDia)?.count ?? 30
    }
}

struct TarjetaDelDiaNueva: View {
    let dia: PantallaHucha.DiaHucha

    var body: some View {
        Tarjeta {
            HStack(alignment: .center, spacing: Diseno.hueco4) {
                
                AnilloDia(dia: dia, grosor: 10, espera: 0.25)
                    .frame(width: 72, height: 72)
                    
                    .id(dia.fecha)
                    .transition(.identity)

                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(Formato.diaCorto(dia.fecha)).font(.headline)
                        if !dia.cerrado {
                            
                            Circle().fill(Diseno.verdeRelleno).frame(width: 6, height: 6)
                                .modifier(Latido(activo: true))
                                .accessibilityLabel("Todavía abierto")
                        }
                        Spacer()

                        Text(Formato.euros(dia.cerrado ? dia.total : dia.ganado))
                            .font(.system(.title3, design: .rounded).weight(.semibold))
                            .monospacedDigit()
                            .contentTransition(.numericText())
                    }
                    fila("eurosign.circle.fill", Diseno.verde, "Ganado", dia.ganado)
                    if dia.sinDirecto(objetivo: dia.objetivo ?? 0) {
                        Label("sin directo", systemImage: "video.slash.fill")
                            .font(.caption.weight(.medium)).foregroundStyle(.secondary)
                    }
                    if dia.cerrado, dia.relleno > 0.004 {
                        fila("tray.and.arrow.up.fill", Diseno.azul, "La reserva", dia.relleno)
                    }
                    if !dia.cerrado, let f = dia.falta, f > 0.004 {
                        fila("target", Diseno.naranja, "Faltan", f)
                    }
                    if dia.aporte > 0.004 {
                        fila("drop.fill", Diseno.verde, "A la reserva", dia.aporte)
                    }
                    if dia.falto, dia.cerrado, dia.falta != nil {
                        Label("Sin cubrir \(Formato.euros(max(0, (dia.falta ?? 0) - dia.relleno)))",
                              systemImage: "exclamationmark.circle.fill")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(Diseno.rojo)
                    }
                }
            }
        }
    }

    private func fila(_ icono: String, _ color: Color, _ titulo: String, _ v: Double) -> some View {
        HStack {
            Label {
                Text(titulo).foregroundStyle(.secondary)
            } icon: {
                Image(systemName: icono).foregroundStyle(color)
            }
            Spacer()
            Text(Formato.euros(v)).monospacedDigit()
        }
        .font(.subheadline)
        .accessibilityElement(children: .combine)
    }
}
