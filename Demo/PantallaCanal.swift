import SwiftUI

struct PantallaCanal: View {
    @Environment(Sesion.self) private var sesion

    @State private var suscriptores: Int?

    @State private var referidos = 0
    @State private var autoLive = true
    @State private var enlace = ""
    @State private var texto = ""
    @State private var trabajando: String?
    @State private var aviso: (texto: String, bien: Bool)?
    @State private var cargado = false

    @State private var autoLeido: Bool?

    @ScaledMetric(relativeTo: .largeTitle) private var tamCifra: CGFloat = 80

    var body: some View {
        Group {

            marcador
        }
        .navigationTitle("Canal")
        .salidaDelTeclado()
        .animation(Diseno.suave, value: aviso?.texto)
        .animation(Diseno.suave, value: trabajando)
        .onChange(of: autoLive) { _, nuevo in
            guard cargado, nuevo != autoLeido else { return }
            autoLeido = nuevo
            Task { await hacer("auto", extra: ["activo": nuevo]) }
        }
        .task { await cargar() }
        .refreshable { await cargar() }
    }

    private var marcador: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Suscriptores")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Marcador.apoyo)
                    Text(suscriptores.map(Formato.numero) ?? "—")
                        .font(.system(size: min(tamCifra, 104), weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .contentTransition(.numericText(value: Double(suscriptores ?? 0)))
                        .lineLimit(1)
                        .minimumScaleFactor(0.45)
                    if referidos > 0 {
                        Text(referidos == 1 ? "1 llegó por invitación" : "\(referidos) llegaron por invitación")
                            .font(.subheadline)
                            .foregroundStyle(Marcador.apoyo)
                    }
                }
                .redacted(reason: cargado ? [] : .placeholder)
                .accessibilityElement(children: .combine)
                .padding(.horizontal, Diseno.margen)

                if let aviso {
                    Banda(aviso)
                        .padding(.horizontal, Diseno.margen)
                        .padding(.top, Diseno.hueco2)
                }

                Toggle(isOn: $autoLive) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Avisar solo").font(.headline)
                        Text("Cuando Plataforma 1 detecte que has empezado a emitir.")
                            .font(.footnote).foregroundStyle(Marcador.apoyo)
                    }
                }
                .padding(.horizontal, Diseno.margen)
                .padding(.top, Diseno.hueco4)

                TituloDeSeccion(texto: "Publicar un mensaje")
                    .padding(.horizontal, Diseno.margen)
                VStack(spacing: Diseno.hueco2) {
                    TextField("Lo que quieras decir", text: $texto, axis: .vertical)
                        .lineLimit(3...6)
                        .padding(Diseno.hueco2)
                        .cristal(.regular, en: .rect(cornerRadius: Diseno.radioCampo))
                    Button {
                        Task { await hacer("publicar", extra: ["texto": texto]) }
                    } label: {
                        HStack {
                            if trabajando == "publicar" {
                                ProgressView().controlSize(.small)
                            } else {
                                Image(systemName: "paperplane")
                            }
                            Text("Publicar")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glass)
                    .controlSize(.large)
                    .disabled(texto.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                              || trabajando != nil)
                }
                .padding(.horizontal, Diseno.margen)
                .padding(.top, Diseno.hueco2)

                Button {
                    Task { await hacer("bienvenida") }
                } label: {
                    HStack {
                        if trabajando == "bienvenida" {
                            ProgressView().controlSize(.small)
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                        Text("Republicar la bienvenida")
                        Spacer()
                    }
                }
                .buttonStyle(.glass)
                .controlSize(.large)
                .disabled(trabajando != nil)
                .padding(.horizontal, Diseno.margen)
                .padding(.top, Diseno.hueco4)
            }
            .padding(.bottom, Diseno.hueco5)
        }
        .scrollEdgeEffectStyle(.soft, for: .top)
        .background { CampoJoya(joya: .tienda) }
    }

    private func cargar() async {
        do {
            let j = try await API.pedir("api/canal", testigo: sesion.testigo)
            suscriptores = j["suscriptores"] as? Int
            referidos = (j["referidos"] as? [Any])?.count ?? 0
            enlace = j["enlace"] as? String ?? ""
            if let a = j["auto_live"] as? [String: Any] {
                autoLive = a["activo"] as? Bool ?? true
            }
            autoLeido = autoLive
            cargado = true
        } catch {
            aviso = (error.localizedDescription, false)
            cargado = true
        }
    }

    private func hacer(_ accion: String, extra: [String: any Sendable] = [:]) async {
        trabajando = accion
        aviso = nil
        var cuerpo: [String: any Sendable] = ["accion": accion]
        cuerpo.merge(extra) { _, b in b }
        do {
            let r = try await API.pedir("api/canal/accion", metodo: "POST",
                                        cuerpo: cuerpo, testigo: sesion.testigo)
            let ok = r["ok"] as? Bool ?? false
            aviso = (r["mensaje"] as? String ?? (ok ? "Hecho." : "No se ha podido."), ok)
            if ok && accion == "publicar" { texto = "" }
        } catch {
            aviso = (error.localizedDescription, false)
        }
        trabajando = nil
    }
}
