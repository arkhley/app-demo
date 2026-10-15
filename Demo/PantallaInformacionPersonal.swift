import SwiftUI
import PhotosUI

struct PantallaInformacionPersonal: View {
    @Environment(Sesion.self) private var sesion

    @State private var nombre = ""
    @State private var telefono = ""
    @State private var telefonoBonito = ""
    @State private var correo = ""
    
    @State private var original: [String: String] = [:]

    @State private var foto: UIImage?
    @State private var eligiendoFoto: PhotosPickerItem?
    @State private var subiendoFoto = false
    @State private var guardando = false
    @State private var editando = false
    @State private var preguntandoSalir = false
    @State private var copiado = false
    @State private var aviso: (texto: String, bien: Bool)?

    @ScaledMetric(relativeTo: .largeTitle) private var ladoAvatar: CGFloat = 108

    @ScaledMetric(relativeTo: .body) private var anchoEtiqueta: CGFloat = 78

    var body: some View {
        ScrollView {
            VStack(spacing: Diseno.hueco3) {
                cabecera

                Grupo {
                    campo("Nombre", texto: $nombre, pista: "Tu nombre")
                    filaTelefono
                    campo("Correo", texto: $correo, pista: "demo@example.com",
                          teclado: .emailAddress)
                }

                if let aviso { Banda(aviso) }
            }
            .padding(.horizontal, Diseno.margen)
            .padding(.vertical, Diseno.hueco2)
        }
        .fondoDePantalla()
        .navigationTitle("Información personal")

        .navigationBarBackButtonHidden(editando)
        .toolbar {

            if editando {
                ToolbarItem(placement: .topBarLeading) {
                    Button(role: .close) { intentarSalir() }
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                if editando {
                    Button(role: .confirm) { Task { await guardar() } }

                        .disabled(!hayCambios || guardando)
                } else {
                    Button("Editar") { editando = true }
                }
            }
        }
        .confirmationDialog("¿Descartar los cambios?", isPresented: $preguntandoSalir,
                            titleVisibility: .visible) {
            Button("No guardar cambios", role: .destructive) { descartar() }
            Button("Seguir editando", role: .cancel) {}
        }

        .salidaDelTeclado()
        .navigationBarTitleDisplayMode(.inline)
        .animation(Diseno.suave, value: copiado)
        .task { await cargar() }
    }

    private var hayCambios: Bool {
        nombre != original["nombre"] || telefono != original["telefono"]
            || correo != original["correo"]
    }

    private var cabecera: some View {
        VStack(spacing: Diseno.hueco2) {
            Group {
                if let foto {
                    Image(uiImage: foto)
                        .resizable().scaledToFill()
                        .frame(width: ladoAvatar, height: ladoAvatar)
                        .clipShape(.circle)
                } else {
                    Text(String(nombre.prefix(1)).uppercased())
                        .font(.system(size: ladoAvatar * 0.4, weight: .medium, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(width: ladoAvatar, height: ladoAvatar)
                        .background(LinearGradient(colors: [Diseno.azul, Diseno.morado],
                                                   startPoint: .topLeading,
                                                   endPoint: .bottomTrailing),
                                    in: .circle)
                }
            }
            .overlay {
                if subiendoFoto {
                    ZStack {
                        Circle().fill(.black.opacity(0.35))
                        ProgressView().tint(.white)
                    }
                }
            }

            PhotosPicker(selection: $eligiendoFoto, matching: .images) {
                Text("Cambiar")
            }
            .buttonStyle(.glass)
            .tint(Diseno.azul)
            .onChange(of: eligiendoFoto) { _, nueva in
                guard let nueva else { return }
                Task { await subirFoto(nueva) }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, Diseno.hueco2)
        .padding(.bottom, Diseno.hueco3)
    }

    private func campo(_ etiqueta: String, texto: Binding<String>, pista: String,
                       teclado: UIKeyboardType = .default) -> some View {
        HStack(spacing: Diseno.hueco2) {
            Text(etiqueta)
                .foregroundStyle(.secondary)
                .frame(width: anchoEtiqueta, alignment: .leading)
            TextField(pista, text: texto)
                .disabled(!editando)
                .keyboardType(teclado)
                .textInputAutocapitalization(teclado == .emailAddress ? .never : .words)
                .autocorrectionDisabled(teclado == .emailAddress)
        }
        .padding(Diseno.hueco3)
    }

    private var filaTelefono: some View {
        HStack(spacing: Diseno.hueco2) {
            Text("Teléfono")
                .foregroundStyle(.secondary)
                .frame(width: anchoEtiqueta, alignment: .leading)
            TextField("+34 600 11 12 22", text: $telefono)
                .disabled(!editando)
                .keyboardType(.phonePad)
                .textContentType(.telephoneNumber)
            if !telefonoBonito.isEmpty {
                Button {
                    UIPasteboard.general.string = original["telefono"] ?? telefono
                    copiado = true
                    Task {
                        try? await Task.sleep(for: .seconds(1.4))
                        copiado = false
                    }
                } label: {

                    Image(systemName: copiado ? "checkmark" : "doc.on.doc")
                        .font(.footnote.weight(.semibold))
                        .contentTransition(.symbolEffect(.replace))
                        .accessibilityLabel(copiado ? "Copiado" : "Copiar el teléfono")
                        .foregroundStyle(copiado ? Diseno.verde : Diseno.azul)
                        .frame(width: 26, height: 26)
                }
                .buttonStyle(.glass)
                .contentShape(.rect)
                .sensoryFeedback(.success, trigger: copiado)
                .accessibilityLabel("Copiar el teléfono")
            }
        }

        .padding(Diseno.hueco3)
    }

    private func cargar() async {
        do {
            let j = try await API.pedir("api/perfil", testigo: sesion.testigo)
            nombre = j["nombre"] as? String ?? sesion.nombre
            telefono = j["telefono"] as? String ?? ""
            telefonoBonito = j["telefono_bonito"] as? String ?? telefono
            correo = j["correo"] as? String ?? ""
            original = ["nombre": nombre, "telefono": telefono, "correo": correo]
            if j["foto"] as? Bool ?? false {
                foto = await API.bajarImagen("api/perfil/foto", testigo: sesion.testigo)
            } else {
                foto = nil
            }
        } catch {
            aviso = (error.localizedDescription, false)
        }
    }

    private func intentarSalir() {
        if hayCambios {
            preguntandoSalir = true
        } else {
            editando = false
        }
    }

    private func descartar() {
        nombre = original["nombre"] ?? ""
        telefono = original["telefono"] ?? ""
        correo = original["correo"] ?? ""
        editando = false
    }

    private func guardar() async {
        bajarTeclado()
        guardando = true
        aviso = nil
        defer { guardando = false }

        let cambios: [(String, String)] = [
            ("nombre", nombre), ("telefono", telefono), ("correo", correo),
        ].filter { original[$0.0] != $0.1 }

        for (clave, valor) in cambios {
            do {
                let j = try await API.pedir("api/perfil", metodo: "POST",
                                            cuerpo: [clave: valor], testigo: sesion.testigo)
                if !(j["ok"] as? Bool ?? false) {
                    aviso = (j["mensaje"] as? String ?? "No se ha podido guardar.", false)
                    await cargar()
                    return
                }
            } catch {
                aviso = (error.localizedDescription, false)
                return
            }
        }

        await cargar()
        aviso = (cambios.isEmpty ? "No había nada que cambiar." : "Guardado.", true)
        sesion.nombre = nombre
        editando = false        
    }

    private func subirFoto(_ elegida: PhotosPickerItem) async {
        subiendoFoto = true
        aviso = nil
        defer { subiendoFoto = false; eligiendoFoto = nil }
        guard let datos = try? await elegida.loadTransferable(type: Data.self) else {
            aviso = ("No se ha podido leer la imagen.", false)
            return
        }
        do {
            _ = try await API.subirFoto(datos, testigo: sesion.testigo)
            
            foto = await API.bajarImagen("api/perfil/foto", testigo: sesion.testigo)
            aviso = ("Foto guardada.", true)
        } catch {
            aviso = (error.localizedDescription, false)
        }
    }
}
