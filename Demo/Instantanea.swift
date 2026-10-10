import Foundation

public struct Instantanea: Codable, Equatable, Sendable {
    public struct Hoy: Codable, Equatable, Sendable {
        public var emitiendo: Bool
        public var minutos: Int
        public var euros: Double
        public var trabajado: Bool
        public var posicion: String?

        public init(emitiendo: Bool, minutos: Int, euros: Double, trabajado: Bool,
                    posicion: String?) {
            self.emitiendo = emitiendo
            self.minutos = minutos
            self.euros = euros
            self.trabajado = trabajado
            self.posicion = posicion
        }
    }

    public var estado: String

    public var manana: String?
    
    public var objetivo: Double
    public var hoy: Hoy
    
    public var normal: Double?
    public var descansos: Int?
    public var llega: Bool?
    public var cubierto: Bool?
    
    public var generado: Date?

    public init(estado: String, manana: String?, objetivo: Double, hoy: Hoy, normal: Double?,
                descansos: Int?, llega: Bool?, cubierto: Bool?, generado: Date?) {
        self.estado = estado
        self.manana = manana
        self.objetivo = objetivo
        self.hoy = hoy
        self.normal = normal
        self.descansos = descansos
        self.llega = llega
        self.cubierto = cubierto
        self.generado = generado
    }

    public static func leer(_ datos: Data) -> Instantanea? {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .custom { decoder in
            let texto = try decoder.singleValueContainer().decode(String.self)
            if let fecha = ISO8601DateFormatter().date(from: texto) { return fecha }
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath,
                                                    debugDescription: "fecha: \(texto)"))
        }
        return try? d.decode(Instantanea.self, from: datos)
    }

    public init?(json j: [String: Any]) {
        guard let estado = j["estado"] as? String else { return nil }
        let h = j["hoy"] as? [String: Any] ?? [:]
        let plan = j["plan"] as? [String: Any]
        let noche = j["noche"] as? [String: Any]
        func numero(_ v: Any?) -> Double? {
            (v as? Double) ?? (v as? Int).map(Double.init)
        }
        self.init(estado: estado,
                  manana: j["manana"] as? String,
                  objetivo: numero(j["objetivo"]) ?? 0,
                  hoy: Hoy(emitiendo: h["emitiendo"] as? Bool ?? false,
                           minutos: h["minutos"] as? Int ?? 0,
                           euros: numero(h["euros"]) ?? 0,
                           trabajado: h["trabajado"] as? Bool ?? false,
                           posicion: h["posicion"] as? String),
                  normal: numero(j["normal"]) ?? numero(noche?["p50"]),
                  descansos: (j["descansos"] as? Int) ?? (plan?["descansos"] as? Int),
                  llega: (j["llega"] as? Bool) ?? (plan?["llega"] as? Bool),
                  cubierto: (j["cubierto"] as? Bool) ?? (plan?["cubierto"] as? Bool),
                  generado: (j["generado"] as? String).flatMap { ISO8601DateFormatter().date(from: $0) })
    }
}

public enum TonoWidget: Sendable {
    case azul, naranja, rojo, verde, gris
}

public extension Instantanea {
    var enDirecto: Bool { estado == "en_directo" }
    var nocheEnMarcha: Bool { hoy.emitiendo || hoy.trabajado }
    var objetivoCubierto: Bool { nocheEnMarcha && objetivo > 0 && hoy.euros >= objetivo }

    var veredicto: String {
        switch estado {
        case "descansar": return "Puedes descansar"
        case "trabajar": return "Toca emitir"
        case "riesgo": return "El mes va justo"
        case "en_directo": return "En directo"
        case "hecho":
            switch manana {
            case "descansar": return "Mañana puedes descansar"
            case "trabajar": return "Mañana toca emitir"
            case "riesgo": return "El mes va justo"
            default: break
            }
            switch hoy.posicion {
            case "encima": return "Por encima de lo normal"
            case "debajo": return "Por debajo de lo normal"
            default: return "Una noche normal"
            }
        case "sin_objetivo": return "Sin objetivo en la Reserva"
        default: return "Tu noche normal"
        }
    }

    var veredictoCorto: String {
        switch (estado, manana) {
        case ("hecho", "descansar"): return "Mañana, descanso"
        case ("hecho", "trabajar"): return "Mañana, a emitir"
        default: return veredicto
        }
    }

    var simbolo: String {
        switch estado {
        case "descansar": return "moon.zzz.fill"
        case "trabajar": return "video.fill"
        case "riesgo": return "exclamationmark.triangle.fill"
        case "en_directo": return "record.circle"
        case "hecho":
            switch manana {
            case "descansar": return "moon.zzz.fill"
            case "trabajar": return "video.fill"
            case "riesgo": return "exclamationmark.triangle.fill"
            default: break
            }
            switch hoy.posicion {
            case "encima": return "arrow.up.right"
            case "debajo": return "arrow.down.right"
            default: return "checkmark"
            }
        default: return "moon.stars.fill"
        }
    }

    var tono: TonoWidget {
        switch estado {
        case "descansar": return .azul
        case "trabajar": return .naranja
        case "riesgo", "en_directo": return .rojo
        case "hecho":
            switch manana {
            case "descansar": return .azul
            case "trabajar": return .naranja
            case "riesgo": return .rojo
            default: return hoy.posicion == "debajo" ? .gris : .verde
            }
        default: return .gris
        }
    }

    var cifra: (euros: Double, que: String)? {
        if nocheEnMarcha { return (hoy.euros, "esta noche") }
        if let n = normal { return (n, "lo normal si emites") }
        return nil
    }

    func apoyo(_ euros: (Double) -> String) -> String? {
        switch estado {
        case "en_directo":
            guard objetivo > 0 else { return nil }
            return objetivoCubierto ? "Objetivo cubierto"
                                    : "Faltan \(euros(objetivo - hoy.euros)) para el objetivo"
        case "descansar", "trabajar", "riesgo", "hecho":
            if cubierto == true { return "El mes ya está cubierto" }
            guard let d = descansos else { return nil }
            if d >= 1 { return d == 1 ? "Te queda un descanso" : "Te quedan unos \(d) descansos" }
            if llega == true { return "No te quedan descansos" }
            
            return veredicto == "El mes va justo" ? "Aunque emitas todos los días" : "El mes va justo"
        default:
            return nil
        }
    }

    var rato: String? {
        guard enDirecto, hoy.minutos > 0 else { return nil }
        let (h, m) = (hoy.minutos / 60, hoy.minutos % 60)
        if h > 0 && m > 0 { return "\(h) h \(m) min" }
        if h > 0 { return "\(h) h" }
        return "\(m) min"
    }

    var avance: Double? {
        guard nocheEnMarcha, objetivo > 0 else { return nil }
        return min(1, max(0, hoy.euros / objetivo))
    }
}

public enum CifraWidget {

    public static func euros(_ valor: Double, oculto: Bool) -> String {
        if oculto { return "••• €" }
        return valor.formatted(.currency(code: "EUR").precision(.fractionLength(0))
            .locale(Locale(identifier: "es_ES")))
            .replacingOccurrences(of: "-", with: "\u{2212}")
    }

    public static func numero(_ valor: Double, oculto: Bool) -> String {
        if oculto { return "•••" }
        return Int(valor.rounded()).formatted(.number.locale(Locale(identifier: "es_ES")))
    }
}
