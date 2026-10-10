#if MAQUETA
import SwiftUI

enum Maqueta {
    private static func argumento(_ clave: String) -> String? {
        UserDefaults.standard.string(forKey: clave)
    }

    static var abrirPanel: Bool { argumento("abrir") == "panel" }
    
    static var progresoPanel: CGFloat? { argumento("progreso").flatMap(Double.init).map { CGFloat($0) } }
    static var herramienta: String? { argumento("herramienta") }
    
    static var pistaFija: CGFloat? { argumento("pista").flatMap(Double.init).map { CGFloat($0) } }
    
    static var pistaAnimada: Bool { argumento("pista") == "animada" }

    static var fondoDePrueba: UIImage? {
        guard argumento("fondo") == "demo" else { return nil }
        let tamano = CGSize(width: 1320, height: 2868)
        let formato = UIGraphicsImageRendererFormat()
        formato.scale = 1
        formato.opaque = true
        return UIGraphicsImageRenderer(size: tamano, format: formato).image { c in
            let cg = c.cgContext
            let w = tamano.width, h = tamano.height
            func degradado(_ a: UIColor, _ b: UIColor, de: CGPoint, hasta: CGPoint) {
                guard let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                         colors: [a.cgColor, b.cgColor] as CFArray,
                                         locations: [0, 1]) else { return }
                cg.drawLinearGradient(g, start: de, end: hasta,
                                      options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
            }
            let oscuro = UIColor(red: 0.17, green: 0.14, blue: 0.21, alpha: 1)
            let medio = UIColor(red: 0.50, green: 0.45, blue: 0.58, alpha: 1)
            let claro = UIColor(red: 0.80, green: 0.76, blue: 0.85, alpha: 1)
            degradado(oscuro, medio, de: .zero, hasta: CGPoint(x: w, y: h))
            
            let cintas: [(CGFloat, CGFloat, UIColor, UIColor)] = [
                (0.06, 0.36, claro, medio), (0.40, 0.68, medio, oscuro), (0.66, 1.02, oscuro, claro),
            ]
            for (arriba, abajo, de, a) in cintas {
                let cinta = UIBezierPath()
                cinta.move(to: CGPoint(x: 0, y: h * arriba))
                cinta.addCurve(to: CGPoint(x: w, y: h * (arriba + 0.1)),
                               controlPoint1: CGPoint(x: w * 0.35, y: h * (arriba - 0.12)),
                               controlPoint2: CGPoint(x: w * 0.6, y: h * (arriba + 0.24)))
                cinta.addLine(to: CGPoint(x: w, y: h * abajo))
                cinta.addCurve(to: CGPoint(x: 0, y: h * (abajo - 0.06)),
                               controlPoint1: CGPoint(x: w * 0.62, y: h * (abajo + 0.1)),
                               controlPoint2: CGPoint(x: w * 0.3, y: h * (abajo - 0.22)))
                cinta.close()
                cg.saveGState()
                cinta.addClip()
                degradado(de, a, de: CGPoint(x: 0, y: h * arriba), hasta: CGPoint(x: w, y: h * abajo))
                cg.restoreGState()
                UIColor(white: 1, alpha: 0.5).setStroke()
                cinta.lineWidth = 3
                cinta.stroke()
            }
        }
    }
    static var abrirCuenta: Bool { argumento("abrir") == "cuenta" }
    static var sub: String? { argumento("sub") }
    static var pantalla: String? { argumento("pantalla") }
    
    static var subImpuestos: String? {
        argumento("imp") ?? (argumento("abrir") == "porque" ? "porque" : nil)
    }
    static var estado: String? { argumento("estado") }

    static var codigoDePrueba: Bool { argumento("codigo") == "prueba" }

    static var caraQueNoLee: Bool { argumento("cara") == "espera" }
    static var caraQueNoAcaba: Bool { argumento("cara") == "nunca" }
    
    static var caraQueLee: Bool { argumento("cara") == "lee" }

    static var llegadaFija: Double? { argumento("llegada").flatMap(Double.init) }
    
    static var fallosDePrueba: Int? { argumento("fallos").flatMap(Int.init) }
    
    static var cristalRegular: Bool { argumento("cristal") == "regular" }

    static func avisarLista() {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("maqueta-lista")
        try? Data("lista".utf8).write(to: url)
    }

    @MainActor
    static func anclada(_ vista: some View) -> some View {
        Group {
            if argumento("bajar") != nil {
                vista.defaultScrollAnchor(anclaSala)
            } else {
                vista
            }
        }
    }

    @MainActor @ViewBuilder
    static func vistaDeInicio() -> some View {
        let p = plataforma ?? "plataforma1"
        switch pantalla ?? "" {
        case "codigos": anclada(PantallaCodigos())
        case "videos": anclada(PantallaVideos())
        case "categoria": anclada(PantallaCategoria(clave: "exclusivos", nombre: "Exclusivos"))
        case "plataformas": anclada(PantallaPlataformas())
        case "transferencias": anclada(PantallaTransferencias())
        case "detalle": anclada(PantallaDetalleP1(periodo: periodo ?? "mes", plataforma: p))
        case "historial": anclada(PantallaHistorial(plataforma: plataforma ?? "todo"))
        case "encargos": anclada(PantallaEncargosBalanza())
        case "apuntar": anclada(PantallaManual(clave: "plataforma2"))
        case "ajustescb": anclada(PantallaAjustesP1())
        case "ajustesmanual": anclada(PantallaAjustesManual(clave: "plataforma2"))
        case "ajustestienda": anclada(PantallaAjustesTienda())
        case "canal": anclada(PantallaCanal())
        case "clientes": anclada(PantallaClientes())
        case "comosecalcula": anclada(PantallaComoSeCalcula(plataforma: p))
        case "widget": anclada(PantallaVistaWidget())
        default: Text("La maqueta no conoce «\(pantalla ?? "")»")
        }
    }

    @MainActor @ViewBuilder
    static func vistaDeCuenta() -> some View {
        switch sub ?? "" {
        case "info": anclada(PantallaInformacionPersonal())
        case "seguridad": anclada(PantallaSeguridad())
        case "faceid": anclada(PantallaFaceID())
        case "claves": anclada(PantallaClaves())
        case "reserva": anclada(PantallaHuchaNueva())
        case "calendario": anclada(PantallaCalendarioHuchaNueva())
        case "impuestos": PantallaImpuestos(trimestreInicial: trimestre)
        case "avisos": anclada(PantallaAvisos())
        case "almacenamiento": anclada(PantallaResumenCuenta())
        case "logs": anclada(PantallaRegistro())
        case "borrar": anclada(PantallaBorrarHistorial())
        case "temas": anclada(PantallaTemas())
        default: Text("La maqueta no conoce «\(sub ?? "")»")
        }
    }

    static var escena: String { argumento("escena") ?? "descansar" }
    static var abrirPrevision: Bool { argumento("abrir") == "prevision" }
    static var hojaEntera: Bool { argumento("altura") == "grande" }
    
    static var plataforma: String? { argumento("plataforma") }
    static var periodo: String? { argumento("periodo") }
    static var bajar: Bool { argumento("bajar") == "1" }
    
    static var anclaSala: UnitPoint {
        switch argumento("bajar") { case "1": .center; case "2": .bottom; default: .top }
    }
    static var abrirChat: Bool { argumento("abrir") == "chat" }
    
    static var pestana: String { argumento("pestana") ?? "inicio" }

    static var calentarVida: Double? { argumento("vida.calentar").flatMap(Double.init) }
    
    static var seccionDeTemas: String? { argumento("seccion") }

    static var cambiarTema: String? { argumento("cambiar") }
    
    static var minutoSala: Int? { argumento("minuto").flatMap(Int.init) }
    
    static var cobroElegido: Int? { argumento("cobro").flatMap(Int.init) }
    
    static var abrirMes: Bool { argumento("abrir") == "mes" }
    
    static var abrirPedido: Bool { argumento("abrir") == "pedido" }
    
    static var abrirNueva: Bool { argumento("abrir") == "nueva" }
    
    static var abrirImpuestos: Bool { ["impuestos", "porque"].contains(argumento("abrir") ?? "") }
    static var abrirPorQue: Bool { subImpuestos == "porque" }
    
    static var trimestre: String { argumento("trimestre") ?? "" }

    static func respuesta(_ ruta: String) -> [String: Any]? {
        var clave = ruta.hasPrefix("/") ? String(ruta.dropFirst()) : ruta
        if let i = clave.firstIndex(of: "?") { clave = String(clave[..<i]) }
        
        if clave == "api/impuestos", let r = ruta.range(of: "trimestre=") {
            let t = String(ruta[r.upperBound...].prefix(7))
            if MaquetaDatos.porEscena[escena]?["api/impuestos/" + t] != nil
                || MaquetaDatos.respuestas["api/impuestos/" + t] != nil {
                clave = "api/impuestos/" + t
            }
        }
        guard let texto = MaquetaDatos.porEscena[escena]?[clave] ?? MaquetaDatos.respuestas[clave],
              let datos = texto.data(using: .utf8),
              var json = try? JSONSerialization.jsonObject(with: datos) as? [String: Any]
        else { return nil }

        if clave == "api/inicio", ruta.contains("periodo=dia"),
           var todas = json["todas"] as? [String: [String: Any]] {
            for k in todas.keys { todas[k]?["serie"] = NSNull() }
            json["todas"] = todas
        }
        
        if clave == "api/inicio", ruta.contains("periodo=semana"),
           var todas = json["todas"] as? [String: [String: Any]] {
            var cal = Calendar(identifier: .gregorian)
            cal.timeZone = TimeZone(identifier: "UTC") ?? .current
            let lector = DateFormatter()
            lector.calendar = cal
            lector.timeZone = cal.timeZone
            lector.dateFormat = "yyyy-MM-dd"
            for k in todas.keys {
                guard var s = todas[k]?["serie"] as? [String: Any],
                      let puntos = s["puntos"] as? [[String: Any]],
                      let ultimo = (puntos.last?["f"] as? String).flatMap(lector.date(from:)) else { continue }
                let lunes = cal.date(byAdding: .day,
                                     value: -((cal.component(.weekday, from: ultimo) + 5) % 7), to: ultimo) ?? ultimo
                let dentro = puntos.filter {
                    guard let f = ($0["f"] as? String).flatMap(lector.date(from:)) else { return false }
                    return f >= lunes
                }
                s["puntos"] = dentro
                todas[k]?["serie"] = dentro.count >= 2 ? s : NSNull()
            }
            json["todas"] = todas
        }

        if clave == "api/inicio", ruta.contains("periodo=quincena"),
           var todas = json["todas"] as? [String: [String: Any]] {
            for k in todas.keys {
                guard let s = todas[k]?["serie"] as? [String: Any],
                      let puntos = s["puntos"] as? [[String: Any]],
                      let ultimo = puntos.last?["f"] as? String else { continue }
                let mes = String(ultimo.prefix(7))
                let primera = (Int(ultimo.suffix(2)) ?? 1) <= 15
                let dentro = puntos.filter {
                    let f = $0["f"] as? String ?? ""
                    let d = Int(f.suffix(2)) ?? 0
                    return f.hasPrefix(mes) && (primera ? d <= 15 : d >= 16)
                }
                var nueva = s
                nueva["puntos"] = dentro
                todas[k]?["serie"] = dentro.count >= 2 ? nueva : NSNull()
            }
            json["todas"] = todas
        }

        if clave == "api/inicio", let r = ruta.range(of: "plataforma=") {
            let p = String(ruta[r.upperBound...].prefix(while: { $0 != "&" }))
            if p != "todas", let una = (json["todas"] as? [String: Any])?[p] as? [String: Any] {
                return una
            }
        }
        return json
    }
}
#endif
