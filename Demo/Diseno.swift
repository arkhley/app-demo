import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

private extension UIColor {
    convenience init(rgb: UInt32) {
        self.init(red: Double((rgb >> 16) & 0xFF) / 255,
                  green: Double((rgb >> 8) & 0xFF) / 255,
                  blue: Double(rgb & 0xFF) / 255,
                  alpha: 1)
    }
}

enum Diseno {

    static let azul = adaptativo(claro: 0x006AD5, oscuro: 0x2997FF)
    static let verde = adaptativo(claro: 0x177D4B, oscuro: 0x34A86E)
    static let rojo = adaptativo(claro: 0xD70015, oscuro: 0xFF5E55)
    static let naranja = adaptativo(claro: 0xB25000, oscuro: 0xE07A26)
    static let morado = adaptativo(claro: 0x6E56CF, oscuro: 0x9A89DD)

    static let fondo = Color(.systemGroupedBackground)

    static let superficie = Color(.secondarySystemGroupedBackground)

    static func tarjetaConTema(_ delEntorno: Color, _ tema: Tema, enLista: Bool = false) -> Color {
        guard !enLista, delEntorno == superficie else { return delEntorno }
        return tema.superficie ?? delEntorno
    }

    static let superficieEnCristal = Color(UIColor { entorno in
        entorno.userInterfaceStyle == .dark ? UIColor(white: 1, alpha: 0.08)
                                            : UIColor(white: 1, alpha: 0.55)
    })

    static let azulRelleno = Color.blue
    static let verdeRelleno = Color.green
    static let rojoRelleno = Color.red
    static let naranjaRelleno = Color.orange
    static let moradoRelleno = Color.purple

    static func colorDePlataforma(_ clave: String) -> Color {
        switch clave {
        case "plataforma1": return naranjaRelleno   
        case "plataforma2":  return moradoRelleno
        case "tienda":   return azulRelleno
        case "todo":       return verdeRelleno
        default:           return azulRelleno
        }
    }

    static func nombreDePlataforma(_ clave: String) -> String {
        switch clave {
        case "plataforma1": return "Plataforma 1"
        case "plataforma2":  return "Plataforma 2"
        case "tienda":   return "Tienda"
        case "pasarela":     return "Pasarela"
        default:           return clave.capitalizandoPrimera
        }
    }

    private static func adaptativo(claro: UInt32, oscuro: UInt32) -> Color {
        Color(UIColor { entorno in
            UIColor(rgb: entorno.userInterfaceStyle == .dark ? oscuro : claro)
        })
    }

    static let hueco1: CGFloat = 6
    static let hueco2: CGFloat = 12
    static let hueco3: CGFloat = 18
    static let hueco4: CGFloat = 26
    static let hueco5: CGFloat = 38

    static let margen: CGFloat = 20

    static let radioTarjeta: CGFloat = 22
    static let radioCampo: CGFloat = 15
    static let radioHeroe: CGFloat = 28
    
    static let radioHoja: CGFloat = 26

    static let radioIcono: CGFloat = 8

    static let ladoIcono: CGFloat = 29

    static var sangriaFila: CGFloat { hueco3 + ladoIcono + hueco2 }

    static func fuerzaHeroe(_ modo: ColorScheme) -> Double { modo == .dark ? 0.45 : 0.30 }

    static let sobreTinte = Color.primary.opacity(0.80)

    static var apoyoEnCristal: AnyShapeStyle {
        AnyShapeStyle(sobreTinte)
    }

    static let suave = Animation.smooth(duration: 0.28)
    
    static let cifra = Animation.smooth(duration: 0.18)
}

private struct CristalOSolido<Forma: Shape>: ViewModifier {
    let variante: Glass
    let forma: Forma
    @Environment(\.accessibilityReduceTransparency) private var menosTransparencia

    func body(content: Content) -> some View {
        Group {
            if menosTransparencia {
                
                content.background(variante == .identity ? AnyShapeStyle(.clear)
                                                         : AnyShapeStyle(.background.secondary),
                                   in: forma)
            } else {
                content.glassEffect(variante, in: forma)
            }
        }

        .modifier(ChocaSiSeSabe(forma: forma))
    }
}

private struct ChocaSiSeSabe<Forma: Shape>: ViewModifier {
    let forma: Forma

    func body(content: Content) -> some View {
        if let f = Self.deChoque(forma) {
            content.chocable(f, reacciona: true)
        } else {
            content
        }
    }

    static func deChoque(_ forma: Forma) -> FormaDeChoque? {
        if forma is Capsule { return .capsula }
        if forma is Circle { return .circulo }
        if let r = forma as? RoundedRectangle { return .caja(radio: r.cornerSize.width) }
        if forma is Rectangle { return .caja(radio: 0) }
        return nil
    }
}

extension View {
    
    func cristal<Forma: Shape>(_ variante: Glass = .regular, en forma: Forma) -> some View {
        modifier(CristalOSolido(variante: variante, forma: forma))
    }
}

struct Tarjeta<Contenido: View>: View {
    var relleno: CGFloat = Diseno.hueco3
    @ViewBuilder var contenido: Contenido
    
    @Environment(\.superficieDeTarjeta) private var superficie
    @Environment(\.enCampo) private var enCampo
    @Environment(\.tema) private var tema
    @Environment(\.dentroDeUnaLista) private var enLista

    var body: some View {
        if enCampo {
            
            contenido
                .frame(maxWidth: .infinity, alignment: .leading)
                .chocable(.caja(radio: 0))
        } else {
            contenido
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(relleno)
                .background(Diseno.tarjetaConTema(superficie, tema, enLista: enLista),
                            in: .rect(cornerRadius: Diseno.radioTarjeta))
                .chocable(.caja(radio: Diseno.radioTarjeta))
        }
    }
}

private struct EnCampo: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var enCampo: Bool {
        get { self[EnCampo.self] }
        set { self[EnCampo.self] = newValue }
    }
}

private struct SuperficieDeTarjeta: EnvironmentKey {
    static let defaultValue = Diseno.superficie
}

extension EnvironmentValues {
    var superficieDeTarjeta: Color {
        get { self[SuperficieDeTarjeta.self] }
        set { self[SuperficieDeTarjeta.self] = newValue }
    }
}

extension View {

    func tarjetasEnCristal(_ activo: Bool = true) -> some View {
        environment(\.superficieDeTarjeta, activo ? Diseno.superficieEnCristal : Diseno.superficie)
    }
}

struct FichaIcono: View {
    let simbolo: String
    let color: Color
    var lado: CGFloat = Diseno.ladoIcono

    @ScaledMetric(relativeTo: .body) private var factor: CGFloat = 1
    private var ladoReal: CGFloat { lado * min(max(factor, 1), 1.6) }

    var body: some View {
        let lado = ladoReal
        Image(systemName: simbolo)
            .font(.system(size: lado * 0.62, weight: .medium))
            .foregroundStyle(.white)
            .frame(width: lado, height: lado)
            .background {
                ZStack {
                    color
                    LinearGradient(colors: [.white.opacity(0.28), .clear, .black.opacity(0.08)],
                                   startPoint: .top, endPoint: .bottom)
                }
            }
            .clipShape(.rect(cornerRadius: lado * 0.263))
            
            .overlay {
                RoundedRectangle(cornerRadius: lado * 0.263, style: .continuous)
                    .strokeBorder(LinearGradient(colors: [.white.opacity(0.5), .clear],
                                                 startPoint: .top, endPoint: .center),
                                  lineWidth: 0.8)
            }
    }
}

struct Grupo<Contenido: View>: View {

    var sangria: CGFloat = Diseno.sangriaFila
    @ViewBuilder var filas: Contenido
    @Environment(\.enCampo) private var enCampo

    var body: some View {
        grupo

            .padding(.horizontal, enCampo ? -Diseno.hueco3 : 0)
    }

    private var grupo: some View {
        Tarjeta(relleno: 0) {
            Group(subviews: filas) { hijos in
                VStack(spacing: 0) {
                    ForEach(hijos.indices, id: \.self) { i in
                        if i > hijos.startIndex {
                            Divider().padding(.leading, sangria)
                        }
                        hijos[i]
                    }
                }
            }
        }
        
        .clipShape(.rect(cornerRadius: Diseno.radioTarjeta))
    }
}

struct Heroe<Pie: View>: View {

    @ScaledMetric(relativeTo: .largeTitle) private var tamCifra: CGFloat = 44
    @Environment(\.colorScheme) private var modo
    let titulo: String
    let valor: String
    let etiqueta: String
    var icono: String = "eurosign.circle"
    var tinte: Color = Diseno.azul
    @ViewBuilder var pie: Pie

    var body: some View {
        VStack(alignment: .leading, spacing: Diseno.hueco2) {
            Label(titulo, systemImage: icono)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Diseno.sobreTinte)

            Text(valor)
                .font(.system(size: tamCifra, weight: .semibold, design: .rounded))
                .contentTransition(.numericText())   
                .minimumScaleFactor(0.6)
                .lineLimit(1)

            Text(etiqueta)
                .font(.subheadline)
                .foregroundStyle(Diseno.sobreTinte)

            pie
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Diseno.hueco4)

        .background { fondo }
        .clipShape(.rect(cornerRadius: Diseno.radioHeroe))
    }

    private var fondo: some View {
        let f = Diseno.fuerzaHeroe(modo)
        return ZStack {
            LinearGradient(colors: [tinte.opacity(f), tinte.opacity(f * 0.45)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            RadialGradient(colors: [tinte.opacity(f * 0.5), .clear],
                           center: .topTrailing, startRadius: 0, endRadius: 220)
        }
        .clipShape(.rect(cornerRadius: Diseno.radioHeroe))
    }
}

extension Heroe where Pie == EmptyView {
    init(titulo: String, valor: String, etiqueta: String,
         icono: String = "eurosign.circle", tinte: Color = Diseno.azul) {
        self.init(titulo: titulo, valor: valor, etiqueta: etiqueta,
                  icono: icono, tinte: tinte) { EmptyView() }
    }
}

struct AccesoHeroe<Destino: View>: View {
    let icono: String
    let titulo: String

    var aviso = false
    @ViewBuilder var destino: Destino

    var body: some View {
        NavigationLink {
            destino
        } label: {
            Label {
                Text(titulo)
            } icon: {
                
                if aviso {
                    Image(systemName: icono).foregroundStyle(Diseno.naranja)
                } else {
                    Image(systemName: icono)
                }
            }
            .font(.subheadline.weight(.medium))
        }
        .buttonStyle(.glass)
        .chocable(.capsula, reacciona: true)
    }
}

struct AccesosHeroe<Contenido: View>: View {
    @ViewBuilder var contenido: Contenido

    var body: some View {
        HStack(spacing: Diseno.hueco2) {
            contenido
            Spacer(minLength: 0)
        }
        .padding(.top, Diseno.hueco2)
    }
}

struct Banda: View {
    let texto: String
    let bien: Bool

    init(_ aviso: (texto: String, bien: Bool)) {
        self.texto = aviso.texto
        self.bien = aviso.bien
    }

    init(texto: String, bien: Bool) {
        self.texto = texto
        self.bien = bien
    }

    @State private var aparecida = false

    var body: some View {
        Label(texto, systemImage: bien ? "checkmark.circle.fill" : "exclamationmark.triangle")
            .font(.subheadline)
            .foregroundStyle(bien ? Diseno.verde : Diseno.rojo)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Diseno.hueco2)
            .background((bien ? Diseno.verde : Diseno.rojo).opacity(0.10),
                        in: .rect(cornerRadius: Diseno.radioCampo))
            .transition(.opacity.combined(with: .move(edge: .top)))

            .sensoryFeedback(bien ? .success : .error, trigger: aparecida)
            .onAppear { aparecida = true }
    }
}

struct SelectorDeslizante: View {
    let opciones: [(clave: String, nombre: String)]
    @Binding var elegida: String
    var onCambio: (String) -> Void = { _ in }

    var body: some View {
        Picker("", selection: $elegida) {
            ForEach(opciones, id: \.clave) { o in
                Text(o.nombre).tag(o.clave)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        
        .sensoryFeedback(.selection, trigger: elegida)

        .onChange(of: elegida) { _, nueva in onCambio(nueva) }
    }
}

struct SelectorPeriodo: View {
    @Binding var periodo: String

    var semanal = false
    var onCambio: (String) -> Void = { _ in }

    static let opciones = [("dia", "Hoy"), ("quincena", "Quincena"), ("mes", "Mes"),
                           ("ano", "Año"), ("total", "Todo")]

    var body: some View {
        SelectorDeslizante(opciones: Self.opciones.map {
                               semanal && $0.0 == "quincena" ? (clave: "semana", nombre: "Semana")
                                                             : (clave: $0.0, nombre: $0.1)
                           },
                           elegida: $periodo, onCambio: onCambio)
            .chocable(.capsula)
            .accessibilityLabel("Periodo")
    }

    static func periodo(para plataforma: String, desde periodo: String) -> String? {
        if plataforma == "plataforma2", periodo == "quincena" { return "semana" }
        if plataforma != "plataforma2", periodo == "semana" { return "quincena" }
        return nil
    }
}

struct Campo: View {
    let titulo: String
    @Binding var valor: String
    var teclado: UIKeyboardType = .default
    var pista: String = ""

    var enfocarAlAbrir = false
    @FocusState private var enfocado: Bool
    @Environment(\.superficieDeTarjeta) private var superficie

    private var relleno: AnyShapeStyle {
        if superficie == Diseno.superficie {
            return AnyShapeStyle(Color(.tertiarySystemFill))
        }
        return AnyShapeStyle(.background.tertiary)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(titulo).font(.footnote).foregroundStyle(.secondary)
            TextField(pista, text: $valor)
                .keyboardType(teclado)
                .autocorrectionDisabled()
                .focused($enfocado)
                .padding(.horizontal, Diseno.hueco2)
                .padding(.vertical, 11)
                .background(relleno, in: .rect(cornerRadius: Diseno.radioCampo))
        }
        .task {
            guard enfocarAlAbrir else { return }

            try? await Task.sleep(for: .milliseconds(450))
            enfocado = true
        }
    }
}

#if canImport(UIKit)
extension View {

    func bajarTeclado() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                        to: nil, from: nil, for: nil)
    }
}

@MainActor
func bajarTeclado() {
    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                    to: nil, from: nil, for: nil)
}

struct SalidaDelTeclado: ViewModifier {
    func body(content: Content) -> some View {
        content
            .scrollDismissesKeyboard(.interactively)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()

                    Button { bajarTeclado() } label: {
                        Image(systemName: "checkmark")
                            .fontWeight(.semibold)
                    }
                    .accessibilityLabel("Cerrar el teclado")
                }
            }
    }
}

extension View {
    
    func salidaDelTeclado() -> some View { modifier(SalidaDelTeclado()) }
}
#endif

struct Tira<Contenido: View>: View {
    @ViewBuilder var contenido: Contenido
    @Environment(\.superficieDeTarjeta) private var superficie
    @Environment(\.tema) private var tema
    @Environment(\.dentroDeUnaLista) private var enLista

    var body: some View {
        HStack(spacing: 0) {
            contenido
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Diseno.hueco3)
        .background(Diseno.tarjetaConTema(superficie, tema, enLista: enLista),
                    in: .rect(cornerRadius: Diseno.radioTarjeta))
        .chocable(.caja(radio: Diseno.radioTarjeta))
    }
}

struct Cifra: View {
    let valor: String
    let pie: String
    var tinte: Color?
    var conBarra: Bool = true
    
    var tendencia: Tendencia?
    
    var piloto: Color?
    var latiendo: Bool = false

    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 4) {
                HStack(spacing: 5) {
                    if let piloto {
                        Circle().fill(piloto).frame(width: 7, height: 7)
                            .modifier(Latido(activo: latiendo))
                    }
                    Text(valor)
                        .font(.headline)
                        .monospacedDigit()          
                        .contentTransition(.numericText())
                        .foregroundStyle(tinte ?? .primary)
                }
                Text(pie)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                if let tendencia { FlechaTendencia(tendencia) }
            }
            .frame(maxWidth: .infinity)

            if conBarra {
                Divider().frame(height: tendencia == nil ? 26 : 40)
            }
        }
    }
}

struct Tendencia: Equatable {
    let porcentaje: Int
    let sube: Bool
    let contra: String

    init?(_ json: [String: Any]?) {
        guard let json,
              let porcentaje = json["porcentaje"] as? Int,
              let sube = json["sube"] as? Bool else { return nil }
        self.porcentaje = porcentaje
        self.sube = sube
        self.contra = json["contra"] as? String ?? ""
    }
}

struct FlechaTendencia: View {
    let t: Tendencia
    init(_ t: Tendencia) { self.t = t }

    var body: some View {
        Label("\(t.porcentaje)%", systemImage: t.sube ? "arrow.up.right" : "arrow.down.right")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(t.sube ? Diseno.verde : Diseno.rojo)
            
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background((t.sube ? Diseno.verde : Diseno.rojo).opacity(0.13), in: Capsule())
            .accessibilityLabel(
                "\(t.sube ? "sube" : "baja") un \(t.porcentaje) por ciento"
                + (t.contra.isEmpty ? "" : " respecto a \(t.contra)"))
    }
}

struct Latido: ViewModifier {
    let activo: Bool
    @Environment(\.accessibilityReduceMotion) private var menosMovimiento
    @State private var encendido = false

    func body(content: Content) -> some View {
        content
            .opacity(activo && encendido && !menosMovimiento ? 0.35 : 1)
            .animation(activo && !menosMovimiento
                       ? .easeInOut(duration: 0.9).repeatForever(autoreverses: true)
                       : .default, value: encendido)
            .onAppear { encendido = true }
    }
}

struct Vacio: View {
    let icono: String
    let titulo: String
    var detalle: String = ""

    var body: some View {
        VStack(spacing: Diseno.hueco2) {
            Image(systemName: icono)
                .font(.largeTitle)
                .fontWeight(.light)
                .foregroundStyle(.tertiary)
            Text(titulo)
                .font(.headline)
            if !detalle.isEmpty {
                Text(detalle)
                    .font(.subheadline)
                    
                    .foregroundStyle(.apoyo)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Diseno.hueco4)
    }
}

enum Formato {

    static func euros(_ valor: Double) -> String {
        
        if Privacidad.compartida.oculta { return Privacidad.tapada }
        return eurosALaVista(valor)
    }

    static func eurosALaVista(_ valor: Double) -> String {
        conMenos(valor.formatted(.currency(code: "EUR").locale(Locale(identifier: "es_ES"))))
    }

    static func conMenos(_ texto: String) -> String {
        texto.replacingOccurrences(of: "-", with: "\u{2212}")
    }

    static func tokens(_ n: Int, unidad: String = "tk") -> String {
        let cifra = Privacidad.compartida.oculta ? "•••" : numero(n)
        return unidad.isEmpty ? cifra : "\(cifra) \(unidad)"
    }

    static func dolares(_ valor: Double) -> String {
        if Privacidad.compartida.oculta { return "•••,•• $" }
        return eurosALaVista(valor).replacingOccurrences(of: "€", with: "$")
    }

    static func importe(_ texto: String) -> String {
        if Privacidad.compartida.oculta && !texto.isEmpty { return "•••" }

        return texto.replacingOccurrences(of: #"(\d)€"#, with: "$1\u{00A0}€", options: .regularExpression)
    }

    static func numero(_ valor: Int) -> String {
        valor.formatted(.number.locale(Locale(identifier: "es_ES")))
    }

    static func ajuste(_ valor: Any?) -> String {
        let n: Double
        switch valor {
        case let d as Double: n = d
        case let i as Int: n = Double(i)
        default: return ""
        }
        if n == 0 { return "" }
        if n == n.rounded() && abs(n) < 1e9 { return String(Int(n)) }
        
        let texto = String(format: "%g", n)

        return texto.replacingOccurrences(of: ".", with: ",")
    }

    static func duracion(_ horas: Double) -> String {
        let minutos = Int((abs(horas) * 60).rounded())
        let (h, m) = (minutos / 60, minutos % 60)
        if h > 0 && m > 0 { return "\(h) h \(m) min" }
        if h > 0 { return "\(h) h" }
        return "\(m) min"
    }

    static func diaCorto(_ iso: String) -> String {
        let p = iso.split(separator: "-")
        guard p.count == 3, let m = Int(p[1]), let d = Int(p[2]), (1...12).contains(m) else {
            return iso
        }
        let meses = ["enero", "febrero", "marzo", "abril", "mayo", "junio", "julio",
                     "agosto", "septiembre", "octubre", "noviembre", "diciembre"]
        return "\(d) de \(meses[m - 1])"
    }
}

enum Ciclos {
    static let todos: [(clave: String, nombre: String)] = [
        ("dia", "Todos los días"),
        ("semana", "Cada semana"),
        ("quincena", "Cada quincena"),
        ("mes", "Una vez al mes"),
        ("manual", "Cuando lo pido yo"),
    ]

    static func nombre(_ clave: String) -> String {
        todos.first { $0.clave == clave }?.nombre ?? clave
    }
}

extension View {

    func fondoDePantalla() -> some View {
        background(FondoDelTema().ignoresSafeArea())
    }
}

struct BotonEditar: View {
    @Binding var editando: Bool
    
    var hayCambios: Bool = true
    var trabajando: Bool = false
    
    let confirmar: () -> Void
    
    var cancelar: () -> Void = {}

    var body: some View {
        Button {
            if !editando {
                editando = true
            } else if hayCambios {
                confirmar()
            } else {
                editando = false
                cancelar()
            }
        } label: {
            if trabajando {
                ProgressView().controlSize(.small)
            } else if !editando {
                Text("Editar")
            } else if hayCambios {

                Image(systemName: "checkmark")
                    .fontWeight(.semibold)
                    .foregroundStyle(.acento)
                    .contentTransition(.symbolEffect(.replace))
            } else {
                Text("Cancelar")
            }
        }
        .disabled(trabajando)
        .sensoryFeedback(.success, trigger: editando)
        .accessibilityLabel(editando ? (hayCambios ? "Guardar" : "Cancelar") : "Editar")
    }
}

struct MarcaConfirmar: View {
    var trabajando: Bool = false

    var body: some View {
        Group {
            if trabajando {
                ProgressView().controlSize(.small)
            } else {
                Image(systemName: "checkmark")
                    .fontWeight(.semibold)
                    .foregroundStyle(.acento)
            }
        }
        .accessibilityLabel("Guardar")
    }
}

