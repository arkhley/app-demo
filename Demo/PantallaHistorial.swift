import SwiftUI

struct PantallaHistorial: View {
    let plataforma: String

    var body: some View {
        
        HistorialNuevo(plataforma: plataforma)
    }

    struct Mes: Identifiable, Equatable {
        let clave: String
        let nombre: String
        let anio: Int
        let enCurso: Bool
        let euros: Double
        let dias: Int
        let horas: Double
        let porDia: Double
        let porHora: Double?
        var tokens: Int = 0
        
        var horaParcial: Bool = false
        
        var partes: [Parte] = []
        var id: String { clave }

        struct Parte: Equatable {
            let clave: String
            let nombre: String
            let euros: Double
        }
    }

    static func leerMeses(_ json: Any?) -> [Mes] {
        ((json as? [[String: Any]]) ?? []).map { m in
            Mes(clave: m["clave"] as? String ?? "",
                nombre: m["nombre"] as? String ?? "",
                anio: m["anio"] as? Int ?? 0,
                enCurso: m["en_curso"] as? Bool ?? false,
                euros: m["euros"] as? Double ?? 0,
                dias: m["dias"] as? Int ?? 0,
                horas: (m["horas"] as? Double) ?? Double(m["horas"] as? Int ?? 0),
                porDia: m["por_dia"] as? Double ?? 0,
                porHora: m["por_hora"] as? Double,
                tokens: m["tokens"] as? Int ?? 0,
                horaParcial: m["hora_parcial"] as? Bool ?? false,
                partes: ((m["partes"] as? [[String: Any]]) ?? []).map {
                    Mes.Parte(clave: $0["clave"] as? String ?? "",
                              nombre: $0["nombre"] as? String ?? "",
                              euros: $0["euros"] as? Double ?? 0)
                })
        }
    }
}
