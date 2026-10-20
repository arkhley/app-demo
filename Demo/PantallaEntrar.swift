import SwiftUI

struct PantallaEntrar: View {
    @Environment(Sesion.self) private var sesion
    @State private var contrasena = ""
    @State private var entrando = false
    @State private var fallo: String?
    @FocusState private var enElCampo: Bool
    
    @ScaledMetric(relativeTo: .largeTitle) private var tamCandado: CGFloat = 44

    var body: some View {
        ZStack {
            fondo

            VStack(spacing: Diseno.hueco4) {
                Spacer()

                VStack(spacing: Diseno.hueco2) {
                    Image(systemName: "lock.shield")
                        .font(.system(size: tamCandado, weight: .light))
                        .foregroundStyle(Diseno.azul)

                    Text("Ingresos")
                        .font(.system(.largeTitle, design: .rounded, weight: .semibold))
                    Text("Panel encargo")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: Diseno.hueco2) {
                    SecureField("Contraseña", text: $contrasena)
                        .textContentType(.password)
                        .submitLabel(.go)
                        .focused($enElCampo)
                        .onSubmit(intentar)
                        .padding(.horizontal, Diseno.hueco3)
                        .padding(.vertical, 14)
                        .background(.background.secondary,
                                    in: .rect(cornerRadius: Diseno.radioCampo))

                    if let fallo {
                        Label(fallo, systemImage: "exclamationmark.triangle")
                            .font(.footnote)
                            .foregroundStyle(Diseno.rojo)
                            .multilineTextAlignment(.center)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }

                    Button(action: intentar) {
                        Group {
                            if entrando {
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
                    .disabled(contrasena.isEmpty || entrando)
                }
                .frame(maxWidth: 340)

                Spacer()
                Spacer()
            }
            .padding(.horizontal, Diseno.hueco5)
        }

        .salidaDelTeclado()
        .animation(Diseno.suave, value: fallo)
        .animation(Diseno.suave, value: entrando)
        .onAppear { enElCampo = true }
    }

    private var fondo: some View { FondoDeEntrada() }

    private func intentar() {
        guard !contrasena.isEmpty, !entrando else { return }
        entrando = true
        fallo = nil
        enElCampo = false
        Task {
            do {
                try await sesion.entrar(contrasena: contrasena)
            } catch {
                fallo = error.localizedDescription
                contrasena = ""
                enElCampo = true
            }
            entrando = false
        }
    }
}

struct FondoDeEntrada: View {
    var body: some View {
        LinearGradient(
            colors: [Diseno.azul.opacity(0.22), Diseno.morado.opacity(0.10), .clear],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
        .background(Color(.systemBackground).ignoresSafeArea())
    }
}
