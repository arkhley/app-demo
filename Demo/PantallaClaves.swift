import SwiftUI
import UniformTypeIdentifiers
#if canImport(UIKit)
import UIKit
#endif

struct PantallaClaves: View {
    @Environment(Sesion.self) private var sesion

    @State private var entradas: [Entrada] = []
    @State private var estado: Carga<Bool> = .cargando
    @State private var editandoEntrada: Entrada?
    @State private var creando = false
    @State private var aviso: (texto: String, bien: Bool)?
    
    @State private var visible: String?
    @State private var secreto = ""
    @State private var copiada: String?
    
    @State private var pidiendoPara: Entrada?
    
    @State private var editando = false

    @State private var borrando: Entrada?

    struct Entrada: Identifiable, Equatable {
        let id: String
        let sitio: String
        let usuario: String
        let notas: String
        let actualizado: String
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Diseno.hueco3) {
                if let aviso { Banda(aviso) }

                switch estado {
                case .cargando:
                    Tarjeta { Vacio(icono: "key", titulo: "Cargando…") }
                        .redacted(reason: .placeholder)
                case .error(let qué):
                    Tarjeta { Vacio(icono: "wifi.exclamationmark",
                                    titulo: "No se ha podido cargar", detalle: qué) }
                case .vacio:
                    Tarjeta { Vacio(icono: "key", titulo: "Ninguna guardada",
                                    detalle: "Guarda aquí tus usuarios y contraseñas.") }
                default:
                    Grupo {
                        ForEach(entradas) { e in fila(e) }
                    }
                }

                Button("Guardar una nueva", systemImage: "plus") { creando = true }
                    .buttonStyle(.glass)
                    .controlSize(.large)

                Text("Se guardan cifradas en tu servidor. Cualquiera con acceso al servidor "
                     + "podría descifrarlas.")
                    .font(.caption).foregroundStyle(.secondary).padding(.horizontal, 4)
            }
            .padding(.horizontal, Diseno.margen)
            .padding(.vertical, Diseno.hueco2)
        }
        .fondoDePantalla()
        .navigationTitle("Contraseñas")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if !entradas.isEmpty {
                    Button(editando ? "Listo" : "Editar") {
                        withAnimation(Diseno.suave) { editando.toggle() }
                    }
                }
            }
        }
        .sheet(item: $pidiendoPara) { e in
            HojaIdentificarse(motivo: "Para ver la contraseña de \(e.sitio)") { vale in
                if vale { Task { await enseñar(e) } }
                else { aviso = ("No se ha podido comprobar quién eres.", false) }
            }
        }
        .sheet(isPresented: $creando) {
            HojaClave(entrada: nil) { cuerpo in await hacer(cuerpo) }
        }
        .sheet(item: $editandoEntrada) { e in
            HojaClave(entrada: e) { cuerpo in await hacer(cuerpo) }
        }
        .confirmationDialog("¿Borrar la de \(borrando?.sitio ?? "")?",
                            isPresented: .init(get: { borrando != nil },
                                               set: { if !$0 { borrando = nil } }),
                            titleVisibility: .visible) {
            Button("Borrar", role: .destructive) {
                if let e = borrando { Task { await hacer(["accion": "borrar", "id": e.id]) } }
                borrando = nil
            }
            Button("Cancelar", role: .cancel) { borrando = nil }
        } message: {
            Text("No se puede recuperar.")
        }
        .animation(Diseno.suave, value: visible)
        .animation(Diseno.suave, value: editando)
        .animation(Diseno.suave, value: entradas)
        .task { await cargar() }

        .onDisappear {
            visible = nil
            secreto = ""
        }
    }

    private func fila(_ e: Entrada) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(e.sitio).fontWeight(.medium)
                    if !e.usuario.isEmpty {
                        Text(e.usuario).font(.footnote).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if editando {
                    Button { editando = false; editandoEntrada = e } label: {
                        Image(systemName: "pencil")
                            .font(.footnote.weight(.semibold))
                            .frame(width: 44, height: 44)
                            .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Editar")
                    Button {
                        borrando = e
                    } label: {
                        Image(systemName: "trash")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(Diseno.rojo)
                            .frame(width: 44, height: 44)
                            .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Borrar")
                } else {
                    Button {
                        Task { await verOcultar(e) }
                    } label: {
                        Image(systemName: visible == e.id ? "eye.slash" : "eye")
                            .font(.footnote.weight(.semibold))
                            .frame(width: 44, height: 44)
                            .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(visible == e.id ? "Ocultar la contraseña"
                                                        : "Ver la contraseña")
                }
            }

            if visible == e.id {
                HStack {
                    Text(secreto.isEmpty ? "—" : secreto)
                        .font(.system(.subheadline, design: .monospaced))
                        .textSelection(.enabled)
                    Spacer()
                    Button {

                        UIPasteboard.general.setItems(
                            [[UTType.plainText.identifier: secreto]],
                            options: [.localOnly: true,
                                      .expirationDate: Date().addingTimeInterval(120)])
                        copiada = e.id
                        Task {
                            try? await Task.sleep(for: .seconds(1.4))
                            if copiada == e.id { copiada = nil }
                        }
                    } label: {
                        Image(systemName: copiada == e.id ? "checkmark" : "doc.on.doc")
                            .font(.caption.weight(.semibold))
                            .contentTransition(.symbolEffect(.replace))
                            .accessibilityLabel(copiada == e.id ? "Copiada" : "Copiar")
                            .frame(width: 30, height: 30)
                    }
                    .buttonStyle(.glass)
                    .sensoryFeedback(.success, trigger: copiada)
                    .accessibilityLabel("Copiar la contraseña")
                }
                .padding(.top, 2)
            }

            if !e.notas.isEmpty {
                Text(e.notas).font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(Diseno.hueco3)
        .contentShape(.rect)
        .contextMenu {
            Button("Editar", systemImage: "pencil") { editandoEntrada = e }
            Button("Borrar", systemImage: "trash", role: .destructive) {
                borrando = e
            }
        }
    }

    private func verOcultar(_ e: Entrada) async {
        if visible == e.id {
            visible = nil
            secreto = ""
            return
        }

        pidiendoPara = e
        return
    }

    private func enseñar(_ e: Entrada) async {
        do {
            let j = try await API.pedir("api/claves/\(e.id)", testigo: sesion.testigo)
            secreto = j["secreto"] as? String ?? ""
            visible = e.id
        } catch {
            aviso = (error.localizedDescription, false)
        }
    }

    private func cargar() async {
        do {
            let j = try await API.pedir("api/claves", testigo: sesion.testigo)
            entradas = ((j["entradas"] as? [[String: Any]]) ?? []).map {
                Entrada(id: $0["id"] as? String ?? "",
                        sitio: $0["sitio"] as? String ?? "",
                        usuario: $0["usuario"] as? String ?? "",
                        notas: $0["notas"] as? String ?? "",
                        actualizado: $0["actualizado"] as? String ?? "")
            }
            estado = entradas.isEmpty ? .vacio : .listo(true)
        } catch {
            estado.fallar(error)
        }
    }

    private func hacer(_ cuerpo: [String: any Sendable]) async {
        do {
            let j = try await API.pedir("api/claves", metodo: "POST",
                                        cuerpo: cuerpo, testigo: sesion.testigo)
            aviso = (j["mensaje"] as? String ?? "Hecho.", j["ok"] as? Bool ?? true)
            visible = nil
            secreto = ""
            await cargar()
        } catch {
            aviso = (error.localizedDescription, false)
        }
    }
}

struct HojaClave: View {
    @Environment(\.dismiss) private var cerrar
    let entrada: PantallaClaves.Entrada?
    let guardar: ([String: any Sendable]) async -> Void

    @State private var sitio = ""
    @State private var usuario = ""
    @State private var secreto = ""
    @State private var notas = ""
    @State private var trabajando = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Sitio", text: $sitio).autocorrectionDisabled()
                    TextField("Usuario o correo", text: $usuario)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                    SecureField(entrada == nil ? "Contraseña" : "Contraseña nueva",
                                text: $secreto)
                }
                Section {
                    TextField("Notas", text: $notas, axis: .vertical).lineLimit(2...5)
                    if entrada != nil {
                        
                        Text("Deja la contraseña en blanco para conservar la de antes.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                }
            }
            .fondoDePantalla()
            .navigationTitle(entrada == nil ? "Nueva" : "Editar")
            .navigationBarTitleDisplayMode(.inline)
            .salidaDelTeclado()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { cerrar() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task {
                            trabajando = true
                            await guardar(["accion": "guardar",
                                           "id": entrada?.id ?? "",
                                           "sitio": sitio, "usuario": usuario,
                                           "secreto": secreto, "notas": notas])
                            trabajando = false
                            cerrar()
                        }
                    } label: {
                        MarcaConfirmar(trabajando: trabajando)
                    }
                    .disabled(sitio.trimmingCharacters(in: .whitespaces).count < 2 || trabajando)
                }
            }
            .onAppear {
                sitio = entrada?.sitio ?? ""
                usuario = entrada?.usuario ?? ""
                notas = entrada?.notas ?? ""
            }
        }
    }
}
