import Foundation

struct InformeSala: Equatable {
    struct Noche: Equatable, Identifiable {
        let jornada: String
        let inicio: Date?
        let enCurso: Bool
        let minutos: Int
        let cortes: Int
        let tokens: Int
        let euros: Double
        let propinas: Int
        let tokensPropinas: Int
        let sinDetalle: Int
        
        var anonimas = 0
        var propinasAnonimas = 0
        let personas: Int
        let nuevos: Int
        let mejor: Persona?
        let pico: Int?
        let unicos: Int?
        let seguidores: Int?
        var id: String { jornada }
    }

    struct Persona: Equatable, Identifiable {
        let quien: String
        let tokens: Int
        var propinas = 0
        var noches = 1
        var nuevo = false
        var vuelve = false
        var primera = ""
        var ultima = ""
        var mayor = 0
        var id: String { quien }
    }

    struct Propina: Equatable, Identifiable {
        let minuto: Int
        let quien: String
        let tokens: Int
        let mensaje: String
        let orden: Int
        var id: Int { orden }
    }

    struct Normal: Equatable {
        let noches: Int
        let tokens: Double?
        let minutos: Double?
        let personas: Double?
        let pico: Double?
        let seguidores: Double?
    }

    struct Detalle: Equatable {
        let noche: Noche
        
        let tramos: [ClosedRange<Int>]
        
        let gente: [(minuto: Int, personas: Int)]
        let seguidoresMin: [(minuto: Int, cuantos: Int)]
        let propinas: [Propina]
        let quienes: [Persona]
        let puesto: Int?
        let de: Int
        let normal: Normal?

        static func == (a: Detalle, b: Detalle) -> Bool {
            a.noche == b.noche && a.tramos == b.tramos && a.propinas == b.propinas
                && a.gente.map(\.personas) == b.gente.map(\.personas)
                && a.seguidoresMin.map(\.cuantos) == b.seguidoresMin.map(\.cuantos)
                && a.quienes == b.quienes && a.puesto == b.puesto && a.normal == b.normal
        }
    }

    struct ResumenGente: Equatable {
        let personas: Int
        let vuelven: Int
        let tokens: Int
        let parteTop10: Double?
    }

    let desde: String
    
    let hoy: String
    let enDirecto: Bool
    let noches: [Noche]
    let noche: Detalle?
    let gente: [Persona]
    let resumenGente: ResumenGente
    let desdeGente: String
}

extension InformeSala {
    init(_ j: [String: Any]) {
        desde = j["desde"] as? String ?? ""
        hoy = j["hoy"] as? String ?? ""
        enDirecto = j["en_directo"] as? Bool ?? false
        noches = ((j["noches"] as? [[String: Any]]) ?? []).map(Self.noche)
        if let d = j["noche"] as? [String: Any] {
            noche = Self.detalle(d)
        } else {
            noche = nil
        }
        let g = j["gente"] as? [String: Any] ?? [:]
        gente = ((g["personas"] as? [[String: Any]]) ?? []).map(Self.persona)
        let r = g["resumen"] as? [String: Any] ?? [:]
        resumenGente = ResumenGente(personas: Self.int(r["personas"]), vuelven: Self.int(r["vuelven"]),
                                    tokens: Self.int(r["tokens"]),
                                    parteTop10: (r["parte_top10"] as? NSNumber)?.doubleValue)
        desdeGente = g["desde"] as? String ?? ""
    }

    private static func int(_ v: Any?) -> Int { (v as? NSNumber)?.intValue ?? 0 }
    private static func intONil(_ v: Any?) -> Int? { (v as? NSNumber)?.intValue }
    private static func doble(_ v: Any?) -> Double? { (v as? NSNumber)?.doubleValue }

    static func noche(_ j: [String: Any]) -> Noche {
        Noche(jornada: j["jornada"] as? String ?? "",
              inicio: (j["inicio"] as? String).flatMap { try? Date($0, strategy: .iso8601) },
              enCurso: j["en_curso"] as? Bool ?? false,
              minutos: int(j["minutos"]), cortes: int(j["cortes"]), tokens: int(j["tokens"]),
              euros: doble(j["euros"]) ?? 0, propinas: int(j["propinas"]),
              tokensPropinas: int(j["tokens_propinas"]), sinDetalle: int(j["sin_detalle"]),
              anonimas: int(j["anonimas"]), propinasAnonimas: int(j["propinas_anonimas"]),
              personas: int(j["personas"]), nuevos: int(j["nuevos"]),
              mejor: (j["mejor"] as? [String: Any]).map { persona($0) },
              pico: intONil(j["pico"]), unicos: intONil(j["unicos"]),
              seguidores: intONil(j["seguidores"]))
    }

    static func persona(_ j: [String: Any]) -> Persona {
        Persona(quien: j["quien"] as? String ?? "", tokens: int(j["tokens"]),
                propinas: int(j["propinas"]), noches: max(int(j["noches"]), 1),
                nuevo: j["nuevo"] as? Bool ?? false, vuelve: j["vuelve"] as? Bool ?? false,
                primera: j["primera"] as? String ?? "", ultima: j["ultima"] as? String ?? "",
                mayor: int(j["mayor"]))
    }

    static func detalle(_ j: [String: Any]) -> Detalle {
        func pares(_ v: Any?) -> [(Int, Int)] {
            ((v as? [[Any]]) ?? []).compactMap { p in
                guard p.count == 2, let a = (p[0] as? NSNumber)?.intValue,
                      let b = (p[1] as? NSNumber)?.intValue else { return nil }
                return (a, b)
            }
        }
        let n = j["normal"] as? [String: Any]
        return Detalle(
            noche: noche(j),
            tramos: pares(j["tramos"]).map { $0.0...max($0.0, $0.1) },
            gente: pares(j["gente"]).map { (minuto: $0.0, personas: $0.1) },
            seguidoresMin: pares(j["seguidores_min"]).map { (minuto: $0.0, cuantos: $0.1) },
            propinas: ((j["lista_propinas"] as? [[String: Any]]) ?? []).enumerated().map { i, p in
                Propina(minuto: int(p["minuto"]), quien: p["quien"] as? String ?? "",
                        tokens: int(p["tokens"]), mensaje: p["mensaje"] as? String ?? "", orden: i)
            },
            quienes: ((j["quienes"] as? [[String: Any]]) ?? []).map(persona),
            puesto: intONil(j["puesto"]),
            de: int(j["de"]),
            normal: n.map {
                Normal(noches: int($0["noches"]), tokens: doble($0["tokens"]),
                       minutos: doble($0["minutos"]), personas: doble($0["personas"]),
                       pico: doble($0["pico"]), seguidores: doble($0["seguidores"]))
            })
    }
}

enum NombreDeNoche {
    private static let dias = ["domingo", "lunes", "martes", "miércoles", "jueves", "viernes",
                               "sábado"]
    private static let meses = ["ene", "feb", "mar", "abr", "may", "jun", "jul", "ago", "sep",
                                "oct", "nov", "dic"]

    private static func fecha(_ jornada: String) -> Date? {
        let p = jornada.split(separator: "-").compactMap { Int($0) }
        guard p.count == 3 else { return nil }
        var c = DateComponents()
        c.year = p[0]; c.month = p[1]; c.day = p[2]; c.hour = 12
        return Calendar(identifier: .gregorian).date(from: c)
    }

    static func titulo(_ jornada: String, hoy: String, enCurso: Bool = false) -> String {
        if enCurso || (!hoy.isEmpty && jornada == hoy) { return "Esta noche" }
        guard let f = fecha(jornada) else { return jornada }
        let cal = Calendar(identifier: .gregorian)
        if let h = fecha(hoy), let ayer = cal.date(byAdding: .day, value: -1, to: h),
           cal.isDate(f, inSameDayAs: ayer) {
            return "Anoche"
        }
        let dia = dias[(cal.component(.weekday, from: f) - 1) % 7].capitalized
        let n = cal.component(.day, from: f)
        if let h = fecha(hoy), cal.component(.month, from: h) == cal.component(.month, from: f) {
            return "\(dia) \(n)"
        }
        return "\(dia) \(n) \(meses[cal.component(.month, from: f) - 1])"
    }

    static func inicial(_ jornada: String) -> String {
        guard let f = fecha(jornada) else { return "" }
        let cal = Calendar(identifier: .gregorian)
        return String(dias[(cal.component(.weekday, from: f) - 1) % 7].prefix(1)).uppercased()
    }

    static func numero(_ jornada: String) -> String {
        guard let f = fecha(jornada) else { return "" }
        return "\(Calendar(identifier: .gregorian).component(.day, from: f))"
    }

    static func hora(_ inicio: Date?, minuto: Int) -> String {
        guard let inicio else { return "" }
        return reloj.string(from: inicio.addingTimeInterval(Double(minuto) * 60))
    }

    private static let reloj: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "es_ES")
        f.timeZone = TimeZone(identifier: "Europe/Madrid")
        f.dateFormat = "HH:mm"
        return f
    }()
}
