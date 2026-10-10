import SwiftUI

@preconcurrency import UserNotifications

struct Tarea: Identifiable, Equatable {
    struct Accion: Equatable {

        let tipo: String
        let texto: String
        
        let destino: String
        
        let pedido: String
        
        let fecha: String
        
        let id: String
        let trimestre: String
        
        let enlace: URL?

        init?(_ j: Any?) {
            guard let j = j as? [String: Any], let tipo = j["tipo"] as? String else { return nil }
            self.tipo = tipo
            texto = j["texto"] as? String ?? ""
            destino = j["destino"] as? String ?? ""
            pedido = j["pedido"] as? String ?? ""
            fecha = j["fecha"] as? String ?? ""
            id = j["id"] as? String ?? ""
            trimestre = j["trimestre"] as? String ?? ""
            enlace = (j["enlace"] as? String).flatMap(URL.init(string:))
        }
    }

    struct Parte: Equatable, Identifiable {
        let para: String
        let euros: Double
        let mes: String
        var id: String { para }
    }

    struct Pedido: Equatable {
        let id: String
        let quien: String
        let importe: String
        let que: String
        let metodo: String
        let faltaPrecio: Bool
        
        let creado: String
    }

    let id: String
    let tipo: String
    let area: String
    let titulo: String
    let plataforma: String
    let euros: Double?
    let usd: Double?
    let aprox: Bool
    let fecha: String
    let vence: String
    let atrasada: Bool
    let accion: Accion?
    let otra: Accion?
    let partes: [Parte]
    
    let cobroEuros: Double?
    let cobroEtiqueta: String
    let pedido: Pedido?
    
    let nocheFin: String
    let nocheMinutos: Int
    let mes: String
    let concepto: String
    let detalle: String
    
    let dias: Int?
    let trimestre: String
    let m130: Double?
    let m303: Double?
    let apartado: Double?
    let necesario: Double?
    
    let comprobado: String
    
    let conBorrador: Bool

    let borradorDudoso: Bool
    
    let errores: Int
    let avisos: Int

    init(_ j: [String: Any]) {
        func num(_ k: String) -> Double? { (j[k] as? NSNumber)?.doubleValue }
        id = j["id"] as? String ?? UUID().uuidString
        tipo = j["tipo"] as? String ?? ""
        area = j["area"] as? String ?? ""
        titulo = j["titulo"] as? String ?? ""
        plataforma = j["plataforma"] as? String ?? ""
        euros = num("euros")
        usd = num("usd")
        aprox = j["aprox"] as? Bool ?? false
        fecha = j["fecha"] as? String ?? ""
        vence = j["vence"] as? String ?? ""
        atrasada = j["atrasada"] as? Bool ?? false
        accion = Accion(j["accion"])
        otra = Accion(j["otra"])
        partes = ((j["partes"] as? [[String: Any]]) ?? []).map {
            Parte(para: $0["para"] as? String ?? "", euros: ($0["euros"] as? NSNumber)?.doubleValue ?? 0,
                  mes: $0["mes"] as? String ?? "")
        }
        let cobro = j["cobro"] as? [String: Any]
        cobroEuros = (cobro?["euros"] as? NSNumber)?.doubleValue
        cobroEtiqueta = cobro?["etiqueta"] as? String ?? ""
        if let p = j["pedido"] as? [String: Any] {
            pedido = Pedido(id: p["id"] as? String ?? "", quien: p["quien"] as? String ?? "",
                            importe: p["importe"] as? String ?? "", que: p["que"] as? String ?? "",
                            metodo: p["metodo"] as? String ?? "",
                            faltaPrecio: p["falta_precio"] as? Bool ?? false,
                            creado: p["creado"] as? String ?? "")
        } else {
            pedido = nil
        }
        let noche = j["noche"] as? [String: Any]
        nocheFin = noche?["fin"] as? String ?? ""
        nocheMinutos = (noche?["minutos"] as? NSNumber)?.intValue ?? 0
        mes = j["mes"] as? String ?? ""
        concepto = j["concepto"] as? String ?? ""
        detalle = j["detalle"] as? String ?? ""
        dias = (j["dias"] as? NSNumber)?.intValue
        trimestre = j["trimestre"] as? String ?? ""
        m130 = num("m130")
        m303 = num("m303")
        apartado = num("apartado")
        necesario = num("necesario")
        comprobado = j["comprobado"] as? String ?? ""
        let borrador = j["borrador"] as? [String: Any]
        
        conBorrador = borrador != nil && !(borrador?["dudoso"] as? Bool ?? false)
            && !(borrador?["desfasado"] as? Bool ?? false)
        borradorDudoso = borrador?["dudoso"] as? Bool ?? false
        errores = (j["errores"] as? NSNumber)?.intValue ?? 0
        avisos = (j["avisos"] as? NSNumber)?.intValue ?? 0
    }
}

@MainActor
@Observable
final class AgendaEstado {
    private(set) var ahora: [Tarea] = []
    private(set) var viene: [Tarea] = []
    private(set) var hoy = ""
    private(set) var estado: Carga<Bool> = .cargando

    private(set) var tachandose: Set<String> = []
    private var pidiendo = false

    var pendientes: [Tarea] { ahora.filter { !tachandose.contains($0.id) } }
    var cuantas: Int { pendientes.count }
    var atrasadas: Int { pendientes.filter(\.atrasada).count }

    func cargar(testigo: String?) async {
        guard !pidiendo else { return }
        pidiendo = true
        defer { pidiendo = false }
        do {
            let j = try await API.pedir("api/agenda", testigo: testigo)
            hoy = j["hoy"] as? String ?? hoy
            ahora = ((j["ahora"] as? [[String: Any]]) ?? []).map(Tarea.init)
            viene = ((j["viene"] as? [[String: Any]]) ?? []).map(Tarea.init)
            
            tachandose.formIntersection(Set(ahora.map(\.id)))
            estado = .listo(true)
            AvisosDeLaAgenda.programar(ahora: pendientes, viene: viene, hoy: hoy)
        } catch {
            estado.fallar(error)
        }
    }

    func tachar(_ t: Tarea, descartar: Bool = false, fecha: String? = nil,
                testigo: String?) async -> (ok: Bool, mensaje: String, deshacer: [[String: Any]]) {
        tachandose.insert(t.id)
        do {
            var cuerpo: [String: any Sendable] = ["id": t.id]
            if descartar { cuerpo["descartar"] = true }
            
            if let fecha { cuerpo["fecha"] = fecha }
            let r = try await API.pedir("api/agenda/hecho", metodo: "POST", cuerpo: cuerpo,
                                        testigo: testigo)
            let ok = r["ok"] as? Bool ?? false
            if !ok { tachandose.remove(t.id) }
            let deshacer = (r["deshacer"] as? [[String: Any]]) ?? []
            await cargar(testigo: testigo)
            return (ok, r["mensaje"] as? String ?? (ok ? "Hecho." : "No se ha podido."), deshacer)
        } catch {
            tachandose.remove(t.id)
            return (false, error.localizedDescription, [])
        }
    }

    func deshacer(_ marcas: [[String: Any]], tarea: String? = nil, testigo: String?) async -> Bool {

        if let tarea { tachandose.remove(tarea) }

        let limpias: [[String: any Sendable]] = marcas.map { m in
            var x: [String: any Sendable] = ["tipo": m["tipo"] as? String ?? "",
                                             "id": m["id"] as? String ?? ""]
            if let s = m["antes"] as? String {
                x["antes"] = s
            } else if let d = m["antes"] as? [String: Any] {
                var antes: [String: any Sendable] = [:]
                for (k, v) in d {
                    if let n = v as? NSNumber { antes[k] = n.doubleValue }
                    else if let s = v as? String { antes[k] = s }
                }
                x["antes"] = antes
            }
            return x
        }
        let cuerpo: [String: any Sendable] = ["marcas": limpias]
        let r = try? await API.pedir("api/agenda/deshacer", metodo: "POST", cuerpo: cuerpo,
                                     testigo: testigo)
        await cargar(testigo: testigo)
        return r?["ok"] as? Bool ?? false
    }

    func propia(_ cuerpo: [String: any Sendable], testigo: String?) async -> (ok: Bool, mensaje: String) {
        do {
            let r = try await API.pedir("api/agenda/propia", metodo: "POST", cuerpo: cuerpo,
                                        testigo: testigo)
            await cargar(testigo: testigo)
            return (r["ok"] as? Bool ?? false, r["mensaje"] as? String ?? "")
        } catch {
            return (false, error.localizedDescription)
        }
    }
}

enum AvisosDeLaAgenda {
    static let clave = "agendaAvisosEnElIPhone"
    private static let prefijo = "agenda."
    
    static let hora = 12

    static var activos: Bool { UserDefaults.standard.bool(forKey: clave) }

    static func pedirPermiso() async -> Bool {
        let centro = UNUserNotificationCenter.current()
        let ajustes = await centro.notificationSettings()
        switch ajustes.authorizationStatus {
        case .authorized, .provisional, .ephemeral: return true
        case .denied: return false
        default:
            return (try? await centro.requestAuthorization(options: [.alert, .sound])) ?? false
        }
    }

    static func quitarTodos() {
        UNUserNotificationCenter.current().getPendingNotificationRequests { pendientes in
            UNUserNotificationCenter.current().removePendingNotificationRequests(
                withIdentifiers: pendientes.map(\.identifier).filter { $0.hasPrefix(prefijo) })
        }
    }

    static func programar(ahora: [Tarea], viene: [Tarea], hoy: String) {
        #if MAQUETA
        return
        #else
        guard activos, !hoy.isEmpty else { return }
        var avisos: [(id: String, dia: String, titulo: String, cuerpo: String)] = []

        for t in viene + ahora {
            guard !t.fecha.isEmpty else { continue }
            switch t.tipo {
            case "cobro":
                avisos.append((t.id, t.fecha, "Hoy \(t.titulo.lowercasedPrimera)",
                               cifra(t) + " · la Agenda te dirá cuánto apartar"))
            case "trimestre":
                for antes in [7, 1] {
                    let dia = Fechas.mas(t.fecha, -antes)
                    avisos.append(("\(t.id).\(antes)", dia,
                                   antes == 1 ? "Mañana se acaba el plazo del trimestre"
                                              : "Quedan \(antes) días para presentar el trimestre",
                                   cifra(t) + " a pagar"))
                }
            case "cuota_cargo":
                avisos.append((t.id, t.fecha, "Hoy se cobra la cuota de autónomo", cifra(t)))
            case "gasto_mes", "gasto_asesoria":

                let clave = t.id.replacingOccurrences(of: "gasto-mes:", with: "gasto:")
                avisos.append((clave, t.fecha, "Sube la factura de \(t.concepto) a la gestoría", cifra(t)))
            case "propia":
                avisos.append((t.id, t.fecha, t.titulo, "Tuya"))
            default:
                break
            }
        }

        if let primera = ahora.first {
            let resto = ahora.count - 1
            avisos.append(("pendientes", Fechas.mas(hoy, 1), "Tienes cosas en la Agenda",
                           AgendaTexto.aviso(primera) + (resto > 0 ? " y \(resto) más" : "")))
        }

        let lista = Array(avisos.prefix(36))
        let centro = UNUserNotificationCenter.current()
        centro.getPendingNotificationRequests { pendientes in
            let centro = UNUserNotificationCenter.current()
            centro.removePendingNotificationRequests(
                withIdentifiers: pendientes.map(\.identifier).filter { $0.hasPrefix(prefijo) })
            let ahoraMismo = Date()
            for a in lista {
                let p = a.dia.split(separator: "-").compactMap { Int($0) }
                guard p.count == 3 else { continue }
                var c = DateComponents(year: p[0], month: p[1], day: p[2], hour: hora)
                c.timeZone = TimeZone(identifier: "Europe/Madrid")
                guard let cuando = Calendar(identifier: .gregorian).date(from: c),
                      cuando > ahoraMismo else { continue }
                let contenido = UNMutableNotificationContent()
                contenido.title = a.titulo
                contenido.body = a.cuerpo
                contenido.sound = .default
                let disparo = UNCalendarNotificationTrigger(dateMatching: c, repeats: false)
                centro.add(UNNotificationRequest(identifier: prefijo + a.id, content: contenido,
                                                 trigger: disparo))
            }
        }
        #endif
    }

    private static func cifra(_ t: Tarea) -> String {
        guard let e = t.euros else { return "" }
        return (t.aprox ? "≈ " : "") + Formato.euros(e)
    }
}

enum AgendaTexto {
    static func nombreDelMes(_ mes: String) -> String { CobrosHucha.nombreDelMes(mes) }

    static func plataforma(_ clave: String) -> String { Diseno.nombreDePlataforma(clave) }

    static func area(_ t: Tarea) -> String {

        if t.tipo == "factura", !t.plataforma.isEmpty { return plataforma(t.plataforma) }
        switch t.area {
        case "apartar": return t.plataforma.isEmpty ? "Apartar" : plataforma(t.plataforma)
        case "hacienda": return "Hacienda"
        case "asesoria": return "Gestoría"
        case "tuya": return "Tuya"
        case "cobro": return plataforma(t.plataforma)
        default: return t.plataforma.isEmpty ? t.area.capitalizandoPrimera : plataforma(t.plataforma)
        }
    }

    static func frase(_ t: Tarea) -> String {
        switch t.tipo {
        case "apartar":
            return "Aparta de este cobro"
        case "plataforma2_noche":
            return "Apunta los tokens de la noche"
        case "pedido_revisar":
            return "Revisa el pedido de \(t.pedido?.quien ?? "un cliente")"
        case "pedido_cobro":
            return "\(t.pedido?.quien ?? "Un cliente") dice que ha pagado"
        case "pedido_aviso":
            return "A \(t.pedido?.quien ?? "un cliente") no le llega el aviso del bot"
        case "cuota_asesoria":
            return "Sube la cuota de \(nombreDelMes(t.mes))"
        case "gasto_asesoria":
            return t.concepto.isEmpty ? "Sube la factura de \(nombreDelMes(t.mes))"
                : "Sube la factura de \(corto(t.concepto))"
        case "trimestre":
            return "Presenta el \(trimestreBonito(t.trimestre))"
        case "factura":
            if t.conBorrador { return "Emite el borrador en la gestoría" }
            return t.borradorDudoso ? "Mira en la gestoría si se creó el borrador"
                : "Haz la factura en la gestoría"
        case "plataforma1_llegado":
            return "¿Te ha llegado el cobro?"
        case "excel_asesoria":
            return "Baja el Excel de la gestoría"
        case "revision_asesoria":
            return "Revisa lo que no cuadra con la gestoría"
        case "gasto_mes":
            return "Gasto de \(corto(t.concepto))"
        default:
            return t.titulo
        }
    }

    static func aviso(_ t: Tarea) -> String {
        switch t.tipo {
        case "apartar":
            return "Aparta \(Formato.euros(t.euros ?? 0)) del cobro de \(plataforma(t.plataforma))"
        case "plataforma2_noche":
            return "Apunta los tokens de Plataforma 2 de la noche"
        case "plataforma2_llegado":
            return "Apunta lo que te llegó de Plataforma 2 al banco"
        case "cuota_asesoria", "gasto_asesoria":
            return frase(t) + " a la gestoría"
        case "factura":
            if t.conBorrador { return "Emite el borrador de \(plataforma(t.plataforma)) en la gestoría" }
            return t.borradorDudoso
                ? "Mira en la gestoría si se creó el borrador de \(plataforma(t.plataforma))"
                : "Haz la factura del cobro de \(plataforma(t.plataforma)) en la gestoría"
        case "plataforma1_llegado":
            return "¿Te ha llegado el cobro de Plataforma 1?"
        case "excel_asesoria":
            return "Baja el Excel de la gestoría del \(trimestreBonito(t.trimestre))"
        default:
            return frase(t)
        }
    }

    static func corto(_ concepto: String) -> String {
        concepto.components(separatedBy: " (").first ?? concepto
    }

    static func trimestreBonito(_ t: String) -> String {
        t.split(separator: "-").last.map(String.init) ?? t
    }
}

extension String {
    
    var lowercasedPrimera: String { prefix(1).lowercased() + dropFirst() }
}
