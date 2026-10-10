import SwiftUI

enum Marcador {

    static func paleta(_ clave: String) -> [Color] {
        switch clave {
        case "plataforma1": return [.orange, ambar, .pink]
        case "plataforma2": return [.purple, .pink, .indigo]
        case "tienda": return [.blue, .cyan, .indigo]
        case "todo": return [.green, .mint, .teal]
        default: return [.blue, .cyan, .mint]
        }
    }

    static let ambar = Color(UIColor { rasgos in
        rasgos.userInterfaceStyle == .dark ? UIColor(red: 1.0, green: 0.62, blue: 0.14, alpha: 1)
                                           : .systemYellow
    })

    static let apoyo = Diseno.sobreTinte
}

struct CampoDeColor: View {
    let plataforma: String
    
    var enDirecto = false

    @Environment(\.colorScheme) private var modo
    @Environment(\.accessibilityReduceMotion) private var menosMovimiento
    @Environment(\.accessibilityReduceTransparency) private var menosTransparencia
    @Environment(\.tema) private var tema

    var body: some View {
        ZStack {
            if tema.esDeFoto {
                FondoDeFoto()
                if enDirecto { luzDelDirecto }
            } else if tema.esOriginal {
                malla.id(tema.id)
            } else {
                
                FondoDeTema(sitio: .inicio(plataforma: plataforma, directo: enDirecto))
                    .id(tema.id)
            }
        }
        .ignoresSafeArea()
    }

    nonisolated static func tonos(_ plataforma: String, tema: Tema, oscuro: Bool) -> [Color] {
        if let delTema = tema.tonosDelCampo(plataforma) { return delTema }
        return Marcador.paleta(plataforma).map { $0.mix(with: mezcla(oscuro), by: fuerza(oscuro)) }
    }

    private nonisolated static func mezcla(_ oscuro: Bool) -> Color { oscuro ? .black : .white }
    private nonisolated static func fuerza(_ oscuro: Bool) -> Double { oscuro ? 0.32 : 0.22 }

    private var malla: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: menosMovimiento)) { t in
            degradado(Float(menosMovimiento ? 0 : t.date.timeIntervalSinceReferenceDate))
        }

        .opacity(menosTransparencia ? 0.6 : 1)
    }

    private func degradado(_ s: Float) -> MeshGradient {
        let latido: Float = enDirecto && !menosMovimiento ? 0.08 * sin(s * 2.4) : 0
        let oscuro = modo == .dark
        var a = Self.tonos(plataforma, tema: tema, oscuro: oscuro)

        if enDirecto {
            a[1] = a[1].mix(with: Color.red.mix(with: Self.mezcla(oscuro), by: Self.fuerza(oscuro)), by: 0.7)
        }
        let base = tema.colorDeFondo
        let medio = a.map { $0.mix(with: base, by: 0.55) }
        return MeshGradient(
            width: 3, height: 4,
            points: [
                [0, 0], [0.5, 0], [1, 0],
                [0, 0.24 + 0.03 * sin(s * 0.5)],
                [0.5 + 0.10 * sin(s * 0.33), 0.28 + 0.05 * cos(s * 0.41) + latido],
                [1, 0.22 + 0.03 * cos(s * 0.47)],
                [0, 0.50], [0.5 + 0.06 * cos(s * 0.29), 0.54], [1, 0.48],
                [0, 1], [0.5, 1], [1, 1],
            ],
            colors: [
                a[0], a[1], a[2],
                a[2], a[0], a[1],
                medio[1], medio[2], medio[0],
                base, base, base,
            ])
    }

    private var luzDelDirecto: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: menosMovimiento)) { t in
            let s = menosMovimiento ? 0 : t.date.timeIntervalSinceReferenceDate
            let latido = menosMovimiento ? 1 : 0.75 + 0.25 * sin(s * 2.4)
            GeometryReader { g in
                RadialGradient(colors: [Joya.luzDirecto.opacity((modo == .dark ? 0.34 : 0.3) * latido),
                                        Joya.luzDirecto.opacity(0)],
                               center: UnitPoint(x: 0.5, y: 0.12),
                               startRadius: 0, endRadius: max(g.size.width, 1) * 0.8)
                    .blendMode(modo == .dark ? .plusLighter : .normal)
            }
        }
        .accessibilityHidden(true)
    }
}

struct EquiposDeCristal: View {
    let equipos: [(clave: String, nombre: String)]
    let elegido: String
    let elegir: (String) -> Void
    @Namespace private var espacio
    @Environment(\.accessibilityReduceTransparency) private var menosTransparencia
    @Environment(\.colorScheme) private var modo

    var body: some View {
        ScrollViewReader { lector in
            ScrollView(.horizontal, showsIndicators: false) {
                GlassEffectContainer(spacing: 8) {
                    HStack(spacing: 8) {
                        ForEach(equipos, id: \.clave) { e in
                            let esta = e.clave == elegido
                            let color = Diseno.colorDePlataforma(e.clave)
                            Button { elegir(e.clave) } label: {
                                HStack(spacing: 7) {
                                    Circle().fill(color.gradient).frame(width: 9, height: 9)
                                    Text(e.nombre)
                                        .font(.subheadline.weight(esta ? .semibold : .medium))
                                        .lineLimit(1)
                                }
                                .padding(.horizontal, 14)
                                .frame(minHeight: 44)

                                .foregroundStyle(esta || (modo == .dark)
                                                 ? AnyShapeStyle(.primary) : AnyShapeStyle(Marcador.apoyo))
                                .cristal(.regular.tint(esta ? color.opacity(0.35) : .clear).interactive(),
                                         en: .capsule)
                                
                                .overlay {
                                    if esta && menosTransparencia {
                                        Capsule().strokeBorder(color, lineWidth: 1.5)
                                    }
                                }
                                .glassEffectID(e.clave, in: espacio)
                                .contentShape(.capsule)
                            }
                            .buttonStyle(.plain)
                            .id(e.clave)
                            .accessibilityLabel(e.nombre)
                            .accessibilityAddTraits(esta ? .isSelected : [])
                        }
                    }
                    .padding(.horizontal, Diseno.margen)
                    .padding(.vertical, 2)
                }
            }
            .scrollClipDisabled()
            .modifier(BordeQueSigue())
            .onChange(of: elegido) { _, nuevo in
                withAnimation(Diseno.suave) { lector.scrollTo(nuevo, anchor: .center) }
            }
        }

        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
    }
}

struct PastillaDeCristal: View {
    let texto: String
    var icono: String?
    var tinte: Color = .clear
    
    var piloto: Color?

    var hueco = false

    @Environment(\.colorScheme) private var modo

    private var fuerzaTinte: Double { modo == .dark ? 0.16 : 0.28 }

    var body: some View {
        let contenido = HStack(spacing: 6) {
            if let piloto {
                PilotoRadar(color: piloto, activo: true, lado: 7)
            } else if let icono {
                Image(systemName: icono).imageScale(.small)
            }
            Text(texto).lineLimit(1)
        }
        .font(.footnote.weight(.semibold))
        .monospacedDigit()
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        Group {
            if hueco {
                contenido.hidden().accessibilityHidden(true)
            } else {
                contenido.cristal(.regular.tint(tinte.opacity(fuerzaTinte)), en: .capsule)
            }
        }
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
    }
}

struct CifraMarcador: View {
    let euros: Double
    @ScaledMetric(relativeTo: .largeTitle) private var tam: CGFloat = 80

    var body: some View {
        Text(Formato.eurosRedondos(euros))
            .font(.system(size: min(tam, 104), weight: .bold, design: .rounded))
            .monospacedDigit()
            .contentTransition(.numericText(value: euros))
            .lineLimit(1)
            .minimumScaleFactor(0.45)
            
            .chocableComoTexto(tamano: min(tam, 104))
            .accessibilityLabel(Formato.euros(euros))
    }
}

struct CintaDeDias: View {
    
    let valores: [Double?]
    
    let hoy: Int?
    let color: Color
    var enDirecto = false
    
    var hoyCubierto = false
    
    var resaltada: Int?
    
    var version: String = ""

    @Environment(\.colorScheme) private var modo
    @Environment(\.accessibilityReduceMotion) private var menosMovimiento
    @State private var subida = false

    private static let alto: CGFloat = 30

    static func espacio(_ casillas: Int) -> CGFloat { casillas > 20 ? 3 : 5 }

    var body: some View {
        let tinta: Color = modo == .dark ? .white : color
        HStack(alignment: .bottom, spacing: Self.espacio(valores.count)) {
            ForEach(valores.indices, id: \.self) { i in
                raya(i, valor: valores[i], tinta: tinta)
                    .chocable(.capsula, reacciona: true)
                    .scaleEffect(x: 1, y: subida || menosMovimiento ? 1 : 0.1, anchor: .bottom)
                    .animation(menosMovimiento ? nil
                               : .spring(duration: 0.55, bounce: 0.35).delay(Double(i) * 0.014),
                               value: subida)
            }
        }
        .frame(height: Self.alto, alignment: .bottom)
        .onAppear { subida = true }
        .onChange(of: version) {
            guard !menosMovimiento else { return }
            subida = false
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(30))
                subida = true
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(resumen)
    }

    @ViewBuilder
    private func raya(_ i: Int, valor: Double?, tinta: Color) -> some View {
        let esHoy = i == hoy
        let luz = resaltada == i
        let atenuada = resaltada != nil && !luz
        if esHoy && hoyCubierto {
            
            Capsule()
                .fill(Diseno.azulRelleno.gradient)
                .overlay {
                    Image(systemName: "checkmark")
                        .font(.system(size: 7, weight: .heavy))
                        .foregroundStyle(.white)
                }
                .frame(height: Self.alto)
                .shadow(color: Diseno.azulRelleno.opacity(0.6), radius: 4, x: 0, y: 1)
                .transition(.scale.combined(with: .opacity))
        } else if esHoy {
            Capsule()
                .fill(enDirecto ? AnyShapeStyle(Diseno.rojoRelleno.gradient) : AnyShapeStyle(tinta.gradient))
                .overlay { filo }
                .frame(height: (valor ?? 0) > 0 || enDirecto ? Self.alto : 14)
                .shadow(color: (enDirecto ? Diseno.rojoRelleno : color).opacity(0.6), radius: 4, x: 0, y: 1)
                .modifier(LatidoDeHoy(activo: !menosMovimiento))
                .opacity(atenuada ? 0.45 : 1)
        } else if let v = valor {
            if v > 0 {
                Capsule()
                    .fill(tinta.gradient)
                    .overlay { filo }
                    .frame(height: Self.alto)
                    .shadow(color: color.opacity(luz ? 0.9 : 0.35), radius: luz ? 7 : 2, x: 0, y: 1)
                    .opacity(atenuada ? 0.45 : 1)
            } else {
                
                Capsule().fill(.secondary.opacity(0.35)).frame(height: 6)
                    .opacity(atenuada ? 0.5 : 1)
            }
        } else {
            Capsule().strokeBorder(Marcador.apoyo.opacity(0.5), lineWidth: 1).frame(height: 10)
        }
    }

    @ViewBuilder
    private var filo: some View {
        if modo == .light {
            Capsule().strokeBorder(.black.opacity(0.45), lineWidth: 0.75)
        }
    }

    private var resumen: String {
        let pasados = valores.compactMap { $0 }
        let emitidos = pasados.filter { $0 > 0 }.count
        let quedan = valores.filter { $0 == nil }.count
        var partes = ["\(emitidos) de \(pasados.count) días con ingresos"]
        if quedan > 0 { partes.append(quedan == 1 ? "queda 1 día" : "quedan \(quedan) días") }
        if enDirecto { partes.append("hoy en directo") }
        if hoyCubierto { partes.append("objetivo de hoy cubierto") }
        return partes.joined(separator: ", ")
    }
}

private struct LatidoDeHoy: ViewModifier {
    let activo: Bool
    @State private var arriba = false

    func body(content: Content) -> some View {
        content
            .opacity(activo && arriba ? 0.6 : 1)
            .animation(activo ? .easeInOut(duration: 1.1).repeatForever(autoreverses: true) : nil,
                       value: arriba)
            .onAppear { if activo { arriba = true } }
    }
}

struct BarraDeHoy: View {
    let euros: Double
    let objetivo: Double
    let color: Color
    var enDirecto = false
    
    var soloObjetivo = false

    @Environment(\.colorScheme) private var modo
    @Environment(\.accessibilityReduceMotion) private var menosMovimiento
    @State private var llena = false

    var body: some View {
        let tope = max(objetivo * 1.25, euros, 1)
        let cubierto = objetivo > 0 && euros >= objetivo
        VStack(alignment: .leading, spacing: 8) {
            GeometryReader { g in
                let w = g.size.width
                ZStack(alignment: .leading) {
                    Capsule().fill(.fill.tertiary)
                    Capsule()
                        .fill((cubierto ? Diseno.verdeRelleno : (modo == .dark ? .white : color)).gradient)

                        .overlay {
                            if modo == .light {
                                Capsule().strokeBorder(.black.opacity(0.6), lineWidth: 0.75)
                            }
                        }
                        .frame(width: max(14, w * CGFloat(euros / tope) * (llena ? 1 : 0)))
                        .shadow(color: color.opacity(0.5), radius: 6, x: 0, y: 2)
                    if objetivo > 0 {
                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(Diseno.azulRelleno)
                            .frame(width: 3, height: 26)
                            .position(x: w * CGFloat(objetivo / tope), y: 9)
                    }
                    if enDirecto {
                        PilotoRadar(color: Diseno.rojoRelleno, activo: true, lado: 8)
                            .position(x: max(10, w * CGFloat(euros / tope) - 10), y: 9)
                    }
                }
            }
            .frame(height: 18)
            HStack {
                if objetivo > 0 && !soloObjetivo {

                    Label {
                        Text(cubierto ? "Objetivo de hoy cubierto"
                                      : "Faltan \(Formato.eurosJustos(objetivo - euros)) para el objetivo")
                            .foregroundStyle(cubierto ? AnyShapeStyle(.primary) : AnyShapeStyle(Marcador.apoyo))
                    } icon: {
                        Image(systemName: cubierto ? "checkmark.circle.fill" : "target")
                            .foregroundStyle(cubierto ? AnyShapeStyle(Diseno.verdeRelleno) : AnyShapeStyle(Marcador.apoyo))
                    }
                }
                Spacer()
                if objetivo > 0 {
                    
                    HStack(spacing: 5) {
                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(Diseno.azulRelleno)
                            .frame(width: 3, height: 12)
                            .accessibilityHidden(true)
                        Text(Formato.eurosJustos(objetivo)).foregroundStyle(.primary)
                    }
                }
            }
            .font(.footnote.weight(.semibold))
            .monospacedDigit()
        }
        .onAppear {
            if menosMovimiento { llena = true } else {
                withAnimation(.spring(duration: 0.8, bounce: 0.2).delay(0.1)) { llena = true }
            }
        }
        .sensoryFeedback(.success, trigger: cubierto) { antes, ahora in ahora && !antes }
        .accessibilityElement(children: .combine)
    }
}

struct ModuloEstaNoche: View {
    let p: PrevisionHoy
    var sala: Int = 0
    let abrir: () -> Void

    var body: some View {
        Button(action: abrir) {
            Group {
                if p.hoy.emitiendo { enDirecto } else { fueraDeDirecto }
            }
            .padding(Diseno.hueco3)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(.rect(cornerRadius: 28))
        }
        .buttonStyle(.plain)
        .cristal(.regular.interactive(), en: .rect(cornerRadius: 28))
        .accessibilityLabel(p.resumenAccesible)
        .accessibilityHint("Abre la previsión")
    }

    private var enDirecto: some View {
        let falta = p.objetivo - p.hoy.euros
        return VStack(alignment: .leading, spacing: Diseno.hueco2) {
            HStack {
                PastillaDeCristal(texto: "En directo", tinte: Diseno.rojoRelleno,
                                  piloto: Diseno.rojoRelleno)
                Spacer()
                if sala > 0 {
                    Label("\(sala)", systemImage: "person.2.fill")
                        .font(.footnote.weight(.semibold)).monospacedDigit()
                        .foregroundStyle(Marcador.apoyo)
                        .accessibilityLabel(sala == 1 ? "1 en la sala" : "\(sala) en la sala")
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                if p.objetivo > 0 {
                    let texto = Text(falta >= 1 ? "Faltan \(Formato.eurosRedondos(falta))"
                         : (-falta >= 1 ? "\(Formato.eurosRedondos(-falta)) por encima" : "Objetivo cubierto"))
                        .font(.system(.title, design: .rounded).weight(.bold)).monospacedDigit()
                        .contentTransition(.numericText(value: falta))
                        .animation(.snappy, value: falta)
                    
                    HStack(spacing: 6) {
                        if falta < 1 {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.title2)
                                .foregroundStyle(.white, Diseno.verdeRelleno)
                                .transition(.scale.combined(with: .opacity))
                                .accessibilityHidden(true)
                        }
                        texto.foregroundStyle(.primary)
                    }
                    .animation(.snappy, value: falta < 1)
                }
                Text(pieDelDirecto(falta: falta))
                    .font(.subheadline).foregroundStyle(Marcador.apoyo)
            }
            if p.objetivo > 0 {
                BarraDeHoy(euros: p.hoy.euros, objetivo: p.objetivo, color: Diseno.verdeRelleno,
                           enDirecto: true, soloObjetivo: true)
            }
        }
    }

    private func pieDelDirecto(falta: Double) -> String {
        var partes: [String] = []
        if p.objetivo > 0 {
            if falta >= 1 { partes.append("para el objetivo de hoy") }
            else if -falta >= 1 { partes.append("del objetivo de hoy") }
        }
        switch p.hoy.personas {
        case 0: if partes.isEmpty { partes.append("Nadie te ha dado propina todavía") }
        case 1: partes.append("1 te ha dado propina")
        default: partes.append("\(p.hoy.personas) te han dado propina")
        }
        return partes.joined(separator: " · ")
    }

    private var fueraDeDirecto: some View {
        HStack(alignment: .top, spacing: Diseno.hueco3) {
            VStack(alignment: .leading, spacing: 4) {
                if p.hoy.trabajado {
                    Text("Esta noche").font(.footnote).foregroundStyle(Marcador.apoyo)
                    Text(Formato.eurosRedondos(p.hoy.euros))
                        .font(.system(.title, design: .rounded).weight(.bold)).monospacedDigit()
                        .contentTransition(.numericText(value: p.hoy.euros))
                        .animation(.snappy, value: p.hoy.euros)
                    posicion(p.hoy.posicion)
                } else if let ultima = p.recientes.last {
                    Text("Última noche · \(Formato.diaSemana(ultima.fecha))")
                        .font(.footnote).foregroundStyle(Marcador.apoyo)
                    Text(Formato.eurosRedondos(ultima.euros))
                        .font(.system(.title, design: .rounded).weight(.bold)).monospacedDigit()
                    posicion(posicionDe(ultima.euros))
                }
            }
            Spacer(minLength: Diseno.hueco1)
            if let plan = p.plan { descansos(plan) }
        }
    }

    private func descansos(_ plan: PrevisionHoy.Plan) -> some View {
        let (cifra, pie, color): (String, String, Color) = {
            if plan.cubierto { return ("Cubierto", "el mes, emitas o no", Diseno.verde) }
            if !plan.llega { return ("Ninguno", "y el mes va justo", Diseno.rojo) }
            switch plan.descansos {
            case 0: return ("Ninguno", "descanso más este mes", Diseno.naranja)
            case 1: return ("1", "descanso este mes", Diseno.azul)
            default: return ("unos \(plan.descansos)", "descansos este mes", Diseno.azul)
            }
        }()
        return VStack(alignment: .trailing, spacing: 4) {
            Image(systemName: "moon.zzz.fill")
                .font(.body)
                .foregroundStyle(color)
                .symbolRenderingMode(.hierarchical)

            Text(cifra)
                .font(.system(.title2, design: .rounded).weight(.bold))
                .foregroundStyle(Color.primary)
                .contentTransition(.numericText())
            Text(pie)
                .font(.footnote)
                .foregroundStyle(Marcador.apoyo)
                .multilineTextAlignment(.trailing)
        }
    }

    private func posicionDe(_ euros: Double) -> String? {
        guard let n = p.noche else { return nil }
        if euros > n.p75 { return "encima" }
        if euros < n.p25 { return "debajo" }
        return "normal"
    }

    @ViewBuilder
    private func posicion(_ cual: String?) -> some View {
        switch cual {
        case "encima":
            
            Label {
                Text("por encima de lo normal").foregroundStyle(.primary)
            } icon: {
                Image(systemName: "arrow.up.right").foregroundStyle(Diseno.verde)
            }
            .font(.footnote.weight(.medium))
        case "debajo":
            Label("por debajo de lo normal", systemImage: "arrow.down.right")
                .font(.footnote.weight(.medium)).foregroundStyle(Marcador.apoyo)
        case "normal":
            Label("una noche normal", systemImage: "equal")
                .font(.footnote.weight(.medium)).foregroundStyle(Marcador.apoyo)
        default:
            EmptyView()
        }
    }
}

struct TablaClasificacion: View {
    struct Fila: Identifiable {
        let clave: String
        let nombre: String
        let euros: Double
        let detalle: String
        let cambio: Tendencia?
        var id: String { clave }
    }
    let filas: [Fila]
    let elegir: (String) -> Void

    var body: some View {
        let total = max(filas.reduce(0) { $0 + $1.euros }, 0.01)
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(filas.enumerated()), id: \.element.id) { i, f in
                Button { elegir(f.clave) } label: {
                    HStack(spacing: Diseno.hueco2) {
                        Text("\(i + 1)")
                            .font(.system(.title3, design: .rounded).weight(.bold)).monospacedDigit()
                            .foregroundStyle(Marcador.apoyo)
                            .frame(width: 22)
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(alignment: .firstTextBaseline) {
                                Text(f.nombre).font(.headline)
                                Spacer()
                                Text(Formato.eurosRedondos(f.euros))
                                    .font(.headline).monospacedDigit()
                                    .contentTransition(.numericText(value: f.euros))
                            }
                            HStack(spacing: Diseno.hueco2) {
                                GeometryReader { g in
                                    ZStack(alignment: .leading) {
                                        Capsule().fill(.fill.quaternary)
                                        Capsule().fill(Diseno.colorDePlataforma(f.clave).gradient)
                                            .frame(width: max(6, g.size.width * CGFloat(f.euros / total)))
                                    }
                                }
                                .frame(height: 6)

                                Text("\(Int((f.euros / total * 100).rounded())) %")
                                    .font(.caption.weight(.semibold)).monospacedDigit()
                                    .foregroundStyle(Marcador.apoyo)
                                    .frame(minWidth: 34, alignment: .trailing)
                            }
                        }
                    }
                    .padding(.vertical, 12)
                    .contentShape(.rect)
                }
                .buttonStyle(Hundirse())
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(i + 1). \(f.nombre), \(Formato.euros(f.euros)), \(Int((f.euros / total * 100).rounded())) por ciento")
                .accessibilityHint("La elige arriba")
                if i < filas.count - 1 { Divider().padding(.leading, 34) }
            }
        }
    }
}

struct ResaltarFila: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(configuration.isPressed ? Color(.systemGray4) : .clear)
            .animation(configuration.isPressed ? nil : .easeOut(duration: 0.3),
                       value: configuration.isPressed)
    }
}

struct Hundirse: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var menosMovimiento

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !menosMovimiento ? 0.98 : 1)
            .opacity(configuration.isPressed ? 0.7 : 1)
            .animation(.spring(duration: 0.25, bounce: 0.3), value: configuration.isPressed)
    }
}

struct CobroQueLlega: Identifiable, Equatable {
    let id: String
    let plataforma: String
    let nombre: String
    let fecha: String
    let euros: Double
    let estimado: Bool
    
    var faltaUSD: Double = 0

    var nota: String {
        faltaUSD > 0.004 ? "cuando junte el mínimo · faltan \(Formato.dolares(faltaUSD))"
                         : "cuando junte el mínimo"
    }
}

struct FilasDeCobros: View {
    let cobros: [CobroQueLlega]

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(cobros.enumerated()), id: \.element.id) { i, c in
                HStack(spacing: Diseno.hueco2) {
                    Circle().fill(Diseno.colorDePlataforma(c.plataforma).gradient)
                        .frame(width: 10, height: 10)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(c.nombre).font(.headline)
                        Text(c.fecha.isEmpty ? c.nota : Formato.diaSemana(c.fecha).capitalized)
                            .font(.footnote).foregroundStyle(Marcador.apoyo)
                    }
                    Spacer()
                    Text((c.estimado ? "≈ " : "") + Formato.eurosRedondos(c.euros))
                        .font(.system(.headline, design: .rounded)).monospacedDigit()
                        .contentTransition(.numericText(value: c.euros))
                }
                .padding(.vertical, 12)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(c.nombre), \(c.fecha.isEmpty ? c.nota : Formato.diaCorto(c.fecha)), "
                                    + (c.estimado ? "unos " : "") + Formato.euros(c.euros))
                if i < cobros.count - 1 { Divider().padding(.leading, 22) }
            }
        }
    }
}

struct FilaDeNumeros: View {
    let numeros: [(titulo: String, valor: Int)]

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            ForEach(Array(numeros.enumerated()), id: \.offset) { i, n in
                VStack(alignment: .leading, spacing: 4) {
                    Text(n.titulo).font(.footnote).foregroundStyle(Marcador.apoyo)
                    Text("\(n.valor)")
                        .font(.system(.title2, design: .rounded).weight(.bold)).monospacedDigit()
                        .contentTransition(.numericText(value: Double(n.valor)))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityElement(children: .combine)
                if i < numeros.count - 1 {
                    Divider().frame(height: 44).padding(.horizontal, Diseno.hueco2)
                }
            }
        }
    }
}

struct FilaDeMedias: View {
    struct Media: Identifiable {
        let titulo: String
        let valor: Double?
        let tendencia: Tendencia?
        let nota: String?
        var id: String { titulo }
    }
    let medias: [Media]

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            ForEach(Array(medias.enumerated()), id: \.element.id) { i, m in
                VStack(alignment: .leading, spacing: 4) {
                    Text(m.titulo).font(.footnote).foregroundStyle(Marcador.apoyo)
                    Text(m.valor.map(Formato.eurosRedondos) ?? "—")
                        .font(.system(.title2, design: .rounded).weight(.bold)).monospacedDigit()
                        .contentTransition(.numericText(value: m.valor ?? 0))
                    if let t = m.tendencia {
                        
                        Label {
                            Text("\(t.porcentaje) %").foregroundStyle(Color.primary)
                        } icon: {
                            Image(systemName: t.sube ? "arrow.up.right" : "arrow.down.right")
                                .fontWeight(.bold)
                                .foregroundStyle(t.sube ? Diseno.verdeRelleno : Diseno.rojoRelleno)
                        }
                        .font(.caption.weight(.semibold)).monospacedDigit()
                    } else if let n = m.nota {
                        Text(n).font(.caption).foregroundStyle(Marcador.apoyo)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityElement(children: .combine)
                if i < medias.count - 1 {
                    Divider().frame(height: 44).padding(.horizontal, Diseno.hueco2)
                }
            }
        }
    }
}

struct TituloDeSeccion: View {
    let texto: String
    var dato: String?

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(texto).font(.title3.weight(.bold))
            Spacer()
            if let dato {
                Text(dato).font(.subheadline.weight(.medium)).monospacedDigit()
                    .foregroundStyle(Marcador.apoyo)
            }
        }
        .padding(.top, Diseno.hueco3)
        .accessibilityAddTraits(.isHeader)
    }
}

struct SeccionPlegable<Contenido: View>: View {
    let titulo: String
    let estado: String
    let bien: Bool
    @Binding var abierto: Bool
    @ViewBuilder var contenido: Contenido

    var body: some View {
        VStack(alignment: .leading, spacing: Diseno.hueco1) {
            Button {
                withAnimation(Diseno.suave) { abierto.toggle() }
            } label: {
                HStack(alignment: .firstTextBaseline, spacing: Diseno.hueco1) {
                    Text(titulo).font(.title3.weight(.bold))
                    Image(systemName: "chevron.down")
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(Marcador.apoyo)
                        .rotationEffect(.degrees(abierto ? 0 : -90))
                    Spacer()

                    Label {
                        Text(estado).foregroundStyle(Color.primary)
                    } icon: {
                        Image(systemName: bien ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                            .foregroundStyle(.white, bien ? Diseno.verdeRelleno : Diseno.rojoRelleno)
                    }
                    .font(.footnote.weight(.semibold))
                }
                .padding(.top, Diseno.hueco3)
                .contentShape(.rect)
            }
            .buttonStyle(Hundirse())
            .accessibilityAddTraits(.isHeader)
            .accessibilityValue(abierto ? "abierto" : "cerrado")

            if abierto {
                contenido
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}

struct BordeDeArribaSuave: ViewModifier {
    let activo: Bool

    func body(content: Content) -> some View {
        if activo {
            content.scrollEdgeEffectStyle(.soft, for: .top)
        } else {
            content
        }
    }
}

struct BordeQueSigue: ViewModifier {
    @State private var quedaMas = false

    func body(content: Content) -> some View {
        content
            .onScrollGeometryChange(for: Bool.self) { g in
                g.visibleRect.maxX < g.contentSize.width - 2
            } action: { _, nuevo in
                withAnimation(.easeOut(duration: 0.2)) { quedaMas = nuevo }
            }
            .mask {
                HStack(spacing: 0) {
                    Color.black
                    LinearGradient(colors: [.black, .black.opacity(quedaMas ? 0 : 1)],
                                   startPoint: .leading, endPoint: .trailing)
                        .frame(width: 36)
                }
                
                .padding(.vertical, -8)
            }
    }
}
