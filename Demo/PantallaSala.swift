import SwiftUI
import WebKit

struct PantallaSala: View {
    @Environment(Sesion.self) private var sesion
    @Environment(\.scenePhase) private var fase

    @State private var estado: Sala?
    @State private var chatSala: [Mensaje] = []
    @State private var chatEncargos: [Mensaje] = []
    @State private var versionChat = ""
    @State private var usuario = ""
    @State private var pestanaChat = "sala"
    @State private var fallo: String?
    
    @State private var verVideo = false

    struct Sala: Equatable {
        var enDirecto = false
        var cuantos = 0
        var siguen24h = 0
        var dejan24h = 0
        
        var siguenTotal = 0
        var dejanTotal = 0

        var seguidores = 0
        var seguidoresBase = 0
        var minutos = 0
        var tokensHoy = 0
        var dentro: [Persona] = []
        var version = ""

        struct Persona: Equatable, Identifiable {
            let quien: String
            let desde: String
            var id: String { quien }
        }
    }

    struct Mensaje: Identifiable, Equatable {
        let id: String
        let de: String
        let texto: String
        let hora: String
    }

    var body: some View {
        contenido
            .task(id: fase) {

                guard fase == .active else { return }
                await vigilar()
            }
    }

    @ViewBuilder
    private var contenido: some View {
        SalaNueva(sala: estado, chatSala: chatSala, chatEncargos: chatEncargos, usuario: usuario)
    }

    @ViewBuilder
    private func video(_ s: Sala) -> some View {
        if s.enDirecto && !usuario.isEmpty && verVideo {
            ZStack(alignment: .topTrailing) {
                Web(url: URL(string: "https://example.com\(usuario)/")!)
                    .aspectRatio(16.0 / 9.0, contentMode: .fit)
                    .clipShape(.rect(cornerRadius: Diseno.radioTarjeta))

                Button { verVideo = false } label: {
                    Image(systemName: "xmark")
                        .accessibilityLabel("Cerrar")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)      
                        .contentShape(.rect)
                }

                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
                .padding(Diseno.hueco2)
                .accessibilityLabel("Ocultar el vídeo")
            }
        } else if s.enDirecto && !verVideo {
            Button("Ver tu directo") { verVideo = true }
                .buttonStyle(.glass)
                .controlSize(.large)
                .frame(maxWidth: .infinity)
        } else {
            Tarjeta {
                Vacio(icono: "video.slash", titulo: "No estás emitiendo",
                      detalle: "Cuando empieces, tu directo se ve aquí.")
            }
        }
    }

    private var chat: some View {
        VStack(alignment: .leading, spacing: Diseno.hueco2) {
            
            SelectorDeslizante(
                opciones: [(clave: "sala", nombre: etiqueta("Sala", chatSala.count)),
                           (clave: "encargos", nombre: etiqueta("Encargos", chatEncargos.count))],
                elegida: $pestanaChat)
                .accessibilityLabel("Qué chat")

            Tarjeta(relleno: 0) {
                let lista = pestanaChat == "sala" ? chatSala : chatEncargos
                if lista.isEmpty {
                    Vacio(icono: "bubble.left",
                          titulo: pestanaChat == "sala" ? "Nadie ha escrito todavía"
                                                        : "Ningún encargo todavía")
                } else {
                    ScrollView {
                        VStack(spacing: 0) {
                            if pestanaChat == "sala" {
                                filas(lista)
                            } else {

                                ForEach(porPersona(lista), id: \.persona) { grupo in
                                    cabeceraPersona(grupo.persona)
                                    filas(grupo.mensajes)
                                }
                            }
                        }
                    }
                    .frame(height: altoChat)
                }
            }

            Text("Para contestar, abre la sala en Plataforma 1.")
                .font(.caption).foregroundStyle(.secondary).padding(.horizontal, 4)
        }
        .animation(Diseno.suave, value: versionChat)
    }

    @ScaledMetric(relativeTo: .subheadline) private var altoChat: CGFloat = 420

    @ViewBuilder
    private func filas(_ lista: [Mensaje]) -> some View {
        ForEach(Array(lista.reversed().prefix(60).enumerated()), id: \.element.id) { i, m in
            if i > 0 { Divider().padding(.leading, Diseno.hueco3) }
            HStack(alignment: .top, spacing: Diseno.hueco2) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(m.de)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Diseno.azul)
                        Text(m.hora)
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                    Text(m.texto).font(.subheadline)
                }
                Spacer(minLength: 0)
            }
            .padding(Diseno.hueco3)
        }
    }

    private func cabeceraPersona(_ quien: String) -> some View {
        HStack {
            Text(quien.isEmpty ? "anónimo" : quien)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal, Diseno.hueco3)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity)
        .background(Color.secondary.opacity(0.10))
    }

    private func porPersona(_ lista: [Mensaje]) -> [(persona: String, mensajes: [Mensaje])] {
        var orden: [String] = []
        var porQuien: [String: [Mensaje]] = [:]
        for m in lista {
            if porQuien[m.de] == nil { orden.append(m.de) }
            porQuien[m.de, default: []].append(m)
        }
        
        return orden.reversed().map { (persona: $0, mensajes: porQuien[$0] ?? []) }
    }

    private func etiqueta(_ titulo: String, _ cuantos: Int) -> String {
        cuantos > 0 ? "\(titulo) · \(cuantos)" : titulo
    }

    private func vigilar() async {
        var seguidos = 0
        while !Task.isCancelled && fase == .active {
            do {
                let j = try await API.pedir("api/sala", testigo: sesion.testigo)
                seguidos = 0
                fallo = nil
                let version = j["version"] as? String ?? ""

                if version != estado?.version {
                    estado = leerSala(j, version: version)

                    if version.split(separator: "|").dropFirst(6).joined() != versionChat {
                        await cargarChat()
                    }
                }
                if usuario.isEmpty { await cargarChat() }
            } catch API.Fallo.sinTestigo {
                return          
            } catch {
                seguidos += 1

                if estado == nil { fallo = error.localizedDescription }
                if seguidos >= 10 { return }
            }
            try? await Task.sleep(for: .seconds(1))
        }
    }

    private func leerSala(_ j: [String: Any], version: String) -> Sala {
        var s = Sala()
        s.enDirecto = j["en_directo"] as? Bool ?? false
        s.cuantos = j["cuantos"] as? Int ?? 0
        s.siguen24h = j["siguen_24h"] as? Int ?? 0
        s.siguenTotal = j["siguen_total"] as? Int ?? 0
        s.dejanTotal = j["dejan_total"] as? Int ?? 0
        s.seguidores = j["seguidores"] as? Int ?? 0
        s.seguidoresBase = j["seguidores_base"] as? Int ?? 0
        s.dejan24h = j["dejan_24h"] as? Int ?? 0
        s.minutos = j["minutos"] as? Int ?? 0
        s.tokensHoy = j["tokens_hoy"] as? Int ?? 0
        s.dentro = ((j["dentro"] as? [[String: Any]]) ?? []).map {
            Sala.Persona(quien: $0["quien"] as? String ?? "",
                         desde: $0["desde"] as? String ?? "")
        }
        s.version = version
        return s
    }

    private func cargarChat() async {
        guard let j = try? await API.pedir("api/chat", testigo: sesion.testigo) else { return }
        func leer(_ clave: String) -> [Mensaje] {
            ((j[clave] as? [[String: Any]]) ?? []).enumerated().map { i, m in
                Mensaje(id: (m["id"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? "m\(i)",
                        de: m["de"] as? String ?? "anónimo",
                        texto: m["texto"] as? String ?? "",
                        hora: m["hora"] as? String ?? "")
            }
        }
        chatSala = leer("sala")
        chatEncargos = leer("encargos")
        versionChat = j["version"] as? String ?? ""
        usuario = j["usuario"] as? String ?? ""
    }
}

struct Web: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        let vista = WKWebView(frame: .zero, configuration: config)
        vista.isOpaque = false
        vista.backgroundColor = .clear
        vista.scrollView.isScrollEnabled = false
        vista.load(URLRequest(url: url))
        return vista
    }

    func updateUIView(_ vista: WKWebView, context: Context) {
        if vista.url != url { vista.load(URLRequest(url: url)) }
    }
}
