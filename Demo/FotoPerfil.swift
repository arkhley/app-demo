import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

@Observable
@MainActor
final class FotoPerfil {
    static let compartida = FotoPerfil()

    private(set) var imagen: UIImage?
    
    private var yaIntentado = false

    private init() {}

    func cargar(testigo: String?) async {
        guard !yaIntentado else { return }
        let bajada = await API.bajarImagen("api/perfil/foto", testigo: testigo)

        if let bajada {
            imagen = bajada
            yaIntentado = true
        }
    }

    func poner(_ nueva: UIImage?) {
        imagen = nueva
        yaIntentado = true
    }

    func olvidar() {
        imagen = nil
        yaIntentado = false
    }
}

struct Avatar: View {
    
    var lado: CGFloat = 28
    var nombre: String = ""

    private var encoge: CGFloat { lado * 0.075 }

    @State private var foto = FotoPerfil.compartida
    @Environment(Sesion.self) private var sesion

    var body: some View {

        retrato
            .frame(width: lado, height: lado)
            .clipShape(.circle)

            .padding(-encoge)
            .task { await foto.cargar(testigo: sesion.testigo) }
    }

    @ViewBuilder
    private var retrato: some View {
        if let img = foto.imagen {
            Image(uiImage: img)
                .resizable()
                .scaledToFill()
        } else if !iniciales.isEmpty {
            LinearGradient(colors: [Diseno.azul, Diseno.morado],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
                .overlay {
                    Text(iniciales)
                        .font(.system(size: lado * 0.42, weight: .semibold))
                        .foregroundStyle(.white)
                }
        } else {
            Image(systemName: "person.crop.circle")
                .resizable()
                .scaledToFit()
                .foregroundStyle(.tint)
        }
    }

    private var iniciales: String {
        let partes = nombre.split(separator: " ").prefix(2)
        let letras = partes.compactMap { $0.first }.map(String.init).joined()
        return letras.uppercased()
    }
}
