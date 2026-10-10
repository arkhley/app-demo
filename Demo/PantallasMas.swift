import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct PantallaCodigos: View {
    @Environment(Sesion.self) private var sesion
    @State private var descuentos: [Codigo] = []
    @State private var custom: [Codigo] = []
    @State private var estado: Carga<Bool> = .cargando
    @State private var creando = false
    @State private var pdfDe: String?
    
    @State private var caducados = 0
    @State private var aviso: (texto: String, bien: Bool)?
    
    @State private var cobrando: Codigo?
    @State private var plataformas: [(clave: String, nombre: String)] = []
    
    @State private var copiado: String?

    @State private var borrandoCodigo: Codigo?

    struct Codigo: Identifiable, Equatable {
        let code: String
        let etiqueta: String
        let caduca: String
        let usados: Int
        let tope: Int
        
        var caducado: Bool = false
        
        var usado: Bool = false
        var id: String { code }
    }

    var body: some View {
        Group {

            marcador
        }
        .navigationTitle("Códigos")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { creando = true } label: { Image(systemName: "plus") }
                    .accessibilityLabel("Nuevo código")
            }
        }
        .sheet(isPresented: $creando) {
            CrearCodigo { await cargar() }
        }
        .sheet(isPresented: .init(get: { pdfDe != nil },
                                  set: { if !$0 { pdfDe = nil } })) {
            if let code = pdfDe {
                NavigationStack {
                    VStack {
                        BotonPDF(ruta: "api/codigos/\(code)/pdf", nombre: "\(code).pdf",
                                 titulo: "PDF de \(code)")
                        Spacer()
                    }
                    .padding(Diseno.margen)
                    .navigationTitle(code)
                    .navigationBarTitleDisplayMode(.inline)
                }
                .presentationDetents([.height(180)])
            }
        }
        .sheet(item: $cobrando) { c in
            HojaCobrarCodigo(codigo: c, plataformas: plataformas) { plataforma, fecha in
                await hacer(["accion": "cobrar", "code": c.code,
                             "plataforma": plataforma, "fecha": fecha])
            }
        }
        .confirmationDialog("¿Borrar \(borrandoCodigo?.code ?? "")?",
                            isPresented: .init(get: { borrandoCodigo != nil },
                                               set: { if !$0 { borrandoCodigo = nil } }),
                            titleVisibility: .visible) {
            Button("Borrar", role: .destructive) {
                if let c = borrandoCodigo { Task { await borrar(c.code) } }
                borrandoCodigo = nil
            }
            Button("Cancelar", role: .cancel) { borrandoCodigo = nil }
        } message: {
            
            if let c = borrandoCodigo, custom.contains(where: { $0.code == c.code }) {
                Text("Si ya se lo diste a un cliente, dejará de valer. No se puede deshacer.")
            } else {
                Text("Quien lo tenga ya no podrá usarlo. No se puede deshacer.")
            }
        }
        .animation(Diseno.suave, value: descuentos)
        .animation(Diseno.suave, value: custom)
        .task { await cargar() }
        .refreshable { await cargar() }
    }

    private var marcador: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                switch estado {
                case .cargando:
                    Vacio(icono: "ticket", titulo: "Cargando…")
                        .redacted(reason: .placeholder)
                        .padding(.top, Diseno.hueco5)
                case .error(let qué):
                    Vacio(icono: "wifi.exclamationmark", titulo: "No se ha podido cargar", detalle: qué)
                        .padding(.top, Diseno.hueco5)
                case .vacio:
                    Vacio(icono: "ticket", titulo: "No hay códigos")
                        .padding(.top, Diseno.hueco5)
                case .listo:
                    if let l = lineaDeApoyo {
                        Text(l)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Marcador.apoyo)
                            .padding(.horizontal, Diseno.margen)
                    }
                    if let aviso {
                        Banda(aviso)
                            .padding(.horizontal, Diseno.margen)
                            .padding(.top, Diseno.hueco2)
                    }
                    if !descuentos.isEmpty { seccionEnCampo("Descuentos", descuentos, custom: false) }
                    if !custom.isEmpty { seccionEnCampo("Encargo con código", custom, custom: true) }
                    
                    if caducados > 0 {
                        Button(role: .destructive) {
                            Task { await hacer(["accion": "barrer_caducados"]) }
                        } label: {
                            Label(caducados == 1 ? "Borrar 1 código caducado"
                                                 : "Borrar \(caducados) códigos caducados",
                                  systemImage: "trash")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.glass)
                        .controlSize(.large)
                        .foregroundStyle(Diseno.rojo)
                        .padding(.horizontal, Diseno.margen)
                        .padding(.top, Diseno.hueco4)
                    }
                }
            }
            .padding(.bottom, Diseno.hueco5)
        }
        .scrollEdgeEffectStyle(.soft, for: .top)
        .background { CampoJoya(joya: .tienda) }
        .sensoryFeedback(.success, trigger: copiado) { _, nuevo in nuevo != nil }
    }

    private var lineaDeApoyo: String? {
        var partes: [String] = []
        let vivos = descuentos.filter { !$0.caducado }.count
        if !descuentos.isEmpty {
            partes.append(vivos == 1 ? "1 descuento en vigor" : "\(vivos) descuentos en vigor")
        }
        let sinCobrar = custom.filter { !$0.usado }.count
        if sinCobrar > 0 {
            partes.append(sinCobrar == 1 ? "1 Encargo con código sin cobrar" : "\(sinCobrar) Encargo con código sin cobrar")
        }
        return partes.isEmpty ? nil : partes.joined(separator: " · ")
    }

    private func seccionEnCampo(_ titulo: String, _ cs: [Codigo], custom: Bool) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            TituloDeSeccion(texto: titulo)
            ForEach(Array(cs.enumerated()), id: \.element.id) { i, c in
                if i > 0 { Divider() }
                FilaDeCodigo(codigo: c, custom: custom, copiado: copiado == c.code,
                             cobrar: custom && !c.usado ? { cobrando = c } : nil)
                    .contentShape(.rect)
                    .onTapGesture { copiar(c) }
                    .accessibilityAddTraits(.isButton)
                    .contextMenu { menuDe(c, custom ? Diseno.morado : Diseno.azul) }
            }
        }
        .padding(.horizontal, Diseno.margen)
    }

    private func copiar(_ c: Codigo) {
        UIPasteboard.general.string = c.code
        withAnimation(Diseno.suave) { copiado = c.code }
        Task {
            try? await Task.sleep(for: .seconds(1.6))
            if copiado == c.code { withAnimation(Diseno.suave) { copiado = nil } }
        }
    }

    private func hacer(_ cuerpo: [String: any Sendable]) async {
        do {
            let j = try await API.pedir("api/codigos/accion", metodo: "POST",
                                        cuerpo: cuerpo, testigo: sesion.testigo)
            aviso = (j["mensaje"] as? String ?? "Hecho.", j["ok"] as? Bool ?? true)
            await cargar()
        } catch {
            aviso = (error.localizedDescription, false)
        }
    }

    @ViewBuilder
    private func menuDe(_ c: Codigo, _ tinte: Color) -> some View {
        if tinte == Diseno.morado && !c.usado {
            Button("Cobrar…", systemImage: "eurosign.circle") { cobrando = c }
        }
        if tinte != Diseno.morado {
            Button("Ver el PDF", systemImage: "doc.richtext") { pdfDe = c.code }
        }
        Button("Borrar", systemImage: "trash", role: .destructive) {
            borrandoCodigo = c
        }
    }

    private func borrar(_ code: String) async {
        _ = try? await API.pedir("api/codigos/\(code)/borrar", metodo: "POST",
                                 testigo: sesion.testigo)
        await cargar()
    }

    private func cargar() async {
        do {
            let j = try await API.pedir("api/codigos", testigo: sesion.testigo)
            func leer(_ clave: String) -> [Codigo] {
                ((j[clave] as? [[String: Any]]) ?? []).map {
                    Codigo(code: $0["code"] as? String ?? "",
                           etiqueta: ($0["etiqueta"] as? String)
                               ?? ($0["descripcion"] as? String ?? ""),
                           caduca: $0["caduca"] as? String ?? "",
                           usados: $0["usados"] as? Int ?? 0,
                           tope: $0["tope"] as? Int ?? 0,

                           caducado: ($0["caducado"] as? Bool ?? false)
                               || ($0["agotado"] as? Bool ?? false),
                           usado: $0["usado"] as? Bool ?? false)
                }
            }
            descuentos = leer("descuentos")
            custom = leer("encargocodigo")
            caducados = j["caducados"] as? Int ?? 0
            plataformas = ((j["plataformas"] as? [[String: Any]]) ?? []).map {
                (clave: $0["clave"] as? String ?? "", nombre: $0["nombre"] as? String ?? "")
            }
            estado = (descuentos.isEmpty && custom.isEmpty) ? .vacio : .listo(true)
        } catch {
            estado.fallar(error)
        }
    }
}

struct PantallaVideos: View {
    @Environment(Sesion.self) private var sesion
    @State private var categorias: [Categoria] = []
    @State private var estado: Carga<Bool> = .cargando
    @State private var creando = false
    @State private var borrandoCat: Categoria?
    @State private var aviso: (texto: String, bien: Bool)?

    struct Categoria: Identifiable, Equatable {
        let clave: String
        let nombre: String
        let precio: Double
        let cuantos: Int
        let vendidos: Int
        
        var activa: Bool = true
        var id: String { clave }
    }

    var body: some View {

        Group {
            switch estado {
            case .cargando:
                ScrollView {
                    Tarjeta { Vacio(icono: "film", titulo: "Cargando…") }
                        .redacted(reason: .placeholder)
                        .padding(Diseno.margen)
                }
            case .error(let qué):
                ScrollView {
                    Tarjeta { Vacio(icono: "wifi.exclamationmark",
                                    titulo: "No se ha podido cargar", detalle: qué) }
                        .padding(Diseno.margen)
                }
            case .vacio:
                ScrollView {
                    Tarjeta { Vacio(icono: "film", titulo: "No hay categorías") }
                        .padding(Diseno.margen)
                }
            case .listo:

                listaDeCategorias.listStyle(.plain).scrollContentBackground(.hidden)
            }
        }
        
        .fondoDeCampo(.tienda)
        .navigationTitle("Vídeos")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { creando = true } label: { Image(systemName: "plus") }
                    .accessibilityLabel("Nueva categoría")
            }
        }
        .sheet(isPresented: $creando) {
            CrearCategoria { await cargar() }
        }
        .confirmationDialog("¿Borrar la categoría?",
                            isPresented: .init(get: { borrandoCat != nil },
                                               set: { if !$0 { borrandoCat = nil } }),
                            titleVisibility: .visible) {
            Button("Borrar", role: .destructive) {
                if let c = borrandoCat { Task { await borrarCategoria(c) } }
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Se borran también sus vídeos del canal de Tienda. No tiene vuelta atrás.")
        }
        .animation(Diseno.suave, value: categorias)
        .task { await cargar() }
        .refreshable { await cargar() }
    }

    private var listaDeCategorias: some View {
        List {
            if let aviso { Banda(aviso).listRowInsets(EdgeInsets()) }
            ForEach(categorias) { c in

                NavigationLink {
                    PantallaCategoria(clave: c.clave, nombre: c.nombre)
                } label: {
                    HStack(spacing: Diseno.hueco2) {
                        FichaIcono(simbolo: c.activa ? "film.fill" : "eye.slash",
                                   color: c.activa ? .purple : .gray)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(c.nombre)
                            Text("\(c.cuantos) \(c.cuantos == 1 ? "vídeo" : "vídeos")"
                                 + (c.vendidos > 0 ? " · \(c.vendidos) vendidos" : "")
                                 + (c.activa ? "" : " · desactivada"))
                                .font(.footnote).foregroundStyle(.apoyo)
                        }
                        Spacer()
                        Text(Formato.euros(c.precio))
                            .font(.subheadline.weight(.medium))
                            .monospacedDigit()
                    }
                    .opacity(c.activa ? 1 : 0.5)
                }
                
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) { borrandoCat = c } label: {
                        Label("Borrar", systemImage: "trash")
                    }
                    Button {
                        Task { await hacer(["accion": "activar",
                                            "key": c.clave,
                                            "activa": !c.activa]) }
                    } label: {
                        Label(c.activa ? "Desactivar" : "Activar",
                              systemImage: c.activa ? "eye.slash" : "eye")
                    }
                    .tint(Diseno.naranjaRelleno)
                }

                .listRowBackground(Color.clear)
            }
        }
    }

    private func borrarCategoria(_ c: Categoria) async {
        _ = try? await API.pedir("api/videos/accion", metodo: "POST",
                                 cuerpo: ["accion": "borrar_categoria", "key": c.clave],
                                 testigo: sesion.testigo)
        borrandoCat = nil
        await cargar()
    }

    private func hacer(_ cuerpo: [String: any Sendable]) async {
        do {
            let j = try await API.pedir("api/videos/accion", metodo: "POST",
                                        cuerpo: cuerpo, testigo: sesion.testigo)
            aviso = (j["mensaje"] as? String ?? "Hecho.", j["ok"] as? Bool ?? true)
            await cargar()
        } catch {
            aviso = (error.localizedDescription, false)
        }
    }

    private func cargar() async {
        do {
            let j = try await API.pedir("api/videos", testigo: sesion.testigo)
            categorias = ((j["categorias"] as? [[String: Any]]) ?? []).map {
                Categoria(clave: $0["key"] as? String ?? "",
                          nombre: $0["nombre"] as? String ?? "",
                          precio: $0["precio_eur"] as? Double ?? 0,
                          cuantos: $0["n_videos"] as? Int ?? 0,
                          vendidos: $0["ventas"] as? Int ?? 0,
                          activa: $0["activa"] as? Bool ?? true)
            }
            estado = categorias.isEmpty ? .vacio : .listo(true)
        } catch {
            estado.fallar(error)
        }
    }
}

struct PantallaRegistro: View {
    @Environment(Sesion.self) private var sesion
    @State private var errores: [Linea] = []
    @State private var servicios: [Servicio] = []
    @State private var peticiones: [Peticion] = []
    @State private var resueltas: [Peticion] = []

    @State private var versionCompilada = ""
    @State private var estado: Carga<Bool> = .cargando

    @State private var copiado: UUID?
    
    @State private var modoEdicion: EditMode = .inactive
    @State private var elegidos: Set<UUID> = []
    @State private var trabajando = false
    @State private var aviso: (texto: String, bien: Bool)?
    @State private var reportando = false
    
    @State private var tachando: Peticion?

    struct Linea: Identifiable, Equatable {
        let origen: String
        let texto: String
        let cuando: String

        let huella: String
        let id = UUID()
    }

    struct Servicio: Identifiable, Equatable {
        let nombre: String
        let bonito: String
        let activo: Bool
        var id: String { nombre }
    }

    struct Peticion: Identifiable, Equatable {
        let id: String
        let tipo: String
        let texto: String
        let cuando: String
        
        var nota: String = ""

        var por: String = ""
        
        var version: String = ""
        var resueltaEl: String = ""
        var esFallo: Bool { tipo == "error" }
        var corregida: Bool { por == "claude" }
    }

    var body: some View {
        Group {
            switch estado {
            case .cargando:
                ScrollView {
                    Tarjeta { Vacio(icono: "list.bullet", titulo: "Cargando…") }
                        .redacted(reason: .placeholder).padding(Diseno.margen)
                }
            case .error(let qué):
                ScrollView {
                    Tarjeta { Vacio(icono: "wifi.exclamationmark",
                                    titulo: "No se ha podido cargar", detalle: qué) }
                        .padding(Diseno.margen)
                }
            case .vacio:
                ScrollView {
                    VStack(spacing: Diseno.hueco3) {
                        if !servicios.isEmpty { salud }
                        if let aviso { Banda(aviso) }
                        if !peticiones.isEmpty || !resueltas.isEmpty { pendientes }
                        Tarjeta { Vacio(icono: "checkmark.seal", titulo: "Ningún error",
                                        detalle: "Todo funcionando.") }
                        reportar
                    }
                    .padding(Diseno.margen)
                }
            case .listo:
                listaDeFallos
            }
        }
        .fondoDePantalla()
        .navigationTitle("Logs y errores")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Copiar todos", systemImage: "doc.on.doc") { copiarTodos() }
                        .disabled(errores.isEmpty)
                    Button("Reportarme algo", systemImage: "exclamationmark.bubble") {
                        reportando = true
                    }
                    Button("Vaciar el registro", systemImage: "trash", role: .destructive) {
                        Task { await hacer(["accion": "borrar_todos"]) }
                    }
                    .disabled(errores.isEmpty)
                } label: {
                    Image(systemName: "ellipsis")
                }
                .accessibilityLabel("Más opciones")
            }
            ToolbarItem(placement: .topBarTrailing) {
                if !errores.isEmpty {

                    EditButton()
                }
            }
        }

        .environment(\.editMode, $modoEdicion)
        .sheet(isPresented: $reportando) {
            HojaReportar { tipo, texto in
                await hacer(["accion": "reportar", "tipo": tipo, "texto": texto])
            }
        }
        .confirmationDialog("¿Quitarla de la lista?", isPresented: .init(
            get: { tachando != nil }, set: { if !$0 { tachando = nil } }
        ), titleVisibility: .visible) {
            Button("Quitarla", role: .destructive) {
                guard let p = tachando else { return }
                tachando = nil
                Task { await hacer(["accion": "marcar", "id": p.id, "hecha": true]) }
            }
            Button("Dejarla", role: .cancel) { tachando = nil }
        } message: {
            Text("Dejaré de verla como pendiente. Lo que yo corrijo se cierra solo.")
        }
        .animation(Diseno.suave, value: copiado)
        .animation(Diseno.suave, value: errores)
        .task { await cargar() }
        .refreshable { await cargar() }
    }

    private var listaDeFallos: some View {
        List(selection: $elegidos) {
            if !servicios.isEmpty { Section { salud } }
            if let aviso { Section { Banda(aviso) } }
            if !peticiones.isEmpty { Section { pendientes } }

            Section {
                ForEach(errores) { l in
                    VStack(alignment: .leading, spacing: 3) {
                        HStack {
                            Text(l.origen)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Diseno.rojo)
                            Spacer()

                            Text(l.cuando.isEmpty ? "sin fecha" : l.cuando)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Text(l.texto)
                            .font(.system(.footnote, design: .monospaced))
                            .textSelection(.enabled)
                    }
                    .contextMenu {
                        Button("Copiar el error", systemImage: "doc.on.doc") { copiar(l) }
                        Button("Copiar todos", systemImage: "doc.on.doc.fill") { copiarTodos() }
                        Button("Quitar del registro", systemImage: "trash", role: .destructive) {
                            Task { await hacer(["accion": "borrar", "huellas": [l.huella]]) }
                        }
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            Task { await hacer(["accion": "borrar", "huellas": [l.huella]]) }
                        } label: {
                            Label("Quitar", systemImage: "trash")
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .listaConTema()

        .toolbar {
            if modoEdicion == .active {
                ToolbarItemGroup(placement: .bottomBar) {
                    Spacer()
                    Button(role: .destructive) {
                        let huellas = errores.filter { elegidos.contains($0.id) }
                                             .map(\.huella)
                        Task {
                            await hacer(["accion": "borrar", "huellas": huellas])
                            elegidos = []
                            modoEdicion = .inactive
                        }
                    } label: {
                        Label(elegidos.isEmpty ? "Eliminar"
                                               : "Eliminar (\(elegidos.count))",
                              systemImage: "trash")
                    }
                    .disabled(elegidos.isEmpty || trabajando)
                }
            }
        }
    }

    private var pendientes: some View {
        Tarjeta {
            VStack(alignment: .leading, spacing: Diseno.hueco2) {
                HStack {
                    Text(peticiones.isEmpty ? "Nada pendiente" : "Apuntado para mí")
                        .font(.headline)
                    Spacer()
                    if !peticiones.isEmpty {
                        Text("\(peticiones.count)")
                            .font(.subheadline).foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }
                ForEach(peticiones) { p in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Image(systemName: p.esFallo ? "ladybug" : "pencil")
                            .font(.caption)
                            .foregroundStyle(p.esFallo ? Diseno.rojo : Diseno.azul)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(p.texto).font(.subheadline)
                            
                            Text(fecha(p.cuando)).font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 0)

                        Button {
                            tachando = p
                        } label: {
                            Image(systemName: "circle")
                                .font(.title3)
                                .foregroundStyle(.tertiary)
                                .frame(width: 44, height: 44)
                                .contentShape(.rect)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Marcar como vista")
                    }
                }

                if !resueltas.isEmpty {
                    Divider()
                    NavigationLink {
                        PantallaResueltos(resueltas: resueltas,
                                          versionCompilada: versionCompilada)
                    } label: {
                        HStack {
                            Label("Logs resueltos", systemImage: "checkmark.seal.fill")
                                .font(.subheadline)
                                .foregroundStyle(Diseno.verde)
                            Spacer()
                            Text("\(resueltas.count)")
                                .font(.subheadline).foregroundStyle(.secondary)
                                .monospacedDigit()

                        }
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func fecha(_ iso: String) -> String {
        let partes = iso.split(separator: "T")
        guard partes.count == 2 else { return iso }
        let d = partes[0].split(separator: "-")
        guard d.count == 3, let mes = Int(d[1]) else { return iso }
        let meses = ["ene", "feb", "mar", "abr", "may", "jun",
                     "jul", "ago", "sep", "oct", "nov", "dic"]
        let nombre = meses[max(0, min(11, mes - 1))]
        return "\(Int(d[2]) ?? 0) \(nombre), \(partes[1].prefix(5))"
    }

    private var reportar: some View {
        Button {
            reportando = true
        } label: {
            Label("Reportar un fallo o un cambio", systemImage: "exclamationmark.bubble")
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
        }
        .buttonStyle(.glass)
        .controlSize(.large)
    }

    private func hacer(_ cuerpo: [String: any Sendable]) async {
        trabajando = true
        defer { trabajando = false }
        do {
            let r = try await API.pedir("api/registro/accion", metodo: "POST",
                                        cuerpo: cuerpo, testigo: sesion.testigo)
            aviso = (r["mensaje"] as? String ?? "Hecho.", r["ok"] as? Bool ?? true)
            await cargar()
        } catch {
            aviso = (error.localizedDescription, false)
        }
    }

    private func texto(_ l: Linea) -> String {
        "[\(l.origen)] \(l.cuando)\n\(l.texto)"
    }

    private func copiar(_ l: Linea) {
        UIPasteboard.general.string = texto(l)
        copiado = l.id
        
        Task {
            try? await Task.sleep(for: .seconds(2))
            if copiado == l.id { copiado = nil }
        }
    }

    private func copiarTodos() {
        UIPasteboard.general.string = errores.map(texto).joined(separator: "\n\n")
        copiado = errores.first?.id
        Task {
            try? await Task.sleep(for: .seconds(2))
            copiado = nil
        }
    }

    private var salud: some View {
        Tarjeta {
            VStack(alignment: .leading, spacing: Diseno.hueco2) {
                let caidos = servicios.filter { !$0.activo }
                if caidos.isEmpty {

                    Label {
                        Text("Los \(servicios.count) servicios, en marcha")
                    } icon: {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.white, Diseno.verde)
                    }
                    .font(.subheadline.weight(.medium))
                } else {
                    ForEach(caidos) { s in
                        Label("\(s.bonito) está parado", systemImage: "exclamationmark.triangle.fill")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Diseno.rojo)
                    }
                }
            }
        }
    }

    private func cargar() async {
        do {
            let j = try await API.pedir("api/registro", testigo: sesion.testigo)
            errores = ((j["errores"] as? [[String: Any]]) ?? []).map {
                Linea(origen: $0["origen"] as? String ?? "",
                      texto: $0["texto"] as? String ?? "",
                      cuando: $0["cuando"] as? String ?? "",
                      huella: $0["huella"] as? String ?? "")
            }
            let s = (j["servicios"] as? [String: Any]) ?? [:]
            servicios = ((s["servicios"] as? [[String: Any]]) ?? []).map {
                Servicio(nombre: $0["nombre"] as? String ?? "",
                         bonito: $0["bonito"] as? String ?? "",
                         activo: $0["activo"] as? Bool ?? false)
            }
            func leerPeticiones(_ clave: String) -> [Peticion] {
                ((j[clave] as? [[String: Any]]) ?? []).map {
                    Peticion(id: $0["id"] as? String ?? UUID().uuidString,
                             tipo: $0["tipo"] as? String ?? "cambio",
                             texto: $0["texto"] as? String ?? "",
                             cuando: $0["cuando"] as? String ?? "",
                             nota: $0["nota"] as? String ?? "",
                             por: $0["por"] as? String ?? "",
                             version: $0["version"] as? String ?? "",
                             resueltaEl: $0["resuelta_el"] as? String ?? "")
                }
            }
            peticiones = leerPeticiones("peticiones")
            resueltas = leerPeticiones("resueltas")
            versionCompilada = j["version_compilada"] as? String ?? ""
            estado = errores.isEmpty ? .vacio : .listo(true)
            if errores.isEmpty { modoEdicion = .inactive }
        } catch {
            estado.fallar(error)
        }
    }
}

struct HojaReportar: View {
    @Environment(\.dismiss) private var cerrar
    let enviar: (String, String) async -> Void

    @State private var tipo = "error"
    @State private var texto = ""
    @State private var mandando = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Qué es", selection: $tipo) {
                        Text("Un fallo").tag("error")
                        Text("Un cambio").tag("cambio")
                    }
                    .pickerStyle(.segmented)
                }
                Section {
                    TextField(tipo == "error"
                              ? "Qué ha pasado y en qué pantalla"
                              : "Qué quieres que cambie",
                              text: $texto, axis: .vertical)
                        .lineLimit(4...10)
                }
            }
            .fondoDePantalla()
            .navigationTitle("Reportar")
            .navigationBarTitleDisplayMode(.inline)
            .salidaDelTeclado()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { cerrar() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(mandando ? "Enviando…" : "Enviar") {
                        Task {
                            mandando = true
                            await enviar(tipo, texto)
                            mandando = false
                            cerrar()
                        }
                    }
                    .disabled(texto.trimmingCharacters(in: .whitespacesAndNewlines).count < 3
                              || mandando)
                }
            }
        }
    }
}

struct HojaCobrarCodigo: View {
    @Environment(\.dismiss) private var cerrar
    let codigo: PantallaCodigos.Codigo
    let plataformas: [(clave: String, nombre: String)]
    let cobrar: (String, String) async -> Void

    @State private var plataforma = "plataforma1"
    @State private var fecha = Date()
    @State private var trabajando = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(codigo.code)
                        .font(.system(.title3, design: .monospaced).weight(.semibold))
                    Text(codigo.etiqueta).font(.subheadline).foregroundStyle(.secondary)
                }
                Section("Por dónde te pagó") {
                    Picker("Plataforma", selection: $plataforma) {
                        ForEach(plataformas, id: \.clave) { p in
                            Text(p.nombre).tag(p.clave)
                        }
                    }
                    .pickerStyle(.menu)
                    DatePicker("Cuándo", selection: $fecha, in: ...Date(),
                               displayedComponents: .date)
                }
                Section {

                    Text((["plataforma1", "plataforma2"].contains(plataforma)
                          ? "Ya cuenta con lo que te paga \(plataformas.first { $0.clave == plataforma }?.nombre ?? "esa plataforma"): no se suma otra vez."
                          : "Se suma a las ganancias de ese día y a la reserva.")
                         + " El código queda marcado, así que no se cuenta dos veces si luego lo canjea.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            .fondoDePantalla()
            .navigationTitle("Cobrar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { cerrar() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(trabajando ? "Cobrando…" : "Cobrar") {
                        Task {
                            trabajando = true
                            await cobrar(plataforma, Self.iso(fecha))
                            trabajando = false
                            cerrar()
                        }
                    }
                    .disabled(trabajando || plataformas.isEmpty)
                }
            }
            .onAppear { plataforma = plataformas.first?.clave ?? "plataforma1" }
        }
    }

    private static func iso(_ d: Date) -> String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: d)
        return String(format: "%04d-%02d-%02d", c.year ?? 2026, c.month ?? 1, c.day ?? 1)
    }
}

struct PantallaResueltos: View {
    let resueltas: [PantallaRegistro.Peticion]
    
    let versionCompilada: String

    private var instalada: String {
        "1.0." + (Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0")
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Diseno.hueco3) {
                ForEach(resueltas) { p in
                    Tarjeta {
                        VStack(alignment: .leading, spacing: Diseno.hueco2) {
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Image(systemName: p.corregida
                                      ? "checkmark.seal.fill" : "checkmark.circle")
                                    .font(.caption)
                                    .foregroundStyle(p.corregida ? Diseno.verde : .secondary)
                                Text(p.corregida ? "Corregido" : "Visto")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(p.corregida ? Diseno.verde : .secondary)
                                Spacer(minLength: 0)
                                if !p.version.isEmpty {
                                    Text(p.version)
                                        .font(.caption).monospacedDigit()
                                        .foregroundStyle(.secondary)
                                }
                            }

                            Text(p.texto)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                            if !p.nota.isEmpty {
                                Divider()
                                Text(p.nota).font(.subheadline)
                            }

                            if !Compilacion.beta, p.corregida, !p.version.isEmpty,
                               p.version != instalada, p.version == versionCompilada {
                                Label("Está en la \(p.version); tú tienes la \(instalada)",
                                      systemImage: "arrow.down.circle")
                                    .font(.caption)
                                    .foregroundStyle(Diseno.naranja)
                            }
                        }
                    }
                }
            }
            .padding(Diseno.margen)
        }
        .fondoDePantalla()
        .navigationTitle("Logs resueltos")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct FilaDeCodigo: View {
    let codigo: PantallaCodigos.Codigo
    let custom: Bool
    let copiado: Bool
    var cobrar: (() -> Void)? = nil

    @Environment(\.colorScheme) private var modo

    private var apagado: Bool { codigo.caducado || (custom && codigo.usado) }

    var body: some View {
        HStack(alignment: .center, spacing: Diseno.hueco2) {
            VStack(alignment: .leading, spacing: 3) {
                Text(codigo.code)
                    .font(.system(.title3, design: .monospaced).weight(.bold))
                    .foregroundStyle(Color.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(codigo.etiqueta.replacingOccurrences(
                        of: #"(\d)%"#, with: "$1\u{00A0}%", options: .regularExpression))
                    .font(.subheadline)
                    .foregroundStyle(Color.primary)
                    .lineLimit(2)
                pie
            }
            Spacer(minLength: Diseno.hueco1)
            derecha
        }
        .padding(.vertical, 12)
        .opacity(apagado ? 0.55 : 1)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Toca para copiar el código")
        .accessibilityActions {
            if let cobrar { Button("Cobrar", action: cobrar) }
        }
    }

    @ViewBuilder
    private var pie: some View {
        HStack(spacing: 6) {
            if custom {
                PuntoDeArea(color: codigo.usado ? Diseno.verdeRelleno : Marcador.apoyo, lado: 7)
                Text(codigo.usado ? "cobrado" : "sin cobrar")
            } else if codigo.caducado {
                PuntoDeArea(color: Diseno.rojoRelleno, lado: 7)
                Text("caducado")
            } else {
                Text(caducidad)
                Text("·")
                if codigo.tope > 0 { barraDeUsos }
                Text(codigo.tope > 0 ? "\(codigo.usados)/\(codigo.tope)"
                                     : (codigo.usados == 1 ? "1 uso" : "\(codigo.usados) usos"))
                    .monospacedDigit()
            }
        }
        .font(.footnote)
        .foregroundStyle(Marcador.apoyo)
        .lineLimit(1)
        .minimumScaleFactor(0.8)
    }

    private var barraDeUsos: some View {
        let parte = min(1, Double(codigo.usados) / Double(max(codigo.tope, 1)))
        return ZStack(alignment: .leading) {
            Capsule().fill(Marcador.apoyo.opacity(0.16))
            Capsule().fill(Diseno.azulRelleno.gradient)
                .frame(width: 44 * CGFloat(parte))
                .overlay {
                    if modo == .light && parte > 0 {
                        Capsule().strokeBorder(.black.opacity(0.6), lineWidth: 0.75)
                    }
                }
        }
        .frame(width: 44, height: 6)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var derecha: some View {
        if let cobrar {
            Button("Cobrar", systemImage: "eurosign.circle", action: cobrar)
                .font(.subheadline.weight(.semibold))
                .buttonStyle(.glass)
        } else if copiado {
            Label {
                Text("Copiado").foregroundStyle(Color.primary)
            } icon: {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.white, Diseno.verdeRelleno)
            }
            .font(.footnote.weight(.semibold))
            .transition(.scale.combined(with: .opacity))
        } else {
            Image(systemName: "doc.on.doc")
                .font(.footnote)
                .foregroundStyle(Marcador.apoyo)
                .accessibilityHidden(true)
        }
    }

    private var caducidad: String {
        let dia = Formato.diaCorto(codigo.caduca)
        return dia == codigo.caduca ? codigo.caduca : "hasta el " + dia
    }
}

