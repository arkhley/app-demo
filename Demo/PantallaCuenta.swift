import SwiftUI
import PhotosUI

struct PantallaCuenta: View {
    
    var enHoja = false

    @Environment(Sesion.self) private var sesion
    @Environment(\.dismiss) private var cerrar
    @Environment(\.tema) private var tema

    @State private var nombre = ""
    @State private var aviso: String?
    @State private var eligiendoFoto: PhotosPickerItem?
    @State private var foto: UIImage?
    @State private var subiendoFoto = false
    
    @State private var enTemas = false

    @ScaledMetric(relativeTo: .largeTitle) private var ladoAvatar: CGFloat = 96

    static let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion")
        as? String ?? "?"

    var body: some View {
        ScrollView {
            VStack(spacing: Diseno.hueco3) {
                cabecera

                Grupo {
                    acceso("person.text.rectangle.fill", .gray,
                           "Información personal") { PantallaInformacionPersonal() }
                    acceso("key.fill", .gray,
                           "Privacidad y seguridad") { PantallaSeguridad() }
                    acceso("faceid", .gray, "Face ID y código") { PantallaFaceID() }
                    acceso("lock.rectangle.stack.fill", .gray,
                           "Contraseñas") { PantallaClaves() }
                }

                Grupo {

                    acceso("banknote.fill", .green, "Reserva y objetivo") { PantallaHuchaNueva() }

                    acceso("calendar", .orange, "Calendario") { PantallaCalendarioHuchaNueva() }

                    acceso("building.columns.fill", .indigo, "Impuestos") { PantallaImpuestos() }
                    acceso("bell.badge.fill", .red, "Notificaciones") { PantallaAvisos() }
                }

                Grupo {

                    if Compilacion.beta {
                        accesoQueSeQueda("paintpalette.fill", .cyan, "Temas",
                                         valor: Temas.compartido.nombreElegido, abierto: $enTemas)
                    }
                    acceso("internaldrive.fill", .gray,
                           "Almacenamiento") { PantallaResumenCuenta() }
                    acceso("hammer.fill", .gray, "Logs y errores") { PantallaRegistro() }
                    acceso("trash.fill", .red, "Borrar historial") { PantallaBorrarHistorial() }
                }

                BotonPDF(ruta: "api/certificado",
                         nombre: "Ganancias.pdf",
                         titulo: "Certificado de ganancias")

                if let aviso {
                    Text(aviso)
                        .font(.footnote)
                        .foregroundStyle(Diseno.rojo)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 4)
                }

                if sesion.usuario == "propietario" {
                    Button("Cerrar sesión", role: .destructive) {
                        if enHoja { cerrar() }
                        sesion.salir()
                    }
                        .buttonStyle(.glass)
                        .controlSize(.large)
                        .padding(.top, Diseno.hueco2)
                } else {
                    Text("Solo el perfil principal puede cerrar sesión en este iPhone.")
                        .font(.footnote).foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.top, Diseno.hueco2)
                }

                Text("Versión \(Self.version)")
                    .font(.caption).foregroundStyle(.secondary)
                    .padding(.top, Diseno.hueco1)
            }
            .padding(.horizontal, Diseno.margen)
            .padding(.vertical, Diseno.hueco2)
        }
        .fondoDePantalla()
        
        .navigationTitle("Cuenta")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if enHoja {
                ToolbarItem(placement: .topBarTrailing) {

                    Button(role: .close) { cerrar() }
                }
            }
        }
        .task { await cargar() }
        .navigationDestination(isPresented: $enTemas) { PantallaTemas() }
        #if MAQUETA
        
        .navigationDestination(isPresented: .constant(Maqueta.sub != nil)) {
            Maqueta.vistaDeCuenta()
        }
        #endif
    }

    private var cabecera: some View {
        VStack(spacing: Diseno.hueco3) {

            PhotosPicker(selection: $eligiendoFoto, matching: .images) {
                ZStack(alignment: .bottomTrailing) {
                    if let foto {
                        Image(uiImage: foto)
                            .resizable().scaledToFill()
                            .frame(width: ladoAvatar, height: ladoAvatar)
                            .clipShape(.circle)
                    } else {
                        Text(String(nombre.prefix(1)).uppercased())
                            .font(.system(size: ladoAvatar * 0.4, weight: .medium,
                                          design: .rounded))
                            .foregroundStyle(.white)
                            .frame(width: ladoAvatar, height: ladoAvatar)
                            .background(LinearGradient(colors: [Diseno.azul, Diseno.morado],
                                                       startPoint: .topLeading,
                                                       endPoint: .bottomTrailing),
                                        in: .circle)
                    }
                    Image(systemName: subiendoFoto ? "arrow.up.circle.fill" : "camera.fill")
                        .font(.caption)
                        .foregroundStyle(tema.sobreRelleno)
                        .frame(width: 28, height: 28)
                        .background(tema.relleno, in: .circle)
                        .overlay(Circle().strokeBorder(Color(.systemBackground), lineWidth: 2))
                }
            }

            .buttonStyle(.plain)
            .onChange(of: eligiendoFoto) { _, nueva in
                guard let nueva else { return }
                Task { await subirFoto(nueva) }
            }

            Text(nombre.isEmpty ? "—" : nombre)
                .font(.largeTitle.weight(.bold))
                .minimumScaleFactor(0.6)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, Diseno.hueco2)
        .padding(.bottom, Diseno.hueco4)

    }

    private func acceso<Destino: View>(_ icono: String, _ tinte: Color, _ titulo: String,
                                       valor: String = "",
                                       @ViewBuilder destino: () -> Destino) -> some View {
        NavigationLink(destination: destino()) {
            fila(icono: icono, tinte: tinte, titulo: titulo, valor: valor) {
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .buttonStyle(.plain)
    }

    private func accesoQueSeQueda(_ icono: String, _ tinte: Color, _ titulo: String, valor: String,
                                  abierto: Binding<Bool>) -> some View {
        Button { abierto.wrappedValue = true } label: {
            fila(icono: icono, tinte: tinte, titulo: titulo, valor: valor) {
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func fila<Cola: View>(icono: String, tinte: Color, titulo: String, valor: String,
                                  @ViewBuilder cola: () -> Cola) -> some View {

        let resto = cola()
        ViewThatFits(in: .horizontal) {
            HStack(spacing: Diseno.hueco2) {
                FichaIcono(simbolo: icono, color: tinte)
                Text(titulo).foregroundStyle(.primary).lineLimit(1)
                Spacer()
                Text(valor)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                resto
            }
            VStack(alignment: .leading, spacing: Diseno.hueco1) {
                HStack(spacing: Diseno.hueco2) {
                    FichaIcono(simbolo: icono, color: tinte)
                    Spacer()
                    resto
                }
                Text(titulo).foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                if !valor.isEmpty {
                    Text(valor)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(Diseno.hueco3)
        .contentShape(.rect)
    }

    private func subirFoto(_ elegida: PhotosPickerItem) async {
        subiendoFoto = true
        aviso = nil
        defer { subiendoFoto = false; eligiendoFoto = nil }
        guard let datos = try? await elegida.loadTransferable(type: Data.self) else {
            aviso = "No se ha podido leer la imagen."
            return
        }
        do {
            _ = try await API.subirFoto(datos, testigo: sesion.testigo)
            foto = UIImage(data: datos)
            
            FotoPerfil.compartida.poner(foto)
            await cargar()
        } catch {
            aviso = error.localizedDescription
        }
    }

    private func cargar() async {
        do {
            let j = try await API.pedir("api/perfil", testigo: sesion.testigo)
            nombre = j["nombre"] as? String ?? sesion.nombre

            if j["foto"] as? Bool ?? false {
                foto = await API.bajarImagen("api/perfil/foto", testigo: sesion.testigo)
                FotoPerfil.compartida.poner(foto)
            } else {
                foto = nil
                FotoPerfil.compartida.poner(nil)
            }
        } catch {
            nombre = sesion.nombre
        }
    }

}

#if canImport(UIKit)
import UIKit
#endif
