import Foundation
#if canImport(UIKit)
import UIKit
#endif

enum API {

    static let servidor = URL(string: "https://example.com")!

    static let servidorEncargo = URL(string: "https://example.com")!

    static func avisarTestigoRechazado() {
        NotificationCenter.default.post(name: .testigoRechazado, object: nil)
    }

    enum Fallo: LocalizedError {
        case sinTestigo
        case credenciales
        case red(String)
        case servidor(Int)

        case dijo(String)

        var errorDescription: String? {
            switch self {
            case .sinTestigo:      return "Tienes que entrar otra vez."
            case .credenciales:    return "Esa contraseña no es."
            case .red(let qué):    return qué
            case .dijo(let qué):   return qué
            case .servidor(let c): return "El servidor ha contestado \(c)."
            }
        }
    }

    static let sesionURL: URLSession = {
        let config = URLSessionConfiguration.default

        config.timeoutIntervalForRequest = 12
        config.waitsForConnectivity = false
        return URLSession(configuration: config)
    }()

    static func direccion(_ ruta: String, base: URL = servidor) -> URL {

        let limpia = ruta.hasPrefix("/") ? String(ruta.dropFirst()) : ruta
        return URL(string: "\(base.absoluteString)/\(limpia)") ?? base
    }

    private static func peticion(_ ruta: String, metodo: String = "GET",
                                 cuerpo: [String: any Sendable]? = nil,
                                 testigo: String?,
                                 base: URL = servidor) throws -> URLRequest {
        var p = URLRequest(url: direccion(ruta, base: base))
        p.httpMethod = metodo
        p.setValue("application/json", forHTTPHeaderField: "Accept")
        if let testigo {
            p.setValue("Bearer \(testigo)", forHTTPHeaderField: "Authorization")
        }
        if let cuerpo {
            p.setValue("application/json", forHTTPHeaderField: "Content-Type")
            p.httpBody = try JSONSerialization.data(withJSONObject: cuerpo)
        }
        return p
    }

    static func pedir(_ ruta: String, metodo: String = "GET",
                      cuerpo: [String: any Sendable]? = nil,
                      testigo: String?) async throws -> [String: Any] {
        #if MAQUETA
        
        guard let json = Maqueta.respuesta(ruta) else { throw Fallo.servidor(404) }
        return json
        #else
        let peticion = try peticion(ruta, metodo: metodo, cuerpo: cuerpo, testigo: testigo)
        let datos: Data
        let respuesta: URLResponse
        do {
            (datos, respuesta) = try await sesionURL.data(for: peticion)
        } catch {
            throw falloDePeticion(error)
        }

        let codigo = (respuesta as? HTTPURLResponse)?.statusCode ?? 0
        
        if codigo == 401 || codigo == 403 { avisarTestigoRechazado(); throw Fallo.sinTestigo }
        guard (200..<300).contains(codigo) else {

            if let j = try? JSONSerialization.jsonObject(with: datos) as? [String: Any],
               let motivo = (j["mensaje"] as? String) ?? (j["error"] as? String),
               !motivo.isEmpty {
                throw Fallo.dijo(motivo)
            }
            throw Fallo.servidor(codigo)
        }

        guard let json = try? JSONSerialization.jsonObject(with: datos) as? [String: Any] else {
            throw Fallo.red("El servidor ha contestado algo que no se entiende.")
        }
        return json
        #endif
    }

    static func falloDePeticion(_ error: Error, alEntrar: Bool = false) -> Error {
        if error is CancellationError || (error as? URLError)?.code == .cancelled
            || Task.isCancelled {
            return CancellationError()
        }
        return Fallo.red(mensajeDeRed(error, alEntrar: alEntrar))
    }

    static func mensajeDeRed(_ error: Error, alEntrar: Bool = false) -> String {
        let e = error as NSError
        switch e.code {
        case NSURLErrorTimedOut:
            return "El servidor ha tardado demasiado."
        case NSURLErrorNotConnectedToInternet:
            return "No hay conexión."
        case NSURLErrorCannotFindHost, NSURLErrorCannotConnectToHost,
             NSURLErrorNetworkConnectionLost, NSURLErrorDNSLookupFailed:
            return alEntrar ? "No se llega al servidor. Para entrar la primera vez hace falta "
                            + "la VPN encendida."
                            : "No se llega al servidor."
        default:
            return e.localizedDescription
        }
    }

    static func entrar(contrasena: String) async throws -> String {
        
        let peticion = try peticion("api/login", metodo: "POST",
                                    cuerpo: ["password": contrasena,
                                             "aparato": nombreDelAparato()],
                                    testigo: nil, base: servidorEncargo)
        let datos: Data
        let respuesta: URLResponse
        do {
            (datos, respuesta) = try await sesionURL.data(for: peticion)
        } catch {
            throw falloDePeticion(error, alEntrar: true)
        }
        let codigo = (respuesta as? HTTPURLResponse)?.statusCode ?? 0
        if codigo == 401 || codigo == 403 { throw Fallo.credenciales }
        guard (200..<300).contains(codigo),
              let json = try? JSONSerialization.jsonObject(with: datos) as? [String: Any],
              let testigo = json["testigo"] as? String else {
            throw Fallo.servidor(codigo)
        }
        return testigo
    }

    private static func nombreDelAparato() -> String {

        let so = ProcessInfo.processInfo.operatingSystemVersion
        return "\(Aparato.paraElServidor)|iOS \(so.majorVersion).\(so.minorVersion)"
    }
}

enum Llavero {
    private static let cuenta = "testigo-panel"
    private static let servicio = "com.example.panel"

    static func guardar(_ valor: String) {
        borrar()
        let consulta: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: servicio,
            kSecAttrAccount as String: cuenta,
            kSecValueData as String: Data(valor.utf8),
            
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
        ]
        SecItemAdd(consulta as CFDictionary, nil)
    }

    static func leer() -> String? {
        let consulta: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: servicio,
            kSecAttrAccount as String: cuenta,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var salida: AnyObject?
        guard SecItemCopyMatching(consulta as CFDictionary, &salida) == errSecSuccess,
              let datos = salida as? Data else { return nil }
        return String(data: datos, encoding: .utf8)
    }

    static func borrar() {
        let consulta: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: servicio,
            kSecAttrAccount as String: cuenta,
        ]
        SecItemDelete(consulta as CFDictionary)
    }
}

extension API {

    static func subirVideo(_ datosVideo: Data, categoria: String, titulo: String,
                           maxMB: Int = 50, testigo: String?) async throws -> [String: Any] {

        guard datosVideo.count <= maxMB * 1024 * 1024 else {
            throw Fallo.dijo("El vídeo pesa \(datosVideo.count / 1048576) MB y por aquí solo "
                             + "caben \(maxMB). Súbelo desde el bot de vídeos de Tienda.")
        }
        let frontera = "Demo-\(UUID().uuidString)"
        var p = URLRequest(url: direccion("api/videos/\(categoria)/subir"))
        p.httpMethod = "POST"
        p.timeoutInterval = 300
        p.setValue("multipart/form-data; boundary=\(frontera)", forHTTPHeaderField: "Content-Type")
        if let testigo { p.setValue("Bearer \(testigo)", forHTTPHeaderField: "Authorization") }

        var cuerpo = Data()
        cuerpo.append("--\(frontera)\r\n".data(using: .utf8)!)
        cuerpo.append("Content-Disposition: form-data; name=\"titulo\"\r\n\r\n"
                      .data(using: .utf8)!)
        cuerpo.append(titulo.data(using: .utf8)!)
        cuerpo.append("\r\n--\(frontera)\r\n".data(using: .utf8)!)
        cuerpo.append("Content-Disposition: form-data; name=\"video\"; filename=\"video.mp4\"\r\n"
                      .data(using: .utf8)!)
        cuerpo.append("Content-Type: video/mp4\r\n\r\n".data(using: .utf8)!)
        cuerpo.append(datosVideo)
        cuerpo.append("\r\n--\(frontera)--\r\n".data(using: .utf8)!)
        p.httpBody = cuerpo

        let larga = URLSessionConfiguration.default
        larga.timeoutIntervalForRequest = 300
        larga.timeoutIntervalForResource = 600
        let sesionLarga = URLSession(configuration: larga)

        let datos: Data
        let respuesta: URLResponse
        do {
            (datos, respuesta) = try await sesionLarga.data(for: p)
        } catch {
            throw falloDePeticion(error)
        }
        let codigo = (respuesta as? HTTPURLResponse)?.statusCode ?? 0
        if codigo == 401 || codigo == 403 { avisarTestigoRechazado(); throw Fallo.sinTestigo }
        guard let json = try? JSONSerialization.jsonObject(with: datos) as? [String: Any] else {
            throw Fallo.red("El servidor ha contestado algo que no se entiende.")
        }
        if !(200..<300).contains(codigo) {
            throw Fallo.dijo((json["mensaje"] as? String) ?? "No se ha podido subir.")
        }
        return json
    }

    static func subirExcel(_ archivo: Data, nombre: String, trimestre: String, tipo: String,
                           testigo: String?) async throws -> [String: Any] {
        let frontera = "Demo-\(UUID().uuidString)"
        var p = URLRequest(url: direccion("api/impuestos/asesoria/excel"))
        p.httpMethod = "POST"
        p.timeoutInterval = 60
        p.setValue("multipart/form-data; boundary=\(frontera)", forHTTPHeaderField: "Content-Type")
        if let testigo { p.setValue("Bearer \(testigo)", forHTTPHeaderField: "Authorization") }
        var cuerpo = Data()
        for (campo, valor) in [("trimestre", trimestre), ("tipo", tipo)] {
            cuerpo.append("--\(frontera)\r\nContent-Disposition: form-data; name=\"\(campo)\"\r\n\r\n"
                          .data(using: .utf8)!)
            cuerpo.append("\(valor)\r\n".data(using: .utf8)!)
        }
        
        cuerpo.append("--\(frontera)\r\nContent-Disposition: form-data; name=\"archivo\"; filename=\"asesoria.xlsx\"\r\n"
                      .data(using: .utf8)!)
        cuerpo.append("Content-Type: application/vnd.openxmlformats-officedocument.spreadsheetml.sheet\r\n\r\n"
                      .data(using: .utf8)!)
        cuerpo.append(archivo)
        cuerpo.append("\r\n--\(frontera)--\r\n".data(using: .utf8)!)
        p.httpBody = cuerpo

        let larga = URLSessionConfiguration.default
        larga.timeoutIntervalForRequest = 60
        let datos: Data
        let respuesta: URLResponse
        do {
            (datos, respuesta) = try await URLSession(configuration: larga).data(for: p)
        } catch {
            throw falloDePeticion(error)
        }
        let codigo = (respuesta as? HTTPURLResponse)?.statusCode ?? 0
        if codigo == 401 || codigo == 403 { avisarTestigoRechazado(); throw Fallo.sinTestigo }
        guard let json = try? JSONSerialization.jsonObject(with: datos) as? [String: Any] else {
            throw Fallo.servidor(codigo)
        }
        if !(json["ok"] as? Bool ?? false) {
            throw Fallo.dijo(json["mensaje"] as? String ?? "No se ha podido subir.")
        }
        return json
    }

    static func subirFoto(_ imagen: Data, testigo: String?) async throws -> [String: Any] {
        let frontera = "Demo-\(UUID().uuidString)"
        var p = URLRequest(url: direccion("api/perfil/foto"))
        p.httpMethod = "POST"
        p.setValue("multipart/form-data; boundary=\(frontera)", forHTTPHeaderField: "Content-Type")
        if let testigo { p.setValue("Bearer \(testigo)", forHTTPHeaderField: "Authorization") }

        var cuerpo = Data()
        cuerpo.append("--\(frontera)\r\n".data(using: .utf8)!)
        cuerpo.append("Content-Disposition: form-data; name=\"foto\"; filename=\"foto.jpg\"\r\n"
                      .data(using: .utf8)!)
        cuerpo.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        cuerpo.append(imagen)
        cuerpo.append("\r\n--\(frontera)--\r\n".data(using: .utf8)!)
        p.httpBody = cuerpo

        let datos: Data
        let respuesta: URLResponse
        do {
            (datos, respuesta) = try await sesionURL.data(for: p)
        } catch {
            throw falloDePeticion(error)
        }
        let codigo = (respuesta as? HTTPURLResponse)?.statusCode ?? 0
        if codigo == 401 || codigo == 403 { avisarTestigoRechazado(); throw Fallo.sinTestigo }
        guard let json = try? JSONSerialization.jsonObject(with: datos) as? [String: Any] else {
            throw Fallo.servidor(codigo)
        }
        if !(json["ok"] as? Bool ?? false) {
            throw Fallo.red(json["mensaje"] as? String ?? "No se ha podido subir.")
        }
        return json
    }

    static func bajarImagen(_ ruta: String, testigo: String?) async -> UIImage? {
        #if MAQUETA
        return nil   
        #else
        var p = URLRequest(url: direccion(ruta))
        if let testigo { p.setValue("Bearer \(testigo)", forHTTPHeaderField: "Authorization") }
        guard let (datos, respuesta) = try? await sesionURL.data(for: p),
              (respuesta as? HTTPURLResponse)?.statusCode == 200 else { return nil }
        return UIImage(data: datos)
        #endif
    }

    static func bajarPDF(_ ruta: String, nombre: String, testigo: String?) async throws -> URL {
        var p = URLRequest(url: direccion(ruta))
        if let testigo { p.setValue("Bearer \(testigo)", forHTTPHeaderField: "Authorization") }
        let datos: Data
        let respuesta: URLResponse
        do {
            (datos, respuesta) = try await sesionURL.data(for: p)
        } catch {
            throw falloDePeticion(error)
        }
        let codigo = (respuesta as? HTTPURLResponse)?.statusCode ?? 0
        if codigo == 401 || codigo == 403 { avisarTestigoRechazado(); throw Fallo.sinTestigo }
        guard codigo == 200 else { throw Fallo.servidor(codigo) }

        let destino = FileManager.default.temporaryDirectory.appendingPathComponent(nombre)
        try datos.write(to: destino)
        return destino
    }
}

extension Notification.Name {
    
    static let testigoRechazado = Notification.Name("Ingresos.testigoRechazado")

    static let recargaFallida = Notification.Name("Ingresos.recargaFallida")
}
