import SwiftUI

@Observable
final class Privacidad: @unchecked Sendable {
    static let compartida = Privacidad()
    
    static let tapada = "•••,•• €"
    private static let clave = "ocultar_cifras"

    @ObservationIgnored private let cerrojo = NSLock()
    @ObservationIgnored private var guardada = UserDefaults.standard.bool(forKey: "ocultar_cifras")

    var oculta: Bool {
        get {
            access(keyPath: \.oculta)
            cerrojo.lock()
            defer { cerrojo.unlock() }
            return guardada
        }
        set {
            withMutation(keyPath: \.oculta) {
                cerrojo.lock()
                guardada = newValue
                cerrojo.unlock()
            }
            UserDefaults.standard.set(newValue, forKey: Self.clave)
            
            PuenteWidget.ocultar(newValue)
        }
    }

    private init() {}
}
