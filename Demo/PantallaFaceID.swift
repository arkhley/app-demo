import SwiftUI

struct PantallaFaceID: View {
    @Environment(Sesion.self) private var sesion
    @Environment(\.dismiss) private var cerrar

    @AppStorage(Ajustes.desbloquearConCara) private var desbloquear = true
    @AppStorage(Ajustes.pedidosConCara) private var pedidos = false

    @State private var hayCodigo = false
    @State private var poniendo = false
    @State private var aviso: (texto: String, bien: Bool)?

    @State private var identificado = false
    @State private var identificando = true
    
    @State private var confirmando: Accion?
    
    @State private var autorizada: Accion?

    enum Accion: Identifiable {
        case cambiar, quitar
        var id: Int { self == .cambiar ? 0 : 1 }
        var motivo: String {
            self == .cambiar ? "Para cambiar el código" : "Para quitar el código"
        }
    }

    private var biometria = Cerrojo.disponible()

    var body: some View {
        ScrollView {
            VStack(spacing: Diseno.hueco3) {
                if identificado {
                    ajustes
                } else {

                    Tarjeta {
                        Vacio(icono: Cerrojo.disponible().icono, titulo: "Identifícate",
                              detalle: "Para ver y cambiar estos ajustes.")
                    }
                }
            }
            .padding(.horizontal, Diseno.margen)
            .padding(.vertical, Diseno.hueco2)
        }
        .fondoDePantalla()
        .navigationTitle("Face ID y código")

        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $poniendo) {
            HojaPonerCodigo { puesto in
                hayCodigo = puesto
                aviso = (puesto ? "Código guardado." : "No se ha podido guardar.", puesto)
            }
        }

        .sheet(isPresented: $identificando, onDismiss: {
            if !identificado { cerrar() }
        }) {
            HojaIdentificarse(motivo: "Para entrar en Face ID y código") { vale in
                identificado = vale
            }
        }

        .sheet(item: $confirmando, onDismiss: {
            guard let hecha = autorizada else { return }
            autorizada = nil
            switch hecha {
            case .cambiar:
                poniendo = true
            case .quitar:
                CodigoNumerico.quitar()
                hayCodigo = false
                aviso = ("Código quitado.", true)
            }
        }) { accion in
            HojaIdentificarse(motivo: accion.motivo) { vale in
                autorizada = vale ? accion : nil
            }
        }
        .animation(Diseno.suave, value: hayCodigo)
        .animation(Diseno.suave, value: identificado)
        .task { hayCodigo = CodigoNumerico.hayCodigo() }
    }

    @ViewBuilder
    private var ajustes: some View {
        if let aviso { Banda(aviso) }

        if biometria == .ninguna {
            Tarjeta {
                Vacio(icono: "faceid", titulo: "Sin Face ID en este iPhone",
                      detalle: "Se entra con el código o con la contraseña.")
            }
        } else {
            Tarjeta {
                VStack(alignment: .leading, spacing: Diseno.hueco3) {
                    Toggle("Desbloquear la app con \(biometria.nombre)", isOn: $desbloquear)
                    Divider()
                    Toggle("Autorizar pedidos con \(biometria.nombre)", isOn: $pedidos)

                    Text("Te la pedirá antes de aprobar un pedido o confirmar un cobro.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        }

        Tarjeta {
            VStack(alignment: .leading, spacing: Diseno.hueco2) {
                Text("Código de desbloqueo").font(.headline)
                Text(hayCodigo ? "Puesto en este aparato."
                               : "Sin poner. Se entra con la contraseña.")
                    .font(.footnote).foregroundStyle(.secondary)
                HStack {

                    Button(hayCodigo ? "Cambiarlo" : "Poner un código") {
                        if hayCodigo { confirmando = .cambiar } else { poniendo = true }
                    }
                    .buttonStyle(.glass)
                    if hayCodigo {
                        Button("Quitarlo", role: .destructive) { confirmando = .quitar }
                            .buttonStyle(.glass)
                    }
                }

                Text("Solo vale en este iPhone. Para entrar en uno nuevo hace falta la "
                     + "contraseña de Ingresos.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

enum Ajustes {
    static let desbloquearConCara = "desbloquear-con-cara"
    static let pedidosConCara = "pedidos-con-cara"

    static func pideCara(_ clave: String, porDefecto: Bool) -> Bool {
        UserDefaults.standard.object(forKey: clave) as? Bool ?? porDefecto
    }
}

struct HojaIdentificarse: View {
    @Environment(\.dismiss) private var cerrar
    let motivo: String
    let hecho: (Bool) -> Void

    @State private var marcado = ""
    @State private var pidiendoCara = true
    @State private var fallos = 0

    @ScaledMetric(relativeTo: .largeTitle) private var tamIcono: CGFloat = 52

    var body: some View {
        NavigationStack {
            VStack(spacing: Diseno.hueco4) {
                Spacer()
                Image(systemName: Cerrojo.disponible().icono)

                    .font(.system(size: tamIcono, weight: .light))
                    .foregroundStyle(Diseno.azul)
                Text(motivo).font(.headline).multilineTextAlignment(.center)

                if CodigoNumerico.hayCodigo() && !pidiendoCara {
                    TecladoNumerico(marcado: $marcado,
                                    digitos: CodigoNumerico.digitos) { intento in
                        if CodigoNumerico.comprueba(intento) {
                            hecho(true)
                            cerrar()
                            return true
                        }
                        fallos += 1
                        if fallos >= CodigoNumerico.maxFallos {
                            hecho(false)
                            cerrar()
                        }
                        return false
                    }
                } else if pidiendoCara {
                    ProgressView()
                }
                Spacer()
                Spacer()
            }
            .frame(maxWidth: 340)
            .frame(maxWidth: .infinity)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { hecho(false); cerrar() }
                }
            }
            .task { await intentar() }
        }
        .interactiveDismissDisabled()
    }

    private func intentar() async {
        
        guard Cerrojo.disponible() != .ninguna || CodigoNumerico.hayCodigo() else {
            hecho(true)
            cerrar()
            return
        }
        if Cerrojo.disponible() != .ninguna, await Cerrojo.pedir(motivo: motivo) == .si {
            hecho(true)
            cerrar()
            return
        }
        
        pidiendoCara = false
        if !CodigoNumerico.hayCodigo() {
            hecho(false)
            cerrar()
        }
    }
}
