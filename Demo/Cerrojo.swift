import Foundation
import LocalAuthentication

enum Cerrojo {

    enum Biometria {
        case faceID
        case touchID
        case ninguna

        var nombre: String {
            switch self {
            case .faceID: return "Face ID"
            case .touchID: return "Touch ID"
            case .ninguna: return ""
            }
        }

        var icono: String {
            switch self {
            case .faceID: return "faceid"
            case .touchID: return "touchid"
            case .ninguna: return "lock"
            }
        }
    }

    static func disponible() -> Biometria {
        let contexto = LAContext()
        var fallo: NSError?
        guard contexto.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics,
                                         error: &fallo) else { return .ninguna }
        switch contexto.biometryType {
        case .faceID: return .faceID
        case .touchID: return .touchID
        default: return .ninguna
        }
    }

    enum Resultado {
        
        case si

        case cancelado
        
        case fallo
    }

    static func pedir(motivo: String = "Para volver a entrar en Ingresos",
                      cancelar: String? = nil, limite: Duration? = nil) async -> Resultado {
        let contexto = LAContext()

        contexto.localizedFallbackTitle = ""
        if let cancelar { contexto.localizedCancelTitle = cancelar }
        guard contexto.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics,
                                         error: nil) else { return .fallo }
        
        let caja = ContextoCompartido(contexto)
        let reloj = limite.map { espera in
            Task {
                try? await Task.sleep(for: espera)
                if !Task.isCancelled { caja.contexto.invalidate() }
            }
        }
        defer { reloj?.cancel() }
        do {
            let vale = try await contexto.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics, localizedReason: motivo)
            return vale ? .si : .fallo
        } catch let error as LAError {
            switch error.code {

            case .userCancel, .systemCancel, .appCancel, .userFallback:
                return .cancelado
            default:
                return .fallo
            }
        } catch {
            return .fallo
        }
    }
}

private final class ContextoCompartido: @unchecked Sendable {
    let contexto: LAContext
    init(_ contexto: LAContext) { self.contexto = contexto }
}

#if canImport(UIKit)
import SwiftUI
import UIKit

final class EscuchaDeToques: UIGestureRecognizer, UIGestureRecognizerDelegate {
    var alTocar: () -> Void = {}

    override init(target: Any?, action: Selector?) {
        super.init(target: target, action: action)
        cancelsTouchesInView = false     
        delaysTouchesBegan = false
        delaysTouchesEnded = false
        delegate = self
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        alTocar()

        state = .failed
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        state = .failed
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        state = .failed
    }

    func gestureRecognizer(_ g: UIGestureRecognizer,
                           shouldRecognizeSimultaneouslyWith otro: UIGestureRecognizer) -> Bool {
        true
    }
}

struct EscucharToques: UIViewRepresentable {
    let alTocar: () -> Void

    func makeUIView(context: Context) -> UIView {
        let v = UIView(frame: .zero)
        v.isUserInteractionEnabled = false
        return v
    }

    func updateUIView(_ vista: UIView, context: Context) {
        let accion = alTocar
        
        DispatchQueue.main.async {
            guard let ventana = vista.window else { return }
            if ventana.gestureRecognizers?.contains(where: { $0 is EscuchaDeToques }) == true {
                return
            }
            let escucha = EscuchaDeToques(target: nil, action: nil)
            escucha.alTocar = accion
            ventana.addGestureRecognizer(escucha)
        }
    }
}
#endif
