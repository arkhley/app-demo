import Foundation
import SwiftUI

@MainActor
@Observable
final class Sesion {
    enum Estado {
        case comprobando        
        case fuera
        case bloqueada          
        case dentro
    }

    private(set) var estado: Estado = .comprobando
    private(set) var testigo: String?
    var nombre: String = "Alex"

    private(set) var usuario = ""

    static let inactividadMaxima: TimeInterval = 10 * 60

    private var ultimoToque = Date()

    func tocado() {
        ultimoToque = Date()
    }

    func revisarCerrojo() {
        #if !MAQUETA
        guard case .dentro = estado else { return }
        if Date().timeIntervalSince(ultimoToque) >= Self.inactividadMaxima {
            estado = .bloqueada
        }
        #endif
    }

    func bloquear() {
        guard case .dentro = estado else { return }
        estado = .bloqueada
    }

    func desbloquear() {
        guard case .bloqueada = estado else { return }
        ultimoToque = Date()
        estado = .dentro
    }

    func arrancar() async {
        #if MAQUETA

        testigo = "maqueta"
        switch Maqueta.estado {
        case "bloqueada": estado = .bloqueada
        case "fuera": estado = .fuera
        
        case "comprobando": estado = .comprobando
        default: estado = .dentro
        }
        #else

        if !UIApplication.shared.isProtectedDataAvailable {
            for await _ in NotificationCenter.default.notifications(
                named: UIApplication.protectedDataDidBecomeAvailableNotification) { break }
        }
        guard let guardado = Llavero.leer() else {
            estado = .fuera
            return
        }
        testigo = guardado
        do {
            let yo = try await API.pedir("api/yo", testigo: guardado)
            if let n = yo["usuario"] as? String, !n.isEmpty { nombre = n; usuario = n }

            estado = .bloqueada
            
            Task { await PuenteWidget.ponerAlDia(testigo: guardado) }
        } catch API.Fallo.sinTestigo {
            Llavero.borrar()
            testigo = nil
            estado = .fuera

            FotoPerfil.compartida.olvidar()
            MemoriaDeInicio.compartida.olvidar()
            PuenteWidget.olvidar()
            AvisosDelIPhone.olvidar()
        } catch {

            estado = .bloqueada
        }
        #endif
    }

    private var comprobandoTestigo = false

    func testigoRechazado() async {
        guard !comprobandoTestigo, let actual = testigo else { return }
        switch estado {
        case .dentro, .bloqueada: break
        default: return
        }
        comprobandoTestigo = true
        defer { comprobandoTestigo = false }
        do {
            _ = try await API.pedir("api/yo", testigo: actual)
        } catch API.Fallo.sinTestigo {
            guard testigo == actual else { return }
            Llavero.borrar()
            testigo = nil
            estado = .fuera
            FotoPerfil.compartida.olvidar()
            MemoriaDeInicio.compartida.olvidar()
            PuenteWidget.olvidar()
            AvisosDelIPhone.olvidar()
        } catch {
            
        }
    }

    func entrar(contrasena: String) async throws {
        let nuevo = try await API.entrar(contrasena: contrasena)
        Llavero.guardar(nuevo)
        testigo = nuevo
        ultimoToque = Date()

        if let yo = try? await API.pedir("api/yo", testigo: nuevo),
           let n = yo["usuario"] as? String, !n.isEmpty {
            nombre = n
            usuario = n
        }
        estado = .dentro
        
        Task { await PuenteWidget.ponerAlDia(testigo: nuevo) }
    }

    func salir() {
        let anterior = testigo
        Llavero.borrar()
        testigo = nil
        estado = .fuera
        
        FotoPerfil.compartida.olvidar()
        MemoriaDeInicio.compartida.olvidar()
        
        PuenteWidget.olvidar()
        
        AvisosDelIPhone.olvidar()

        if let anterior {
            Task { _ = try? await API.pedir("api/salir", metodo: "POST", testigo: anterior) }
        }
    }
}

enum Carga<T> {
    case cargando
    case listo(T)
    case vacio
    case error(String)
}

extension Carga {

    mutating func fallar(_ error: Error) {
        if error is CancellationError || (error as NSError).code == NSURLErrorCancelled { return }
        switch self {
        case .listo, .vacio:
            if let f = error as? API.Fallo, case .sinTestigo = f { return }
            NotificationCenter.default.post(name: .recargaFallida, object: nil)
        default: self = .error(error.localizedDescription)
        }
    }
}
