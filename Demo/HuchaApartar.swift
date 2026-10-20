import SwiftUI

struct ApartarHucha: View {
    let datos: CobrosHucha
    @Binding var plataforma: String
    let marcando: String?
    let cambiarMes: (String) -> Void
    let marcar: (CobrosHucha.Cobro) -> Void
    
    var completar: (CobrosHucha.Cobro) -> Void = { _ in }

    private static let filtros = [(clave: "todo", nombre: "Todo"),
                                  (clave: "plataforma1", nombre: "Plataforma 1"),
                                  (clave: "plataforma2", nombre: "Plataforma 2"),
                                  (clave: "tienda", nombre: "Tienda")]

    var body: some View {
        VStack(spacing: Diseno.hueco3) {
            cabecera
            resumen
            SelectorDeslizante(opciones: Self.filtros, elegida: $plataforma)
                .accessibilityLabel("Plataforma")
            lista
        }
    }

    private var indice: Int { datos.meses.firstIndex(of: datos.mes) ?? 0 }

    private var cabecera: some View {
        HStack(spacing: Diseno.hueco2) {
            Text("Apartar").font(.title3.weight(.semibold))
            Spacer()
            if datos.meses.count > 1 {
                
                Button {
                    cambiarMes(datos.meses[indice + 1])
                } label: {
                    Image(systemName: "chevron.left").fontWeight(.semibold)
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
                .disabled(indice + 1 >= datos.meses.count)
                .accessibilityLabel("Mes anterior")
            }
            Text(CobrosHucha.nombreDelMes(datos.mes).capitalized)
                .font(.subheadline.weight(.semibold))
                .contentTransition(.opacity)
                .frame(minWidth: 84)
            if datos.meses.count > 1 {
                Button {
                    cambiarMes(datos.meses[indice - 1])
                } label: {
                    Image(systemName: "chevron.right").fontWeight(.semibold)
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
                .disabled(indice == 0)
                .accessibilityLabel("Mes siguiente")
            }
        }
        .padding(.leading, 4)
    }

    private var resumen: some View {
        Tarjeta {
            VStack(alignment: .leading, spacing: Diseno.hueco3) {
                accion
                barra
                if datos.sobra > 0.004 {

                    Label("Puedes sacar \(Formato.euros(datos.sobra))",
                          systemImage: "arrow.uturn.up.circle.fill")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Diseno.naranja)
                }
            }
        }
    }

    @ViewBuilder
    private var accion: some View {
        if datos.pendienteTotal > 0.004 {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: Diseno.hueco2) {
                    Image(systemName: "tray.and.arrow.down.fill")
                        .font(.title2)
                        .foregroundStyle(Diseno.azulRelleno)
                        .symbolEffect(.bounce, value: datos.pendienteTotal)
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Aparta")
                            .font(.subheadline).foregroundStyle(.secondary)
                        Text(Formato.euros(datos.pendienteTotal))
                            .font(.system(.title, design: .rounded).weight(.semibold))
                            .foregroundStyle(Diseno.azul)
                            .monospacedDigit()
                            .contentTransition(.numericText())
                    }
                }
                
                if datos.pendiente.count > 1 {
                    HStack(spacing: Diseno.hueco3) {
                        ForEach(datos.pendiente.keys.sorted(), id: \.self) { m in
                            Text("\(CobrosHucha.nombreDelMes(m).prefix(3)) \(Formato.euros(datos.pendiente[m] ?? 0))")
                                .font(.caption).foregroundStyle(.secondary).monospacedDigit()
                        }
                    }
                }
            }
            .accessibilityElement(children: .combine)
        } else if datos.yaLlegado > 0.004 {
            Label("Todo apartado", systemImage: "checkmark.seal.fill")
                .font(.headline)
                .foregroundStyle(Diseno.verde)
                .symbolEffect(.bounce, value: datos.apartado)
        }
    }

    @ViewBuilder
    private var barra: some View {
        let hucha = max(datos.hucha, 0)
        let apartado = min(datos.apartado, hucha)
        let llegadoSinApartar = max(0, min(datos.yaLlegado, hucha) - apartado)
        let porLlegar = max(0, hucha - apartado - llegadoSinApartar)
        VStack(alignment: .leading, spacing: Diseno.hueco2) {
            HStack(alignment: .firstTextBaseline) {
                Text("Reserva de \(CobrosHucha.nombreDelMes(datos.mes))")
                    .font(.subheadline).foregroundStyle(.secondary)
                Spacer()
                Text(Formato.euros(datos.hucha))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(datos.hucha < 0 ? Diseno.rojo : Color.primary)
                    .monospacedDigit()
                    .contentTransition(.numericText())
            }

            if hucha > 0.004 {
                GeometryReader { g in
                    HStack(spacing: 2) {
                        tramo(apartado / hucha, g.size.width, AnyShapeStyle(Diseno.verdeRelleno))
                        tramo(llegadoSinApartar / hucha, g.size.width,
                              AnyShapeStyle(Diseno.azulRelleno))
                        tramo(porLlegar / hucha, g.size.width, AnyShapeStyle(.fill.secondary))
                    }
                }
                .frame(height: 10)
                .clipShape(.capsule)
                .animation(Diseno.suave, value: datos)
            }
            HStack(spacing: Diseno.hueco3) {
                leyenda(Diseno.verdeRelleno, "apartado", datos.apartado)
                leyenda(Diseno.azulRelleno, "por apartar", max(0, datos.yaLlegado - datos.apartado))
                leyenda(Color.secondary.opacity(0.4), "por llegar", datos.porLlegar)
            }
        }
    }

    private func tramo(_ parte: Double, _ ancho: CGFloat, _ estilo: AnyShapeStyle) -> some View {
        Rectangle()
            .fill(estilo)
            .frame(width: max(0, (ancho - 4) * parte))
            .opacity(parte > 0.001 ? 1 : 0)
    }

    private func leyenda(_ color: Color, _ texto: String, _ valor: Double) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: 4) {
                Circle().fill(color).frame(width: 7, height: 7)
                Text(texto).font(.caption2).foregroundStyle(.secondary)
            }
            Text(Formato.eurosRedondos(valor))
                .font(.caption.weight(.semibold))
                .monospacedDigit()
                .contentTransition(.numericText())
        }
        .accessibilityElement(children: .combine)
    }

    private var visibles: [CobrosHucha.Cobro] {
        switch plataforma {
        case "todo": return datos.cobros
        
        case "tienda":
            return datos.cobros.filter { !["plataforma1", "plataforma2"].contains($0.plataforma) }
        default: return datos.cobros.filter { $0.plataforma == plataforma }
        }
    }

    @ViewBuilder
    private var lista: some View {
        let cobros = visibles
        if cobros.isEmpty {
            Tarjeta {
                Vacio(icono: "calendar.badge.clock",
                      titulo: "Nada en \(CobrosHucha.nombreDelMes(datos.mes))")
            }
        } else {
            Tarjeta(relleno: 0) {
                VStack(spacing: 0) {
                    ForEach(Array(cobros.enumerated()), id: \.element.id) { i, c in
                        FilaApartar(cobro: c, primero: i == 0, ultimo: i == cobros.count - 1,
                                    marcando: marcando == c.id,
                                    alCompletar: { completar(c) }) { marcar(c) }
                    }
                }
                .padding(.vertical, Diseno.hueco1)
            }
        }
    }
}

private struct FilaApartar: View {
    let cobro: CobrosHucha.Cobro
    let primero: Bool
    let ultimo: Bool
    let marcando: Bool
    var alCompletar: () -> Void = {}
    let alMarcar: () -> Void

    private var color: Color { Diseno.colorDePlataforma(cobro.plataforma) }

    private var nombre: String { Diseno.nombreDePlataforma(cobro.plataforma) }

    var body: some View {
        HStack(alignment: .top, spacing: Diseno.hueco2) {
            VStack(spacing: 0) {
                Rectangle().fill(primero ? Color.clear : Color.secondary.opacity(0.25))
                    .frame(width: 2, height: 16)
                Circle()
                    .fill(cobro.llegado ? color : Color.clear)
                    .overlay(Circle().strokeBorder(color, lineWidth: cobro.llegado ? 0 : 2))
                    .frame(width: 12, height: 12)
                Rectangle().fill(ultimo ? Color.clear : Color.secondary.opacity(0.25))
                    .frame(width: 2)
                    .frame(maxHeight: .infinity)
            }
            .frame(width: 12)

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline) {
                    Text(nombre).font(.subheadline.weight(.semibold))
                    Spacer()
                    
                    Text((cobro.estimado && !cobro.llegado ? "≈ " : "")
                         + Formato.euros(cobro.eurosDelMes))
                        .font(.subheadline.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(cobro.llegado ? .primary : .secondary)
                }
                HStack(spacing: 5) {
                    if cobro.tipo != "juntando", !cobro.fecha.isEmpty {
                        Image(systemName: cobro.llegado ? "checkmark" : "clock")
                            .font(.caption2.weight(.semibold))
                        Text("\(Formato.diaCorto(cobro.fecha)) · \(cobro.etiqueta)")
                    } else {
                        Text(cobro.etiqueta)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(detalleAccesible)

                if cobro.otrosMeses {
                    Text("parte de \(Formato.euros(cobro.euros))")
                        .font(.caption2).foregroundStyle(.secondary)
                }
                if cobro.llegado && cobro.paraImpuestos > 0.004 {
                    Label("\(Formato.euros(cobro.paraImpuestos)) para impuestos",
                          systemImage: "building.columns")
                        .font(.caption2).foregroundStyle(.secondary)
                }
                pie
            }
            .padding(.vertical, Diseno.hueco2)
        }
        .padding(.horizontal, Diseno.hueco3)
    }

    private var detalleAccesible: String {
        guard cobro.tipo != "juntando", !cobro.fecha.isEmpty else { return cobro.etiqueta }
        return "\(cobro.etiqueta), \(cobro.llegado ? "llegó" : "llega") el "
            + Formato.diaCorto(cobro.fecha)
    }

    @ViewBuilder
    private var pie: some View {
        if cobro.tipo == "juntando" {
            
            let falta = min(100, max(0, cobro.faltaUSD))
            VStack(alignment: .leading, spacing: 4) {
                ProgressView(value: 100 - falta, total: 100)
                    .tint(color)
                Text("faltan \(Formato.eurosRedondos(falta).replacingOccurrences(of: "€", with: "$")) para cobrar")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .padding(.top, 2)
            .accessibilityElement(children: .combine)
        } else if cobro.llegado, let x = cobro.paraLaHucha {
            VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center, spacing: Diseno.hueco2) {
                if x > 0.004 {
                    Label {
                        Text(Formato.euros(x))
                            .font(.headline)
                            .monospacedDigit()
                    } icon: {
                        Image(systemName: cobro.apartado ? "checkmark.circle.fill"
                                                         : "tray.and.arrow.down.fill")
                    }
                    .foregroundStyle(cobro.apartado ? Diseno.verde : Diseno.azul)
                    .accessibilityLabel(cobro.apartado ? "Apartado \(Formato.euros(x))"
                                                       : "Para apartar \(Formato.euros(x))")
                    Spacer()
                    Button(action: alMarcar) {
                        Group {
                            if marcando {
                                ProgressView().controlSize(.small)
                            } else {
                                Image(systemName: cobro.apartado ? "checkmark.circle.fill"
                                                                 : "circle")
                                    .font(.system(size: 28))
                                    .foregroundStyle(cobro.apartado ? Diseno.verdeRelleno
                                                                    : Color.secondary)
                                    .contentTransition(.symbolEffect(.replace))
                            }
                        }
                        .frame(width: 44, height: 44)
                        .contentShape(.rect)
                    }
                    .buttonStyle(.borderless)
                    .disabled(marcando)
                    
                    .sensoryFeedback(.success, trigger: cobro.apartado) { _, ahora in ahora }
                    .accessibilityLabel(cobro.apartado ? "Apartado. Toca para desmarcar"
                                                       : "Marcar como apartado")
                } else {
                    
                    Label("nada que apartar", systemImage: "minus.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            }
            if cobro.apartado && cobro.faltaMas > 0.004 {
                FaltaMas(euros: cobro.faltaMas, motivo: "la reserva necesita más de este cobro",
                         trabajando: marcando, accion: alCompletar)
            }
            }
        }
    }
}

struct FaltaMas: View {
    let euros: Double
    let motivo: String
    let trabajando: Bool
    let accion: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: Diseno.hueco2) {
            VStack(alignment: .leading, spacing: 1) {
                Label("Faltan \(Formato.euros(euros)) más", systemImage: "arrow.up.circle.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Diseno.azul)
                    .monospacedDigit()
                Text(motivo).font(.caption2).foregroundStyle(.secondary)
            }
            Spacer()
            Button(action: accion) {
                if trabajando { ProgressView().controlSize(.small) } else { Text("Apartado") }
            }
            .buttonStyle(.glass)
            .disabled(trabajando)
            .accessibilityLabel("Apartados \(Formato.euros(euros)) más")
        }
        .transition(.opacity.combined(with: .move(edge: .top)))
    }
}
