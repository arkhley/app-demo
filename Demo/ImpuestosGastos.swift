import SwiftUI

struct PantallaGastos: View {
    let trimestre: String
    let alCambiar: () async -> Void

    @Environment(Sesion.self) private var sesion
    @State private var todos: [[String: Any]] = []
    @State private var cargado = false
    @State private var editando: [String: Any]?
    @State private var nuevo = false
    @State private var aviso: String?

    @State private var borrando: [String: Any]?

    var body: some View {
        List {
            if let aviso {
                Text(aviso).font(.footnote).foregroundStyle(Diseno.rojo)
            }
            if !cargado && aviso == nil {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
            } else if cargado && todos.isEmpty {
                Vacio(icono: "cart", titulo: "Sin gastos",
                      detalle: "La cuota de autónomo ya cuenta sola.")
                    .listRowBackground(Color.clear)
            }
            ForEach(grupos, id: \.mes) { g in
                Section(DatosImpuestos.mes(g.mes).capitalized + " " + g.mes.prefix(4)) {

                    ForEach(g.gastos, id: \.idGasto) { gasto in
                        Button { editando = gasto } label: { FilaGasto(g: gasto) }
                            .buttonStyle(.plain)
                            
                            .swipeActions(allowsFullSwipe: false) {
                                Button("Borrar", systemImage: "trash", role: .destructive) {
                                    borrando = gasto
                                }
                            }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .listaConTema()
        .navigationTitle("Gastos")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Añadir gasto", systemImage: "plus") { nuevo = true }
            }
        }
        .task { await cargar() }
        .refreshable { await cargar() }
        .sheet(isPresented: $nuevo) {
            HojaGasto(gasto: nil) { await cargar(); await alCambiar() }
        }
        .sheet(isPresented: Binding(get: { editando != nil }, set: { if !$0 { editando = nil } })) {
            HojaGasto(gasto: editando) { await cargar(); await alCambiar() }
        }
        .confirmationDialog("¿Borrar este gasto?",
                            isPresented: .init(get: { borrando != nil },
                                               set: { if !$0 { borrando = nil } }),
                            titleVisibility: .visible) {
            Button("Borrar", role: .destructive) {
                if let g = borrando { Task { await borrar(g) } }
                borrando = nil
            }
            Button("Cancelar", role: .cancel) { borrando = nil }
        } message: {
            
            if borrando?["mensual"] as? Bool ?? false {
                Text("Es de cada mes: se borra de todos los meses y cambian los impuestos de cada trimestre.")
            } else {
                Text("Cambian los impuestos de su trimestre.")
            }
        }
    }

    private var grupos: [(mes: String, gastos: [[String: Any]])] {
        let porMes = Dictionary(grouping: todos) { String(($0["fecha"] as? String ?? "").prefix(7)) }
        return porMes.keys.sorted(by: >).map { (mes: $0, gastos: porMes[$0] ?? []) }
    }

    private func cargar() async {
        do {
            let j = try await API.pedir("api/impuestos/gastos", testigo: sesion.testigo)
            todos = j["gastos"] as? [[String: Any]] ?? []
            cargado = true
            aviso = nil
        } catch {
            aviso = error.localizedDescription
        }
    }

    private func borrar(_ g: [String: Any]) async {
        do {
            _ = try await API.pedir("api/impuestos/gasto", metodo: "POST",
                                    cuerpo: ["id": g["id"] as? String ?? "", "borrar": true],
                                    testigo: sesion.testigo)
            await cargar()
            await alCambiar()
        } catch {
            aviso = error.localizedDescription
        }
    }
}

private extension Dictionary where Key == String, Value == Any {
    
    var idGasto: String { self["id"] as? String ?? "" }
}

private struct FilaGasto: View {
    let g: [String: Any]

    var body: some View {
        let total = (g["total"] as? NSNumber)?.doubleValue ?? 0
        let iva = (g["iva_pct"] as? NSNumber)?.doubleValue ?? 0
        let ticket = (g["documento"] as? String) == "ticket"
        let proveedor = g["proveedor_nombre"] as? String ?? ""
        let concepto = g["concepto"] as? String ?? ""
        HStack(spacing: Diseno.hueco2) {
            VStack(alignment: .leading, spacing: 3) {
                Text(proveedor.isEmpty ? concepto : proveedor)
                HStack(spacing: 6) {
                    Text(Formato.diaCorto(g["fecha"] as? String ?? ""))
                    if g["mensual"] as? Bool ?? false {
                        Image(systemName: "repeat").accessibilityLabel("cada mes")
                    }
                    
                    Text(ticket ? "Ticket" : iva > 0 ? "Factura · IVA \(Int(iva)) %" : "Factura · sin IVA")
                }
                .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Text(Formato.euros(total)).monospacedDigit()
        }
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
    }
}

struct HojaGasto: View {
    let gasto: [String: Any]?
    let alGuardar: () async -> Void

    @Environment(Sesion.self) private var sesion
    @Environment(\.dismiss) private var cerrar
    @State private var contactos: [DatosImpuestos.Contacto] = []
    @State private var proveedor = ""
    @State private var documento = "factura"
    @State private var iva = 21
    @State private var concepto = ""
    @State private var total = ""
    @State private var fecha = Date()
    @State private var mensual = false
    @State private var nuevoProveedor = false
    @State private var trabajando = false
    @State private var aviso: String?

    private var proveedores: [DatosImpuestos.Contacto] {
        contactos.filter { !$0.esCliente }
    }
    private var elegido: DatosImpuestos.Contacto? {
        proveedores.first { $0.id == proveedor }
    }
    private var importe: Double { CuentaIVA.numero(total) ?? 0 }
    
    private var cuenta: (base: Double, iva: Double, total: Double) {
        CuentaIVA.aplicar(importe, pct: Double(iva), modo: documento == "ticket" ? "sin" : "incluido")
    }
    
    private var puedeGuardar: Bool {
        !trabajando && importe != 0
            && !(concepto.trimmingCharacters(in: .whitespaces).isEmpty && elegido == nil)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    selectorProveedor
                    HStack {
                        Text("Pagado")
                        Spacer()
                        TextField("0,00", text: $total)
                            .keyboardType(.numbersAndPunctuation)   
                            .multilineTextAlignment(.trailing)
                            .monospacedDigit()
                        Text("€").foregroundStyle(.secondary)
                    }
                    DatePicker("Día", selection: $fecha, displayedComponents: .date)
                        .environment(\.locale, Locale(identifier: "es_ES"))
                    TextField(elegido?.nombre ?? "Qué es", text: $concepto)
                }

                Section {
                    Picker("Documento", selection: $documento) {
                        Text("Factura").tag("factura")
                        Text("Ticket").tag("ticket")
                    }
                    .pickerStyle(.segmented)
                    if documento == "factura" {
                        Picker("IVA", selection: $iva) {
                            Text("21 %").tag(21)
                            Text("10 %").tag(10)
                            Text("4 %").tag(4)
                            Text("Exento").tag(0)
                        }
                        .pickerStyle(.segmented)
                    }
                    if importe > 0 {           
                        BarraFactura(base: cuenta.base, iva: cuenta.iva,
                                     nombreBase: "Gasto", nombreIVA: "IVA a descontar")
                            .padding(.vertical, Diseno.hueco1)
                    }
                } footer: {
                    
                    if documento == "ticket" {
                        Text("Con ticket el IVA no se descuenta: todo cuenta como gasto.")
                    } else if iva == 0 {
                        Text("Sin IVA: todo cuenta como gasto.")
                    } else {
                        Text("La base baja el 130 y el IVA baja el 303.")
                    }
                }
                .animation(.smooth(duration: 0.25), value: documento)

                Section {
                    Toggle("Cada mes", isOn: $mensual)
                } footer: {
                    if mensual { Text("Se repite el mismo día de cada mes desde esta fecha.") }
                }
                if let aviso {
                    Text(aviso).foregroundStyle(Diseno.rojo).font(.footnote)
                }
            }
            .navigationTitle(gasto == nil ? "Nuevo gasto" : "Gasto")
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
            .sheet(isPresented: $nuevoProveedor) {
                HojaContacto(tipo: "proveedor", contacto: nil) { nombre in
                    await cargarContactos()
                    if let k = proveedores.first(where: { $0.nombre == nombre }) { elegir(k) }
                }
            }
            .task {
                rellenar()
                await cargarContactos()
            }
        }
    }

    private var selectorProveedor: some View {
        Menu {
            Picker("Proveedor", selection: Binding(get: { proveedor }, set: { id in
                if let k = proveedores.first(where: { $0.id == id }) { elegir(k) } else { proveedor = "" }
            })) {
                Text("Ninguno").tag("")
                ForEach(proveedores) { k in
                    Text(k.nombre).tag(k.id)
                }
            }
            Divider()
            Button("Nuevo proveedor", systemImage: "plus") { nuevoProveedor = true }
        } label: {
            HStack {
                Text("Proveedor").foregroundStyle(.primary)
                Spacer()
                VStack(alignment: .trailing, spacing: 1) {
                    Text(elegido?.nombre ?? "Ninguno").foregroundStyle(.secondary)
                    if let k = elegido {
                        Text(k.resumen).font(.caption2).foregroundStyle(.secondary)
                    }
                }
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption.weight(.semibold)).foregroundStyle(.tertiary)
            }
            .contentShape(.rect)
        }
    }

    private func elegir(_ k: DatosImpuestos.Contacto) {
        proveedor = k.id
        withAnimation(.smooth(duration: 0.25)) {
            iva = Int(k.ivaPct)
            documento = k.documento
        }
    }

    private func rellenar() {
        guard let g = gasto else { return }
        concepto = g["concepto"] as? String ?? ""
        proveedor = g["proveedor"] as? String ?? ""
        if let t = (g["total"] as? NSNumber)?.doubleValue { total = CuentaIVA.paraPegar(t) }
        iva = Int((g["iva_pct"] as? NSNumber)?.doubleValue ?? 21)
        documento = (g["documento"] as? String) == "ticket" || (g["sin_factura"] as? Bool ?? false)
            ? "ticket" : "factura"
        mensual = g["mensual"] as? Bool ?? false
        if let f = g["fecha"] as? String, let d = Self.iso.date(from: f) { fecha = d }
        
        if concepto == (g["proveedor_nombre"] as? String) { concepto = "" }
    }

    private static let iso: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "Europe/Madrid")
        return f
    }()

    private func cargarContactos() async {
        if let j = try? await API.pedir("api/impuestos/contactos", testigo: sesion.testigo) {
            contactos = ((j["contactos"] as? [[String: Any]]) ?? []).map(DatosImpuestos.Contacto.init)
        }
    }

    private func guardar() async {
        trabajando = true
        defer { trabajando = false }
        var cuerpo: [String: any Sendable] = [
            "concepto": concepto, "total": total,
            "iva_pct": documento == "ticket" ? 0 : iva, "documento": documento,
            "proveedor": proveedor, "fecha": Self.iso.string(from: fecha), "mensual": mensual,
        ]
        if let id = gasto?["id"] as? String { cuerpo["id"] = id }
        do {
            _ = try await API.pedir("api/impuestos/gasto", metodo: "POST", cuerpo: cuerpo,
                                    testigo: sesion.testigo)
            await alGuardar()
            cerrar()
        } catch {
            aviso = error.localizedDescription
        }
    }
}
