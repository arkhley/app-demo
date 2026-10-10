import SwiftUI

struct SalaNueva: View {
    
    let sala: PantallaSala.Sala?
    let chatSala: [PantallaSala.Mensaje]
    let chatEncargos: [PantallaSala.Mensaje]
    let usuario: String

    @Environment(Sesion.self) private var sesion
    @State private var informe: InformeSala?
    @State private var fallo: String?

    @State private var fijada: String?
    @Environment(\.scenePhase) private var fase
    @State private var verChat = false
    @State private var verVideo = false
    
    @State private var rastreando = false

    private var enDirecto: Bool { sala?.enDirecto ?? informe?.enDirecto ?? false }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if let informe, let d = informe.noche {
                    SalaEstadio(informe: informe, d: d, sala: sala, jornada: eleccion,
                                rastreando: $rastreando)
                } else if informe != nil {
                    Vacio(icono: "video.slash", titulo: "Todavía no hay ningún directo",
                          detalle: "Cuando emitas, cada noche sale aquí.")
                        .padding(.top, Diseno.hueco5)
                } else if let fallo {
                    Vacio(icono: "wifi.exclamationmark", titulo: "No se ha podido cargar", detalle: fallo)
                        .padding(.top, Diseno.hueco5)
                } else {
                    Vacio(icono: "person.3", titulo: "Cargando…")
                        .redacted(reason: .placeholder)
                        .padding(.top, Diseno.hueco5)
                }
            }
            .padding(.bottom, Diseno.hueco5)
        }
        .scrollDisabled(rastreando)
        .scrollEdgeEffectStyle(.soft, for: .top)
        #if MAQUETA
        .defaultScrollAnchor(Maqueta.anclaSala)
        .onAppear { if Maqueta.abrirChat { verChat = true } }
        #endif
        .background {

            CampoJoya(joya: .sala, luz: enDirecto ? Joya.luzDirecto : nil, late: enDirecto)
        }
        .navigationTitle(titulo)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                
                if !chatSala.isEmpty || !chatEncargos.isEmpty {
                    Button { verChat = true } label: {
                        Label("Chat y encargos", systemImage: "bubble.left.and.bubble.right.fill")
                    }
                }
                if enDirecto && !usuario.isEmpty {
                    Button { verVideo = true } label: {
                        
                        Label("Ver tu directo", systemImage: "video.fill")
                    }
                }
                if !usuario.isEmpty, let url = URL(string: "https://example.com\(usuario)/") {
                    Link(destination: url) {
                        Label("Abrir la sala en Plataforma 1", systemImage: "arrow.up.forward.app")
                    }
                }
            }
        }
        .sheet(isPresented: $verChat) {
            HojaChat(chatSala: chatSala, chatEncargos: chatEncargos)
                .hojaQueChoca()
        }
        .sheet(isPresented: $verVideo) {
            HojaVideo(usuario: usuario)
                .hojaQueChoca()
        }
        .task(id: fijada) { await cargar() }

        .task(id: enDirecto) {
            if informe != nil { await cargar() }
            guard enDirecto else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(20))
                await cargar()
            }
        }
        
        .onChange(of: fase) { _, nueva in
            if nueva == .active, informe != nil { Task { await cargar() } }
        }
    }

    private var eleccion: Binding<String> {
        Binding(get: { fijada ?? informe?.noche?.noche.jornada ?? "" },
                set: { nueva in fijada = nueva == informe?.noches.first?.jornada ? nil : nueva })
    }

    private var titulo: String {
        guard let n = informe?.noche?.noche else { return "Sala" }
        return NombreDeNoche.titulo(n.jornada, hoy: informe?.hoy ?? "", enCurso: n.enCurso)
    }

    private func cargar() async {
        let pedida = fijada
        let ruta = pedida.map { "api/sala/informe?noche=\($0)" } ?? "api/sala/informe"
        do {
            let j = try await API.pedir(ruta, testigo: sesion.testigo)

            guard pedida == fijada else { return }
            let nuevo = InformeSala(j)
            if nuevo != informe {
                withAnimation(Diseno.suave) { informe = nuevo }
            }
            fallo = nil
        } catch is CancellationError {
            return
        } catch {
            if informe == nil { fallo = error.localizedDescription }
        }
    }
}

struct SalaEstadio: View {
    let informe: InformeSala
    let d: InformeSala.Detalle
    let sala: PantallaSala.Sala?
    @Binding var jornada: String
    @Binding var rastreando: Bool

    @State private var minuto: Int?
    @State private var repeticion: Task<Void, Never>?
    @Environment(\.accessibilityReduceMotion) private var menosMovimiento

    private var enVivo: Bool { d.noche.enCurso && (sala?.enDirecto ?? true) }
    
    private var enSala: Set<String> {
        guard enVivo, let s = sala else { return [] }
        return Set(s.dentro.map(\.quien))
    }
    
    private var tuGenteEnSala: [InformeSala.Persona] {
        informe.gente.filter { enSala.contains($0.quien) }
    }
    private var total: Int { max(d.tramos.last?.upperBound ?? d.noche.minutos, 1) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            TiraDeNoches(noches: informe.noches, elegida: $jornada, alto: 40)

            LineaDeLaNoche(n: d.noche)
                .padding(.horizontal, Diseno.margen)
                .padding(.top, Diseno.hueco2)

            Estadio(d: d, minuto: minuto,
                    presentesAhora: enVivo && minuto == nil ? sala?.cuantos : nil,
                    tuGenteEnSala: enVivo && minuto == nil ? tuGenteEnSala : [])
                .frame(height: 250)
                .padding(.top, Diseno.hueco2)

            Escenario(d: d, minuto: minuto, sala: enVivo ? sala : nil)
                .frame(maxWidth: .infinity)
                .padding(.top, Diseno.hueco1)
            pieDelEscenario
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Diseno.margen)
                .padding(.top, Diseno.hueco2)

            TituloDeSeccion(texto: "Minuto a minuto", dato: lectura)
                .animation(.snappy(duration: 0.15), value: minuto)
                .padding(.horizontal, Diseno.margen)
            HStack(alignment: .center, spacing: Diseno.hueco1) {
                if !menosMovimiento {
                    Button {
                        if repeticion != nil { parar() } else { repetir() }
                    } label: {
                        Image(systemName: repeticion != nil ? "pause.fill" : "play.fill")
                            .font(.title3.weight(.semibold))
                            .contentTransition(.symbolEffect(.replace))
                            .frame(width: 30, height: 30)
                    }
                    .buttonStyle(.glass)
                    .buttonBorderShape(.circle)
                    .accessibilityLabel(repeticion != nil ? "Parar" : "Repetir la noche")
                    .padding(.leading, Diseno.margen)
                }
                GraficoNoche(d: d, minuto: $minuto, rastreando: $rastreando, alto: 130)
            }
            .padding(.top, Diseno.hueco1)
            LeyendaNoche(gente: !d.gente.isEmpty, propinas: !d.propinas.isEmpty,
                         seguidores: !d.seguidoresMin.isEmpty)
                .padding(.horizontal, Diseno.margen)
                .padding(.top, Diseno.hueco1)
            if d.gente.isEmpty {
                Text("La gente en la sala se apunta desde el 3 oct.")
                    .font(.footnote).foregroundStyle(Marcador.apoyo)
                    .padding(.horizontal, Diseno.margen)
            }

            LoMejorDeLaNoche(d: d, enSala: enSala)
                .padding(.top, Diseno.hueco2)
            SeccionTuGente(informe: informe, enSala: enSala)
                .padding(.horizontal, Diseno.margen)
                .padding(.top, Diseno.hueco2)
            if let s = sala {
                SeccionSeguidores(sala: s)
                    .padding(.horizontal, Diseno.margen)
                    .padding(.top, Diseno.hueco2)
                if enVivo && !s.dentro.isEmpty {
                    NavigationLink {
                        PantallaQuienHay(sala: s, informe: informe)
                    } label: {
                        HStack(spacing: 4) {
                            TituloDeSeccion(texto: "En la sala ahora", dato: "\(s.cuantos)")
                            Image(systemName: "chevron.right")
                                .font(.footnote.weight(.bold))
                                .foregroundStyle(Marcador.apoyo)
                                .padding(.top, Diseno.hueco3)
                        }
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, Diseno.margen)
                }
            }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: propinasHasta) { antes, ahora in
            repeticion != nil && ahora > antes
        }
        .onChange(of: jornada) { parar(); minuto = nil }
        .onDisappear { parar() }
        #if MAQUETA
        .onAppear { if let m = Maqueta.minutoSala { minuto = min(m, total) } }
        #endif
    }

    @ViewBuilder
    private var pieDelEscenario: some View {
        if enVivo && minuto == nil {
            if !tuGenteEnSala.isEmpty {
                Text("De tu gente, en la sala: " + tuGenteEnSala.prefix(4).map(\.quien).joined(separator: ", "))
                    .font(.subheadline.weight(.medium))
            }
        } else if minuto == nil, let texto = pieDeLaNoche {
            Text(texto)
                .font(.subheadline)
                .foregroundStyle(Marcador.apoyo)
        }
    }

    private var pieDeLaNoche: String? {
        var partes: [String] = []
        if let u = d.noche.unicos { partes.append(u == 1 ? "pasó 1 persona" : "pasaron \(Formato.numero(u)) personas") }
        if let p = d.puesto, d.de > 2 {

            partes.append(p == 1 ? "tu mejor noche en tokens"
                          : p == d.de ? "tu noche con menos tokens"
                          : "la \(p).ª de tus \(d.de) noches en tokens")
        }
        return partes.isEmpty ? nil : partes.joined(separator: " · ").capitalizandoPrimera
    }

    private var lectura: String? {
        guard let m = minuto,
              let p = d.propinas.filter({ abs($0.minuto - m) <= 1 }).max(by: { $0.tokens < $1.tokens })
        else { return nil }
        return "\(p.quien) · \(Formato.tokens(p.tokens))"
    }

    private var propinasHasta: Int { minuto.map { m in d.propinas.filter { $0.minuto <= m }.count } ?? 0 }

    private func repetir() {
        parar()
        repeticion = Task { @MainActor in
            let pasos = 120
            for i in 0...pasos {
                if Task.isCancelled { return }
                minuto = total * i / pasos
                try? await Task.sleep(for: .milliseconds(50))
            }
            try? await Task.sleep(for: .milliseconds(600))
            if !Task.isCancelled {
                withAnimation(.snappy(duration: 0.3)) { minuto = nil }
                repeticion = nil
            }
        }
    }

    private func parar() {
        repeticion?.cancel()
        repeticion = nil
    }
}

private struct Escenario: View {
    let d: InformeSala.Detalle
    let minuto: Int?
    
    let sala: PantallaSala.Sala?

    struct Dato: Identifiable {
        let valor: String
        let numero: Double
        let pie: String
        var cambio: (texto: String, sube: Bool)?
        var id: String { pie }
    }

    private var datos: [Dato] {
        let n = d.noche
        if let m = minuto {
            let tokens = d.propinas.filter { $0.minuto <= m }.reduce(0) { $0 + $1.tokens }
            var r = [Dato(valor: Formato.tokens(tokens, unidad: ""), numero: Double(tokens), pie: "tokens hasta aquí")]
            if !d.gente.isEmpty {
                let g = d.gente.last { $0.minuto <= m }?.personas ?? 0
                r.append(Dato(valor: "\(g)", numero: Double(g), pie: "en la sala"))
            }
            r.append(Dato(valor: NombreDeNoche.hora(n.inicio, minuto: m), numero: Double(m), pie: "hora"))
            return r
        }
        if let s = sala {

            let seguidores = n.seguidores ?? s.siguen24h
            return [Dato(valor: Formato.tokens(n.tokens, unidad: ""), numero: Double(n.tokens), pie: "tokens esta noche"),
                    Dato(valor: "\(s.cuantos)", numero: Double(s.cuantos), pie: "en la sala"),
                    Dato(valor: "+\(seguidores)", numero: Double(seguidores),
                         pie: n.seguidores != nil ? "seguidores" : "seguidores 24 h")]
        }
        var r = [Dato(valor: Formato.tokens(n.tokens, unidad: ""), numero: Double(n.tokens), pie: "tokens",
                      cambio: cambio(Double(n.tokens), d.normal?.tokens))]
        if let pico = n.pico {
            r.append(Dato(valor: "\(pico)", numero: Double(pico), pie: "a la vez",
                          cambio: cambio(Double(pico), d.normal?.pico)))
        } else {
            r.append(Dato(valor: "\(n.personas)", numero: Double(n.personas), pie: n.personas == 1 ? "dio" : "dieron",
                          cambio: cambio(Double(n.personas), d.normal?.personas)))
        }
        if let s = n.seguidores {
            r.append(Dato(valor: "+\(s)", numero: Double(s), pie: "seguidores",
                          cambio: cambio(Double(s), d.normal?.seguidores)))
        }
        return r
    }

    private func cambio(_ valor: Double, _ normal: Double?) -> (texto: String, sube: Bool)? {
        guard let normal, normal > 0 else { return nil }
        let p = Int(((valor - normal) / normal * 100).rounded())
        guard abs(p) >= 5 else { return nil }
        return (texto: "\(abs(p)) % \(p > 0 ? "sobre" : "bajo") lo normal", sube: p > 0)
    }

    var body: some View {
        HStack(alignment: .top, spacing: Diseno.hueco2) {
            ForEach(Array(datos.enumerated()), id: \.element.id) { i, x in
                if i > 0 { Divider().frame(height: 40).padding(.top, 4) }
                VStack(spacing: 1) {
                    Text(x.valor)
                        .font(.system(.title, design: .rounded).weight(.bold)).monospacedDigit()
                        .contentTransition(.numericText(value: x.numero))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text(x.pie)
                        .font(.caption)
                        .foregroundStyle(Marcador.apoyo)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    if let c = x.cambio {

                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Circle().fill(c.sube ? Diseno.verdeRelleno : Diseno.rojoRelleno)
                                .frame(width: 6, height: 6)
                                .alignmentGuide(.firstTextBaseline) { $0[.bottom] }
                            Text(c.texto)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(Color.primary)
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                                .minimumScaleFactor(0.85)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .combine)
            }
        }
        .padding(.horizontal, Diseno.hueco3)
        .padding(.vertical, Diseno.hueco2)
        .cristal(.regular, en: .capsule)
        .padding(.horizontal, Diseno.margen)
        .animation(.snappy(duration: 0.2), value: minuto)
        
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
    }

}

private struct Estadio: View {
    let d: InformeSala.Detalle
    
    let minuto: Int?
    
    var presentesAhora: Int?
    
    var tuGenteEnSala: [InformeSala.Persona] = []

    @Environment(\.colorScheme) private var modo

    var body: some View {
        Canvas { ctx, size in
            let centro = CGPoint(x: size.width / 2, y: size.height - 6)
            let asientos = Self.asientos(en: size, centro: centro)
            let quienes = d.quienes
            let dieron = Set(quienes.map(\.quien))
            let visitas = tuGenteEnSala.filter { !dieron.contains($0.quien) }.prefix(6)
            let delante = quienes.count + visitas.count
            let maxT = Double(max(quienes.map(\.tokens).max() ?? 1, 1))
            let presentes: Int = {
                if let m = minuto { return d.gente.last { $0.minuto <= m }?.personas ?? 0 }
                if let ahora = presentesAhora { return ahora }
                return d.noche.unicos ?? 0
            }()
            let primeroDe: [String: Int] = d.propinas.reduce(into: [:]) { r, p in
                if r[p.quien] == nil { r[p.quien] = p.minuto }
            }
            let tinta: Color = modo == .dark ? .white : .black
            let alfaLleno = modo == .dark ? 0.46 : 0.32
            let alfaVacio = modo == .dark ? 0.14 : 0.07
            let maxRadio = asientos.map { hypot($0.x - centro.x, $0.y - centro.y) }.max() ?? 1

            let siguieron = minuto == nil && presentesAhora == nil ? (d.noche.seguidores ?? 0) : 0

            func radio(_ q: InformeSala.Persona) -> CGFloat {
                4 + 10.5 * CGFloat((Double(q.tokens) / maxT).squareRoot())
            }
            var sitios: [(punto: CGPoint, radio: CGFloat)] = []
            func colocar(_ r: CGFloat) -> CGPoint? {
                for a in asientos where sitios.allSatisfy({ hypot(a.x - $0.punto.x, a.y - $0.punto.y) >= r + $0.radio + 4 }) {
                    sitios.append((a, r))
                    return a
                }
                return nil
            }
            let sitiosQuien = quienes.map { colocar(radio($0)) }
            let sitiosVisita = visitas.map { _ in colocar(5) }

            let libres = asientos.filter { a in sitios.allSatisfy { hypot(a.x - $0.punto.x, a.y - $0.punto.y) >= $0.radio + 3 } }
            let llenos = min(max(presentes - delante, 0), libres.count)
            
            let verdes = min(siguieron, llenos)
            for (i, a) in libres.enumerated() {
                let lleno = i < llenos
                
                let lejos = min(max((hypot(a.x - centro.x, a.y - centro.y) - 46) / max(maxRadio - 46, 1), 0), 1)
                let r: CGFloat = lleno ? 2.6 - 0.9 * lejos : 1.6 - 0.4 * lejos
                let siguio = lleno && verdes > 0 && (i * verdes / max(llenos, 1)) != ((i + 1) * verdes / max(llenos, 1))
                let color: Color = siguio ? Diseno.verdeRelleno
                    : tinta.opacity((lleno ? alfaLleno : alfaVacio) * (1 - 0.4 * lejos))
                let punto = Path(ellipseIn: CGRect(x: a.x - r, y: a.y - r, width: r * 2, height: r * 2))
                ctx.fill(punto, with: .color(color))
                
                if siguio && modo == .light {
                    ctx.stroke(punto, with: .color(.black.opacity(0.6)), lineWidth: 0.6)
                }
            }
            
            for k in visitas.indices {
                guard let a = sitiosVisita[k - visitas.startIndex] else { continue }
                let r: CGFloat = 5
                
                ctx.stroke(Path(ellipseIn: CGRect(x: a.x - r, y: a.y - r, width: r * 2, height: r * 2)),
                           with: .color(modo == .dark ? .white : .black.opacity(0.7)), lineWidth: 1.5)
            }
            
            for (i, q) in quienes.enumerated() {
                guard let a = sitiosQuien[i] else { continue }
                let encendido = minuto.map { m in (primeroDe[q.quien] ?? .max) <= m } ?? true
                let r = radio(q)
                let caja = CGRect(x: a.x - r, y: a.y - r, width: r * 2, height: r * 2)
                if encendido {
                    ctx.drawLayer { capa in
                        capa.addFilter(.shadow(color: Sala.color.opacity(0.75), radius: 7))
                        capa.fill(Path(ellipseIn: caja), with: .color(Sala.color))
                    }

                    if modo == .light {
                        ctx.stroke(Path(ellipseIn: caja), with: .color(.black.opacity(0.6)),
                                   lineWidth: 1)
                    }
                    if q.vuelve {
                        ctx.stroke(Path(ellipseIn: caja.insetBy(dx: -2.5, dy: -2.5)),
                                   with: .color(.white.opacity(0.95)), lineWidth: 1.4)
                    }
                    if q.nuevo {
                        ctx.fill(Path(ellipseIn: CGRect(x: caja.maxX - 2.5, y: caja.minY - 2.5,
                                                        width: 5, height: 5)),
                                 with: .color(.yellow))
                    }
                } else {
                    ctx.stroke(Path(ellipseIn: caja), with: .color(Sala.color.opacity(0.5)), lineWidth: 1)
                }
            }
            
            if let primero = quienes.first, let a = sitiosQuien.first ?? nil,
               minuto.map({ m in (primeroDe[primero.quien] ?? .max) <= m }) ?? true {
                    let r = radio(primero)
                ctx.draw(etiqueta("\(primero.quien) · \(Formato.tokens(primero.tokens))"),
                         at: CGPoint(x: a.x, y: a.y - r - 11))
            }
        }

        .dynamicTypeSize(...DynamicTypeSize.xxLarge)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("La sala de la noche")
        .accessibilityValue(resumen)
    }

    private func etiqueta(_ texto: String) -> Text {
        Text(texto)
            .font(.caption.weight(.bold))
            .foregroundStyle(modo == .dark ? Color.white : Color.black.opacity(0.8))
    }

    private var resumen: String {
        var partes: [String] = []
        if let ahora = presentesAhora { partes.append("\(ahora) en la sala ahora") }
        else if let u = d.noche.unicos { partes.append("\(u) personas pasaron") }
        partes.append(d.quienes.count == 1 ? "1 dio propina" : "\(d.quienes.count) dieron propina")
        if let p = d.quienes.first { partes.append("la que más, \(p.quien), \(p.tokens) tokens") }
        return partes.joined(separator: ", ")
    }

    static func asientos(en size: CGSize, centro: CGPoint) -> [CGPoint] {
        var lista: [CGPoint] = []
        let paso: CGFloat = 9.5
        var radio: CGFloat = 46
        let maxRadio = min(size.width / 2 - 10, size.height - 16)
        while radio <= maxRadio {
            let n = max(Int((CGFloat.pi * radio) / paso), 1)
            let mitad = CGFloat.pi / 2
            var fila: [CGFloat] = []
            for k in 0..<n { fila.append(CGFloat.pi * (CGFloat(k) + 0.5) / CGFloat(n)) }
            fila.sort { abs($0 - mitad) < abs($1 - mitad) }
            for ang in fila {
                lista.append(CGPoint(x: centro.x - cos(ang) * radio, y: centro.y - sin(ang) * radio))
            }
            radio += paso
        }
        return lista
    }
}

private struct LeyendaNoche: View {
    let gente: Bool
    let propinas: Bool
    let seguidores: Bool
    @Environment(\.colorScheme) private var modo

    var body: some View {
        HStack(spacing: Diseno.hueco2) {
            if gente {
                Label { Text("gente en la sala") } icon: {

                    Capsule().fill(modo == .dark ? Color.white : Sala.color).frame(width: 12, height: 3)
                }
            }
            if propinas {
                Label { Text("propinas") } icon: {
                    Circle().fill(Sala.color).frame(width: 7, height: 7)
                }
            }
            if seguidores {
                Label { Text("seguidores nuevos") } icon: {
                    RoundedRectangle(cornerRadius: 1).fill(Diseno.verdeRelleno).frame(width: 2.5, height: 9)
                }
            }
        }
        .labelStyle(LeyendaEstilo())
        .font(.caption)
        .foregroundStyle(Marcador.apoyo)
        .accessibilityElement(children: .combine)
    }

    private struct LeyendaEstilo: LabelStyle {
        func makeBody(configuration: Configuration) -> some View {
            HStack(spacing: 5) { configuration.icon; configuration.title }
        }
    }
}

struct LoMejorDeLaNoche: View {
    let d: InformeSala.Detalle
    var enSala: Set<String> = []
    var cuantos = 5

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            TituloDeSeccion(texto: "Quién dio", dato: d.noche.personas == 1 ? "1 persona"
                            : "\(d.noche.personas) personas")
                .padding(.horizontal, Diseno.margen)
            if d.quienes.isEmpty && d.noche.sinDetalle == 0 && d.noche.anonimas == 0 {
                Text("Nadie dio propina esa noche.")
                    .font(.subheadline).foregroundStyle(Marcador.apoyo)
                    .padding(.horizontal, Diseno.margen)
                    .padding(.top, Diseno.hueco1)
            }
            VStack(spacing: 0) {
                ForEach(Array(d.quienes.prefix(cuantos).enumerated()), id: \.element.id) { i, p in
                    FilaDePersona(p: p, puesto: i + 1, detalle: detalleDe(p), enSala: enSala.contains(p.quien),
                                  deUnaNoche: true)
                    if i < min(cuantos, d.quienes.count) - 1 || hayFilasSinNombre {
                        Divider().padding(.leading, 80)
                    }
                }
                if d.quienes.count > cuantos {
                    NavigationLink {
                        PantallaQuienDio(d: d, enSala: enSala)
                    } label: {
                        HStack {
                            Text("Ver las \(d.quienes.count) personas")
                            Spacer()
                            Image(systemName: "chevron.right").font(.footnote.weight(.semibold))
                        }
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Marcador.apoyo)
                        .padding(.vertical, 10)
                        .padding(.leading, 80)
                        .contentShape(.rect)
                    }
                    .buttonStyle(Hundirse())
                    if hayFilasSinNombre { Divider().padding(.leading, 80) }
                }

                if d.noche.anonimas > 0 {
                    FilaSinNombre(icono: "person.fill.questionmark", titulo: "Anónimas",
                                  detalle: d.noche.propinasAnonimas == 1 ? "1 propina sin nombre"
                                      : "\(d.noche.propinasAnonimas) propinas sin nombre",
                                  tokens: d.noche.anonimas)
                    if d.noche.sinDetalle > 0 { Divider().padding(.leading, 80) }
                }
                if d.noche.sinDetalle > 0 {
                    FilaSinNombre(icono: "lock.fill", titulo: "Encargos, club y otros",
                                  detalle: "Plataforma 1 no dice de quién", tokens: d.noche.sinDetalle)
                }
            }
            .padding(.horizontal, Diseno.margen)
        }
    }

    private var hayFilasSinNombre: Bool { d.noche.anonimas > 0 || d.noche.sinDetalle > 0 }

    static func detalle(_ p: InformeSala.Persona) -> String {
        let veces = p.propinas == 1 ? "1 propina" : "\(p.propinas) propinas"
        if p.nuevo { return "Primera vez · \(veces)" }
        return "Ha dado en \(p.noches) noches · \(veces)"
    }

    private func detalleDe(_ p: InformeSala.Persona) -> String { Self.detalle(p) }
}

private struct FilaSinNombre: View {
    let icono: String
    let titulo: String
    let detalle: String
    let tokens: Int

    var body: some View {
        HStack(spacing: Diseno.hueco2) {
            Color.clear.frame(width: 22)
            Image(systemName: icono)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(Color.gray.gradient, in: .circle)
            VStack(alignment: .leading, spacing: 2) {
                Text(titulo).font(.headline)
                Text(detalle).font(.footnote).foregroundStyle(Marcador.apoyo)
            }
            Spacer()
            Text(Formato.tokens(tokens))
                .font(.system(.headline, design: .rounded)).monospacedDigit()
        }
        .padding(.vertical, 10)
        .accessibilityElement(children: .combine)
    }
}

private struct PantallaQuienDio: View {
    let d: InformeSala.Detalle
    let enSala: Set<String>

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(Array(d.quienes.enumerated()), id: \.element.id) { i, p in
                    FilaDePersona(p: p, puesto: i + 1, detalle: LoMejorDeLaNoche.detalle(p),
                                  enSala: enSala.contains(p.quien), deUnaNoche: true)
                    if i < d.quienes.count - 1 { Divider().padding(.leading, 80) }
                }
            }
            .padding(.horizontal, Diseno.margen)
            .padding(.bottom, Diseno.hueco5)
        }
        .fondoDePantalla()
        .navigationTitle("Quién dio")
        .navigationSubtitle(NombreDeNoche.corta(d.noche.jornada))
    }
}

private struct SeccionSeguidores: View {
    let sala: PantallaSala.Sala

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            TituloDeSeccion(texto: "Seguidores",
                            dato: sala.seguidoresBase > 0 ? Formato.numero(sala.seguidores) : nil)
            HStack(spacing: Diseno.hueco2) {

                Label {
                    Text("+\(sala.siguen24h)").foregroundStyle(Color.primary)
                } icon: {
                    Image(systemName: "heart.fill").foregroundStyle(Diseno.verdeRelleno)
                }
                .accessibilityLabel("\(sala.siguen24h) nuevos en 24 horas")
                Label {
                    Text("−\(sala.dejan24h)").foregroundStyle(Color.primary)
                } icon: {
                    Image(systemName: "heart.slash.fill")
                        .foregroundStyle(sala.dejan24h > 0 ? AnyShapeStyle(Diseno.rojoRelleno)
                                                           : AnyShapeStyle(Marcador.apoyo))
                }
                .accessibilityLabel("\(sala.dejan24h) bajas en 24 horas")
                Text("en 24 h").foregroundStyle(Marcador.apoyo)
            }
            .font(.subheadline.weight(.semibold))
            .monospacedDigit()
            if sala.seguidoresBase == 0 {
                
                Text("Plataforma 1 no dice cuántos seguidores tienes. Apunta los que ya tenías en "
                     + "Ajustes de Plataforma 1 y la app los mantiene desde ahí.")
                    .font(.footnote).foregroundStyle(Marcador.apoyo)
            }
        }
    }
}

private struct PantallaQuienHay: View {
    let sala: PantallaSala.Sala
    let informe: InformeSala

    var body: some View {
        let tuyos = Dictionary(informe.gente.map { ($0.quien, $0) }, uniquingKeysWith: { a, _ in a })
        let lista = sala.dentro.sorted { (tuyos[$0.quien]?.tokens ?? -1) > (tuyos[$1.quien]?.tokens ?? -1) }
        ScrollView {
            VStack(spacing: 0) {
                ForEach(Array(lista.enumerated()), id: \.element.id) { i, p in
                    HStack(spacing: Diseno.hueco2) {
                        Inicial(nombre: p.quien.isEmpty ? "?" : p.quien, tuyo: tuyos[p.quien] != nil,
                                vuelve: (tuyos[p.quien]?.noches ?? 0) > 1)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(p.quien.isEmpty ? "anónimo" : p.quien).font(.headline).lineLimit(1)
                            Text("desde las \(p.desde)").font(.footnote).foregroundStyle(.secondary)
                        }
                        Spacer()
                        if let t = tuyos[p.quien] {
                            Text(Formato.tokens(t.tokens))
                                .font(.system(.headline, design: .rounded)).monospacedDigit()
                                .foregroundStyle(Sala.color)
                        }
                    }
                    .padding(.vertical, 10)
                    .accessibilityElement(children: .combine)
                    if i < lista.count - 1 { Divider().padding(.leading, 46) }
                }

                Text("Solo quien haya entrado desde que la app escucha.")
                    .font(.footnote).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, Diseno.hueco2)
            }
            .padding(.horizontal, Diseno.margen)
            .padding(.bottom, Diseno.hueco5)
        }
        .fondoDePantalla()
        .navigationTitle("En la sala ahora")
        .navigationSubtitle("\(sala.cuantos) personas")
    }
}

struct LineaDeLaNoche: View {
    let n: InformeSala.Noche

    var body: some View {
        let fin = n.inicio.map { $0.addingTimeInterval(Double(n.minutos) * 60) }
        var partes = [Formato.duracion(Double(n.minutos) / 60)]
        if let i = n.inicio {
            partes.append(n.enCurso ? "desde las \(hora(i))" : "\(hora(i)) → \(fin.map(hora) ?? "")")
        }
        if n.cortes > 0 { partes.append(n.cortes == 1 ? "1 corte" : "\(n.cortes) cortes") }
        return Text(partes.joined(separator: " · "))
            .font(.subheadline)
            .monospacedDigit()
            .foregroundStyle(Marcador.apoyo)
    }

    private func hora(_ d: Date) -> String { NombreDeNoche.hora(d, minuto: 0) }
}

private struct HojaChat: View {
    let chatSala: [PantallaSala.Mensaje]
    let chatEncargos: [PantallaSala.Mensaje]
    @State private var cual = "sala"

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    let lista = cual == "sala" ? chatSala : chatEncargos
                    if lista.isEmpty {
                        Vacio(icono: "bubble.left", titulo: cual == "sala" ? "Nadie ha escrito todavía"
                                                                         : "Ningún encargo todavía")
                    }
                    
                    ForEach(lista.reversed()) { m in
                        HStack(alignment: .top, spacing: Diseno.hueco2) {
                            Inicial(nombre: m.de, lado: 28, tuyo: false)
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Text(m.de).font(.subheadline.weight(.semibold))
                                    Text(m.hora).font(.caption2).foregroundStyle(Diseno.apoyoEnCristal)
                                }
                                Text(m.texto).font(.subheadline)
                            }
                        }
                        .padding(.vertical, 8)
                        .accessibilityElement(children: .combine)
                    }
                    
                    Text("Para contestar, abre la sala en Plataforma 1.")
                        .font(.footnote).foregroundStyle(.secondary)
                        .padding(.vertical, Diseno.hueco2)
                }
                .padding(.horizontal, Diseno.margen)
            }
            .navigationTitle(cual == "sala" ? "Chat" : "Encargos")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .top) {
                SelectorDeslizante(opciones: [(clave: "sala", nombre: "Sala · \(chatSala.count)"),
                                              (clave: "encargos", nombre: "Encargos · \(chatEncargos.count)")],
                                   elegida: $cual)
                    .padding(.horizontal, Diseno.margen)
            }
        }
        .presentationDetents([.medium, .large])
    }
}

private struct HojaVideo: View {
    let usuario: String

    var body: some View {
        VStack {
            if let url = URL(string: "https://example.com\(usuario)/") {
                Web(url: url)
                    .aspectRatio(16.0 / 9.0, contentMode: .fit)
                    .clipShape(.rect(cornerRadius: Diseno.radioTarjeta))
                    .padding(Diseno.margen)
            }
            Spacer(minLength: 0)
        }
        .presentationDetents([.medium])
    }
}

extension String {

    var capitalizandoPrimera: String { prefix(1).uppercased() + dropFirst() }
}
