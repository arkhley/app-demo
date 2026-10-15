import SwiftUI

enum PantallaHucha {
    
    struct MesHucha: Equatable {
        let mes: String
        let diasHechos: Int
        let diasQueQuedan: Int
        let ganado: Double
        let objetivoHastaHoy: Double
        let objetivoMes: Double
    }

    struct MesCerrado: Identifiable, Equatable {
        let mes: String
        let saldoFinal: Double
        let ganado: Double
        let objetivoMes: Double
        var id: String { mes }
    }

    struct Supone: Equatable {
        let alaSemana: Double
        let alMes: Double

        var diasDelMes: Int = 0
        let tokensDia: Int?
        let tokensMes: Int?
    }

    struct DiaHucha: Identifiable, Equatable {
        let fecha: String
        let ganado: Double
        let aporte: Double
        let relleno: Double
        let total: Double
        let falto: Bool
        let cerrado: Bool

        var objetivo: Double? = nil
        var falta: Double? = nil
        var id: String { fecha }

        init?(_ j: [String: Any]) {
            guard let f = j["fecha"] as? String else { return nil }
            fecha = f
            ganado = (j["ganado"] as? Double) ?? 0
            aporte = (j["aporte"] as? Double) ?? 0
            relleno = (j["relleno"] as? Double) ?? 0
            total = (j["total"] as? Double) ?? 0
            falto = (j["falto"] as? Bool) ?? false
            cerrado = (j["cerrado"] as? Bool) ?? false
            objetivo = (j["objetivo"] as? NSNumber)?.doubleValue
            falta = (j["falta"] as? NSNumber)?.doubleValue
        }
    }
}
