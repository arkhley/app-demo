import SwiftUI

struct PantallaBloqueo: View {
    @Environment(Sesion.self) private var sesion
    @Environment(\.scenePhase) private var fase

    @State private var biometria = Cerrojo.disponible()

    @AppStorage(Ajustes.desbloquearConCara) private var desbloquearConCara = true
    @State private var pidiendo = false
    @State private var conContrasena = false
    @State private var contrasena = ""
    @State private var comprobando = false
    @State private var fallo: String?

    @State private var estuvoEnSegundoPlano = false

    @State private var hayCodigo = false
    @State private var marcado = ""
    @State private var fallosCodigo = 0
    @FocusState private var enElCampo: Bool

    @State private var comoElIPhone = PantallaBloqueo.hayCodigoPuesto()
    
    @Environment(\.cerrojoSaliendo) private var saliendo

    var body: some View {
        if comoElIPhone {
            CerrojoComoElIPhone()
        } else {
            clasica
        }
    }

    static func hayCodigoPuesto() -> Bool {
        #if MAQUETA
        if Maqueta.codigoDePrueba { return true }
        #endif
        return CodigoNumerico.hayCodigo()
    }

    private var clasica: some View {
        ZStack {
            FondoDeEntrada()
                .animation(nil) { $0.opacity(saliendo ? 0 : 1) }

            VStack(spacing: Diseno.hueco4) {
                Spacer()

                VStack(spacing: Diseno.hueco2) {
                    Image(systemName: caraActiva ? biometria.icono : "lock")
                        .font(.system(size: tamIcono, weight: .light))
                        .foregroundStyle(Diseno.azul)
                        .symbolEffect(.pulse, isActive: pidiendo)
                    Text("Ingresos")
                        .font(.system(.largeTitle, design: .rounded, weight: .semibold))
                    Text(subtitulo)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                if conContrasena {
                    campoContrasena
                } else if hayCodigo && fallosCodigo < CodigoNumerico.maxFallos {

                    TecladoNumerico(marcado: $marcado,
                                    digitos: CodigoNumerico.digitos) { intento in
                        if CodigoNumerico.comprueba(intento) {
                            sesion.desbloquear()
                            return true
                        }
                        fallosCodigo += 1

                        if fallosCodigo >= CodigoNumerico.maxFallos {
                            conContrasena = true
                            fallo = "Demasiados intentos. Escribe la contraseña."
                        }
                        return false
                    }

                    Button("Usar la contraseña") {
                        conContrasena = true
                        enElCampo = true
                    }
                    .font(.subheadline)
                } else if !caraActiva {
                    campoContrasena
                } else {
                    Button {
                        Task { await intentarCara() }
                    } label: {
                        Label("Entrar con \(biometria.nombre)", systemImage: biometria.icono)
                            .frame(maxWidth: .infinity)
                            .frame(height: 22)
                    }
                    .buttonStyle(.glassProminent)
                    .controlSize(.large)
                    .disabled(pidiendo)

                    Button("Usar la contraseña") {
                        conContrasena = true
                        enElCampo = true
                    }
                    .font(.subheadline)
                }

                Spacer()
                Spacer()
            }
            .frame(maxWidth: 340)
            .padding(.horizontal, Diseno.hueco5)
        }

        .salidaDelTeclado()
        .animation(Diseno.suave, value: conContrasena)
        .animation(Diseno.suave, value: fallo)

        .task {
            hayCodigo = CodigoNumerico.hayCodigo()
            biometria = Cerrojo.disponible()
            await intentarCara()
        }

        .onChange(of: fase) { _, nueva in
            if nueva == .background { estuvoEnSegundoPlano = true; return }
            guard nueva == .active, estuvoEnSegundoPlano, !conContrasena else { return }
            estuvoEnSegundoPlano = false
            Task { await intentarCara() }
        }
    }

    private var caraActiva: Bool { desbloquearConCara && biometria != .ninguna }

    @ScaledMetric(relativeTo: .largeTitle) private var tamIcono: CGFloat = 52

    private var subtitulo: String {
        if conContrasena || !caraActiva { return "Escribe la contraseña del panel" }
        if hayCodigo { return "Escribe tu código" }
        return "Se ha bloqueado por seguridad"
    }

    private var campoContrasena: some View {
        VStack(spacing: Diseno.hueco2) {
            SecureField("Contraseña", text: $contrasena)
                .textContentType(.password)
                .submitLabel(.go)
                .focused($enElCampo)
                .onSubmit { Task { await intentarContrasena() } }
                .padding(.horizontal, Diseno.hueco3)
                .padding(.vertical, 14)
                .background(.background.secondary, in: .rect(cornerRadius: Diseno.radioCampo))

            if let fallo {
                Label(fallo, systemImage: "exclamationmark.triangle")
                    .font(.footnote)
                    .foregroundStyle(Diseno.rojo)
                    .multilineTextAlignment(.center)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            Button {
                Task { await intentarContrasena() }
            } label: {
                Group {
                    if comprobando {
                        ProgressView().tint(.white)
                    } else {
                        Text("Entrar").fontWeight(.semibold)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 22)
            }
            .buttonStyle(.glassProminent)
            .controlSize(.large)
            .disabled(contrasena.isEmpty || comprobando)

            if caraActiva {
                Button("Volver a \(biometria.nombre)") {
                    conContrasena = false
                    contrasena = ""
                    fallo = nil
                    Task { await intentarCara() }
                }
                .font(.subheadline)
            }
        }
    }

    private func intentarCara() async {
        guard !pidiendo, !conContrasena, caraActiva else { return }
        pidiendo = true
        let salida = await Cerrojo.pedir()
        pidiendo = false
        switch salida {
        case .si:
            sesion.desbloquear()
        case .cancelado:

            if hayCodigo && fallosCodigo < CodigoNumerico.maxFallos {
                marcado = ""
            } else {
                conContrasena = true
                enElCampo = true
            }
        case .fallo:

            biometria = Cerrojo.disponible()
            if biometria == .ninguna { conContrasena = true }
        }
    }

    private func intentarContrasena() async {
        guard !contrasena.isEmpty, !comprobando else { return }
        comprobando = true
        fallo = nil
        bajarTeclado()
        do {
            try await sesion.entrar(contrasena: contrasena)
            contrasena = ""
        } catch {
            fallo = error.localizedDescription
            contrasena = ""
            enElCampo = true
        }
        comprobando = false
    }
}
