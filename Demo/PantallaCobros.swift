import SwiftUI

struct Cobro: Identifiable, Equatable {
    let id: String
    let fecha: String
    let plataforma: String
    let nombre: String
    let euros: Double
    let detalle: String
    let tokens: Int
    let estimado: Bool
    let llegado: Bool
    
    let total: Double

    let faltaUSD: Double

    init(_ j: [String: Any]) {
        id = j["id"] as? String ?? UUID().uuidString
        fecha = j["fecha"] as? String ?? ""
        plataforma = j["plataforma"] as? String ?? ""
        nombre = j["nombre"] as? String ?? ""
        euros = j["euros"] as? Double ?? Double(j["euros"] as? Int ?? 0)
        detalle = j["detalle"] as? String ?? ""
        tokens = j["tokens"] as? Int ?? 0
        estimado = j["estimado"] as? Bool ?? false
        llegado = j["llegado"] as? Bool ?? true
        total = (j["total"] as? Double) ?? euros
        faltaUSD = (j["falta_usd"] as? NSNumber)?.doubleValue ?? 0
    }

    var sinFecha: String {
        faltaUSD > 0.004 ? "cuando junte el mínimo · faltan \(Formato.dolares(faltaUSD))"
                         : "cuando junte el mínimo"
    }

    var color: Color { Diseno.colorDePlataforma(plataforma) }
}

struct MesDeCobros: Identifiable, Equatable {
    var id: String { mes }
    let mes: String
    let llegado: Double
    let porLlegar: Double
    let cobros: [Cobro]

    init(_ j: [String: Any]) {
        mes = j["mes"] as? String ?? ""
        llegado = (j["llegado"] as? Double) ?? Double(j["llegado"] as? Int ?? 0)
        porLlegar = (j["por_llegar"] as? Double) ?? Double(j["por_llegar"] as? Int ?? 0)
        cobros = ((j["cobros"] as? [[String: Any]]) ?? []).map(Cobro.init)
    }
}

enum Fechas {
    private static let cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }()

    static func fecha(_ iso: String) -> Date? {
        let p = iso.split(separator: "-").compactMap { Int($0) }
        guard p.count == 3 else { return nil }
        return cal.date(from: DateComponents(year: p[0], month: p[1], day: p[2]))
    }

    static func dias(de a: String, a b: String) -> Int {
        guard let x = fecha(a), let y = fecha(b) else { return 0 }
        return cal.dateComponents([.day], from: x, to: y).day ?? 0
    }

    static func mas(_ iso: String, _ dias: Int) -> String {
        guard let f = fecha(iso), let g = cal.date(byAdding: .day, value: dias, to: f) else {
            return iso
        }
        let c = cal.dateComponents([.year, .month, .day], from: g)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    static func diaDeLaSemana(_ iso: String) -> String {
        guard let f = fecha(iso) else { return "" }
        let n = cal.component(.weekday, from: f)          
        return ["domingo", "lunes", "martes", "miércoles", "jueves", "viernes", "sábado"][n - 1]
    }

    static func larga(_ iso: String) -> String { "\(diaDeLaSemana(iso)) \(Formato.diaCorto(iso))" }

    static func corta(_ iso: String) -> String {
        let d = Formato.diaCorto(iso).split(separator: " ")
        guard d.count == 3 else { return iso }
        return "\(d[0]) \(d[2].prefix(3))"
    }

    static func cuando(_ iso: String, hoy: String) -> String {
        let n = dias(de: hoy, a: iso)
        switch n {
        case 0: return "hoy"
        case 1: return "mañana"
        case -1: return "ayer"
        case let x where x > 1: return "en \(x) días"
        default: return "hace \(-n) días"
        }
    }
}

struct PantallaCobros: View {
    @Environment(Sesion.self) private var sesion
    @Environment(\.scenePhase) private var fase

    @State private var hoy = ""
    @State private var llegados: [Cobro] = []
    @State private var proximos: [Cobro] = []
    @State private var esteMes: Double = 0
    @State private var porLlegar: Double = 0
    @State private var cuantos = 0
    @State private var meses: [MesDeCobros] = []
    @State private var faltaApartar: Double?
    @State private var estado: Carga<Bool> = .cargando
    
    @State private var rastreando = false

    var body: some View {
        contenido
            .navigationTitle("Cobros")
            .task(id: fase) {
                guard fase == .active else { return }
                await cargar()
            }
    }

    @ViewBuilder
    private var contenido: some View {
        ScrollView {
            marcador
        }
        .refreshable { await cargar() }
        .scrollDisabled(rastreando)
        .scrollEdgeEffectStyle(.soft, for: .top)
        #if MAQUETA
        .defaultScrollAnchor(Maqueta.anclaSala)
        #endif
        .background { campo }
    }

    @ViewBuilder
    private var marcador: some View {
        switch estado {
        case .cargando:
            Vacio(icono: "eurosign.circle", titulo: "Cargando…")
                .redacted(reason: .placeholder)
                .frame(maxWidth: .infinity)
                .padding(.top, Diseno.hueco5)
        case .error(let qué):
            Vacio(icono: "wifi.exclamationmark", titulo: "No se ha podido cargar", detalle: qué)
                .frame(maxWidth: .infinity)
                .padding(.top, Diseno.hueco5)
        case .vacio:
            Vacio(icono: "eurosign.circle", titulo: "Todavía no hay cobros")
                .frame(maxWidth: .infinity)
                .padding(.top, Diseno.hueco5)
        default:
            CobrosMarcador(hoy: hoy, llegados: llegados, proximos: proximos, meses: meses,
                           faltaApartar: faltaApartar, rastreando: $rastreando)
        }
    }

    private var campo: some View {
        CampoJoya(joya: .cobros)
    }

    private func cargar() async {
        do {
            let j = try await API.pedir("api/cobros", testigo: sesion.testigo)
            hoy = j["hoy"] as? String ?? ""
            llegados = ((j["llegados"] as? [[String: Any]]) ?? []).map(Cobro.init)
            proximos = ((j["proximos"] as? [[String: Any]]) ?? []).map(Cobro.init)

            proximos += ((j["juntando"] as? [[String: Any]]) ?? []).map(Cobro.init)
            esteMes = j["este_mes"] as? Double ?? 0
            porLlegar = j["por_llegar"] as? Double ?? 0
            cuantos = j["cuantos"] as? Int ?? 0
            meses = ((j["meses"] as? [[String: Any]]) ?? []).map(MesDeCobros.init)

            if let h = try? await API.pedir("api/hucha/cobros?falta_mas=1", testigo: sesion.testigo),
               h["hay_objetivo"] as? Bool ?? false {
                faltaApartar = ((h["pendiente"] as? [String: Any])?["total"] as? NSNumber)?.doubleValue ?? 0
            } else {
                faltaApartar = nil
            }
            estado = (llegados.isEmpty && proximos.isEmpty) ? .vacio : .listo(true)
        } catch {
            if (error as NSError).code == NSURLErrorCancelled || error is CancellationError { return }
            estado.fallar(error)
        }
    }
}

