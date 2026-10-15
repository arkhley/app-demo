import SwiftUI

enum Sala {
    static let color = Diseno.colorDePlataforma("plataforma1")
}

struct Inicial: View {
    let nombre: String
    var lado: CGFloat = 34
    
    var tuyo = true
    
    var vuelve = false

    var body: some View {

        let color: Color = tuyo ? Color(red: 0.69, green: 0.30, blue: 0.0) : Color(white: 0.40)
        Circle()
            .fill(color)
            .overlay {
                if vuelve {
                    Circle().strokeBorder(.white.opacity(0.95), lineWidth: 1.5).padding(-3)
                }
            }
            .overlay {
                Text(String(nombre.prefix(1)).uppercased())
                    .font(.system(size: lado * 0.46, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }
            .frame(width: lado, height: lado)
            .accessibilityHidden(true)
    }
}

struct FilaDePersona: View {
    let p: InformeSala.Persona
    var puesto: Int?
    
    var detalle: String
    var enSala = false

    var deUnaNoche = false

    var body: some View {
        HStack(spacing: Diseno.hueco2) {
            if let puesto {
                Text("\(puesto)")
                    .font(.system(.headline, design: .rounded)).monospacedDigit()
                    .foregroundStyle(Marcador.apoyo)
                    .frame(minWidth: 22)
            }
            Inicial(nombre: p.quien, vuelve: deUnaNoche ? p.vuelve : p.noches > 1)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(p.quien).font(.headline).lineLimit(1)
                    if p.nuevo {
                        Image(systemName: "sparkle")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.yellow)
                            .accessibilityLabel("primera vez")
                    }
                    if enSala {
                        PilotoRadar(color: Diseno.rojoRelleno, activo: true, lado: 7)
                            .accessibilityLabel("en la sala ahora")
                    }
                }
                Text(detalle).font(.footnote).foregroundStyle(Marcador.apoyo).lineLimit(1)
            }
            Spacer(minLength: Diseno.hueco1)
            Text(Formato.tokens(p.tokens))
                .font(.system(.headline, design: .rounded)).monospacedDigit()
                .contentTransition(.numericText(value: Double(p.tokens)))
        }
        .padding(.vertical, 10)
        .accessibilityElement(children: .combine)
    }
}

struct TiraDeNoches: View {
    let noches: [InformeSala.Noche]
    @Binding var elegida: String
    var alto: CGFloat = 54

    @Environment(\.colorScheme) private var modo

    var body: some View {
        let lista = Array(noches.prefix(40).reversed())
        let maximo = Double(max(lista.map(\.tokens).max() ?? 1, 1))
        ScrollViewReader { lector in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .bottom, spacing: 6) {
                    ForEach(lista) { n in
                        let esta = n.jornada == elegida
                        Button {
                            elegida = n.jornada
                        } label: {
                            VStack(spacing: 5) {
                                ZStack(alignment: .top) {
                                    Capsule()
                                        .fill(esta ? AnyShapeStyle((modo == .dark ? Color.white : Sala.color).gradient)
                                                   : AnyShapeStyle(Color.white.opacity(modo == .dark ? 0.3 : 0.62)))

                                        .overlay {
                                            if modo == .light {
                                                Capsule().strokeBorder(.black.opacity(0.6), lineWidth: 0.75)
                                            }
                                        }
                                        .frame(width: 14, height: max(8, alto * CGFloat((Double(n.tokens) / maximo).squareRoot())))
                                        .shadow(color: esta ? Sala.color.opacity(0.6) : .clear, radius: 6, x: 0, y: 2)
                                    if n.enCurso {
                                        PilotoRadar(color: Diseno.rojoRelleno, activo: true, lado: 7)
                                            .offset(y: -12)
                                    }
                                }
                                .frame(height: alto, alignment: .bottom)
                                Text(NombreDeNoche.numero(n.jornada))
                                    .font(.caption2.weight(esta ? .bold : .medium)).monospacedDigit()
                                    .lineLimit(1)
                                    .fixedSize()
                                    .foregroundStyle(esta ? AnyShapeStyle(.primary) : AnyShapeStyle(Marcador.apoyo))
                            }
                            .frame(width: 26)
                            .contentShape(.rect)
                        }
                        .buttonStyle(Hundirse())
                        .id(n.jornada)
                        .accessibilityLabel("\(NombreDeNoche.titulo(n.jornada, hoy: "")), \(n.tokens) tokens")
                        .accessibilityAddTraits(esta ? .isSelected : [])
                    }
                }
                .padding(.horizontal, Diseno.margen)
                .padding(.top, 14)
            }
            .defaultScrollAnchor(.trailing)
            .scrollClipDisabled()
            .modifier(BordeQueSigue())
            .onChange(of: elegida) { _, nueva in
                withAnimation(Diseno.suave) { lector.scrollTo(nueva, anchor: .center) }
            }
        }

        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        .sensoryFeedback(.selection, trigger: elegida)
    }
}

struct GraficoNoche: View {
    let d: InformeSala.Detalle
    @Binding var minuto: Int?
    @Binding var rastreando: Bool
    var alto: CGFloat = 190

    @Environment(\.colorScheme) private var modo
    @Environment(\.accessibilityReduceMotion) private var menosMovimiento
    @State private var dibujado = false

    private var total: Int { max(d.tramos.last?.upperBound ?? d.noche.minutos, 1) }
    private var maxGente: Int { max(d.gente.map(\.personas).max() ?? 0, 1) }
    private var maxPropina: Int { max(d.propinas.map(\.tokens).max() ?? 1, 1) }

    var body: some View {
        GeometryReader { g in
            let w = g.size.width
            let base = alto - 26
            let tinta: Color = modo == .dark ? .white : Sala.color
            ZStack(alignment: .topLeading) {
                Canvas { ctx, size in
                    func x(_ m: Int) -> CGFloat { CGFloat(m) / CGFloat(total) * (size.width - 16) + 8 }
                    
                    if d.gente.count > 1 {
                        var curva = Path()
                        for (i, p) in d.gente.enumerated() {
                            let pt = CGPoint(x: x(p.minuto), y: base - CGFloat(p.personas) / CGFloat(maxGente) * (base - 18))
                            if i == 0 { curva.move(to: pt) } else { curva.addLine(to: pt) }
                        }
                        var area = curva
                        area.addLine(to: CGPoint(x: x(d.gente.last!.minuto), y: base))
                        area.addLine(to: CGPoint(x: x(d.gente.first!.minuto), y: base))
                        area.closeSubpath()
                        ctx.fill(area, with: .linearGradient(
                            Gradient(colors: [tinta.opacity(0.32), tinta.opacity(0.02)]),
                            startPoint: CGPoint(x: 0, y: 18), endPoint: CGPoint(x: 0, y: base)))
                        ctx.stroke(curva, with: .color(tinta.opacity(0.9)),
                                   style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                    }
                    
                    var anterior: Int?
                    for t in d.tramos {
                        if let a = anterior, t.lowerBound > a {
                            var hueco = Path()
                            hueco.move(to: CGPoint(x: x(a), y: base))
                            hueco.addLine(to: CGPoint(x: x(t.lowerBound), y: base))
                            ctx.stroke(hueco, with: .color(.primary.opacity(0.35)),
                                       style: StrokeStyle(lineWidth: 1.5, dash: [3, 4]))
                        }
                        var linea = Path()
                        linea.move(to: CGPoint(x: x(t.lowerBound), y: base))
                        linea.addLine(to: CGPoint(x: x(t.upperBound), y: base))
                        ctx.stroke(linea, with: .color(.primary.opacity(0.35)), lineWidth: 1.5)
                        anterior = t.upperBound
                    }
                    
                    for s in d.seguidoresMin {
                        let r = CGRect(x: x(s.minuto) - 1, y: base + 5, width: 2, height: 4 + CGFloat(min(s.cuantos, 4)) * 2)
                        ctx.fill(Path(roundedRect: r, cornerRadius: 1), with: .color(Diseno.verdeRelleno))
                    }
                    
                    for p in d.propinas {
                        let h = 8 + CGFloat((Double(p.tokens) / Double(maxPropina)).squareRoot()) * (base - 30)
                        let px = x(max(0, min(p.minuto, total)))
                        var palo = Path()
                        palo.move(to: CGPoint(x: px, y: base))
                        palo.addLine(to: CGPoint(x: px, y: base - h))
                        let elegida = minuto.map { abs($0 - p.minuto) <= 1 } ?? false
                        ctx.stroke(palo, with: .color(Sala.color.opacity(elegida ? 1 : 0.75)), lineWidth: elegida ? 2.5 : 1.5)
                        let lado: CGFloat = elegida ? 9 : 6
                        ctx.fill(Path(ellipseIn: CGRect(x: px - lado / 2, y: base - h - lado / 2, width: lado, height: lado)),
                                 with: .color(Sala.color))
                    }
                }
                .mask(alignment: .leading) {
                    Rectangle().frame(width: dibujado || menosMovimiento ? w : 0)
                }

                ForEach(marcas, id: \.self) { m in
                    Text(NombreDeNoche.hora(d.noche.inicio, minuto: m))
                        .font(.caption2).monospacedDigit()
                        .foregroundStyle(Marcador.apoyo)
                        .fixedSize()
                        
                        .position(x: min(max(CGFloat(m) / CGFloat(total) * (w - 16) + 8, 22), w - 22),
                                  y: alto - 6)
                }

                if let m = minuto {
                    let px = CGFloat(m) / CGFloat(total) * (w - 16) + 8
                    Rectangle()
                        .fill(Color.primary.opacity(0.4))
                        .frame(width: 1, height: base - 8)
                        .position(x: px, y: (base + 8) / 2)
                    Circle()
                        .fill(.clear)
                        .frame(width: 22, height: 22)
                        .cristal(.regular.tint(Sala.color.opacity(0.35)), en: .circle)
                        .overlay(Circle().fill(.white).frame(width: 6, height: 6))
                        .position(x: px, y: base - CGFloat(gente(en: m)) / CGFloat(maxGente) * (base - 18))
                        .allowsHitTesting(false)
                }
            }
            .contentShape(.rect)
            .gesture(MantenerYDeslizar(
                alEmpezar: { p in rastreando = true; leer(p.x, ancho: w) },
                alMover: { p in leer(p.x, ancho: w) },
                alAcabar: {
                    rastreando = false
                    withAnimation(.snappy(duration: 0.25)) { minuto = nil }
                }))
        }
        .frame(height: alto)
        .sensoryFeedback(.selection, trigger: minuto) { _, nuevo in nuevo != nil }
        .onAppear {
            if menosMovimiento { dibujado = true } else {
                withAnimation(.easeOut(duration: 0.9)) { dibujado = true }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("La noche minuto a minuto")
        .accessibilityValue(resumenAccesible)
    }

    private var marcas: [Int] {
        let paso = total > 150 ? 60 : 30
        return Array(stride(from: 0, through: total, by: paso))
    }

    func gente(en m: Int) -> Int {
        d.gente.last { $0.minuto <= m }?.personas ?? d.gente.first?.personas ?? 0
    }

    private func leer(_ x: CGFloat, ancho: CGFloat) {
        let m = Int(((x - 8) / max(ancho - 16, 1) * CGFloat(total)).rounded())
        let nuevo = min(max(m, 0), total)
        if nuevo != minuto { minuto = nuevo }
    }

    private var resumenAccesible: String {
        var partes = ["\(d.propinas.count) propinas"]
        if let pico = d.noche.pico { partes.append("pico de \(pico) personas") }
        if let s = d.noche.seguidores { partes.append("\(s) seguidores nuevos") }
        return partes.joined(separator: ", ")
    }
}

struct SeccionTuGente: View {
    let informe: InformeSala
    
    var enSala: Set<String> = []
    var cuantos = 6

    var body: some View {
        let r = informe.resumenGente
        VStack(alignment: .leading, spacing: 0) {
            NavigationLink {
                PantallaTuGente(informe: informe, enSala: enSala)
            } label: {
                HStack(spacing: 4) {
                    TituloDeSeccion(texto: "Tu gente", dato: "\(r.personas) personas")
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(Marcador.apoyo)
                        .padding(.top, Diseno.hueco3)
                }
            }
            .buttonStyle(.plain)
            if let parte = r.parteTop10 {
                
                Text("Los 10 primeros dan el \(Int((parte * 100).rounded())) % · \(r.vuelven) han vuelto otra noche")
                    .font(.subheadline)
                    .foregroundStyle(Marcador.apoyo)
                    .padding(.top, 4)
            }
            VStack(spacing: 0) {
                ForEach(Array(informe.gente.prefix(cuantos).enumerated()), id: \.element.id) { i, p in
                    FilaDePersona(p: p, puesto: i + 1, detalle: detalleDe(p),
                                  enSala: enSala.contains(p.quien))
                    if i < min(cuantos, informe.gente.count) - 1 { Divider().padding(.leading, 80) }
                }
            }
            .padding(.top, Diseno.hueco1)
            
            Text("Solo propinas desde el \(NombreDeNoche.corta(informe.desdeGente)): los encargos no dicen de quién son.")
                .font(.footnote)
                .foregroundStyle(Marcador.apoyo)
                .padding(.top, Diseno.hueco1)
        }
    }

    func detalleDe(_ p: InformeSala.Persona) -> String {
        p.noches > 1 ? "\(p.noches) noches · la mayor \(Formato.tokens(p.mayor))"
                     : "1 noche · \(NombreDeNoche.corta(p.ultima))"
    }
}

struct PantallaTuGente: View {
    let informe: InformeSala
    var enSala: Set<String> = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(informe.gente.enumerated()), id: \.element.id) { i, p in
                    FilaDePersona(p: p, puesto: i + 1,
                                  detalle: SeccionTuGente(informe: informe).detalleDe(p),
                                  enSala: enSala.contains(p.quien))
                    if i < informe.gente.count - 1 { Divider().padding(.leading, 80) }
                }
            }
            .padding(.horizontal, Diseno.margen)
            .padding(.bottom, Diseno.hueco5)
        }
        .fondoDePantalla()
        .navigationTitle("Tu gente")
        .navigationSubtitle("\(informe.resumenGente.personas) personas · \(informe.resumenGente.vuelven) han vuelto")
    }
}

extension NombreDeNoche {
    
    static func corta(_ jornada: String) -> String {
        let p = jornada.split(separator: "-").compactMap { Int($0) }
        guard p.count == 3, (1...12).contains(p[1]) else { return jornada }
        let meses = ["ene", "feb", "mar", "abr", "may", "jun", "jul", "ago", "sep", "oct", "nov", "dic"]
        return "\(p[2]) \(meses[p[1] - 1])"
    }
}
