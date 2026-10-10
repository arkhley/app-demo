import SwiftUI

struct PantallaCarga: View {
    
    static let duracion: Duration = .milliseconds(1500)

    @Environment(\.colorScheme) private var modo
    @Environment(\.accessibilityReduceMotion) private var menosMovimiento

    @State private var entrado = false

    private var fondo: Color {
        modo == .dark ? CargaIncrustada.fondoOscuro : CargaIncrustada.fondoClaro
    }

    var body: some View {
        ZStack {
            fondo.ignoresSafeArea()

            if let imagen = Self.imagen(modo == .dark ? "oscuro" : "claro") {
                GeometryReader { marco in
                    Image(uiImage: imagen)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: marco.size.width * 0.62)
                        .position(x: marco.size.width / 2, y: marco.size.height / 2)
                }
                .accessibilityLabel("Ingresos")
            } else {
                
                Text("Ingresos").font(.largeTitle.weight(.semibold))
            }
        }
        
        .opacity(menosMovimiento || entrado ? 1 : 0)
        .task {
            guard !menosMovimiento else { return }
            withAnimation(.easeOut(duration: 0.35)) { entrado = true }
        }
    }

    private static let memoria = NSCache<NSString, UIImage>()

    static func imagen(_ nombre: String) -> UIImage? {
        if let guardada = memoria.object(forKey: nombre as NSString) { return guardada }
        let b64 = nombre == "oscuro" ? CargaIncrustada.oscuro : CargaIncrustada.claro
        guard let datos = Data(base64Encoded: b64), let imagen = UIImage(data: datos) else {
            return nil
        }
        memoria.setObject(imagen, forKey: nombre as NSString)
        return imagen
    }
}
