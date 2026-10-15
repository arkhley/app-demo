import SwiftUI

struct PantallaDetalleP1: View {
    var periodo: String = "mes"
    var plataforma: String = "plataforma1"

    var body: some View {
        
        DetalleNuevo(periodo: periodo, plataforma: plataforma)
    }

    struct Linea: Identifiable, Equatable {
        var clave: String = ""
        let nombre: String
        let tokens: Int
        let veces: Int
        let euros: Double
        var id: String { nombre }
    }

    struct DiaDetalle: Identifiable, Equatable {
        let fecha: String
        let tokens: Int
        let euros: Double
        let cuantas: Int
        var horas: Double = 0
        
        var sinDetalle: Int = 0
        let propinas: [Propina]
        var id: String { fecha }

        struct Propina: Identifiable, Equatable {
            let hora: String
            let tokens: Int
            let concepto: String
            let de: String
            let clase: String
            var id: String { "\(hora)|\(tokens)|\(de)|\(concepto)" }
        }
    }

    static func lineas(_ json: Any?) -> [Linea] {
        ((json as? [[String: Any]]) ?? []).map {
            Linea(clave: $0["clave"] as? String ?? "",
                  nombre: $0["nombre"] as? String ?? "",
                  tokens: $0["tokens"] as? Int ?? 0,
                  veces: $0["veces"] as? Int ?? 0,
                  euros: $0["euros"] as? Double ?? 0)
        }
    }

    static func dias(_ json: Any?) -> [DiaDetalle] {
        ((json as? [[String: Any]]) ?? []).map { d in
            DiaDetalle(fecha: d["fecha"] as? String ?? "",
                       tokens: d["tokens"] as? Int ?? 0,
                       euros: d["euros"] as? Double ?? 0,
                       cuantas: d["cuantas"] as? Int ?? 0,
                       horas: (d["horas"] as? Double) ?? Double(d["horas"] as? Int ?? 0),
                       sinDetalle: d["sin_detalle"] as? Int ?? 0,
                       propinas: ((d["propinas"] as? [[String: Any]]) ?? []).map {
                           DiaDetalle.Propina(hora: $0["hora"] as? String ?? "",
                                              tokens: $0["tokens"] as? Int ?? 0,
                                              concepto: $0["concepto"] as? String ?? "",
                                              de: $0["de"] as? String ?? "",
                                              clase: $0["clase"] as? String ?? "")
                       })
        }
    }

    static func titulo(_ periodo: String) -> String {
        switch periodo {
        case "dia": return "Detalle · hoy"
        case "quincena": return "Detalle · esta quincena"
        case "semana": return "Detalle · esta semana"
        case "mes": return "Detalle · este mes"
        case "ano": return "Detalle · este año"
        default: return "Detalle · todo"
        }
    }
}
