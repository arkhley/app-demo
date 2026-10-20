import SwiftUI

struct GastosFijos: Equatable {
    struct Importe: Equatable, Hashable {
        let desde: String          
        let euros: Double
    }

    struct Cuotas: Equatable {
        let total: Int
        let pagadas: Int
        let quedan: Int
        
        let falta: Double
        let pagado: Double
    }

    struct Gasto: Identifiable, Equatable {
        let id: String
        let nombre: String
        let simbolo: String
        let dia: Int
        let desde: String
        
        let hasta: String
        
        let importe: Double
        let importes: [Importe]
        
        let proximoPago: String
        let cuotas: Cuotas?
        
        let cambio: Importe?
        
        let estado: String

        var paraSiempre: Bool { hasta.isEmpty }
        
        var importeVisible: Double { importe > 0 ? importe : (importes.first?.euros ?? 0) }
    }

    struct Mes: Equatable, Identifiable {
        let mes: String
        let total: Double
        
        let partes: [String: Double]
        var id: String { mes }
    }

    struct EsteMes: Equatable {
        let mes: String
        let total: Double
        let apartado: Double
        
        let porApartar: Double
        
        let porLlegar: Double
        
        let falta: Double
    }

    struct Sueldo: Equatable {
        
        let meses: [String]
        
        let media: Double?
        
        let parteGastos: Double?
    }

    let hoy: String
    let mes: String
    let gastos: [Gasto]
    let esteMes: EsteMes
    let sueldo: Sueldo
    let proyeccion: [Mes]
    
    let libreDesde: String
    
    let despues: Double?
    let hayIndefinidos: Bool
    
    let faltaTotal: Double

    static func de(_ j: [String: Any]) -> GastosFijos {
        func n(_ v: Any?) -> Double { (v as? NSNumber)?.doubleValue ?? 0 }
        func nOpc(_ v: Any?) -> Double? { (v as? NSNumber)?.doubleValue }
        func i(_ v: Any?) -> Int { (v as? NSNumber)?.intValue ?? 0 }
        func s(_ v: Any?) -> String { v as? String ?? "" }
        func importe(_ v: Any?) -> Importe? {
            guard let d = v as? [String: Any] else { return nil }
            return Importe(desde: s(d["desde"]), euros: n(d["euros"]))
        }
        let gastos = ((j["gastos"] as? [[String: Any]]) ?? []).map { g in
            Gasto(id: s(g["id"]), nombre: s(g["nombre"]), simbolo: s(g["simbolo"]),
                  dia: max(1, i(g["dia"])), desde: s(g["desde"]), hasta: s(g["hasta"]),
                  importe: n(g["importe"]),
                  importes: ((g["importes"] as? [[String: Any]]) ?? []).compactMap { importe($0) },
                  proximoPago: s(g["proximo_pago"]),
                  cuotas: (g["cuotas"] as? [String: Any]).map {
                      Cuotas(total: i($0["total"]), pagadas: i($0["pagadas"]),
                             quedan: i($0["quedan"]), falta: n($0["falta"]), pagado: n($0["pagado"]))
                  },
                  cambio: importe(g["cambio"]), estado: s(g["estado"]))
        }
        let m = (j["este_mes"] as? [String: Any]) ?? [:]
        let su = (j["sueldo"] as? [String: Any]) ?? [:]
        return GastosFijos(
            hoy: s(j["hoy"]), mes: s(j["mes"]), gastos: gastos,
            esteMes: EsteMes(mes: s(m["mes"]), total: n(m["total"]), apartado: n(m["apartado"]),
                             porApartar: n(m["por_apartar"]), porLlegar: n(m["por_llegar"]),
                             falta: n(m["falta"])),
            sueldo: Sueldo(meses: (su["meses"] as? [String]) ?? [], media: nOpc(su["media"]),
                           parteGastos: nOpc(su["parte_gastos"])),
            proyeccion: ((j["proyeccion"] as? [[String: Any]]) ?? []).map { p in
                Mes(mes: s(p["mes"]), total: n(p["total"]),
                    partes: ((p["partes"] as? [String: Any]) ?? [:]).mapValues { n($0) })
            },
            libreDesde: s(j["libre_desde"]), despues: nOpc(j["despues"]),
            hayIndefinidos: j["hay_indefinidos"] as? Bool ?? false,
            faltaTotal: n(j["falta_total"]))
    }
}

@MainActor
@Observable
final class EstadoGastosFijos {
    var estado: Carga<GastosFijos> = .cargando

    func cargar(testigo: String?) async {
        do {
            let j = try await API.pedir("api/gastos", testigo: testigo)
            withAnimation(Diseno.suave) { estado = .listo(GastosFijos.de(j)) }
        } catch {
            estado.fallar(error)
        }
    }

    func mandar(_ ruta: String, _ cuerpo: [String: any Sendable],
                testigo: String?) async -> (ok: Bool, mensaje: String) {
        do {
            let j = try await API.pedir(ruta, metodo: "POST", cuerpo: cuerpo, testigo: testigo)
            await cargar(testigo: testigo)
            return (j["ok"] as? Bool ?? true, j["mensaje"] as? String ?? "")
        } catch API.Fallo.dijo(let motivo) {
            return (false, motivo)
        } catch {
            return (false, error.localizedDescription)
        }
    }
}

enum MesesGasto {
    private static let nombres = ["enero", "febrero", "marzo", "abril", "mayo", "junio", "julio",
                                  "agosto", "septiembre", "octubre", "noviembre", "diciembre"]

    static func partes(_ mes: String) -> (año: Int, mes: Int)? {
        let p = mes.split(separator: "-").compactMap { Int($0) }
        guard p.count >= 2, (1...12).contains(p[1]) else { return nil }
        return (p[0], p[1])
    }

    static func sumar(_ mes: String, _ n: Int) -> String {
        guard let (a, m) = partes(mes) else { return mes }
        let t = a * 12 + (m - 1) + n
        return String(format: "%04d-%02d", t / 12, t % 12 + 1)
    }

    static func entre(_ a: String, _ b: String) -> Int {
        guard let (y1, m1) = partes(a), let (y2, m2) = partes(b) else { return 0 }
        return (y2 * 12 + m2) - (y1 * 12 + m1)
    }

    static func nombre(_ mes: String, hoy: String = "") -> String {
        guard let (a, m) = partes(mes) else { return mes }
        let año = partes(hoy)?.año
        return año == a ? nombres[m - 1] : "\(nombres[m - 1]) de \(a)"
    }

    static func corto(_ mes: String, conAño: Bool = false) -> String {
        guard let (a, m) = partes(mes) else { return mes }
        let c = String(nombres[m - 1].prefix(3))
        return conAño ? "\(c) \(String(format: "%02d", a % 100))" : c
    }

    static var actual: String {
        let c = Calendar.current.dateComponents([.year, .month], from: Date())
        return String(format: "%04d-%02d", c.year ?? 2026, c.month ?? 1)
    }
}

enum TipoDeGasto: String, CaseIterable, Identifiable {
    case casa, luz, agua, gas, internet, movil, suscripcion, coche, transporte, seguro, salud,
         gimnasio, estudios, mascota, prestamo, compra, ocio, otro

    var id: String { rawValue }

    var simbolo: String {
        switch self {
        case .casa: "house.fill"
        case .luz: "bolt.fill"
        case .agua: "drop.fill"
        case .gas: "flame.fill"
        case .internet: "wifi"
        case .movil: "iphone"
        case .suscripcion: "play.tv.fill"
        case .coche: "car.fill"
        case .transporte: "tram.fill"
        case .seguro: "umbrella.fill"
        case .salud: "cross.case.fill"
        case .gimnasio: "dumbbell.fill"
        case .estudios: "graduationcap.fill"
        case .mascota: "pawprint.fill"
        case .prestamo: "creditcard.fill"
        case .compra: "cart.fill"
        case .ocio: "gamecontroller.fill"
        case .otro: "ellipsis"
        }
    }

    var nombre: String {
        switch self {
        case .casa: "Casa"
        case .luz: "Luz"
        case .agua: "Agua"
        case .gas: "Gas"
        case .internet: "Internet"
        case .movil: "Móvil"
        case .suscripcion: "Suscripción"
        case .coche: "Coche"
        case .transporte: "Transporte"
        case .seguro: "Seguro"
        case .salud: "Salud"
        case .gimnasio: "Gimnasio"
        case .estudios: "Estudios"
        case .mascota: "Mascota"
        case .prestamo: "Préstamo"
        case .compra: "Compra"
        case .ocio: "Ocio"
        case .otro: "Otro"
        }
    }

    var color: Color {
        switch self {
        case .casa, .estudios: Color(.systemIndigo)
        case .luz: Color(.systemYellow)
        case .agua, .internet, .movil: Color(.systemTeal)
        case .gas, .salud: Color(.systemPink)
        case .suscripcion, .ocio: Color(.systemPurple)
        case .coche, .transporte, .mascota: Color(.systemBrown)
        case .seguro, .gimnasio, .compra: Color(.systemMint)
        case .prestamo, .otro: Color(.systemGray)
        }
    }

    static func de(simbolo: String) -> TipoDeGasto {
        allCases.first { $0.simbolo == simbolo } ?? .otro
    }
}
