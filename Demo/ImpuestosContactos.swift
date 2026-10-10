import SwiftUI

struct PantallaContactos: View {
    let alCambiar: () async -> Void

    @Environment(Sesion.self) private var sesion
    @State private var contactos: [DatosImpuestos.Contacto] = []
    @State private var editando: DatosImpuestos.Contacto?
    @State private var nuevoTipo: String?
    @State private var aviso: String?
    @State private var borrando: DatosImpuestos.Contacto?

    var body: some View {
        List {
            if let aviso {
                Text(aviso).font(.footnote).foregroundStyle(Diseno.rojo)
            }
            Section("Clientes") {
                ForEach(contactos.filter(\.esCliente)) { k in fila(k) }
            }
            Section("Proveedores") {
                let lista = contactos.filter { !$0.esCliente }
                if lista.isEmpty {
                    Text("Ninguno").foregroundStyle(.secondary)
                }
                ForEach(lista) { k in fila(k) }
            }
        }
        .listStyle(.insetGrouped)
        .listaConTema()
        .navigationTitle("Clientes y proveedores")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Cliente", systemImage: "person.crop.circle.badge.plus") {
                        nuevoTipo = "cliente"
                    }
                    Button("Proveedor", systemImage: "shippingbox") { nuevoTipo = "proveedor" }
                } label: {
                    Label("Añadir", systemImage: "plus")
                }
            }
        }
        .task { await cargar() }
        .refreshable { await cargar() }
        .sheet(item: $editando) { k in
            HojaContacto(tipo: k.tipo, contacto: k) { _ in
                await cargar()
                await alCambiar()
            }
        }
        .sheet(isPresented: Binding(get: { nuevoTipo != nil }, set: { if !$0 { nuevoTipo = nil } })) {
            HojaContacto(tipo: nuevoTipo ?? "proveedor", contacto: nil) { _ in
                await cargar()
                await alCambiar()
            }
        }
        .confirmationDialog("¿Borrar \(borrando?.nombre ?? "")?",
                            isPresented: .init(get: { borrando != nil },
                                               set: { if !$0 { borrando = nil } }),
                            titleVisibility: .visible) {
            Button("Borrar", role: .destructive) {
                if let k = borrando { Task { await borrar(k) } }
                borrando = nil
            }
            Button("Cancelar", role: .cancel) { borrando = nil }
        } message: {
            
            Text("Los gastos que ya tiene apuntados se quedan como están.")
        }
    }

    @ViewBuilder
    private func fila(_ k: DatosImpuestos.Contacto) -> some View {

        if k.fijo && k.id != "pasarela" {
            contenido(k, bloqueado: true)
        } else {
            Button { editando = k } label: { contenido(k, bloqueado: false) }
                .buttonStyle(.plain)
                .swipeActions(allowsFullSwipe: false) {
                    if !k.fijo {
                        Button("Borrar", systemImage: "trash", role: .destructive) {
                            borrando = k
                        }
                    }
                }
        }
    }

    private func contenido(_ k: DatosImpuestos.Contacto, bloqueado: Bool) -> some View {
        HStack(spacing: Diseno.hueco2) {
            FichaIcono(simbolo: icono(k), color: color(k))
            VStack(alignment: .leading, spacing: 2) {
                Text(k.nombre).foregroundStyle(.primary)
                Text(k.resumen).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: bloqueado ? "lock.fill" : "chevron.right")
                .font(bloqueado ? .caption : .footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
                .accessibilityLabel(bloqueado ? "Fijo" : "")
        }
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
    }

    private func icono(_ k: DatosImpuestos.Contacto) -> String {
        if k.esCliente { return k.ivaModo == "sin" ? "globe.europe.africa.fill" : "person.fill" }
        return k.documento == "ticket" ? "receipt.fill" : "doc.text.fill"
    }

    private func color(_ k: DatosImpuestos.Contacto) -> Color {
        let conIVA = k.esCliente ? k.ivaModo != "sin" : (k.ivaPct > 0 && k.documento == "factura")
        return conIVA ? .orange : .gray
    }

    private func cargar() async {
        do {
            let j = try await API.pedir("api/impuestos/contactos", testigo: sesion.testigo)
            contactos = ((j["contactos"] as? [[String: Any]]) ?? []).map(DatosImpuestos.Contacto.init)
            aviso = nil
        } catch {
            aviso = error.localizedDescription
        }
    }

    private func borrar(_ k: DatosImpuestos.Contacto) async {
        do {
            _ = try await API.pedir("api/impuestos/contacto", metodo: "POST",
                                    cuerpo: ["id": k.id, "borrar": true], testigo: sesion.testigo)
            await cargar()
            await alCambiar()
        } catch {
            aviso = error.localizedDescription
        }
    }
}

struct HojaContacto: View {
    let tipo: String
    let contacto: DatosImpuestos.Contacto?
    let alGuardar: (String) async -> Void

    @Environment(Sesion.self) private var sesion
    @Environment(\.dismiss) private var cerrar
    @State private var nombre = ""
    @State private var modo = "incluido"          
    @State private var pct = 21
    @State private var documento = "factura"      
    @State private var trabajando = false
    @State private var aviso: String?

    private var esCliente: Bool { tipo == "cliente" }
    private var esPasarela: Bool { contacto?.id == "pasarela" }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(esCliente ? "Nombre del cliente" : "Nombre del proveedor",
                              text: $nombre)
                        .disabled(contacto?.fijo == true)
                }
                if esCliente {
                    Section {
                        Picker("IVA", selection: $modo) {
                            if !esPasarela { Text("Sin IVA").tag("sin") }
                            Text("Incluido").tag("incluido")
                            Text("Encima").tag("encima")
                        }
                        .pickerStyle(.segmented)
                        if modo != "sin" && !esPasarela {
                            Picker("Tipo", selection: $pct) {
                                Text("21 %").tag(21)
                                Text("10 %").tag(10)
                                Text("4 %").tag(4)
                            }
                            .pickerStyle(.segmented)
                        }
                    } header: {
                        Text("IVA de sus ventas")
                    } footer: {
                        Text(pieCliente)
                    }
                } else {
                    Section {
                        Picker("Documento", selection: $documento) {
                            Text("Factura").tag("factura")
                            Text("Ticket").tag("ticket")
                        }
                        .pickerStyle(.segmented)
                        Picker("IVA", selection: $pct) {
                            Text("21 %").tag(21)
                            Text("10 %").tag(10)
                            Text("4 %").tag(4)
                            Text("Exento").tag(0)
                        }
                        .pickerStyle(.segmented)
                    } header: {
                        Text("Lo de siempre")
                    } footer: {
                        Text(documento == "ticket"
                             ? "Con ticket el IVA no se descuenta. En cada gasto se puede cambiar."
                             : "En cada gasto se puede cambiar.")
                    }
                }
                if let aviso {
                    Text(aviso).foregroundStyle(Diseno.rojo).font(.footnote)
                }
            }
            .navigationTitle(contacto == nil ? (esCliente ? "Nuevo cliente" : "Nuevo proveedor")
                                             : (contacto?.nombre ?? ""))
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
                    .disabled(trabajando || nombre.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                guard let k = contacto else { return }
                nombre = k.nombre
                modo = k.ivaModo
                pct = k.ivaPct > 0 ? Int(k.ivaPct) : (k.esCliente ? 21 : 0)
                documento = k.documento
            }
        }
    }

    private var pieCliente: String {
        switch modo {
        case "encima": return "Lo que te paguen es la base; la factura suma el IVA."
        case "incluido": return "Lo que te paguen ya lleva el IVA dentro."
        default: return "Sus ventas no llevan IVA."
        }
    }

    private func guardar() async {
        trabajando = true
        defer { trabajando = false }
        var cuerpo: [String: any Sendable] = ["tipo": tipo, "nombre": nombre, "iva_pct": pct]
        if let k = contacto { cuerpo["id"] = k.id }
        if esCliente {
            cuerpo["iva_modo"] = modo
            if modo == "sin" { cuerpo["iva_pct"] = 0 }
        } else {
            cuerpo["documento"] = documento
        }
        do {
            _ = try await API.pedir("api/impuestos/contacto", metodo: "POST", cuerpo: cuerpo,
                                    testigo: sesion.testigo)
            await alGuardar(nombre.trimmingCharacters(in: .whitespaces))
            cerrar()
        } catch {
            aviso = error.localizedDescription
        }
    }
}
