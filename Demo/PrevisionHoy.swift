import SwiftUI

struct PrevisionHoy: Equatable {
    struct Noche: Equatable {
        let p10, p25, p50, p75, p90: Double
        let probObjetivo: Double?
        let grandeDesde: Double
        let probGrande: Double
        let noches: Int
    }
    struct Plan: Equatable {
        let dias: Int
        let noches: Int?
        let descansos: Int
        let probSiTodo: Double?
        let llega: Bool
        let cubierto: Bool
        let ganado: Double
        let objetivoMes: Double
        let seguridad: Double
    }
    struct Hoy: Equatable {
        let emitiendo: Bool
        let minutos: Int
        let euros: Double
        let personas: Int
        let sala: Int
        let trabajado: Bool
        let posicion: String?
    }
    struct Factor: Identifiable, Equatable {
        let clave: String
        let nombre: String
        let estado: String
        let noches: Int
        let tiene: Int
        let necesita: Int
        let efectoHoy: Double
        
        let unidad: String
        var id: String { clave }
    }
    struct Pasada: Identifiable, Equatable {
        let fecha: String
        let euros: Double
        var id: String { fecha }
    }
    struct DiaSemana: Identifiable, Equatable {
        let fecha: String
        let dia: String
        let p25, p50, p75: Double
        var id: String { fecha }
    }
    
    struct MesRegistro: Identifiable, Equatable {
        let mes: String
        let noches: Int
        let ganado: Double
        let p10, p50, p90: Double
        let dentro: Bool
        
        let despues: Bool
        var id: String { mes }
    }

    let jornada: String
    let dia: String
    let estado: String

    let manana: String?
    let objetivo: Double
    let noche: Noche?
    let plan: Plan?
    let hoy: Hoy
    let factores: [Factor]
    let dentroMitad: Double?
    let nochesAcierto: Int
    let recientes: [Pasada]
    let semana: [DiaSemana]
    let registro: [MesRegistro]
    let calculado: String

    init?(_ j: [String: Any]) {
        guard let jornada = j["jornada"] as? String else { return nil }
        func n(_ v: Any?) -> Double? { (v as? NSNumber)?.doubleValue }
        func e(_ v: Any?) -> Int { (v as? NSNumber)?.intValue ?? 0 }
        self.jornada = jornada
        dia = j["dia"] as? String ?? ""
        estado = j["estado"] as? String ?? ""
        manana = j["manana"] as? String
        objetivo = n(j["objetivo"]) ?? 0
        if let x = j["noche"] as? [String: Any] {
            noche = Noche(p10: n(x["p10"]) ?? 0, p25: n(x["p25"]) ?? 0, p50: n(x["p50"]) ?? 0,
                          p75: n(x["p75"]) ?? 0, p90: n(x["p90"]) ?? 0,
                          probObjetivo: n(x["prob_objetivo"]),
                          grandeDesde: n(x["grande_desde"]) ?? 0,
                          probGrande: n(x["prob_grande"]) ?? 0,
                          noches: e(x["noches"]))
        } else {
            noche = nil
        }
        if let x = j["plan"] as? [String: Any] {
            plan = Plan(dias: e(x["dias"]), noches: (x["noches"] as? NSNumber)?.intValue,
                        descansos: e(x["descansos"]), probSiTodo: n(x["prob_si_todo"]),
                        llega: x["llega"] as? Bool ?? false,
                        cubierto: x["cubierto"] as? Bool ?? false,
                        ganado: n(x["ganado"]) ?? 0, objetivoMes: n(x["objetivo_mes"]) ?? 0,
                        seguridad: n(x["seguridad"]) ?? 0.8)
        } else {
            plan = nil
        }
        let h = j["hoy"] as? [String: Any] ?? [:]
        hoy = Hoy(emitiendo: h["emitiendo"] as? Bool ?? false, minutos: e(h["minutos"]),
                  euros: n(h["euros"]) ?? 0, personas: e(h["personas"]), sala: e(h["sala"]),
                  trabajado: h["trabajado"] as? Bool ?? false,
                  posicion: h["posicion"] as? String)
        factores = ((j["factores"] as? [[String: Any]]) ?? []).map {
            Factor(clave: $0["clave"] as? String ?? "", nombre: $0["nombre"] as? String ?? "",
                   estado: $0["estado"] as? String ?? "", noches: e($0["noches"]),
                   tiene: e($0["tiene"]), necesita: e($0["necesita"]),
                   efectoHoy: n($0["efecto_hoy"]) ?? 0, unidad: $0["unidad"] as? String ?? "")
        }
        let a = j["acierto"] as? [String: Any] ?? [:]
        dentroMitad = n(a["dentro_mitad"])
        nochesAcierto = e(a["noches"])
        recientes = ((j["recientes"] as? [[String: Any]]) ?? []).map {
            Pasada(fecha: $0["fecha"] as? String ?? "", euros: n($0["euros"]) ?? 0)
        }
        semana = ((j["semana"] as? [[String: Any]]) ?? []).map {
            DiaSemana(fecha: $0["fecha"] as? String ?? "", dia: $0["dia"] as? String ?? "",
                      p25: n($0["p25"]) ?? 0, p50: n($0["p50"]) ?? 0, p75: n($0["p75"]) ?? 0)
        }
        registro = ((j["registro"] as? [[String: Any]]) ?? []).map {
            MesRegistro(mes: $0["mes"] as? String ?? "", noches: e($0["noches"]),
                        ganado: n($0["ganado"]) ?? 0, p10: n($0["p10"]) ?? 0,
                        p50: n($0["p50"]) ?? 0, p90: n($0["p90"]) ?? 0,
                        dentro: $0["dentro"] as? Bool ?? false,
                        despues: $0["despues"] as? Bool ?? false)
        }
        calculado = j["calculado"] as? String ?? ""
    }

    var nocheEnMarcha: Bool { hoy.emitiendo || hoy.trabajado }

    var objetivoCubierto: Bool { nocheEnMarcha && objetivo > 0 && hoy.euros >= objetivo }

    var mananaEnBeta: String? { estado == "hecho" ? manana : nil }
}

extension PrevisionHoy {

    var veredicto: String {
        switch estado {
        case "descansar": return "Puedes descansar"
        case "trabajar": return "Toca emitir"
        case "riesgo": return "El mes va justo"
        case "en_directo": return "En directo"
        case "hecho":
            switch mananaEnBeta {
            case "descansar": return "Mañana puedes descansar"
            case "trabajar": return "Mañana toca emitir"
            case "riesgo": return "El mes va justo"
            default: break
            }
            switch hoy.posicion {
            case "encima": return "Por encima de lo normal"
            case "debajo": return "Por debajo de lo normal"
            default: return "Una noche normal"
            }

        case "sin_objetivo": return "Sin objetivo en la Reserva"
        default: return "Tu noche normal"
        }
    }

    var explicacion: String {
        switch estado {
        case "descansar", "trabajar", "riesgo", "hecho":
            guard let plan else { return "" }
            if plan.cubierto { return "El mes ya está cubierto, emitas o no" }
            
            if plan.descansos >= 1 {
                return plan.descansos == 1 ? "Te queda un descanso, más o menos"
                                           : "Te quedan unos \(plan.descansos) descansos este mes"
            }
            if plan.llega { return "No te quedan descansos este mes" }

            return veredicto == "El mes va justo" ? "Aunque emitas todos los días" : "El mes va justo"
        case "en_directo":
            if objetivo > 0 {
                return objetivoCubierto
                    ? "Objetivo de la Reserva cubierto"
                    : "Faltan \(Formato.eurosJustos(objetivo - hoy.euros)) para el objetivo"
            }
            return ""
        default:
            
            return ""
        }
    }

    var subtituloEsDelMes: Bool {
        plan != nil && ["descansar", "trabajar", "riesgo", "hecho"].contains(estado)
    }

    var simbolo: String {
        switch estado {
        case "descansar": return "moon.zzz.fill"
        case "trabajar": return "video.fill"
        case "riesgo": return "exclamationmark.triangle.fill"
        case "en_directo": return "record.circle"
        case "hecho":
            switch mananaEnBeta {
            case "descansar": return "moon.zzz.fill"
            case "trabajar": return "video.fill"
            case "riesgo": return "exclamationmark.triangle.fill"
            default: break
            }
            switch hoy.posicion {
            case "encima": return "arrow.up.right"
            case "debajo": return "arrow.down.right"
            default: return "checkmark"
            }
        default: return "moon.stars.fill"
        }
    }

    var tinte: Color {
        switch estado {
        case "descansar": return Diseno.azul
        case "trabajar": return Diseno.naranja
        case "riesgo", "en_directo": return Diseno.rojo
        case "hecho":
            switch mananaEnBeta {
            case "descansar": return Diseno.azul
            case "trabajar": return Diseno.naranja
            case "riesgo": return Diseno.rojo
            default: return hoy.posicion == "debajo" ? .secondary : Diseno.verde
            }
        default: return .secondary
        }
    }

    var resumenAccesible: String {
        var partes = [veredicto]
        switch estado {
        case "en_directo":
            partes.append("Llevas \(Formato.eurosRedondos(hoy.euros))"
                          + (hoy.minutos > 0 ? " en \(Formato.duracion(Double(hoy.minutos) / 60))" : ""))
        case "hecho":
            partes.append("\(Formato.eurosRedondos(hoy.euros)) esta noche")
        default:
            break
        }
        if !explicacion.isEmpty { partes.append(explicacion) }
        if let n = noche, ["descansar", "trabajar", "riesgo"].contains(estado) {
            partes.append("Si emites, lo normal son \(Formato.eurosRedondos(n.p50))")
        }
        return partes.joined(separator: ". ")
    }
}

private func deDiez(_ p: Double) -> String {
    if p >= 0.95 { return ">9 de 10" }
    let n = Int((p * 10).rounded())
    return n <= 0 ? "<1 de 10" : "\(n) de 10"
}

struct CapsulaPrevision: View {
    let p: PrevisionHoy
    
    var anchoMaximo: CGFloat? = nil
    let abrir: () -> Void

    static func anchoCentrado(en pantalla: CGFloat) -> CGFloat? {
        pantalla > 0 ? max(pantalla - 2 * 72, 120) : nil
    }

    @Environment(\.accessibilityReduceMotion) private var menosMovimiento

    private static let altoMinimo: CGFloat = 30

    var body: some View {

        AnchoMaximo(maximo: anchoMaximo ?? .infinity) { boton }
    }

    private var boton: some View {
        Button(action: abrir) {
            HStack(spacing: 6) {
                if p.estado == "en_directo" {
                    enDirecto
                } else {
                    Image(systemName: p.simbolo)
                        .foregroundStyle(p.tinte)
                        .symbolRenderingMode(.hierarchical)
                        .contentTransition(.symbolEffect(.replace))
                    if p.mananaEnBeta != nil {

                        ViewThatFits(in: .horizontal) {
                            HStack(spacing: 6) {
                                Text(texto).fontWeight(.semibold)
                                Text("· \(Formato.eurosRedondos(p.hoy.euros))")
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(Diseno.apoyoEnCristal)
                            }
                            Text(texto).fontWeight(.semibold)
                        }
                    } else {
                        Text(texto)
                            .fontWeight(.semibold)
                            .contentTransition(.numericText())
                    }
                }
            }
            
            .font(.body)
            .monospacedDigit()
            .foregroundStyle(.primary)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .frame(minHeight: Self.altoMinimo)
            .animation(.snappy(duration: 0.3), value: p.hoy.euros)
            
            .animation(menosMovimiento ? .easeInOut(duration: 0.2)
                                       : .spring(duration: 0.4, bounce: 0.4),
                       value: p.objetivoCubierto)
        }
        .buttonStyle(.glass)
        .chocable(.capsula, reacciona: true)

        .dynamicTypeSize(...DynamicTypeSize.xxLarge)
        
        .sensoryFeedback(.success, trigger: p.objetivoCubierto) { antes, ahora in ahora && !antes }
        .accessibilityLabel(p.resumenAccesible)
        .accessibilityHint("Abre el detalle")
        .accessibilityShowsLargeContentViewer {
            Label(p.estado == "en_directo" ? "\(Formato.eurosRedondos(p.hoy.euros)) · \(rato)" : texto,
                  systemImage: p.simbolo)
        }
    }

    private var texto: String {
        switch p.estado {
        case "descansar", "trabajar", "riesgo": return p.veredicto
        case "hecho":
            return p.mananaEnBeta != nil ? p.veredicto : "\(Formato.eurosRedondos(p.hoy.euros)) esta noche"
        default:
            guard let n = p.noche else { return p.veredicto }
            return "Unos \(Formato.eurosRedondos(n.p50)) si emites"
        }
    }

    @ViewBuilder
    private var enDirecto: some View {
        PilotoRadar(color: Diseno.rojoRelleno, activo: true, lado: 8)
        Text(Formato.eurosRedondos(p.hoy.euros))
            .fontWeight(.semibold)
            .contentTransition(.numericText(value: p.hoy.euros))
        if p.objetivoCubierto {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Diseno.azul)
                .transition(menosMovimiento ? .opacity : .scale(scale: 0.2).combined(with: .opacity))
        }
        if p.hoy.minutos > 0 {
            Text("· \(rato)")
                .foregroundStyle(Diseno.apoyoEnCristal)
                .contentTransition(.numericText())
        }
    }

    private var rato: String { Formato.duracion(Double(p.hoy.minutos) / 60) }
}

struct EscalaNoche {
    let tope: Double

    init(noche: PrevisionHoy.Noche, objetivo: Double, actual: Double?,
         maximo: Double = 0) {
        tope = max(noche.p90, objetivo * 1.25, actual ?? 0, maximo, 1) * 1.06
    }

    func t(_ euros: Double) -> CGFloat {
        CGFloat(min(1, max(0, (max(euros, 0) / tope).squareRoot())))
    }
}

struct BandaNoche: View {
    let noche: PrevisionHoy.Noche
    let objetivo: Double
    
    var actual: Double?
    
    var escala: EscalaNoche?
    var alto: CGFloat = 10

    @Environment(\.accessibilityReduceMotion) private var menosMovimiento
    @ScaledMetric(relativeTo: .caption2) private var altoCifras: CGFloat = 15

    @ScaledMetric(relativeTo: .caption2) private var anchoCifra: CGFloat = 46
    @State private var abierta = false

    private var esc: EscalaNoche {
        escala ?? EscalaNoche(noche: noche, objetivo: objetivo, actual: actual)
    }

    var body: some View {
        VStack(spacing: 4) {
            
            GeometryReader { g in
                if objetivo > 0 {
                    marcaObjetivo
                        .position(x: limitar(esc.t(objetivo) * g.size.width, g.size.width,
                                             anchoCifra * 0.57),
                                  y: g.size.height / 2)
                }
            }
            .frame(height: altoCifras)

            GeometryReader { g in
                let w = g.size.width
                let mediana = esc.t(noche.p50) * w
                ZStack(alignment: .leading) {
                    Capsule().fill(.fill.tertiary)
                    tramo(desde: esc.t(noche.p10) * w, hasta: esc.t(noche.p90) * w,
                          mediana: mediana, estilo: AnyShapeStyle(Diseno.verdeRelleno.opacity(0.22)))
                    tramo(desde: esc.t(noche.p25) * w, hasta: esc.t(noche.p75) * w,
                          mediana: mediana,
                          estilo: AnyShapeStyle(LinearGradient(
                            colors: [Diseno.verdeRelleno.opacity(0.75), Diseno.verdeRelleno],
                            startPoint: .leading, endPoint: .trailing)))
                    
                    Capsule()
                        .fill(.white)
                        .frame(width: 3, height: alto + 4)
                        .shadow(color: .black.opacity(0.25), radius: 1.5, x: 0, y: 1)
                        .position(x: mediana, y: alto / 2)
                        .opacity(abierta ? 1 : 0)
                    if objetivo > 0 {

                        RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                            .fill(Diseno.azulRelleno)
                            .frame(width: cubierto ? 3.5 : 2, height: alto + (cubierto ? 12 : 8))
                            .position(x: esc.t(objetivo) * w, y: alto / 2)
                            .animation(menosMovimiento ? nil : .spring(duration: 0.45, bounce: 0.5),
                                       value: cubierto)
                    }
                    if let actual {
                        Circle()
                            .fill(Diseno.verdeRelleno)
                            .overlay(Circle().strokeBorder(.white, lineWidth: 2.5))
                            .frame(width: alto + 6, height: alto + 6)
                            .shadow(color: Diseno.verdeRelleno.opacity(0.5), radius: 4, x: 0, y: 2)
                            .position(x: esc.t(actual) * w, y: alto / 2)
                            .animation(menosMovimiento ? nil : .spring(duration: 0.6, bounce: 0.25),
                                       value: actual)
                    }
                }
            }
            .frame(height: alto)

            GeometryReader { g in
                let w = g.size.width
                let (a, b) = (esc.t(noche.p25) * w, esc.t(noche.p75) * w)
                let aparta = max(0, anchoCifra - (b - a)) / 2
                Text(Formato.eurosRedondos(noche.p25))
                    .fixedSize()
                    .position(x: limitar(a - aparta, w, anchoCifra * 0.45), y: g.size.height / 2)
                Text(Formato.eurosRedondos(noche.p75))
                    .fixedSize()
                    .position(x: limitar(b + aparta, w, anchoCifra * 0.52), y: g.size.height / 2)
            }
            .font(.caption2.weight(.medium))
            .monospacedDigit()
            .foregroundStyle(Diseno.apoyoEnCristal)
            .frame(height: altoCifras)
        }

        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
        .accessibilityHidden(true)
        .onAppear {
            if menosMovimiento { abierta = true; return }
            withAnimation(.spring(duration: 0.75, bounce: 0.22).delay(0.12)) { abierta = true }
        }
    }

    private func tramo(desde: CGFloat, hasta: CGFloat, mediana: CGFloat,
                       estilo: AnyShapeStyle) -> some View {
        let ancho = max(hasta - desde, alto)
        let ancla = ancho > 0 ? min(1, max(0, (mediana - desde) / ancho)) : 0.5
        return Capsule()
            .fill(estilo)
            .frame(width: ancho, height: alto)
            .scaleEffect(x: abierta ? 1 : 0.02, y: 1, anchor: UnitPoint(x: ancla, y: 0.5))
            .position(x: desde + ancho / 2, y: alto / 2)
    }

    private var cubierto: Bool { actual != nil && (actual ?? 0) >= objetivo && objetivo > 0 }

    @ViewBuilder
    private var marcaObjetivo: some View {
        HStack(spacing: 3) {
            if cubierto {
                Image(systemName: "checkmark.circle.fill")
                    .transition(menosMovimiento ? .opacity
                                                : .scale(scale: 0.2).combined(with: .opacity))
            }
            Text(Formato.eurosJustos(objetivo))
        }
        .font(.caption2.weight(.semibold))
        .monospacedDigit()
        .foregroundStyle(Diseno.azul)
        .fixedSize()
        .animation(menosMovimiento ? .easeInOut(duration: 0.2) : .spring(duration: 0.4, bounce: 0.4),
                   value: cubierto)
    }

    private func limitar(_ x: CGFloat, _ ancho: CGFloat, _ margen: CGFloat) -> CGFloat {
        min(max(x, margen), max(margen, ancho - margen))
    }
}

struct HojaPrevision: View {
    let p: PrevisionHoy
    @Environment(\.dismiss) private var cerrar
    @Environment(\.accessibilityReduceTransparency) private var menosTransparencia
    @ScaledMetric(relativeTo: .body) private var anchoIcono: CGFloat = 22
    
    @State private var altura: PresentationDetent = .medium

    private var opaca: Bool { altura == .large || menosTransparencia }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Diseno.hueco4) {
                    if let n = p.noche { seccionNoche(n) }
                    if p.nocheEnMarcha { seccionEstaNoche }
                    if let plan = p.plan { seccionMes(plan) }
                    if !p.registro.isEmpty { seccionRegistro }
                    if !p.semana.isEmpty { seccionSemana }
                    seccionComprobado
                }
                .padding(.horizontal, Diseno.margen)
                .padding(.vertical, Diseno.hueco2)
            }

            .background {
                if opaca { FondoDelTema().ignoresSafeArea().transition(.opacity) }
            }
            .tarjetasEnCristal(!opaca)
            .animation(Diseno.suave, value: opaca)
            .containerBackground(.clear, for: .navigation)

            .navigationTitle(p.veredicto)
            .modifier(Subtitulo(texto: p.explicacion))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button(role: .close) { cerrar() }
                }
            }
        }
        .presentationDetents([.medium, .large], selection: $altura)
        #if MAQUETA
        
        .task {
            guard Maqueta.hojaEntera else { return }
            try? await Task.sleep(for: .seconds(1))
            altura = .large
        }
        #endif

        .presentationContentInteraction(.scrolls)
    }

    private func seccionNoche(_ n: PrevisionHoy.Noche) -> some View {
        let esc = EscalaNoche(noche: n, objetivo: p.objetivo,
                              actual: p.nocheEnMarcha ? p.hoy.euros : nil,
                              maximo: p.recientes.map(\.euros).max() ?? 0)
        return VStack(alignment: .leading, spacing: Diseno.hueco2) {
            Text("Tu noche normal").font(.headline).padding(.leading, 4)
            Tarjeta {
                VStack(alignment: .leading, spacing: Diseno.hueco3) {
                    PuntosDeNoches(noches: p.recientes, noche: n, objetivo: p.objetivo,
                                   escala: esc)
                    BandaNoche(noche: n, objetivo: p.objetivo,
                               actual: p.nocheEnMarcha ? p.hoy.euros : nil,
                               escala: esc, alto: 12)
                    HStack(spacing: 0) {
                        Cifra(valor: Formato.eurosRedondos(n.p50), pie: "lo normal")
                        if let prob = n.probObjetivo, p.objetivo > 0 {
                            Cifra(valor: deDiez(prob),
                                  pie: "noches pasan de \(Formato.eurosJustos(p.objetivo))")
                        }
                        Cifra(valor: deDiez(n.probGrande),
                              pie: "noches pasan de \(Formato.eurosRedondos(n.grandeDesde))",
                              conBarra: false)
                    }
                }
            }

            if let dentro = p.dentroMitad, p.nochesAcierto > 0 {
                Text("La banda verde es la mitad de tus noches. Probada en \(p.nochesAcierto): "
                     + "acertó \(Int((dentro * 100).rounded())) de cada 100.")
                    .font(.caption).foregroundStyle(Diseno.apoyoEnCristal).padding(.horizontal, 4)
            }
        }
    }

    private var seccionEstaNoche: some View {
        VStack(alignment: .leading, spacing: Diseno.hueco2) {
            Text("Esta noche").font(.headline).padding(.leading, 4)
            Tira {
                Cifra(valor: Formato.eurosRedondos(p.hoy.euros), pie: "llevas",
                      tinte: Diseno.verde)
                if p.hoy.emitiendo {
                    Cifra(valor: Formato.duracion(Double(p.hoy.minutos) / 60), pie: "emitiendo")
                    Cifra(valor: "\(p.hoy.sala)", pie: "en la sala", piloto: Diseno.rojoRelleno,
                          latiendo: true)
                }
                Cifra(valor: "\(p.hoy.personas)",
                      pie: p.hoy.personas == 1 ? "te ha dado propina" : "te han dado propina",
                      conBarra: false)
            }
        }
    }

    private func seccionMes(_ plan: PrevisionHoy.Plan) -> some View {
        VStack(alignment: .leading, spacing: Diseno.hueco2) {
            Text("Este mes").font(.headline).padding(.leading, 4)
            Tarjeta {
                VStack(alignment: .leading, spacing: Diseno.hueco2) {

                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        if p.subtituloEsDelMes {
                            Text(plan.dias == 1 ? "1 día" : "\(plan.dias) días")
                                .font(.system(.title2, design: .rounded).weight(.semibold))
                                .contentTransition(.numericText(value: Double(plan.dias)))
                            Text(plan.dias == 1 ? "queda este mes" : "quedan este mes")
                                .font(.subheadline).foregroundStyle(Diseno.apoyoEnCristal)
                        } else {
                            Text(plan.descansos == 0 ? "Ningún descanso"
                                 : plan.descansos == 1 ? "1 descanso" : "unos \(plan.descansos) descansos")
                                .font(.system(.title2, design: .rounded).weight(.semibold))
                                .foregroundStyle(!plan.llega && !plan.cubierto ? Diseno.rojo
                                                 : (plan.descansos > 0 ? Diseno.azul : Diseno.naranja))
                                .contentTransition(.numericText(value: Double(plan.descansos)))
                            Text(plan.dias == 1 ? "en el día que queda" : "en los \(plan.dias) días que quedan")
                                .font(.subheadline).foregroundStyle(Diseno.apoyoEnCristal)
                        }
                    }
                    RepartoDelMes(plan: plan)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Llevas \(Formato.eurosRedondos(plan.ganado)) de "
                             + "\(Formato.eurosRedondos(plan.objetivoMes))")

                        if plan.cubierto {
                            if !p.subtituloEsDelMes { Text("El mes ya está cubierto, emitas o no") }
                        } else if let noches = plan.noches {
                            Text(noches == 1 ? "Haría falta más o menos 1 noche más"
                                             : "Harían falta unas \(noches) noches más")
                        } else if !p.subtituloEsDelMes {
                            Text("Ni emitiendo todos los días es seguro llegar")
                                .foregroundStyle(Diseno.rojo)
                        }
                        if p.objetivo > 0 {
                            
                            Text("Cada día sin emitir cuesta \(Formato.eurosJustos(p.objetivo)) de la Reserva")
                                .foregroundStyle(Diseno.apoyoEnCristal)
                        }
                    }
                    .font(.subheadline)
                }
            }
        }
    }

    private var seccionRegistro: some View {
        let aciertos = p.registro.filter(\.dentro).count
        let tope = max(p.registro.map { max($0.p90, $0.ganado) }.max() ?? 1, 1) * 1.05
        let ultimoDespues = p.registro.filter(\.despues).map(\.mes).max()
        return VStack(alignment: .leading, spacing: Diseno.hueco2) {
            HStack(alignment: .firstTextBaseline) {
                Text("Cómo ha acertado el mes").font(.headline)
                Spacer()
                Text("\(aciertos) de \(p.registro.count)")
                    .font(.subheadline.weight(.semibold)).monospacedDigit()
                    .foregroundStyle(Diseno.apoyoEnCristal)
            }
            .padding(.horizontal, 4)
            Tarjeta(relleno: 0) {
                VStack(spacing: 0) {
                    ForEach(Array(p.registro.enumerated()), id: \.element.id) { i, m in
                        if i > 0 { Divider().padding(.leading, Diseno.hueco3) }
                        FilaMesRegistro(m: m, tope: tope)
                    }
                }
            }
            
            if let mes = ultimoDespues {
                Text("Hasta \(nombreDeMes(mes)), calculado después con lo que había al empezar cada mes. "
                     + "La banda es lo que decía para esas noches; el punto, lo que sumaron.")
                    .font(.caption).foregroundStyle(Diseno.apoyoEnCristal).padding(.horizontal, 4)
            }
        }
    }

    private var seccionSemana: some View {
        VStack(alignment: .leading, spacing: Diseno.hueco2) {
            Text("Próximos días").font(.headline).padding(.leading, 4)
            Tarjeta {
                let tope = max(p.semana.map(\.p75).max() ?? 1, 1)
                HStack(alignment: .bottom, spacing: 0) {
                    ForEach(p.semana) { d in
                        VStack(spacing: 6) {
                            Text(Formato.eurosRedondos(d.p50))
                                .font(.caption2.weight(.semibold)).monospacedDigit()
                            ZStack(alignment: .bottom) {
                                Capsule().fill(.fill.tertiary)
                                Capsule()
                                    .fill(Diseno.verdeRelleno.gradient)
                                    .frame(height: max(8, 70 * (d.p75 - d.p25) / tope))
                                    .offset(y: -70 * d.p25 / tope)
                            }
                            .frame(width: 10, height: 70)
                            Text(d.dia).font(.caption2).foregroundStyle(Diseno.apoyoEnCristal)
                        }
                        .frame(maxWidth: .infinity)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("\(d.dia), lo normal \(Formato.eurosRedondos(d.p50))")
                    }
                }
            }
        }
    }

    private var seccionComprobado: some View {
        VStack(alignment: .leading, spacing: Diseno.hueco2) {
            Text("Lo que se ha comprobado").font(.headline).padding(.leading, 4)
            Tarjeta(relleno: 0) {
                VStack(spacing: 0) {
                    ForEach(Array(p.factores.enumerated()), id: \.element.id) { i, f in
                        if i > 0 { Divider().padding(.leading, Diseno.hueco3 + anchoIcono + Diseno.hueco2) }
                        FilaFactor(f: f, anchoIcono: anchoIcono)
                    }
                }
            }
            if let cuando = horaDeCalculo {
                Text("Recalculado \(cuando)")
                    .font(.caption).foregroundStyle(Diseno.apoyoEnCristal).padding(.horizontal, 4)
            }
        }
    }

    private var horaDeCalculo: String? {
        guard p.calculado.count >= 16 else { return nil }
        let fecha = String(p.calculado.prefix(10))
        let hora = String(p.calculado.dropFirst(11).prefix(5))

        let c = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        let hoy = String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
        return fecha == hoy ? "hoy a las \(hora)" : "el \(Formato.diaCorto(fecha)) a las \(hora)"
    }
}

struct Subtitulo: ViewModifier {
    let texto: String

    @ViewBuilder
    func body(content: Content) -> some View {
        if texto.isEmpty {
            content
        } else {
            content.navigationSubtitle(texto)
        }
    }
}

private struct FilaFactor: View {
    let f: PrevisionHoy.Factor
    let anchoIcono: CGFloat

    var body: some View {
        HStack(spacing: Diseno.hueco2) {
            Image(systemName: icono)
                .font(.body.weight(.semibold))
                .foregroundStyle(color)
                .frame(width: anchoIcono)
            VStack(alignment: .leading, spacing: 2) {
                Text(f.nombre).font(.subheadline.weight(.medium))
                Text(detalle).font(.footnote).foregroundStyle(Diseno.apoyoEnCristal)
            }
            Spacer(minLength: 4)
            if f.estado == "midiendo", f.necesita > 0 {
                ProgressView(value: Double(min(f.tiene, f.necesita)), total: Double(f.necesita))
                    .frame(width: 52)
                    .tint(Color.secondary)
            }
        }
        .padding(.horizontal, Diseno.hueco3)
        .padding(.vertical, 12)
        .accessibilityElement(children: .combine)
    }

    private var icono: String {
        switch f.estado {
        case "confirmado": return "checkmark.seal.fill"
        case "midiendo": return "hourglass"
        default: return "equal.circle"
        }
    }

    private var color: Color {
        switch f.estado {
        case "confirmado": return Diseno.verde
        default: return .secondary
        }
    }

    private var detalle: String {
        switch f.estado {
        case "confirmado":
            let pct = Int(((exp(f.efectoHoy) - 1) * 100).rounded())
            return pct == 0 ? "Cambia lo que ganas; hoy no" : "Hoy cuenta: \(pct > 0 ? "+" : "")\(pct) %"
        case "midiendo":
            let unidad = !f.unidad.isEmpty ? f.unidad
                : (f.clave == "sala" || f.clave == "personas" ? "directos" : "noches")
            return "Midiendo · \(min(f.tiene, f.necesita)) de \(f.necesita) \(unidad)"
        default:
            return "No cambia lo que ganas · \(f.noches) noches"
        }
    }
}

private func nombreDeMes(_ mes: String) -> String {
    let nombres = ["enero", "febrero", "marzo", "abril", "mayo", "junio", "julio", "agosto",
                   "septiembre", "octubre", "noviembre", "diciembre"]
    guard let m = Int(mes.suffix(2)), (1...12).contains(m) else { return mes }
    return nombres[m - 1]
}

private struct FilaMesRegistro: View {
    let m: PrevisionHoy.MesRegistro
    let tope: Double

    @ScaledMetric(relativeTo: .subheadline) private var anchoMes: CGFloat = 40

    var body: some View {
        HStack(spacing: Diseno.hueco2) {
            VStack(alignment: .leading, spacing: 1) {
                Text(nombreDeMes(m.mes).prefix(3).capitalized)
                    .font(.subheadline.weight(.semibold))
                Text(m.noches == 1 ? "1 noche" : "\(m.noches) noches")
                    .font(.caption2).foregroundStyle(Diseno.apoyoEnCristal).fixedSize()
            }
            .frame(minWidth: anchoMes, alignment: .leading)
            GeometryReader { g in
                let w = g.size.width
                let x = { (v: Double) in CGFloat(min(max(v / tope, 0), 1)) * w }
                ZStack(alignment: .leading) {
                    Capsule().fill(.fill.tertiary).frame(height: 6)
                    Capsule()
                        .fill(Diseno.verdeRelleno.opacity(0.3))
                        .frame(width: max(x(m.p90) - x(m.p10), 6), height: 10)
                        .offset(x: x(m.p10))
                    Capsule().fill(.white)
                        .frame(width: 2, height: 12)
                        .shadow(color: .black.opacity(0.2), radius: 1, x: 0, y: 0.5)
                        .offset(x: x(m.p50) - 1)
                    Circle()
                        .fill(Diseno.verdeRelleno)
                        .overlay(Circle().strokeBorder(.white, lineWidth: 2))
                        .frame(width: 12, height: 12)
                        .offset(x: x(m.ganado) - 6)
                }
                .frame(height: g.size.height)
            }
            .frame(height: 16)
            Text(Formato.eurosRedondos(m.ganado))
                .font(.caption.weight(.medium)).monospacedDigit()
                .frame(minWidth: 52, alignment: .trailing)
            Image(systemName: m.dentro ? "checkmark" : "xmark")
                .font(.footnote.weight(.bold))
                .foregroundStyle(m.dentro ? Diseno.verde : .secondary)
                .frame(width: 16)
        }
        .padding(.horizontal, Diseno.hueco3)
        .padding(.vertical, 11)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(nombreDeMes(m.mes).capitalized): \(m.noches) noches, "
                            + "\(Formato.eurosRedondos(m.ganado)). Decía entre "
                            + "\(Formato.eurosRedondos(m.p10)) y \(Formato.eurosRedondos(m.p90)). "
                            + (m.dentro ? "Acertó" : "Falló"))
    }
}

private struct PuntosDeNoches: View {
    let noches: [PrevisionHoy.Pasada]
    let noche: PrevisionHoy.Noche
    let objetivo: Double
    let escala: EscalaNoche

    @Environment(\.accessibilityReduceMotion) private var menosMovimiento
    @Environment(\.accessibilityReduceTransparency) private var menosTransparencia
    @State private var elegida: Int?
    @State private var caidos = false

    private static let lado: CGFloat = 9
    private static let alto: CGFloat = 104

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(rotulo)
                .font(.footnote.weight(elegida == nil ? .regular : .semibold))
                .foregroundStyle(elegida == nil ? AnyShapeStyle(.secondary) : AnyShapeStyle(.primary))
                .monospacedDigit()
                .contentTransition(.numericText())
                .animation(Diseno.cifra, value: rotulo)

            GeometryReader { g in
                let pos = posiciones(ancho: g.size.width, alto: g.size.height)
                ZStack(alignment: .topLeading) {
                    
                    Rectangle()
                        .fill(Diseno.verdeRelleno.opacity(0.08))
                        .frame(width: max(0, (escala.t(noche.p75) - escala.t(noche.p25)) * g.size.width),
                               height: g.size.height)
                        .offset(x: escala.t(noche.p25) * g.size.width)
                    if objetivo > 0 {
                        Path { c in
                            let x = escala.t(objetivo) * g.size.width
                            c.move(to: CGPoint(x: x, y: 0))
                            c.addLine(to: CGPoint(x: x, y: g.size.height))
                        }
                        .stroke(Diseno.azulRelleno.opacity(0.7),
                                style: StrokeStyle(lineWidth: 1.2, dash: [3, 3]))
                    }
                    ForEach(Array(noches.enumerated()), id: \.element.id) { i, n in
                        let reciente = noches.count > 1 ? Double(i) / Double(noches.count - 1) : 1
                        Circle()
                            .fill(Diseno.verdeRelleno.opacity(elegida == nil || elegida == i
                                                               ? 0.5 + 0.5 * reciente : 0.3))
                            .frame(width: Self.lado, height: Self.lado)
                            .position(x: pos[i].x, y: caidos ? pos[i].y : -Self.lado)
                            .animation(menosMovimiento ? nil
                                       : .spring(duration: 0.55, bounce: 0.3)
                                           .delay(Double(i) * 0.012), value: caidos)
                    }
                }
                
                .clipped()
                
                .overlay(alignment: .topLeading) {
                    if let i = elegida, pos.indices.contains(i) {
                        lente.position(pos[i])
                    }
                }
                .contentShape(.rect)
                .gesture(MantenerYDeslizar(
                    alEmpezar: { q in elegir(q.x, pos) },
                    alMover: { q in elegir(q.x, pos) },
                    alAcabar: { withAnimation(.snappy(duration: 0.25)) { elegida = nil } }))
            }
            .frame(height: Self.alto)
        }
        
        .sensoryFeedback(.selection, trigger: elegida) { _, nueva in nueva != nil }
        .onAppear { caidos = true }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Tus últimas \(noches.count) noches")
        .accessibilityValue(valorAccesible)
        .accessibilityAdjustableAction { d in
            guard !noches.isEmpty else { return }
            let actual = elegida ?? (noches.count - 1)
            switch d {
            case .increment: elegida = min(noches.count - 1, actual + 1)
            case .decrement: elegida = max(0, actual - 1)
            @unknown default: break
            }
        }
    }

    private var rotulo: String {
        guard let i = elegida, noches.indices.contains(i) else {
            return "Tus últimas \(noches.count) noches"
        }
        return "\(Formato.diaSemana(noches[i].fecha).capitalized) · \(Formato.euros(noches[i].euros))"
    }

    private var valorAccesible: String {
        let i = elegida ?? (noches.count - 1)
        guard noches.indices.contains(i) else { return "" }
        return "\(Formato.diaCorto(noches[i].fecha)), \(Formato.euros(noches[i].euros))"
    }

    @ViewBuilder
    private var lente: some View {
        if menosTransparencia {
            Circle().fill(Diseno.verdeRelleno)
                .overlay(Circle().strokeBorder(.white, lineWidth: 2))
                .frame(width: 18, height: 18)
                .allowsHitTesting(false)
        } else {
            Circle()
                .fill(.white)
                .frame(width: 6, height: 6)
                .shadow(color: Diseno.verdeRelleno, radius: 3)
                .frame(width: 26, height: 26)
                .glassEffect(.regular.tint(Diseno.verdeRelleno.opacity(0.35)), in: .circle)
                .allowsHitTesting(false)
        }
    }

    private func posiciones(ancho: CGFloat, alto: CGFloat) -> [CGPoint] {
        let lado = Self.lado
        let paso = lado + 1
        let medio = alto / 2
        var puestas: [CGPoint] = []
        var salida = Array(repeating: CGPoint.zero, count: noches.count)
        
        let orden = noches.indices.sorted { noches[$0].euros < noches[$1].euros }
        for i in orden {
            let x = min(max(escala.t(noches[i].euros) * ancho, lado / 2), ancho - lado / 2)
            var y = medio
            
            for k in 0..<40 {
                let salto = CGFloat((k + 1) / 2) * paso * (k % 2 == 0 ? 1 : -1)
                let prueba = medio + salto
                let choca = puestas.contains { hypot($0.x - x, $0.y - prueba) < paso }
                if !choca || prueba < lado / 2 || prueba > alto - lado / 2 {
                    y = min(max(prueba, lado / 2), alto - lado / 2)
                    break
                }
            }
            let punto = CGPoint(x: x, y: y)
            puestas.append(punto)
            salida[i] = punto
        }
        return salida
    }

    private func elegir(_ x: CGFloat, _ pos: [CGPoint]) {
        guard !pos.isEmpty else { return }
        let cerca = pos.indices.min { abs(pos[$0].x - x) < abs(pos[$1].x - x) } ?? 0
        if cerca != elegida { elegida = cerca }
    }
}

private struct RepartoDelMes: View {
    let plan: PrevisionHoy.Plan

    @Environment(\.accessibilityReduceMotion) private var menosMovimiento
    @State private var lleno = false

    private var noBasta: Bool { !plan.llega && !plan.cubierto }
    private var trabajo: Int { plan.cubierto ? 0 : min(plan.noches ?? plan.dias, plan.dias) }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if plan.dias > 0 {
                HStack(spacing: plan.dias > 20 ? 2 : 3) {
                    ForEach(0..<plan.dias, id: \.self) { i in
                        Capsule()
                            .fill(i < trabajo
                                  ? (noBasta ? Diseno.rojoRelleno : Diseno.verdeRelleno).gradient
                                  : Diseno.azulRelleno.gradient)
                            .scaleEffect(x: 1, y: lleno ? 1 : 0.05, anchor: .bottom)
                            .animation(menosMovimiento ? nil
                                       : .spring(duration: 0.5, bounce: 0.3).delay(Double(i) * 0.015),
                                       value: lleno)
                    }
                }
                .frame(height: 18)
            }

            HStack {
                if trabajo > 0 {
                    Label((trabajo == 1 ? "1 noche" : "\(trabajo) noches") + (noBasta ? ", no basta" : ""),
                          systemImage: "video.fill")
                        .foregroundStyle(noBasta ? Diseno.rojo : Diseno.verde)
                }
                Spacer()
                if plan.descansos > 0 {
                    Label(plan.descansos == 1 ? "1 libre" : "\(plan.descansos) libres",
                          systemImage: "moon.zzz.fill")
                        .foregroundStyle(Diseno.azul)
                }
            }
            .font(.caption.weight(.semibold))
            .monospacedDigit()
        }
        .onAppear { lleno = true }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(noBasta
            ? "Ni emitiendo los \(plan.dias) días que quedan se llega al objetivo"
            : "De los \(plan.dias) días que quedan, \(trabajo) noches para llegar "
              + "y \(plan.descansos) libres")
    }
}

struct AnchoMaximo: Layout {
    let maximo: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard let hijo = subviews.first else { return .zero }
        let ancho = proposal.width.map { min($0, maximo) } ?? (maximo.isFinite ? maximo : nil)
        return hijo.sizeThatFits(ProposedViewSize(width: ancho, height: proposal.height))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        subviews.first?.place(at: CGPoint(x: bounds.midX, y: bounds.midY), anchor: .center,
                              proposal: ProposedViewSize(width: min(bounds.width, maximo), height: bounds.height))
    }
}
