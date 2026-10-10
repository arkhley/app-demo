import PhotosUI
import SwiftUI

struct PantallaCategoria: View {
    @Environment(Sesion.self) private var sesion
    let clave: String
    let nombre: String

    @State private var videos: [Video] = []
    @State private var vetados: [Cliente] = []
    @State private var clientes: [Cliente] = []
    @State private var estado: Carga<Bool> = .cargando
    @State private var eligiendo: PhotosPickerItem?
    @State private var subiendo = false
    @State private var aviso: (texto: String, bien: Bool)?
    @State private var vetando = false
    
    @State private var maxSubidaMB = 50
    
    @State private var borrando: Video?

    struct Video: Identifiable, Equatable {
        let id: String
        let titulo: String
        let vendidos: Int
        
        var vetados: Int = 0
    }

    struct Cliente: Identifiable, Equatable {
        let id: String
        let nombre: String
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Diseno.hueco3) {
                if let aviso { Banda(aviso) }

                switch estado {
                case .cargando:
                    Tarjeta { Vacio(icono: "film", titulo: "Cargando…") }
                        .redacted(reason: .placeholder)
                case .error(let qué):
                    Tarjeta { Vacio(icono: "wifi.exclamationmark",
                                    titulo: "No se ha podido cargar", detalle: qué) }
                default:
                    listaVideos
                    subir
                    seccionVetados
                }
            }
            .padding(.horizontal, Diseno.margen)
            .padding(.vertical, Diseno.hueco2)
        }
        
        .fondoDeCampo(.tienda)
        .navigationTitle(nombre)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $vetando) {
            HojaVetar(clientes: clientes,
                      yaVetados: Set(vetados.map(\.id)),
                      videos: videos) { id, videoID in

                var cuerpo: [String: any Sendable] = ["accion": "vetar", "key": clave,
                                                      "user_id": id, "vetar": true]
                if let videoID { cuerpo["video_id"] = videoID }
                await hacer(cuerpo)
            }
        }
        .confirmationDialog("¿Borrar «\(borrando.map { $0.titulo.isEmpty ? "Sin título" : $0.titulo } ?? "")»?",
                            isPresented: .init(get: { borrando != nil },
                                               set: { if !$0 { borrando = nil } }),
                            titleVisibility: .visible) {
            Button("Borrar el vídeo", role: .destructive) {
                if let v = borrando {
                    Task { await hacer(["accion": "borrar_video", "key": clave, "video_id": v.id]) }
                }
                borrando = nil
            }
            Button("Cancelar", role: .cancel) { borrando = nil }
        } message: {
            Text("Se borra también del canal de Tienda. No se puede deshacer.")
        }
        .animation(Diseno.suave, value: videos)
        .animation(Diseno.suave, value: vetados)
        .task { await cargar() }
        .refreshable { await cargar() }
    }

    @ViewBuilder
    private var listaVideos: some View {
        if videos.isEmpty {
            Tarjeta { Vacio(icono: "film", titulo: "Ningún vídeo todavía",
                            detalle: "Sube uno desde aquí o desde el bot de Tienda.") }
        } else {
            Tarjeta(relleno: 0) {
                VStack(spacing: 0) {
                    ForEach(Array(videos.enumerated()), id: \.element.id) { i, v in
                        if i > 0 { Divider().padding(.leading, Diseno.hueco3) }
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(v.titulo.isEmpty ? "Sin título" : v.titulo)
                                HStack(spacing: 8) {
                                    if v.vendidos > 0 {
                                        Text(v.vendidos == 1 ? "1 vendido" : "\(v.vendidos) vendidos")
                                    }
                                    if v.vetados > 0 {
                                        Text(v.vetados == 1 ? "1 vetado" : "\(v.vetados) vetados")
                                            .foregroundStyle(Diseno.rojo)
                                    }
                                }
                                .font(.footnote).foregroundStyle(.apoyo)
                            }
                            Spacer()
                        }
                        .padding(Diseno.hueco3)
                        .contextMenu {
                            Button("Borrar el vídeo", systemImage: "trash", role: .destructive) {
                                borrando = v
                            }
                        }
                    }
                }
                
                .padding(.horizontal, -Diseno.hueco3)
            }
        }
    }

    private var subir: some View {
        VStack(spacing: 6) {
            PhotosPicker(selection: $eligiendo, matching: .videos) {
                HStack {
                    if subiendo { ProgressView().controlSize(.small) }
                    else { Image(systemName: "arrow.up.circle") }
                    Text(subiendo ? "Subiendo…" : "Subir un vídeo")
                }
                .frame(maxWidth: .infinity).padding(.vertical, 4)
            }
            .buttonStyle(.glass)
            .controlSize(.large)
            .disabled(subiendo)
            .onChange(of: eligiendo) { _, nuevo in
                guard let nuevo else { return }
                Task { await subirVideo(nuevo) }
            }

            Text(maxSubidaMB >= 1000
                 ? "Hasta \(maxSubidaMB / 1000) GB."
                 : "Hasta \(maxSubidaMB) MB. Los más grandes, desde el bot de Tienda.")
                .font(.caption).foregroundStyle(.apoyo)
        }
    }

    private var seccionVetados: some View {
        VStack(alignment: .leading, spacing: Diseno.hueco2) {
            HStack {
                Text("No pueden comprar").font(.headline)
                Spacer()
                
                Button("Añadir", systemImage: "plus") { vetando = true }
                    .font(.subheadline)
                    .buttonStyle(.glass)
            }
            .padding(.leading, 0)

            if vetados.isEmpty {
                Tarjeta { Vacio(icono: "person.2", titulo: "Nadie",
                                detalle: "Todos tus clientes pueden comprar de esta categoría.") }
            } else {
                Tarjeta(relleno: 0) {
                    VStack(spacing: 0) {
                        ForEach(Array(vetados.enumerated()), id: \.element.id) { i, c in
                            if i > 0 { Divider().padding(.leading, Diseno.hueco3) }
                            HStack {
                                Text(c.nombre)
                                Spacer()
                                Button("Quitar") {
                                    Task { await hacer(["accion": "vetar", "key": clave,
                                                        "user_id": c.id, "vetar": false]) }
                                }
                                .font(.footnote)
                                .buttonStyle(.glass)
                            }
                            .padding(Diseno.hueco3)
                        }
                    }
                    .padding(.horizontal, -Diseno.hueco3)
                }
            }
            
            Text("A quien esté aquí le sale «no quedan vídeos», no que está vetado.")
                .font(.caption).foregroundStyle(.apoyo).padding(.horizontal, 0)
        }
    }

    private func subirVideo(_ elegido: PhotosPickerItem) async {
        subiendo = true
        aviso = nil
        defer { subiendo = false; eligiendo = nil }
        do {
            guard let datos = try await elegido.loadTransferable(type: Data.self) else {
                aviso = ("No se ha podido leer el vídeo.", false)
                return
            }
            let j = try await API.subirVideo(datos, categoria: clave, titulo: "",
                                             maxMB: maxSubidaMB, testigo: sesion.testigo)
            aviso = (j["mensaje"] as? String ?? "Subido.", j["ok"] as? Bool ?? true)
            await cargar()
        } catch {
            aviso = (error.localizedDescription, false)
        }
    }

    private func cargar() async {
        do {
            let j = try await API.pedir("api/videos/\(clave)", testigo: sesion.testigo)
            videos = ((j["videos"] as? [[String: Any]]) ?? []).map {
                Video(id: $0["id"] as? String ?? "",
                      titulo: $0["titulo"] as? String ?? "",
                      vendidos: ($0["purchased_by"] as? [Any])?.count ?? 0,
                      vetados: ($0["vetados"] as? [Any])?.count ?? 0)
            }
            vetados = ((j["vetados"] as? [[String: Any]]) ?? []).map {
                Cliente(id: $0["id"] as? String ?? "", nombre: $0["nombre"] as? String ?? "")
            }
            maxSubidaMB = j["max_subida_mb"] as? Int ?? 50
            clientes = ((j["clientes"] as? [[String: Any]]) ?? []).map {
                Cliente(id: $0["id"] as? String ?? "", nombre: $0["usuario"] as? String ?? "")
            }
            estado = .listo(true)
        } catch {
            estado.fallar(error)
        }
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
}

struct HojaVetar: View {
    @Environment(\.dismiss) private var cerrar
    let clientes: [PantallaCategoria.Cliente]
    let yaVetados: Set<String>
    let videos: [PantallaCategoria.Video]
    
    let vetar: (String, String?) async -> Void

    @State private var busca = ""
    
    @State private var alcance = ""

    private var filtrados: [PantallaCategoria.Cliente] {

        let libres = alcance.isEmpty ? clientes.filter { !yaVetados.contains($0.id) } : clientes
        guard !busca.isEmpty else { return libres }
        return libres.filter { $0.nombre.localizedCaseInsensitiveContains(busca) }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("Dónde", selection: $alcance) {
                        Text("Toda la categoría").tag("")
                        ForEach(videos) { v in
                            Text(v.titulo.isEmpty ? "Sin título" : v.titulo).tag(v.id)
                        }
                    }
                    .pickerStyle(.menu)
                }
                Section {
                    ForEach(filtrados) { c in
                        Button {
                            Task {
                                await vetar(c.id, alcance.isEmpty ? nil : alcance)
                                cerrar()
                            }
                        } label: {
                            HStack {
                                Text(c.nombre)
                                Spacer()
                                Image(systemName: "person.badge.minus")
                                    .foregroundStyle(Diseno.rojo)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .searchable(text: $busca, prompt: "Buscar cliente")
            .overlay {
                if filtrados.isEmpty {
                    
                    Vacio(icono: "person.2",
                          titulo: clientes.isEmpty ? "Ningún cliente todavía" : "Ninguno más")
                }
            }
            .fondoDePantalla()
            .navigationTitle("Vetar a alguien")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { cerrar() }
                }
            }
        }
    }
}
