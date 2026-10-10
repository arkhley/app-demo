import SwiftUI
import UniformTypeIdentifiers

struct ImportarPlataforma1: View {

    var clave: String = "plataforma1"
    
    var alImportar: () async -> Void

    @Environment(Sesion.self) private var sesion

    @State private var eligiendo = false
    @State private var trabajando = false
    @State private var aviso: (texto: String, bien: Bool)?
    @State private var hay = false
    @State private var resumen = ""
    @State private var explicando = false

    var body: some View {
        VStack(alignment: .leading, spacing: Diseno.hueco2) {
            if hay {
                Label(resumen, systemImage: "checkmark.seal.fill")
                    .font(.subheadline)
                    .foregroundStyle(Diseno.verde)
            } else {
                Text("Todavía no has importado nada.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: Diseno.hueco2) {
                Button {
                    eligiendo = true
                } label: {
                    Label(hay ? "Importar otro" : "Importar archivo",
                          systemImage: "square.and.arrow.down")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.glass)
                .disabled(trabajando)

                Button {
                    explicando = true
                } label: {
                    Image(systemName: "questionmark")
                        .frame(width: 44, height: 44)
                        .contentShape(.rect)
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
                .accessibilityLabel("De dónde se saca el archivo")
            }

            if trabajando {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("Importando…").font(.footnote).foregroundStyle(.secondary)
                }
            }

            if let aviso { Banda(texto: aviso.texto, bien: aviso.bien) }
        }

        .fileImporter(isPresented: $eligiendo,
                      allowedContentTypes: [.json, .plainText, .text, .data],
                      allowsMultipleSelection: false) { resultado in
            Task { await importar(resultado) }
        }
        .sheet(isPresented: $explicando) { HojaDeDondeSale(clave: clave) }
        .task { await mirarQueHay() }
    }

    private func mirarQueHay() async {
        guard let j = try? await API.pedir("api/importar/\(clave)",
                                           testigo: sesion.testigo) else { return }
        hay = j["hay"] as? Bool ?? false
        guard hay else { return }
        let dias = j["dias"] as? Int ?? 0
        let tokens = j["tokens"] as? Int ?? 0
        let desde = j["desde"] as? String ?? ""
        let hasta = j["hasta"] as? String ?? ""
        resumen = "\(dias) días · \(Formato.tokens(tokens, unidad: "tokens")) · "
            + "\(Formato.diaCorto(desde)) a \(Formato.diaCorto(hasta))"
    }

    private func importar(_ resultado: Result<[URL], Error>) async {
        aviso = nil
        guard case .success(let urls) = resultado, let url = urls.first else {
            if case .failure(let e) = resultado { aviso = (e.localizedDescription, false) }
            return
        }
        trabajando = true
        defer { trabajando = false }

        let abierto = url.startAccessingSecurityScopedResource()
        defer { if abierto { url.stopAccessingSecurityScopedResource() } }

        guard let datos = try? Data(contentsOf: url) else {
            aviso = ("No se ha podido leer el archivo.", false)
            return
        }

        guard let texto = String(data: datos, encoding: .utf8) else {
            aviso = ("No se ha podido leer el archivo como texto.", false)
            return
        }

        if clave == "plataforma1", (try? JSONSerialization.jsonObject(with: datos)) == nil {
            aviso = ("Ese archivo no es un JSON. Tiene que ser el que se baja de Plataforma 1 "
                     + "con «Descargar JSON».", false)
            return
        }

        do {
            let j = try await API.pedir("api/importar/\(clave)", metodo: "POST",
                                        cuerpo: ["archivo_texto": texto],
                                        testigo: sesion.testigo)
            let ok = j["ok"] as? Bool ?? false
            var texto = j["mensaje"] as? String ?? "Importado."
            if ok, let r = j["resumen"] as? [String: Any] {
                let tk = r["tokens"] as? Int ?? 0
                texto += " \(Formato.tokens(tk, unidad: "tokens")) en total."
            }
            aviso = (texto, ok)
            if ok {
                await mirarQueHay()
                await alImportar()
            }
        } catch {
            aviso = (error.localizedDescription, false)
        }
    }
}

private struct HojaDeDondeSale: View {
    let clave: String
    @Environment(\.dismiss) private var cerrar
    @Environment(\.tema) private var tema
    @State private var copiado = false

    private let enlace = "https://example.com"
        + "&campaign=&period=0&search_criteria=3&start_date=2020-01-01"
        + "&end_date=2030-01-01&formato=json"

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Diseno.hueco3) {
                    if clave != "plataforma1" {

                        Tarjeta {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Busca la exportación en tu panel")
                                    .font(.subheadline.weight(.semibold))
                                Text("En las estadísticas de ganancias, un botón de descargar "
                                     + "(JSON, CSV o Excel). Vale cualquier archivo que tenga "
                                     + "una fecha y los tokens de cada día.")
                                    .font(.footnote).foregroundStyle(.secondary)
                                Text("Si el que bajes no se entiende, la app te lo dirá y me "
                                     + "mandas las dos primeras líneas para ajustarlo.")
                                    .font(.footnote).foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                    } else {
                    paso(1, "Abre este enlace en el navegador, con tu Plataforma 1 iniciado.")
                    Button {
                        UIPasteboard.general.string = enlace
                        copiado = true
                        Task {
                            try? await Task.sleep(for: .seconds(1.6))
                            copiado = false
                        }
                    } label: {
                        Label(copiado ? "Copiado" : "Copiar el enlace",
                              systemImage: copiado ? "checkmark" : "doc.on.doc")
                            .contentTransition(.symbolEffect(.replace))
                            .frame(maxWidth: .infinity).padding(.vertical, 4)
                    }
                    .buttonStyle(.glass)
                    .sensoryFeedback(.success, trigger: copiado) { _, nuevo in nuevo }

                    paso(2, "Si se descarga un archivo, guárdalo.")
                    paso(3, "Si en vez de descargarse sale el texto en pantalla, guarda la "
                          + "página con «Origen de la página» (no «Archivo web» ni PDF).")
                    paso(4, "Vuelve aquí y tócale a «Importar archivo».")

                    Tarjeta {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Qué se lee del archivo").font(.subheadline.weight(.semibold))
                            Text("Solo el apartado «Tokens cobrados», que son tus tokens día "
                                 + "a día, y los cobros adelantados. Lo de afiliados no cuenta.")
                                .font(.footnote).foregroundStyle(.secondary)
                        }
                    }
                    }
                }
                .padding(Diseno.margen)
            }
            .fondoDePantalla()
            .navigationTitle("De dónde se saca")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button(role: .close) { cerrar() } }
            }
        }
    }

    private func paso(_ n: Int, _ texto: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Diseno.hueco2) {
            Text("\(n)")
                .font(.footnote.weight(.bold))
                .foregroundStyle(tema.sobreRelleno)
                .frame(width: 22, height: 22)
                .background(tema.relleno, in: .circle)
            Text(texto).font(.subheadline)
        }
    }
}
