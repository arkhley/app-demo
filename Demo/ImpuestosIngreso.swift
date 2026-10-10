import SwiftUI

struct HojaIngreso: View {
    
    let cobro: DatosImpuestos.Cobro?
    let contactos: [DatosImpuestos.Contacto]
    let alGuardar: () async -> Void

    @Environment(Sesion.self) private var sesion
    @Environment(\.dismiss) private var cerrar

    @State private var modo = "incluido"
    @State private var numero = ""
    @State private var facturaTexto = ""

    @State private var aceptada = false
    
    @State private var cliente = "pasarela"
    @State private var fecha = Date()
    @State private var importeTexto = ""
    @State private var concepto = ""

    @State private var trabajando = false
    @State private var aviso: String?
    @State private var preguntandoBorrar = false
    @ScaledMetric(relativeTo: .largeTitle) private var tamCifra: CGFloat = 42

    private var esNuevo: Bool { cobro == nil }
    
    private var editable: Bool { esNuevo || cobro?.manual == true }
    private var plataforma: String { cobro?.plataforma ?? "tienda" }
    private var esPlataforma1: Bool { plataforma == "plataforma1" }
    private var esPlataforma2: Bool { plataforma == "plataforma2" }
    private var esVenta: Bool { ["tienda", "pasarela"].contains(plataforma) }

    private var esPasarela: Bool { esVenta && ["", "pasarela"].contains(cobro?.cliente ?? "") }

    private var clientesDeVenta: [DatosImpuestos.Contacto] {
        contactos.filter { $0.esCliente && !["plataforma1", "plataforma2"].contains($0.id) }
    }
    private var clienteActual: DatosImpuestos.Contacto? {
        let id = editable ? cliente : (cobro?.cliente ?? "pasarela")
        return contactos.first { $0.id == id }
    }
    private var pct: Double { clienteActual?.ivaPct ?? cobro?.ivaPct ?? 21 }
    
    private var conIVA: Bool {
        guard esVenta else { return false }
        return (clienteActual?.ivaModo ?? cobro?.ivaModo ?? "sin") != "sin"
    }
    private var cobrado: Double {
        editable ? (CuentaIVA.numero(importeTexto) ?? 0) : (cobro?.euros ?? 0)
    }
    private var cuenta: (base: Double, iva: Double, total: Double) {
        CuentaIVA.aplicar(cobrado, pct: pct, modo: conIVA ? modo : "sin")
    }
    
    private var paraFactura: Double {
        esVenta ? cuenta.total : (cobro?.paraFactura ?? 0)
    }

    private var nombre: String {
        if esPlataforma1 { return "Plataforma 1" }
        if esPlataforma2 { return "Plataforma 2" }
        return clienteActual?.nombre ?? "Pasarela"
    }

    private var puedeGuardar: Bool {
        !trabajando && (!editable || cobrado > 0)
    }

    var body: some View {
        NavigationStack {
            Form {
                cabecera
                if editable { seccionVenta }
                if conIVA { seccionIVA }
                if esPlataforma1, let c = cobro { seccionConversion(c) }
                
                if !(aceptada && cobro?.facturaDeOtroDia == true) { seccionParaFactura }
                
                if esPlataforma1 || esPlataforma2 || esPasarela, let c = cobro,
                   c.facturaNumero.isEmpty {
                    SeccionBorradorAsesoria(cobro: c, alCrear: alGuardar)
                }
                seccionFactura
                if cobro?.manual == true {
                    Section {
                        Button("Borrar este ingreso", role: .destructive) {
                            preguntandoBorrar = true
                        }
                    }
                }
                if let aviso {
                    Text(aviso).foregroundStyle(Diseno.rojo).font(.footnote)
                }
            }
            .navigationTitle(esNuevo ? "Nuevo ingreso" : "Ingreso")
            .navigationBarTitleDisplayMode(.inline)
            .salidaDelTeclado()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { cerrar() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button { Task { await guardar() } } label: {
                        MarcaConfirmar(trabajando: trabajando)
                    }
                    .disabled(!puedeGuardar)
                }
            }
            .confirmationDialog("¿Borrar este ingreso?", isPresented: $preguntandoBorrar,
                                titleVisibility: .visible) {
                Button("Borrar", role: .destructive) { Task { await borrar() } }
                Button("Cancelar", role: .cancel) {}
            } message: {
                
                Text("Deja de contar en los impuestos, en la reserva y en los totales.")
            }
            .onAppear(perform: rellenar)
        }
        .presentationDetents([.large])
    }

    private var cabecera: some View {
        Section {
            VStack(alignment: .leading, spacing: Diseno.hueco1) {
                HStack(spacing: Diseno.hueco1) {
                    if Logo.hay(plataforma) {
                        Logo(plataforma: plataforma, alto: 16)
                    } else {
                        Text(nombre).font(.subheadline.weight(.semibold))
                    }
                    Spacer()
                    if let c = cobro {
                        Text(Formato.diaCorto(c.fecha))
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                }
                Text(Formato.euros(cobrado))
                    .font(.system(size: tamCifra, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                    .contentTransition(.numericText(value: cobrado))
                    .animation(.smooth(duration: 0.3), value: cobrado)
                Text(subtitulo)
                    .font(.caption).foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)
            .padding(.vertical, Diseno.hueco1)
        }
    }

    private var subtitulo: String {
        if esPlataforma1 { return "Llegó a tu Monedero · \(cobro?.etiqueta ?? "")" }
        if esPlataforma2 { return "Llegó a tu banco · \(cobro?.etiqueta ?? "")" }
        if esNuevo { return "Lo que te pagó el cliente" }
        return "Cobrado · \(cobro?.etiqueta ?? "")"
    }

    private var seccionVenta: some View {
        Section {
            Picker("Cliente", selection: $cliente) {
                ForEach(clientesDeVenta) { k in
                    Text(k.nombre).tag(k.id)
                }
            }
            .onChange(of: cliente) { _, nuevo in
                
                if let k = contactos.first(where: { $0.id == nuevo }), k.ivaModo != "sin" {
                    modo = k.ivaModo
                }
            }
            HStack {
                Text("Cobrado")
                Spacer()
                TextField("0,00", text: $importeTexto)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .monospacedDigit()
                Text("€").foregroundStyle(.secondary)
            }
            DatePicker("Día", selection: $fecha, in: ...Date(), displayedComponents: .date)
                .environment(\.locale, Locale(identifier: "es_ES"))
            TextField("Qué fue (opcional)", text: $concepto)
        }
    }

    private var seccionIVA: some View {
        Section {
            
            Picker("IVA", selection: $modo) {
                Text("IVA incluido").tag("incluido")
                Text("IVA encima").tag("encima")
            }
            .pickerStyle(.segmented)
            .sensoryFeedback(.selection, trigger: modo)
            BarraFactura(base: cuenta.base, iva: cuenta.iva)
                .padding(.vertical, Diseno.hueco1)
        } header: {
            Text("IVA \(Int(pct)) %")
        } footer: {
            
            if modo == "encima" {
                Text("La factura sale por \(Formato.euros(cuenta.total)): lo que cobraste más \(Formato.euros(cuenta.iva)) de IVA.")
            } else {
                Text("Los \(Formato.euros(cobrado)) ya llevan el IVA dentro: \(Formato.euros(cuenta.base)) + \(Formato.euros(cuenta.iva)).")
            }
        }
    }

    private func seccionConversion(_ c: DatosImpuestos.Cobro) -> some View {
        Section {
            HStack(spacing: Diseno.hueco2) {
                paso(CuentaIVA.dolares(c.usd), "en Monedero")
                Image(systemName: "divide")
                    .font(.caption.weight(.bold)).foregroundStyle(.tertiary)
                paso(String(format: "%.4f", c.cambio).replacingOccurrences(of: ".", with: ","),
                     "$ por €")
                Image(systemName: "equal")
                    .font(.caption.weight(.bold)).foregroundStyle(.tertiary)
                paso(Formato.euros(c.paraFactura), "para la factura", fuerte: true)
            }
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(CuentaIVA.dolares(c.usd)) entre \(c.cambio) igual a \(Formato.euros(c.paraFactura))")
            if c.facturaDeOtroDia, let f = c.facturaEuros {
                HStack {
                    Label {
                        Text("En tu factura").foregroundStyle(.primary)
                    } icon: {
                        Image(systemName: aceptada ? "doc.text.fill" : "exclamationmark.triangle.fill")
                            .foregroundStyle(aceptada ? Diseno.verde : Diseno.naranja)
                            .contentTransition(.symbolEffect(.replace))
                    }
                    Spacer()
                    Text(Formato.euros(f)).monospacedDigit().fontWeight(.semibold)
                }
                Toggle("Dejarla como está", isOn: $aceptada.animation(Diseno.suave))
                    .sensoryFeedback(.selection, trigger: aceptada)
            }
        } header: {
            Text(c.cambioDia.isEmpty ? "Cambio del BCE"
                                     : "Cambio del BCE del \(Formato.diaCorto(c.cambioDia))")
        } footer: {
            if c.facturaDeOtroDia, let f = c.facturaEuros {
                
                if aceptada {
                    Text("Los impuestos cuentan los \(Formato.euros(f)) de tu factura.")
                } else {
                    Text("Tu factura usa el cambio de otro día: cámbiala en la gestoría por \(Formato.euros(c.paraFactura)) o déjala como está.")
                }
            } else if c.cambioDia != c.fecha && !c.cambioDia.isEmpty {
                Text("Llegó el \(Formato.diaCorto(c.fecha)); el BCE no publica en fin de semana.")
            }
        }
    }

    private func paso(_ valor: String, _ pie: String, fuerte: Bool = false) -> some View {
        VStack(spacing: 2) {
            Text(valor)
                .font(fuerte ? .subheadline.weight(.semibold) : .subheadline)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(pie).font(.caption2).foregroundStyle(.secondary)
        }
    }

    private var seccionParaFactura: some View {
        Section {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Para tu factura").font(.subheadline).foregroundStyle(.secondary)
                    Text(Formato.euros(paraFactura))
                        .font(.system(.title2, design: .rounded).weight(.semibold))
                        .foregroundStyle(Diseno.azul)
                        .monospacedDigit()
                        .contentTransition(.numericText(value: paraFactura))
                        .animation(.smooth(duration: 0.3), value: paraFactura)
                }
                Spacer()
                BotonCopiar(valor: paraFactura)
                    .disabled(paraFactura <= 0)
            }
        } footer: {
            Text(piePara)
        }
    }

    private var piePara: String {
        if esPlataforma1 { return "Ponla tal cual en la gestoría y las cifras de la app y de tu gestoría serán las mismas." }
        if esPlataforma2 { return "Lo que llegó al banco: Plataforma 2 ya lo convierte." }
        return conIVA ? "El total de la factura simplificada, con el IVA." : "Sin IVA."
    }

    private var seccionFactura: some View {
        Section {
            HStack {
                Text("Número")
                Spacer()
                TextField(esVenta ? "PP2026/00004" : "F2026/00033", text: $numero)
                    .multilineTextAlignment(.trailing)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.characters)
                    .monospacedDigit()
            }
            if !esVenta {
                HStack {
                    Text("Importe")
                    Spacer()
                    TextField(CuentaIVA.paraPegar(paraFactura), text: $facturaTexto)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .monospacedDigit()
                    Text("€").foregroundStyle(.secondary)
                }
            }
        } header: {
            Text("Tu factura en la gestoría")
        } footer: {
            if esPlataforma1 {
                Text("La que pusiste en la gestoría. Si no es la de arriba, la app te avisa.")
            } else if esPlataforma2 {
                Text("Lo que pusiste en la gestoría. Si es otra cifra, los impuestos usan la tuya.")
            }
        }
    }

    private func rellenar() {
        guard let c = cobro else {
            let pasarela = contactos.first { $0.id == "pasarela" }
            cliente = "pasarela"
            modo = pasarela?.ivaModo == "encima" ? "encima" : "incluido"
            return
        }
        modo = c.ivaModo == "sin" ? "incluido" : c.ivaModo
        numero = c.facturaNumero
        aceptada = c.facturaAceptada
        if let f = c.facturaEuros, !esVenta { facturaTexto = CuentaIVA.paraPegar(f) }
        if c.manual {
            cliente = c.cliente.isEmpty ? "pasarela" : c.cliente
            importeTexto = CuentaIVA.paraPegar(c.euros)
            concepto = c.concepto
            fecha = Self.iso.date(from: c.fecha) ?? Date()
        }
    }

    private static let iso: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "Europe/Madrid")
        return f
    }()

    private func guardar() async {
        trabajando = true
        defer { trabajando = false }
        var cuerpo: [String: any Sendable] = ["numero": numero]
        if let c = cobro { cuerpo["id"] = c.id } else { cuerpo["nuevo"] = true }
        if conIVA { cuerpo["iva_modo"] = modo }
        if !esVenta { cuerpo["factura_euros"] = facturaTexto }
        if let c = cobro, esPlataforma1, aceptada != c.facturaAceptada { cuerpo["aceptada"] = aceptada }
        if editable {
            cuerpo["cliente"] = cliente
            cuerpo["fecha"] = Self.iso.string(from: fecha)
            cuerpo["importe"] = importeTexto
            cuerpo["concepto"] = concepto
            if !conIVA { cuerpo["iva_modo"] = "sin" }
        }
        do {
            _ = try await API.pedir("api/impuestos/ingreso", metodo: "POST", cuerpo: cuerpo,
                                    testigo: sesion.testigo)
            await alGuardar()
            cerrar()
        } catch {
            aviso = error.localizedDescription
        }
    }

    private func borrar() async {
        guard let c = cobro else { return }
        trabajando = true
        defer { trabajando = false }
        do {
            _ = try await API.pedir("api/impuestos/ingreso", metodo: "POST",
                                    cuerpo: ["id": c.id, "borrar": true],
                                    testigo: sesion.testigo)
            await alGuardar()
            cerrar()
        } catch {
            aviso = error.localizedDescription
        }
    }
}
