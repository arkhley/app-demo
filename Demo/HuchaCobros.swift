import SwiftUI

struct CobrosHucha: Equatable {
    struct Cobro: Identifiable, Equatable {
        let id: String
        let plataforma: String
        let tipo: String
        
        let fecha: String

        let euros: Double
        let eurosDelMes: Double
        let otrosMeses: Bool
        let llegado: Bool
        let estimado: Bool
        let etiqueta: String
        
        let paraLaHucha: Double?
        let apartado: Bool
        
        let faltaUSD: Double

        var paraImpuestos: Double = 0
        
        var faltaMas: Double = 0
    }

    let mes: String
    let meses: [String]
    let hayObjetivo: Bool
    let enCurso: Bool
    let hucha: Double
    let yaLlegado: Double
    let porLlegar: Double
    let apartado: Double
    let faltaApartar: Double
    let sobra: Double
    let cobros: [Cobro]
    
    let pendiente: [String: Double]
    let pendienteTotal: Double

    init(_ j: [String: Any]) {
        func n(_ v: Any?) -> Double { (v as? NSNumber)?.doubleValue ?? 0 }
        mes = j["mes"] as? String ?? ""
        meses = j["meses"] as? [String] ?? []
        hayObjetivo = j["hay_objetivo"] as? Bool ?? false
        enCurso = j["en_curso"] as? Bool ?? false
        hucha = n(j["hucha"])
        yaLlegado = n(j["ya_llegado"])
        porLlegar = n(j["por_llegar"])
        apartado = n(j["apartado"])
        faltaApartar = n(j["falta_apartar"])
        sobra = n(j["sobra"])
        cobros = ((j["cobros"] as? [[String: Any]]) ?? []).map { c in
            Cobro(id: c["id"] as? String ?? "",
                  plataforma: c["plataforma"] as? String ?? "",
                  tipo: c["tipo"] as? String ?? "",
                  fecha: c["fecha"] as? String ?? "",
                  euros: n(c["euros"]),
                  eurosDelMes: n(c["euros_del_mes"]),
                  otrosMeses: c["otros_meses"] as? Bool ?? false,
                  llegado: c["llegado"] as? Bool ?? false,
                  estimado: c["estimado"] as? Bool ?? false,
                  etiqueta: c["etiqueta"] as? String ?? "",
                  paraLaHucha: (c["para_la_hucha"] as? NSNumber)?.doubleValue,
                  apartado: c["apartado"] as? Bool ?? false,
                  faltaUSD: n(c["falta_usd"]),
                  paraImpuestos: n(c["para_impuestos"]),
                  faltaMas: n(c["falta_mas"]))
        }
        let p = j["pendiente"] as? [String: Any] ?? [:]
        pendienteTotal = n(p["total"])
        pendiente = ((p["por_mes"] as? [String: Any]) ?? [:]).mapValues { n($0) }
    }

    static func nombreDelMes(_ iso: String, conAño: Bool = false) -> String {
        let p = iso.split(separator: "-")
        guard p.count >= 2, let m = Int(p[1]), (1...12).contains(m) else { return iso }
        let meses = ["enero", "febrero", "marzo", "abril", "mayo", "junio", "julio", "agosto",
                     "septiembre", "octubre", "noviembre", "diciembre"]
        return conAño ? "\(meses[m - 1]) de \(p[0])" : meses[m - 1]
    }
}
