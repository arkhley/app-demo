import SwiftUI
import WidgetKit

public enum FormaWidget: CaseIterable, Sendable {
    case pequeno, rectangular, circular, linea
}

public extension TonoWidget {
    var color: Color {
        switch self {
        case .azul: return .blue
        case .naranja: return .orange
        case .rojo: return .red
        case .verde: return .green
        case .gris: return .secondary
        }
    }
}

public struct VistaWidget: View {
    let i: Instantanea?
    let oculto: Bool
    let forma: FormaWidget

    let ahora: Date

    public init(_ i: Instantanea?, oculto: Bool, forma: FormaWidget, ahora: Date = Date()) {
        self.i = i
        self.oculto = oculto
        self.forma = forma
        self.ahora = ahora
    }

    private var deCuando: String? {
        guard let g = i?.generado, ahora.timeIntervalSince(g) > 30 * 60 else { return nil }
        return "a las " + g.formatted(.dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits)
            .locale(Locale(identifier: "es_ES")))
    }

    public var body: some View {
        Group {
            if let i {
                switch forma {
                case .pequeno: Pequeno(i: i, oculto: oculto, deCuando: deCuando)
                case .rectangular: Rectangular(i: i, oculto: oculto, deCuando: deCuando)
                case .circular: Circular(i: i, oculto: oculto)
                case .linea: Linea(i: i, oculto: oculto, deCuando: deCuando)
                }
            } else {
                SinDatos(forma: forma)
            }
        }

        .dynamicTypeSize(...DynamicTypeSize.xxLarge)
        .accessibilityElement(children: .combine)
    }
}

private struct Pequeno: View {
    let i: Instantanea
    let oculto: Bool
    let deCuando: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Image(systemName: i.simbolo)
                    .foregroundStyle(i.tono.color)
                    .symbolRenderingMode(.hierarchical)
                    .widgetAccentable()
                Text(i.veredicto)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
            }
            .font(.subheadline.weight(.semibold))

            Spacer(minLength: 6)

            if let c = i.cifra {
                Text(CifraWidget.euros(c.euros, oculto: oculto))
                    .font(.system(size: 34, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .privacySensitive()
                
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 4) {
                        Text(c.que)
                        if let deCuando { Text("· \(deCuando)") }
                        else if i.enDirecto, let rato = i.rato { Text("· \(rato)") }
                    }
                    Text(c.que)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            }

            Spacer(minLength: 6)

            if let a = i.avance {
                BarraDelObjetivo(avance: a, color: i.objetivoCubierto ? .blue : i.tono.color)
                    .frame(height: 5)
            } else if let apoyo = i.apoyo({ CifraWidget.euros($0, oculto: oculto) }) {
                Text(apoyo)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

private struct BarraDelObjetivo: View {
    let avance: Double
    let color: Color

    var body: some View {
        GeometryReader { g in
            ZStack(alignment: .leading) {
                Capsule().fill(.secondary.opacity(0.25))
                Capsule()
                    .fill(color.gradient)
                    .frame(width: max(g.size.height, g.size.width * avance))
                    .widgetAccentable()
            }
        }
        .accessibilityHidden(true)
    }
}

private struct Rectangular: View {
    let i: Instantanea
    let oculto: Bool
    let deCuando: String?

    private func euros(_ v: Double) -> String { CifraWidget.euros(v, oculto: oculto) }

    private func cabecera(_ veredicto: String, conRato: Bool = true) -> some View {
        HStack(spacing: 4) {
            Image(systemName: i.simbolo).widgetAccentable()
            Text(veredicto)
            if conRato, i.enDirecto, let rato = i.rato { Text("· \(rato)").fontWeight(.regular) }
        }
        .font(.headline)
        .lineLimit(1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {

            ViewThatFits(in: .horizontal) {
                cabecera(i.veredicto)
                cabecera(i.veredictoCorto)
                cabecera(i.veredictoCorto, conRato: false)
                    .minimumScaleFactor(0.75)
            }

            if i.nocheEnMarcha {
                Text("\(euros(i.hoy.euros)) esta noche" + (deCuando.map { " · \($0)" } ?? ""))
                    .font(.body.weight(.medium))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .privacySensitive()
            }
            if let apoyo = i.apoyo(euros) {
                Text(apoyo)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            if !i.nocheEnMarcha, let n = i.normal {
                Text("Si emites, unos \(euros(n))" + (deCuando.map { " · \($0)" } ?? ""))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .privacySensitive()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct Circular: View {
    let i: Instantanea
    let oculto: Bool

    var body: some View {
        if let a = i.avance {
            
            Gauge(value: a) {
                Image(systemName: i.simbolo)
            } currentValueLabel: {
                Text(CifraWidget.numero(i.hoy.euros, oculto: oculto))
                    .monospacedDigit()
                    .minimumScaleFactor(0.6)
                    .privacySensitive()
            }
            .gaugeStyle(.accessoryCircularCapacity)
            .tint(i.objetivoCubierto ? .blue : i.tono.color)
        } else {
            ZStack {
                AccessoryWidgetBackground()
                Image(systemName: i.simbolo)
                    .font(.title2.weight(.semibold))
                    .widgetAccentable()
            }
            .accessibilityLabel(i.veredicto)
        }
    }
}

private struct Linea: View {
    let i: Instantanea
    let oculto: Bool
    
    var deCuando: String?

    private var texto: String {
        let euros = CifraWidget.euros(i.hoy.euros, oculto: oculto)
        if i.enDirecto, let deCuando { return "\(euros) · \(deCuando)" }
        if i.enDirecto { return i.rato.map { "\(euros) · \($0)" } ?? euros }
        if i.estado == "hecho" && i.manana == nil { return "\(euros) esta noche" }
        return i.veredictoCorto
    }

    var body: some View {
        Label(texto, systemImage: i.simbolo)
            .privacySensitive(i.nocheEnMarcha)
    }
}

private struct SinDatos: View {
    let forma: FormaWidget

    var body: some View {
        switch forma {
        case .pequeno:
            VStack(alignment: .leading, spacing: 6) {
                Image(systemName: "moon.stars.fill")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
                Text("Abre la app para ver esta noche")
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(3)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        case .rectangular:
            Label("Abre la app para ver esta noche", systemImage: "moon.stars.fill")
                .font(.headline)
                .lineLimit(2)
        case .circular:
            ZStack {
                AccessoryWidgetBackground()
                Image(systemName: "moon.stars.fill").font(.title2)
            }
        case .linea:
            Label("Abre la app", systemImage: "moon.stars.fill")
        }
    }
}
