import SwiftUI

struct PantallaPlataformas: View {
    @Environment(Sesion.self) private var sesion

    @State private var lista: [Ficha] = []
    @State private var estado: Carga<Bool> = .cargando
    @State private var anadiendo = false
    @State private var nombreNuevo = ""
    @State private var nuevaEnDinero = false

    @State private var catalogo: [DelCatalogo] = []
    @State private var guardando = false
    @State private var aviso: (texto: String, bien: Bool)?
    @State private var borrando: Ficha?

    struct DelCatalogo: Identifiable, Equatable {
        let clave: String
        let nombre: String
        
        let enDinero: Bool
        var id: String { clave }
    }

    struct Ficha: Identifiable, Equatable {
        let clave: String
        let nombre: String
        let aMano: Bool
        let borrable: Bool
        let ultimoDia: String
        let error: String
        let ultimoOK: String
        var id: String { clave }
    }

    var body: some View {
        Group {

            marcador
        }
        .navigationTitle("Gestión de plataformas")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {

                Menu {
                    ForEach(catalogo) { p in
                        Button {
                            Task { await anadir(p.nombre, enDinero: p.enDinero) }
                        } label: {
                            Label(p.nombre,
                                  systemImage: p.enDinero ? "eurosign.circle" : "circlebadge.2")
                        }
                    }
                    if !catalogo.isEmpty { Divider() }
                    Button("Otra…", systemImage: "square.and.pencil") {
                        nombreNuevo = ""
                        anadiendo = true
                    }
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Añadir plataforma")
            }
        }
        .sheet(isPresented: $anadiendo) { hojaNueva.hojaQueChoca() }
        .confirmationDialog("¿Borrar \(borrando?.nombre ?? "")?",
                            isPresented: .init(get: { borrando != nil },
                                               set: { if !$0 { borrando = nil } }),
                            titleVisibility: .visible) {
            Button("Borrar con todo lo apuntado", role: .destructive) {
                if let b = borrando { Task { await hacer(["accion": "borrar", "clave": b.clave]) } }
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Se van sus días, sus ajustes y su histórico. No se puede deshacer.")
        }
        .animation(Diseno.suave, value: lista)
        .animation(Diseno.suave, value: aviso?.texto)
        .task { await cargar() }
        .refreshable { await cargar() }
    }

    private var marcador: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                switch estado {
                case .cargando:
                    Vacio(icono: "square.grid.2x2", titulo: "Cargando…")
                        .redacted(reason: .placeholder)
                        .padding(.top, Diseno.hueco5)
                case .error(let qué):
                    Vacio(icono: "wifi.exclamationmark", titulo: "No se ha podido cargar", detalle: qué)
                        .padding(.top, Diseno.hueco5)
                default:
                    lineaDeApoyo
                        .padding(.horizontal, Diseno.margen)
                    if let aviso {
                        Banda(aviso)
                            .padding(.horizontal, Diseno.margen)
                            .padding(.top, Diseno.hueco2)
                    }
                    VStack(spacing: 0) {
                        ForEach(Array(lista.enumerated()), id: \.element.id) { i, f in
                            if i > 0 { Divider().padding(.leading, 22) }
                            enlace(f) { filaEnCampo(f) }
                        }
                    }
                    .padding(.horizontal, Diseno.margen)
                    .padding(.top, Diseno.hueco3)
                }
            }
            .padding(.bottom, Diseno.hueco5)
        }
        .scrollEdgeEffectStyle(.soft, for: .top)
        .background { CampoJoya(joya: .todo) }
    }

    @ViewBuilder
    private var lineaDeApoyo: some View {
        let caidas = lista.filter { !$0.error.isEmpty }.count
        HStack(spacing: 6) {
            if caidas > 0 {
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundStyle(.white, Diseno.rojoRelleno)
            }
            Text((lista.count == 1 ? "1 plataforma" : "\(lista.count) plataformas") + " · "
                 + (caidas == 0 ? (lista.count == 1 ? "al día" : "todas al día")
                    : caidas == 1 ? "1 sin conexión" : "\(caidas) sin conexión"))
        }
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(Marcador.apoyo)
    }

    private func filaEnCampo(_ f: Ficha) -> some View {
        HStack(spacing: Diseno.hueco2) {
            PuntoDeArea(color: Diseno.colorDePlataforma(f.clave))
                .frame(minWidth: 10)
            VStack(alignment: .leading, spacing: 2) {
                Text(f.nombre)
                    .font(.headline)
                    .foregroundStyle(Color.primary)
                HStack(spacing: 5) {
                    if !f.error.isEmpty {
                        Image(systemName: "exclamationmark.circle.fill")
                            .foregroundStyle(.white, Diseno.rojoRelleno)
                    }
                    Text(pie(f))
                }
                .font(.footnote)
                .foregroundStyle(Marcador.apoyo)
            }
            Spacer(minLength: Diseno.hueco1)
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Marcador.apoyo)
                .accessibilityHidden(true)
        }
        .padding(.vertical, 12)
        .contentShape(.rect)
    }

    @ViewBuilder
    private func enlace<Etiqueta: View>(_ f: Ficha, @ViewBuilder etiqueta: () -> Etiqueta) -> some View {
        if f.clave == "tienda" {
            NavigationLink { PantallaAjustesTienda() } label: { etiqueta() }
                .buttonStyle(Hundirse())
        } else if f.clave == "plataforma1" {
            NavigationLink { PantallaAjustesP1() } label: { etiqueta() }
                .buttonStyle(Hundirse())
                .contextMenu { if f.borrable { botonBorrar(f) } }
        } else if f.aMano {
            NavigationLink { PantallaAjustesManual(clave: f.clave) } label: { etiqueta() }
                .buttonStyle(Hundirse())
                .contextMenu { if f.borrable { botonBorrar(f) } }
        }
    }

    private func botonBorrar(_ f: Ficha) -> some View {
        Button("Borrar \(f.nombre)", systemImage: "trash", role: .destructive) {
            borrando = f
        }
    }

    private func pie(_ f: Ficha) -> String {
        if !f.error.isEmpty { return "Sin conexión" }
        if f.aMano {
            return f.ultimoDia.isEmpty ? "Sin días apuntados"
                                       : "Último día: \(Formato.diaCorto(f.ultimoDia))"
        }
        if f.ultimoOK.count >= 16 {
            return "Al día · " + String(f.ultimoOK.dropFirst(11).prefix(5))
        }
        return "Al día"
    }

    private var hojaNueva: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Diseno.hueco3) {
                    Tarjeta {
                        VStack(alignment: .leading, spacing: Diseno.hueco2) {
                            Campo(titulo: "Nombre", valor: $nombreNuevo,
                                  pista: "Plataforma 3")
                            Toggle("Se apunta en euros", isOn: $nuevaEnDinero)
                            Text(nuevaEnDinero
                                 ? "Apuntarás los euros de cada día."
                                 : "Apuntarás los tokens de cada día, como en Plataforma 2.")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    Button {
                        Task {
                            await anadir(nombreNuevo, enDinero: nuevaEnDinero)
                            anadiendo = false
                        }
                    } label: {
                        HStack {
                            if guardando { ProgressView().controlSize(.small).tint(.white) }
                            else { Image(systemName: "plus") }
                            Text("Añadir")
                        }
                        .frame(maxWidth: .infinity).padding(.vertical, 4)
                    }
                    .buttonStyle(.glassProminent)
                    .controlSize(.large)
                    .rellenoDelTema(nil)
                    .disabled(guardando || nombreNuevo.trimmingCharacters(in: .whitespaces).count < 2)
                }
                .padding(.horizontal, Diseno.margen)
                .padding(.vertical, Diseno.hueco2)
            }
            
            .navigationTitle("Añadir plataforma")
            .salidaDelTeclado()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancelar") { anadiendo = false }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func cargar() async {
        do {
            let j = try await API.pedir("api/plataformas", testigo: sesion.testigo)
            lista = ((j["lista"] as? [[String: Any]]) ?? []).compactMap { p in
                let clave = p["clave"] as? String ?? ""

                guard clave != "todo" else { return nil }
                let e = (p["estado"] as? [String: Any]) ?? [:]
                return Ficha(clave: clave,
                             nombre: p["nombre"] as? String ?? clave,
                             aMano: p["a_mano"] as? Bool ?? false,
                             borrable: p["borrable"] as? Bool ?? false,
                             ultimoDia: p["ultimo_dia"] as? String ?? "",
                             error: e["error"] as? String ?? "",
                             ultimoOK: e["ultimo_ok"] as? String ?? "")
            }
            catalogo = ((j["catalogo"] as? [[String: Any]]) ?? []).map {
                DelCatalogo(clave: $0["clave"] as? String ?? "",
                            nombre: $0["nombre"] as? String ?? "",
                            enDinero: $0["en_dinero"] as? Bool ?? false)
            }
            estado = .listo(true)
        } catch {
            estado.fallar(error)
        }
    }

    private func anadir(_ nombre: String, enDinero: Bool) async {
        await hacer(["accion": "crear", "nombre": nombre, "en_dinero": enDinero])
    }

    private func hacer(_ cuerpo: [String: any Sendable]) async {
        bajarTeclado()
        guardando = true
        aviso = nil
        do {
            let j = try await API.pedir("api/plataformas", metodo: "POST",
                                        cuerpo: cuerpo, testigo: sesion.testigo)
            aviso = (j["mensaje"] as? String ?? "", j["ok"] as? Bool ?? false)
            await cargar()
        } catch {
            aviso = (error.localizedDescription, false)
        }
        borrando = nil
        guardando = false
    }
}

struct BotonPDF: View {
    @Environment(Sesion.self) private var sesion
    let ruta: String
    let nombre: String
    var titulo: String = "Comprobante"

    @State private var archivo: URL?
    @State private var bajando = false
    @State private var fallo: String?

    var body: some View {
        Group {
            if let archivo {
                ShareLink(item: archivo) {
                    etiqueta("square.and.arrow.up", "Compartir \(titulo.lowercased())")
                }
            } else {
                Button { Task { await bajar() } } label: {
                    etiqueta(bajando ? "arrow.down.circle" : "doc.richtext", titulo)
                }
                .disabled(bajando)
            }
        }
        .buttonStyle(.glass)
        .controlSize(.large)
        .alert("No se ha podido", isPresented: .init(
            get: { fallo != nil }, set: { if !$0 { fallo = nil } }
        )) {
            Button("Vale", role: .cancel) {}
        } message: {
            Text(fallo ?? "")
        }
    }

    private func etiqueta(_ icono: String, _ texto: String) -> some View {
        HStack {
            if bajando { ProgressView().controlSize(.small) }
            else { Image(systemName: icono) }
            Text(texto)
            Spacer()
        }
        .padding(.vertical, 4)
    }

    private func bajar() async {
        bajando = true
        do {
            archivo = try await API.bajarPDF(ruta, nombre: nombre, testigo: sesion.testigo)
        } catch {
            fallo = error.localizedDescription
        }
        bajando = false
    }
}
