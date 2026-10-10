import SwiftUI
import CoreImage.CIFilterBuiltins
#if canImport(UIKit)
import UIKit
#endif

struct HojaTokens: View {
    @Environment(Sesion.self) private var sesion
    @Environment(\.dismiss) private var cerrar

    enum Sentido: String { case tokens, euros }

    @State private var sentido: Sentido = .tokens
    @State private var plataforma = "plataforma1"
    @State private var texto = ""
    @State private var cambio: [String: [String: Double]] = [:]
    @State private var fallo: String?
    @FocusState private var escribiendo: Bool

    private var euroPorToken: Double {
        let c = cambio[plataforma] ?? [:]
        return (c["usd_por_token"] ?? 0) * (c["eur_por_usd"] ?? 0)
    }

    private var numero: Double { min(max(CuentaIVA.numero(texto) ?? 0, 0), 999_999_999) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Qué escribes", selection: $sentido) {
                        Text("Tokens → euros").tag(Sentido.tokens)
                        Text("Euros → tokens").tag(Sentido.euros)
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                }
                Section {
                    resultado
                }
                Section {
                    TextField(sentido == .tokens ? "Tokens" : "Euros que quieres que te lleguen",
                              text: $texto)
                        .keyboardType(sentido == .tokens ? .numberPad : .decimalPad)
                        .font(.system(.title2, design: .rounded).weight(.semibold))
                        .monospacedDigit()
                        .focused($escribiendo)
                    Picker("Plataforma", selection: $plataforma) {
                        Text("Plataforma 1").tag("plataforma1")
                        Text("Plataforma 2").tag("plataforma2")
                    }
                } footer: {
                    Text(pie)
                }
                if let fallo {
                    Section { Text(fallo).foregroundStyle(Diseno.rojo) }
                }
            }
            .navigationTitle("Tokens y euros")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .close) { cerrar() }
                }
            }
            .onChange(of: sentido) { _, _ in texto = "" }
        }
        
        .hojaDeHerramienta(opacaSi: escribiendo)
        .task { await cargar() }
        .onAppear { escribiendo = true }
    }

    @ViewBuilder
    private var resultado: some View {
        let por = euroPorToken
        VStack(alignment: .leading, spacing: 4) {
            if numero <= 0 || por <= 0 {
                Text(sentido == .tokens ? "— €" : "— tokens")
                    .font(.system(.largeTitle, design: .rounded).weight(.bold))
                    .foregroundStyle(Diseno.apoyoEnCristal)
                Text(sentido == .tokens ? "Escribe los tokens" : "Escribe los euros")
                    .font(.subheadline).foregroundStyle(Diseno.apoyoEnCristal)
            } else if sentido == .tokens {
                Text("≈ " + Formato.eurosALaVista(numero * por))
                    .font(.system(.largeTitle, design: .rounded).weight(.bold))
                    .monospacedDigit()
                    .contentTransition(.numericText(value: numero * por))
                Text("te llegan por \(Formato.numero(Int(numero))) tokens")
                    .font(.subheadline).foregroundStyle(Diseno.apoyoEnCristal)
            } else {
                let tokens = Int((numero / por).rounded(.up))
                Text("\(Formato.numero(tokens)) tokens")
                    .font(.system(.largeTitle, design: .rounded).weight(.bold))
                    .monospacedDigit()
                    .contentTransition(.numericText(value: Double(tokens)))
                Text("para que te lleguen \(Formato.eurosALaVista(numero))")
                    .font(.subheadline).foregroundStyle(Diseno.apoyoEnCristal)
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private var pie: String {
        let c = cambio[plataforma] ?? [:]
        let porDolar = String(format: "%.4f", c["eur_por_usd"] ?? 0).replacingOccurrences(of: ".", with: ",")
        if plataforma == "plataforma1" {
            let comision = Formato.eurosALaVista(c["comision_cobro_usd"] ?? 0).replacingOccurrences(of: "€", with: "$")
            return "A 0,05 $ el token y \(porDolar) € el dólar, el cambio de hoy con lo que se queda Monedero. "
                + "Cada cobro se lleva además \(comision)."
        }
        return "A 0,05 $ el token y \(porDolar) € el dólar, el cambio de hoy por SEPA."
    }

    private func cargar() async {
        do {
            let j = try await API.pedir("api/herramientas/cambio", testigo: sesion.testigo)
            var c: [String: [String: Double]] = [:]
            for p in ["plataforma1", "plataforma2"] {
                let d = (j[p] as? [String: Any]) ?? [:]
                c[p] = d.compactMapValues { ($0 as? NSNumber)?.doubleValue }
            }
            cambio = c
        } catch is CancellationError {
        } catch {
            fallo = error.localizedDescription
        }
    }
}

struct HojaAdelanto: View {
    @Environment(Sesion.self) private var sesion
    @Environment(\.dismiss) private var cerrar

    @State private var datos: [String: Any]?
    @State private var fallo: String?

    private func n(_ v: Any?) -> Double { (v as? NSNumber)?.doubleValue ?? 0 }

    private func tarifa(_ v: Double) -> String {
        Formato.eurosALaVista(v).replacingOccurrences(of: "€", with: "$")
    }

    var body: some View {
        NavigationStack {
            Form {
                if let d = datos {
                    contenido(d)
                } else if let fallo {
                    Section { Text(fallo).foregroundStyle(Diseno.rojo) }
                } else {
                    Section { ProgressView().frame(maxWidth: .infinity) }
                }
            }
            .navigationTitle("Adelanto de Plataforma 1")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .close) { cerrar() }
                }
            }
        }
        .hojaDeHerramienta()
        .task { await cargar() }
    }

    @ViewBuilder
    private func contenido(_ d: [String: Any]) -> some View {
        let usd = n(d["usd"])
        let hoy = d["hoy"] as? [String: Any] ?? [:]
        let cierre = d["cierre"] as? [String: Any] ?? [:]
        Section {
            VStack(alignment: .leading, spacing: 4) {
                Text(CuentaIVA.dolares(usd))
                    .font(.system(.largeTitle, design: .rounded).weight(.bold))
                    .monospacedDigit()
                Text(usd > 0 ? "sin cobrar de esta quincena · \(Formato.tokens(Int(n(d["tokens"])), unidad: "tokens"))"
                             : "No queda nada sin cobrar de esta quincena.")
                    .font(.subheadline).foregroundStyle(Diseno.apoyoEnCristal)
            }
            .accessibilityElement(children: .combine)
        }
        if usd > 0 {
            Section {
                fila("Pídelo hoy", hoy, coste: n(hoy["coste_usd"]))
                fila("Espera al cierre", cierre, coste: n(cierre["coste_usd"]))
            } footer: {

                Text("Si lo adelantas, lo que ganes después llega aparte al cierre y se lleva otros "
                     + "\(tarifa(n(d["aparte_usd"]))).")
            }
            if usd < n(d["minimo_usd"]) {
                Section {
                    Label("Por debajo de \(tarifa(n(d["minimo_usd"]))) Plataforma 1 no paga la quincena: se junta con la siguiente.",
                          systemImage: "exclamationmark.circle")
                        .font(.footnote)
                }
            }
        }
    }

    private func fila(_ titulo: String, _ x: [String: Any], coste: Double) -> some View {
        let fecha = x["fecha"] as? String ?? ""
        return HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(titulo)
                
                Text("llega el \(Fechas.diaDeLaSemana(fecha).prefix(3)) \(Fechas.corta(fecha)) · "
                     + "se quedan \(tarifa(coste))")
                    .font(.footnote).foregroundStyle(Diseno.apoyoEnCristal)
            }
            Spacer(minLength: Diseno.hueco1)
            Text(Formato.euros(n(x["euros"])))
                .font(.system(.headline, design: .rounded))
                .monospacedDigit()
        }
        .accessibilityElement(children: .combine)
    }

    private func cargar() async {
        do {
            datos = try await API.pedir("api/herramientas/adelanto", testigo: sesion.testigo)
        } catch is CancellationError {
        } catch {
            fallo = error.localizedDescription
        }
    }
}

struct HojaEnlaces: View {
    @Environment(Sesion.self) private var sesion
    @Environment(\.dismiss) private var cerrar

    struct Enlace: Identifiable, Equatable {
        let id: String
        let nombre: String
        let detalle: String
        let url: URL
    }

    @State private var enlaces: [Enlace] = []
    @State private var fallo: String?
    @State private var qr: Enlace?

    var body: some View {
        NavigationStack {
            Form {
                if enlaces.isEmpty && fallo == nil {
                    Section { ProgressView().frame(maxWidth: .infinity) }
                }
                if !enlaces.isEmpty {
                    Section {
                        ForEach(enlaces) { e in fila(e) }
                    }
                }
                if let fallo {
                    Section { Text(fallo).foregroundStyle(Diseno.rojo) }
                }
            }
            .navigationTitle("Tus enlaces")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .close) { cerrar() }
                }
            }
            .sheet(item: $qr) { e in HojaQR(enlace: e) }
        }
        .hojaDeHerramienta()
        .task { await cargar() }
    }

    private func fila(_ e: Enlace) -> some View {
        HStack(spacing: Diseno.hueco2) {
            VStack(alignment: .leading, spacing: 2) {
                Text(e.nombre)
                Text(e.detalle.isEmpty ? Self.corta(e.url) : e.detalle)
                    .font(.footnote).foregroundStyle(Diseno.apoyoEnCristal)
                    .lineLimit(1)
            }
            Spacer(minLength: Diseno.hueco1)
            Button { qr = e } label: {
                Image(systemName: "qrcode")
                    .frame(width: 44, height: 44)
                    .contentShape(.rect)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Código QR de \(e.nombre)")
            ShareLink(item: e.url) {
                Image(systemName: "square.and.arrow.up")
                    .frame(width: 44, height: 44)
                    .contentShape(.rect)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Compartir \(e.nombre)")
        }
    }

    static func corta(_ url: URL) -> String {
        url.absoluteString.replacingOccurrences(of: "https://", with: "")
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }

    private func cargar() async {
        do {
            let j = try await API.pedir("api/herramientas/enlaces", testigo: sesion.testigo)
            enlaces = ((j["enlaces"] as? [[String: Any]]) ?? []).compactMap { x in
                guard let s = x["url"] as? String, let u = URL(string: s) else { return nil }
                return Enlace(id: x["clave"] as? String ?? s, nombre: x["nombre"] as? String ?? s,
                              detalle: x["detalle"] as? String ?? "", url: u)
            }
            if enlaces.isEmpty { fallo = "No hay enlaces que enseñar." }
        } catch is CancellationError {
        } catch {
            fallo = error.localizedDescription
        }
    }
}

struct HojaQR: View {
    let enlace: HojaEnlaces.Enlace
    @Environment(\.dismiss) private var cerrar

    var body: some View {
        NavigationStack {
            VStack(spacing: Diseno.hueco3) {
                if let imagen = Self.codigo(enlace.url.absoluteString) {
                    Image(decorative: imagen, scale: 1)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .padding(Diseno.hueco3)
                        .background(.white, in: .rect(cornerRadius: Diseno.radioTarjeta))
                        .frame(maxWidth: 280)
                        .accessibilityLabel("Código QR de \(enlace.nombre)")
                }
                VStack(spacing: 2) {
                    Text(enlace.nombre).font(.headline)
                    Text(HojaEnlaces.corta(enlace.url))
                        .font(.footnote).foregroundStyle(Diseno.apoyoEnCristal)
                        .textSelection(.enabled)
                }
            }
            .padding(Diseno.margen)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .close) { cerrar() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    static func codigo(_ texto: String) -> CGImage? {
        let filtro = CIFilter.qrCodeGenerator()
        filtro.message = Data(texto.utf8)
        filtro.correctionLevel = "M"
        guard let salida = filtro.outputImage?.transformed(by: CGAffineTransform(scaleX: 12, y: 12))
        else { return nil }
        return CIContext().createCGImage(salida, from: salida.extent)
    }
}

struct HojaComprobar: View {
    @Environment(Sesion.self) private var sesion
    @Environment(\.dismiss) private var cerrar

    struct Punto: Identifiable {
        let id: String
        let titulo: String
        let ok: Bool
        let detalle: String
    }

    @State private var puntos: [Punto] = []
    @State private var cuando = ""
    @State private var comprobando = false
    @State private var fallo: String?
    @State private var resultado: Bool?

    private var fallan: Int { puntos.filter { !$0.ok }.count }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    veredicto
                }
                if !puntos.isEmpty {
                    Section {
                        ForEach(puntos) { p in
                            LabeledContent {
                                Text(p.detalle).monospacedDigit()
                            } label: {
                                Label {
                                    Text(p.titulo)
                                } icon: {
                                    Image(systemName: p.ok ? "checkmark.circle.fill" : "xmark.circle.fill")
                                        .foregroundStyle(.white, p.ok ? Diseno.verdeRelleno : Diseno.rojoRelleno)
                                }
                            }
                            .accessibilityElement(children: .combine)
                        }
                    } footer: {
                        if fallan > 0 {
                            
                            Text("Si algo sigue fallando, apúntalo en «Logs y errores» y lo miro.")
                        }
                    }
                }
                if let fallo {
                    Section { Text(fallo).foregroundStyle(Diseno.rojo) }
                }
                Section {
                    Button {
                        Task { await comprobar() }
                    } label: {
                        Label("Comprobar otra vez", systemImage: "arrow.clockwise")
                    }
                    .disabled(comprobando)
                }
            }
            .navigationTitle("Comprobar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .close) { cerrar() }
                }
            }
        }
        .hojaDeHerramienta()
        .task { await comprobar() }
        .sensoryFeedback(trigger: resultado) { _, nuevo in
            guard let nuevo else { return nil }
            return nuevo ? .success : .warning
        }
    }

    @ViewBuilder
    private var veredicto: some View {
        HStack(spacing: Diseno.hueco2) {
            if comprobando && puntos.isEmpty {
                ProgressView()
                Text("Comprobando…").foregroundStyle(Diseno.apoyoEnCristal)
            } else if !puntos.isEmpty {
                Image(systemName: fallan == 0 ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                    .font(.system(size: 36, weight: .semibold))
                    .foregroundStyle(fallan == 0 ? Diseno.verdeRelleno : Diseno.naranjaRelleno)
                    .contentTransition(.symbolEffect(.replace))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(fallan == 0 ? "Todo funciona"
                         : fallan == 1 ? "1 cosa falla" : "\(fallan) cosas fallan")
                        .font(.title3.weight(.bold))
                    if !cuando.isEmpty {
                        Text("Comprobado a las \(cuando)")
                            .font(.footnote).foregroundStyle(Diseno.apoyoEnCristal)
                    }
                }
            }
        }
        .frame(minHeight: 44)
        .accessibilityElement(children: .combine)
    }

    private func comprobar() async {
        comprobando = true
        defer { comprobando = false }
        fallo = nil
        do {
            let j = try await API.pedir("api/herramientas/sistema", testigo: sesion.testigo)
            puntos = ((j["puntos"] as? [[String: Any]]) ?? []).map {
                Punto(id: $0["clave"] as? String ?? UUID().uuidString,
                      titulo: $0["titulo"] as? String ?? "",
                      ok: $0["ok"] as? Bool ?? false,
                      detalle: $0["detalle"] as? String ?? "")
            }
            let c = j["cuando"] as? String ?? ""
            cuando = c.count >= 16 ? String(c.dropFirst(11).prefix(5)) : ""
            resultado = nil
            resultado = fallan == 0
        } catch is CancellationError {
        } catch {
            fallo = error.localizedDescription
        }
    }
}

extension View {

    func hojaDeHerramienta(opacaSi forzada: Bool = false) -> some View {
        modifier(HojaDeHerramienta(forzada: forzada))
    }
}

private struct HojaDeHerramienta: ViewModifier {
    let forzada: Bool
    @Environment(\.accessibilityReduceTransparency) private var menosTransparencia
    @State private var altura: PresentationDetent = .medium

    func body(content: Content) -> some View {
        let opaca = forzada || altura == .large || menosTransparencia
        content
            .scrollContentBackground(opaca ? .visible : .hidden)
            .presentationDetents([.medium, .large], selection: $altura)
    }
}
