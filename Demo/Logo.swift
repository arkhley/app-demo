import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct Logo: View {
    let plataforma: String
    var alto: CGFloat = 18

    @Environment(\.colorScheme) private var modo

    static let conLogo: Set<String> = []
    static func hay(_ plataforma: String) -> Bool { conLogo.contains(plataforma) }

    private var archivo: String {
        
        if plataforma == "plataforma2" && modo == .dark { return "plataforma2-oscuro" }
        return plataforma
    }

    private var nombre: String {
        plataforma == "plataforma1" ? "Plataforma 1" : "Plataforma 2"
    }

    var body: some View {
        if let imagen = Self.imagen(archivo) {
            Image(uiImage: imagen)
                .resizable()
                .aspectRatio(contentMode: .fit)   
                .frame(height: alto)
                
                .accessibilityLabel(nombre)
        } else {
            
            Text(nombre)
                .font(.system(size: alto * 0.8, weight: .semibold))
        }
    }

    private static let memoria = NSCache<NSString, UIImage>()

    static func imagen(_ nombre: String) -> UIImage? {
        if let guardada = memoria.object(forKey: nombre as NSString) { return guardada }
        guard let b64 = LogosIncrustados.png[nombre],
              let datos = Data(base64Encoded: b64),
              let imagen = UIImage(data: datos) else { return nil }
        memoria.setObject(imagen, forKey: nombre as NSString)
        return imagen
    }
}
