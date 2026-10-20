import SwiftUI
import PhotosUI

struct PantallaSeguridad: View {
    @Environment(Sesion.self) private var sesion

    @State private var sesiones: [Aparato] = []
    @State private var apps: [Aparato] = []
    @State private var perfiles: [Perfil] = []
    @State private var estado: Carga<Bool> = .cargando
    @State private var aviso: (texto: String, bien: Bool)?
    @State private var creandoPerfil = false
    @State private var cambiandoPassword = false
    
    @State private var borrandoPerfil: Perfil?

    struct Aparato: Identifiable, Equatable {
        let sid: String
        
        let familia: String
        
        let modelo: String
        let identificador: String
        let sistema: String
        let ultima: String
        let desde: String
        let actual: Bool

        let accion: String
        var id: String { sid }
    }

    struct Perfil: Identifiable, Equatable {
        let uid: String
        let nombre: String
        let rol: String
        let borrable: Bool
        var id: String { uid }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Diseno.hueco3) {
                switch estado {
                case .cargando:
                    Tarjeta { Vacio(icono: "lock", titulo: "Cargando…") }
                        .redacted(reason: .placeholder)
                case .error(let qué):
                    Tarjeta { Vacio(icono: "wifi.exclamationmark",
                                    titulo: "No se ha podido cargar", detalle: qué) }
                default:
                    if let aviso { Banda(aviso) }
                    dispositivos
                    seccionPerfiles
                    contrasenaYCodigo
                }
            }
            .padding(.horizontal, Diseno.margen)
            .padding(.vertical, Diseno.hueco2)
        }
        .fondoDePantalla()
        
        .navigationTitle("Privacidad y seguridad")

        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {

                Button { creandoPerfil = true } label: { Image(systemName: "plus") }
                    .accessibilityLabel("Nuevo perfil")
            }
        }
        .sheet(isPresented: $creandoPerfil) {
            HojaNuevoPerfil { nombre, password in
                await hacer(["accion": "crear", "nombre": nombre, "password": password])
            }
        }
        .sheet(isPresented: $cambiandoPassword) {
            HojaCambiarPassword { actual, nueva in
                await hacer(["accion": "password", "actual": actual, "nueva": nueva])
            }
        }
        .confirmationDialog("¿Borrar el perfil de \(borrandoPerfil?.nombre ?? "")?",
                            isPresented: .init(get: { borrandoPerfil != nil },
                                               set: { if !$0 { borrandoPerfil = nil } }),
                            titleVisibility: .visible) {
            Button("Borrar", role: .destructive) {
                if let p = borrandoPerfil { Task { await hacer(["accion": "borrar", "uid": p.uid]) } }
                borrandoPerfil = nil
            }
            Button("Cancelar", role: .cancel) { borrandoPerfil = nil }
        } message: {
            Text("No podrá volver a entrar en Ingresos.")
        }
        .animation(Diseno.suave, value: sesiones)
        .animation(Diseno.suave, value: apps)
        .task { await cargar() }
    }

    @ViewBuilder
    private var dispositivos: some View {
        let todos = apps + sesiones
        VStack(alignment: .leading, spacing: Diseno.hueco2) {
            Text("Dispositivos vinculados").font(.headline).padding(.leading, 4)
            if todos.isEmpty {
                Tarjeta { Vacio(icono: "laptopcomputer.and.iphone",
                                titulo: "Ninguno ahora mismo") }
            } else {
                Tarjeta(relleno: 0) {
                    VStack(spacing: 0) {
                        ForEach(Array(todos.enumerated()), id: \.element.id) { i, a in
                            if i > 0 {

                                Divider().padding(.leading, Diseno.hueco3 + 44)
                            }
                            NavigationLink {
                                PantallaUnAparato(aparato: a) { cuerpo in await hacer(cuerpo) }
                            } label: {
                                FilaDeAparato(titulo: a.familia.isEmpty ? "Aparato" : a.familia,
                                              detalle: a.modelo,
                                              esteMismo: a.actual)
                                    .padding(.horizontal, Diseno.hueco3)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    private var seccionPerfiles: some View {
        VStack(alignment: .leading, spacing: Diseno.hueco2) {
            Text("Perfiles").font(.headline).padding(.leading, 4)
            Tarjeta(relleno: 0) {
                VStack(spacing: 0) {
                    ForEach(Array(perfiles.enumerated()), id: \.element.id) { i, p in
                        if i > 0 { Divider().padding(.leading, Diseno.hueco3) }
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(p.nombre)
                                Text(p.rol).font(.footnote).foregroundStyle(.secondary)
                            }
                            Spacer()
                            if p.borrable {
                                Button("Borrar", role: .destructive) {
                                    borrandoPerfil = p
                                }
                                .font(.footnote)
                                .buttonStyle(.glass)
                            }
                        }
                        .padding(Diseno.hueco3)
                    }
                }
            }
            Text("Todos los perfiles tienen acceso completo: pedidos, cobros y códigos.")
                .font(.footnote).foregroundStyle(.secondary).padding(.horizontal, 4)
        }
    }

    private var contrasenaYCodigo: some View {
        Button("Cambiar la contraseña de Ingresos", systemImage: "key") {
            cambiandoPassword = true
        }
        .buttonStyle(.glass)
        .controlSize(.large)
    }

    private func cargar() async {
        do {
            let j = try await API.pedir("api/cuenta", testigo: sesion.testigo)
            sesiones = ((j["sesiones"] as? [[String: Any]]) ?? []).map {
                leerAparato($0, accion: "cerrar_aparato", campo: "sid")
            }
            apps = ((j["apps"] as? [[String: Any]]) ?? []).map {
                leerAparato($0, accion: "cerrar_app", campo: "id")
            }
            perfiles = ((j["perfiles"] as? [[String: Any]]) ?? []).map {
                Perfil(uid: $0["id"] as? String ?? "",
                       nombre: $0["nombre"] as? String ?? "",
                       rol: $0["rol"] as? String ?? "",
                       borrable: $0["borrable"] as? Bool ?? false)
            }
            estado = .listo(true)
        } catch {
            estado.fallar(error)
        }
    }

    private func leerAparato(_ j: [String: Any], accion: String, campo: String) -> Aparato {

        let familia = (j["familia"] as? String).flatMap { $0.isEmpty ? nil : $0 }
            ?? j["aparato"] as? String ?? "Aparato"
        let modelo = (j["modelo"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? familia
        return Aparato(sid: j["id"] as? String ?? "",
                       familia: familia,
                       modelo: modelo,
                       identificador: j["identificador"] as? String ?? "",
                       sistema: j["sistema"] as? String ?? "",
                       ultima: (j["visto"] as? String) ?? (j["ultima"] as? String) ?? "",
                       desde: j["desde"] as? String ?? "",
                       actual: j["actual"] as? Bool ?? false,
                       accion: accion)
    }

    private func hacer(_ cuerpo: [String: any Sendable]) async {
        do {
            let j = try await API.pedir("api/cuenta/seguridad", metodo: "POST",
                                        cuerpo: cuerpo, testigo: sesion.testigo)
            aviso = (j["mensaje"] as? String ?? "", j["ok"] as? Bool ?? false)
            await cargar()
        } catch {
            aviso = (error.localizedDescription, false)
        }
    }
}

struct PantallaUnAparato: View {
    @Environment(\.dismiss) private var volver
    let aparato: PantallaSeguridad.Aparato
    let hacer: ([String: any Sendable]) async -> Void

    @State private var confirmando = false
    @ScaledMetric(relativeTo: .largeTitle) private var tamIcono: CGFloat = 64

    var body: some View {
        ScrollView {
            VStack(spacing: Diseno.hueco3) {
                VStack(spacing: 6) {
                    Image(systemName: Aparato.simbolo(aparato.familia + " " + aparato.modelo))
                        .font(.system(size: tamIcono, weight: .light))
                        .foregroundStyle(.primary)
                        .padding(.bottom, 4)
                    Text(aparato.familia).font(.title2.weight(.semibold))
                    Text(aparato.actual ? "Este \(aparato.modelo)" : aparato.modelo)
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                .padding(.vertical, Diseno.hueco4)

                Tarjeta(relleno: 0) {
                    VStack(spacing: 0) {
                        fila("Modelo", aparato.modelo)
                        if !aparato.identificador.isEmpty {
                            Divider().padding(.leading, Diseno.hueco3)
                            fila("Identificador", aparato.identificador)
                        }
                        if !aparato.sistema.isEmpty {
                            Divider().padding(.leading, Diseno.hueco3)
                            fila("Versión", aparato.sistema)
                        }
                        if !aparato.desde.isEmpty {
                            Divider().padding(.leading, Diseno.hueco3)
                            fila("Se conecta desde", aparato.desde)
                        }
                        if !aparato.ultima.isEmpty {
                            Divider().padding(.leading, Diseno.hueco3)
                            fila("Última vez", aparato.ultima)
                        }
                    }
                }

                if !aparato.actual {
                    Button("Cerrar sesión en este aparato", role: .destructive) {
                        confirmando = true
                    }
                    .buttonStyle(.glass)
                    .controlSize(.large)
                    .frame(maxWidth: .infinity)

                    Text("Tendrá que volver a entrar con la contraseña de Ingresos.")
                        .font(.footnote).foregroundStyle(.secondary)
                        .padding(.horizontal, 4)
                } else {

                    Text("Es el aparato que estás usando.")
                        .font(.footnote).foregroundStyle(.secondary)
                        .padding(.horizontal, 4)
                }
            }
            .padding(.horizontal, Diseno.margen)
            .padding(.vertical, Diseno.hueco2)
        }
        .fondoDePantalla()
        .navigationTitle("Información del dispositivo")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("¿Cerrar sesión en \(aparato.modelo)?",
                            isPresented: $confirmando, titleVisibility: .visible) {
            Button("Cerrar sesión", role: .destructive) {
                Task {
                    let campo = aparato.accion == "cerrar_app" ? "id" : "sid"
                    await hacer(["accion": aparato.accion, campo: aparato.sid])
                    volver()
                }
            }
            Button("Cancelar", role: .cancel) {}
        }
    }

    private func fila(_ t: String, _ v: String) -> some View {
        HStack {
            Text(t)
            Spacer()
            Text(v).foregroundStyle(.secondary)
        }
        .padding(Diseno.hueco3)
    }
}

struct PantallaResumenCuenta: View {
    @Environment(Sesion.self) private var sesion

    @State private var libreGB: Double = 0
    @State private var usadoGB: Double = 0
    @State private var totalGB: Double = 0
    @State private var porcentaje = 0
    @State private var estado: Carga<Bool> = .cargando

    var body: some View {
        ScrollView {
            VStack(spacing: Diseno.hueco3) {
                switch estado {
                case .cargando:
                    Tarjeta { Vacio(icono: "internaldrive", titulo: "Cargando…") }
                        .redacted(reason: .placeholder)
                case .error(let qué):
                    Tarjeta { Vacio(icono: "wifi.exclamationmark",
                                    titulo: "No se ha podido cargar", detalle: qué) }
                default:
                    Heroe(titulo: "Espacio libre",
                          valor: String(format: "%.0f GB", libreGB),
                          etiqueta: String(format: "de %.0f GB · %d %% ocupado",
                                           totalGB, porcentaje),
                          icono: "internaldrive.fill", tinte: Diseno.azulRelleno)

                    Text("Los vídeos no ocupan aquí: están en el canal de Tienda.")
                        .font(.caption).foregroundStyle(.secondary).padding(.horizontal, 4)
                }
            }
            .padding(.horizontal, Diseno.margen)
            .padding(.vertical, Diseno.hueco2)
        }
        .fondoDePantalla()
        .navigationTitle("Almacenamiento")

        .navigationBarTitleDisplayMode(.inline)
        .task { await cargar() }
    }

    private func cargar() async {
        do {
            let j = try await API.pedir("api/cuenta", testigo: sesion.testigo)
            if let e = j["espacio"] as? [String: Any] {
                libreGB = e["libre_gb"] as? Double ?? 0
                usadoGB = e["usado_gb"] as? Double ?? 0
                totalGB = e["total_gb"] as? Double ?? 0
                porcentaje = e["porcentaje"] as? Int ?? 0
            }
            estado = .listo(true)
        } catch {
            estado.fallar(error)
        }
    }
}

struct PantallaCompras: View {
    @Environment(Sesion.self) private var sesion

    @State private var compras: [Compra] = []
    @State private var estado: Carga<Bool> = .cargando

    struct Compra: Identifiable, Equatable {
        let id: String
        let cliente: String
        let que: String
        let importe: String
        let eur: Double
        let cuando: String
    }

    private var total: Double { compras.reduce(0) { $0 + $1.eur } }

    var body: some View {
        ScrollView {
            VStack(spacing: Diseno.hueco3) {
                switch estado {
                case .cargando:
                    Tarjeta { Vacio(icono: "bag", titulo: "Cargando…") }
                        .redacted(reason: .placeholder)
                case .error(let qué):
                    Tarjeta { Vacio(icono: "wifi.exclamationmark",
                                    titulo: "No se ha podido cargar", detalle: qué) }
                case .vacio:
                    Tarjeta { Vacio(icono: "bag", titulo: "Todavía no hay compras",
                                    detalle: "Aquí aparece cada cobro con lo que se llevó.") }
                default:
                    Heroe(titulo: "Suma de lo que se ve aquí",
                          valor: Formato.euros(total),
                          etiqueta: "\(compras.count) "
                                    + (compras.count == 1 ? "compra" : "compras"),
                          icono: "bag.fill", tinte: Diseno.verdeRelleno)

                    Tarjeta(relleno: 0) {
                        VStack(spacing: 0) {
                            ForEach(Array(compras.enumerated()), id: \.element.id) { i, c in
                                if i > 0 { Divider().padding(.leading, Diseno.hueco3) }
                                NavigationLink { PantallaPedido(id: c.id) } label: {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(Formato.importe(c.importe)).fontWeight(.medium)
                                            Text("\(c.cliente) · \(c.cuando)")
                                                .font(.footnote).foregroundStyle(.secondary)
                                            Text(c.que)
                                                .font(.caption).foregroundStyle(.secondary)
                                                .lineLimit(2)
                                        }
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(.footnote.weight(.semibold))
                                            .foregroundStyle(.tertiary)
                                    }
                                    .padding(Diseno.hueco3)
                                    .contentShape(.rect)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    Text("Los 60 cobros más recientes.")
                        .font(.caption).foregroundStyle(.secondary).padding(.horizontal, 4)
                }
            }
            .padding(.horizontal, Diseno.margen)
            .padding(.vertical, Diseno.hueco2)
        }
        .fondoDePantalla()
        .navigationTitle("Contenido y compras")

        .navigationBarTitleDisplayMode(.inline)
        .task { await cargar() }
    }

    private func cargar() async {
        do {
            let j = try await API.pedir("api/cuenta", testigo: sesion.testigo)

            compras = ((j["compras"] as? [[String: Any]]) ?? []).map {
                Compra(id: $0["id"] as? String ?? "",
                       cliente: $0["cliente"] as? String ?? "",
                       que: $0["que"] as? String ?? "",
                       importe: $0["importe"] as? String ?? "",
                       eur: $0["eur"] as? Double ?? 0,
                       cuando: $0["cuando"] as? String ?? "")
            }
            estado = compras.isEmpty ? .vacio : .listo(true)
        } catch {
            estado.fallar(error)
        }
    }
}

struct PantallaBorrarHistorial: View {
    @Environment(Sesion.self) private var sesion
    @State private var confirmando: String?
    @State private var aviso: (texto: String, bien: Bool)?
    @State private var trabajando = false

    var body: some View {
        ScrollView {
            VStack(spacing: Diseno.hueco3) {
                if let aviso { Banda(aviso) }

                Tarjeta {
                    VStack(alignment: .leading, spacing: Diseno.hueco2) {
                        Text("Borrar pedidos cerrados").font(.headline)
                        Text("Los rechazados, cancelados, caducados y no recibidos. Los cobrados se quedan.")
                            .font(.footnote).foregroundStyle(.secondary)
                        Button("Borrar los cerrados", role: .destructive) {
                            confirmando = "borrar_cerrados"
                        }
                        .buttonStyle(.glass)

                        .foregroundStyle(Diseno.rojo)
                        .disabled(trabajando)
                    }
                }

                Tarjeta {
                    VStack(alignment: .leading, spacing: Diseno.hueco2) {
                        Text("Borrar todo el historial").font(.headline)
                        Text("Todos los pedidos, también los cobrados. Cambia tus ingresos.")
                            .font(.footnote).foregroundStyle(Diseno.rojo)
                        Button("Borrar todo", role: .destructive) {
                            confirmando = "borrar_todo"
                        }
                        .buttonStyle(.glass)
                        .foregroundStyle(Diseno.rojo)
                        .disabled(trabajando)
                    }
                }
            }
            .padding(.horizontal, Diseno.margen)
            .padding(.vertical, Diseno.hueco2)
        }
        .fondoDePantalla()
        .navigationTitle("Borrar historial")

        .navigationBarTitleDisplayMode(.inline)
        .animation(Diseno.suave, value: aviso?.texto)
        .confirmationDialog("¿Seguro?", isPresented: .init(
            get: { confirmando != nil }, set: { if !$0 { confirmando = nil } }
        ), titleVisibility: .visible) {
            Button("Borrar", role: .destructive) {
                if let a = confirmando { Task { await borrar(a) } }
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text(confirmando == "borrar_todo"
                 ? "Se borran TODOS los pedidos y tus ingresos cambiarán. No tiene vuelta atrás."
                 : "Se borran los pedidos cerrados. No tiene vuelta atrás.")
        }
    }

    private func borrar(_ accion: String) async {
        trabajando = true
        do {
            let j = try await API.pedir("api/cuenta/historial", metodo: "POST",
                                        cuerpo: ["accion": accion], testigo: sesion.testigo)
            aviso = (j["mensaje"] as? String ?? "", j["ok"] as? Bool ?? false)
        } catch {
            aviso = (error.localizedDescription, false)
        }
        trabajando = false
        confirmando = nil
    }
}

struct HojaNuevoPerfil: View {
    @Environment(\.dismiss) private var cerrar
    let crear: (String, String) async -> Void

    @State private var nombre = ""
    @State private var password = ""
    @State private var repetida = ""
    @State private var trabajando = false

    private var puede: Bool {
        nombre.trimmingCharacters(in: .whitespaces).count >= 2
            && password.count >= 8 && password == repetida && !trabajando
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Nombre", text: $nombre)
                        .textContentType(.username)
                        .autocorrectionDisabled()
                    SecureField("Contraseña", text: $password)
                        .textContentType(.newPassword)
                    SecureField("Repítela", text: $repetida)
                        .textContentType(.newPassword)
                }
                Section {

                    if !password.isEmpty && password.count < 8 {
                        Text("La contraseña tiene que tener al menos 8 caracteres.")
                            .font(.footnote).foregroundStyle(Diseno.rojo)
                    } else if !repetida.isEmpty && password != repetida {
                        Text("Las dos contraseñas no coinciden.")
                            .font(.footnote).foregroundStyle(Diseno.rojo)
                    }
                    Text("Tendrá acceso completo, igual que tú.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            .fondoDePantalla()
            .navigationTitle("Nuevo perfil")
            .navigationBarTitleDisplayMode(.inline)
            .salidaDelTeclado()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { cerrar() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(trabajando ? "Creando…" : "Crear") {
                        Task {
                            trabajando = true
                            await crear(nombre, password)
                            trabajando = false
                            cerrar()
                        }
                    }
                    .disabled(!puede)
                }
            }
        }
    }
}

struct HojaCambiarPassword: View {
    @Environment(\.dismiss) private var cerrar
    let cambiar: (String, String) async -> Void

    @State private var actual = ""
    @State private var nueva = ""
    @State private var repetida = ""
    @State private var trabajando = false

    private var puede: Bool {
        !actual.isEmpty && nueva.count >= 8 && nueva == repetida && !trabajando
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField("Contraseña de ahora", text: $actual)
                        .textContentType(.password)
                }
                Section {
                    SecureField("Nueva", text: $nueva).textContentType(.newPassword)
                    SecureField("Repítela", text: $repetida).textContentType(.newPassword)
                }
                Section {
                    if !nueva.isEmpty && nueva.count < 8 {
                        Text("Al menos 8 caracteres.")
                            .font(.footnote).foregroundStyle(Diseno.rojo)
                    } else if !repetida.isEmpty && nueva != repetida {
                        Text("Las dos no coinciden.")
                            .font(.footnote).foregroundStyle(Diseno.rojo)
                    }

                    Text("Los aparatos que ya están dentro siguen dentro. La nueva hace falta "
                         + "para entrar en uno nuevo.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            .fondoDePantalla()
            .navigationTitle("Contraseña de Ingresos")
            .navigationBarTitleDisplayMode(.inline)
            .salidaDelTeclado()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { cerrar() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(trabajando ? "Cambiando…" : "Cambiar") {
                        Task {
                            trabajando = true
                            await cambiar(actual, nueva)
                            trabajando = false
                            cerrar()
                        }
                    }
                    .disabled(!puede)
                }
            }
        }
    }
}

struct HojaPonerCodigo: View {
    @Environment(\.dismiss) private var cerrar
    let hecho: (Bool) -> Void

    @State private var primero = ""
    @State private var segundo = ""
    @State private var confirmando = false
    @State private var aviso: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: Diseno.hueco4) {
                Spacer()
                Text(confirmando ? "Repítelo" : "Elige un código")
                    .font(.headline)
                if let aviso {
                    Text(aviso).font(.footnote).foregroundStyle(Diseno.rojo)
                }
                TecladoNumerico(marcado: confirmando ? $segundo : $primero,
                                digitos: CodigoNumerico.digitos) { intento in
                    if !confirmando {
                        confirmando = true
                        aviso = nil
                        return true            
                    }
                    guard intento == primero else {
                        
                        primero = ""
                        segundo = ""
                        confirmando = false
                        aviso = "No coinciden. Empieza otra vez."
                        return false
                    }
                    let ok = CodigoNumerico.poner(intento)
                    hecho(ok)
                    cerrar()
                    return ok
                }
                Spacer()
                Spacer()
            }
            .frame(maxWidth: 340)
            .frame(maxWidth: .infinity)
            .navigationTitle("Código")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { hecho(CodigoNumerico.hayCodigo()); cerrar() }
                }
            }
        }
    }
}
