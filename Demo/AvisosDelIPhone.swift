import SwiftUI
import UserNotifications
#if canImport(BackgroundTasks)
import BackgroundTasks
#endif

enum AvisosDelIPhone {

    static let tarea = "avisos"
    private static let prefijo = "avisos."
    private static let claveLlave = "avisos.llave"
    
    private static let claveYa = "avisos.ya"
    private static let zona = TimeZone(identifier: "Europe/Madrid") ?? .current

    private static var llave: String? { UserDefaults.standard.string(forKey: claveLlave) }

    @MainActor private static var pidiendoLlave = false

    @MainActor
    static func asegurarLlave(testigo: String?) async {
        #if !MAQUETA
        guard llave == nil, let testigo, !pidiendoLlave else { return }
        pidiendoLlave = true
        defer { pidiendoLlave = false }
        let r = try? await API.pedir("api/avisos/testigo", metodo: "POST",
                                     cuerpo: ["aparato": "Avisos|Avisos del iPhone||"], testigo: testigo)
        if let nueva = r?["testigo"] as? String, !nueva.isEmpty {
            UserDefaults.standard.set(nueva, forKey: claveLlave)
        }
        #endif
    }

    static func olvidar() {
        #if !MAQUETA
        if let llave {
            Task { _ = try? await API.pedir("api/avisos/salir", metodo: "POST", testigo: llave) }
        }
        UserDefaults.standard.removeObject(forKey: claveLlave)
        UserDefaults.standard.removeObject(forKey: claveYa)
        quitarTodos()
        #endif
    }

    @MainActor
    static func renovar(testigo: String?, enPrimerPlano: Bool) async {
        #if !MAQUETA
        let permiso = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
        let conPermiso = permiso == .authorized || permiso == .provisional

        let ruta = "api/avisos/datos?permiso=\(conPermiso ? 1 : 0)"

        var j: [String: Any]?
        if let actual = llave {
            do {
                j = try await API.pedir(ruta, testigo: actual)
            } catch API.Fallo.sinTestigo {
                if llave == actual { UserDefaults.standard.removeObject(forKey: claveLlave) }
                await asegurarLlave(testigo: testigo)
            } catch {}
        }
        if j == nil, let testigo {
            j = try? await API.pedir(ruta, testigo: testigo)
        }
        guard let j, conPermiso else { return }
        await programar(Datos(j), enPrimerPlano: enPrimerPlano)
        #endif
    }

    @MainActor
    static func enSegundoPlano() async {
        programarSiguiente()
        await renovar(testigo: nil, enPrimerPlano: false)
    }

    static func programarSiguiente() {
        #if canImport(BackgroundTasks) && !MAQUETA
        let peticion = BGAppRefreshTaskRequest(identifier: tarea)
        peticion.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
        try? BGTaskScheduler.shared.submit(peticion)
        #endif
    }

    static func quitarTodos() {
        let centro = UNUserNotificationCenter.current()
        centro.getPendingNotificationRequests { pendientes in
            UNUserNotificationCenter.current().removePendingNotificationRequests(
                withIdentifiers: pendientes.map(\.identifier).filter { $0.hasPrefix(prefijo) })
        }
    }

    private struct Aviso {
        let id: String
        
        let cuando: Date?
        let titulo: String
        let cuerpo: String
    }

    @MainActor
    private static func programar(_ d: Datos, enPrimerPlano: Bool) async {
        guard d.enElIPhone else {
            quitarTodos()
            return
        }
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = zona
        let ahora = Date()
        var avisos: [Aviso] = []

        let guardado = UserDefaults.standard.stringArray(forKey: claveYa)
        let sembrar = guardado == nil
        var ya = Set(guardado ?? [])
        
        var orden = guardado ?? []
        var siguenAhi = Set<String>()

        func apuntar(_ id: String) {
            if ya.insert(id).inserted { orden.append(id) }
        }

        func deUnMomento(_ id: String, _ titulo: String, _ cuerpo: String, aunqueAbierta: Bool = false) {
            siguenAhi.insert(id)
            guard !ya.contains(id) else { return }
            apuntar(id)
            if !sembrar && (!enPrimerPlano || aunqueAbierta) {
                avisos.append(Aviso(id: id, cuando: nil, titulo: titulo, cuerpo: cuerpo))
            }
        }

        let reservaEnJuego = d.reservaActiva ? fraseDeLaReserva(d) : nil
        var alistarseHoy = false
        if d.alistarse, let (h, m) = horaYMinuto(d.horaAlistarse) {
            
            for i in 0..<5 {
                guard let dia = cal.date(byAdding: .day, value: i, to: cal.startOfDay(for: ahora)),
                      d.diasAlistarse.contains((cal.component(.weekday, from: dia) + 5) % 7),
                      let cuando = cal.date(bySettingHour: h, minute: m, second: 0, of: dia) else { continue }
                let jornada = jornadaDe(cuando, cal)
                let esHoy = jornada == d.jornada
                if esHoy { alistarseHoy = true }
                if cuando > ahora {
                    avisos.append(Aviso(id: "alistarse.\(jornada)", cuando: cuando,
                                        titulo: "Hora de alistarte",
                                        cuerpo: esHoy ? (reservaEnJuego ?? fraseDeHoy(d)) : ""))
                }
                if d.segundo != 0, let otro = cal.date(byAdding: .minute, value: d.segundo, to: cuando),
                   otro > ahora {
                    avisos.append(Aviso(id: "segundo.\(jornada)", cuando: otro,
                                        titulo: d.segundo < 0 ? "En \(duracion(-d.segundo)), hora de alistarte"
                                                              : "Era la hora de alistarte",
                                        cuerpo: d.segundo < 0 ? "A las \(d.horaAlistarse)"
                                                              : "Hace \(duracion(d.segundo))"))
                }
            }
        }
        
        if let reservaEnJuego, !alistarseHoy,
           let base = fecha(d.jornada, cal),
           let cuando = cal.date(bySettingHour: 21, minute: 0, second: 0, of: base), cuando > ahora {
            avisos.append(Aviso(id: "reserva.\(d.jornada)", cuando: cuando, titulo: reservaEnJuego, cuerpo: ""))
        }

        for r in d.reservaAvisos { siguenAhi.insert("reserva:\(r.id)") }
        if d.reservaActiva {
            for r in d.reservaAvisos {
                deUnMomento("reserva:\(r.id)", r.titulo, r.cuerpo, aunqueAbierta: true)
            }
        }

        if d.descansar {
            let cuerpo = d.descansos.map { $0 == 1 ? "Te queda 1 descanso este mes" : "Te quedan unos \($0) descansos este mes" } ?? ""
            if d.estado == "descansar", let base = fecha(d.jornada, cal),
               let cuando = cal.date(bySettingHour: 12, minute: 0, second: 0, of: base), cuando > ahora {
                avisos.append(Aviso(id: "descansar.\(d.jornada)", cuando: cuando,
                                    titulo: "Hoy puedes descansar", cuerpo: cuerpo))
            }
            if d.manana == "descansar", let base = fecha(d.jornada, cal),
               let manana = cal.date(byAdding: .day, value: 1, to: base),
               let cuando = cal.date(bySettingHour: 12, minute: 0, second: 0, of: manana), cuando > ahora {
                avisos.append(Aviso(id: "descansar.\(Datos.iso(manana, cal))", cuando: cuando,
                                    titulo: "Hoy puedes descansar", cuerpo: ""))
            }
        }

        if d.pedidos {
            for p in d.pedidosEsperando {
                deUnMomento("pedido:\(p.id):\(p.estado)", "Un cliente espera",
                            p.estado == "awaiting_payment_confirm"
                                ? "Dice que ha pagado: comprueba que te ha llegado"
                                : "Tienes un pedido por revisar")
            }
        }

        if !d.semanaId.isEmpty { siguenAhi.insert("semana:\(d.semanaId)") }
        if d.semana, d.semanaCerrada, let hasta = fecha(d.semanaHasta, cal),
           let lunes = cal.date(byAdding: .day, value: 1, to: hasta),
           let cuando = cal.date(bySettingHour: 12, minute: 0, second: 0, of: lunes) {
            let id = "semana:\(d.semanaId)"
            let titulo = "Tu semana: \(Formato.euros(d.semanaEuros))"
            var cuerpo = d.semanaNoches == 1 ? "1 noche" : "\(d.semanaNoches) noches"
            if d.semanaAnterior > 0 {
                let cambio = Int(((d.semanaEuros / d.semanaAnterior - 1) * 100).rounded())
                cuerpo += cambio == 0 ? " · igual que la anterior"
                    : " · \(cambio > 0 ? "+" : "−")\(abs(cambio)) % sobre la anterior"
            }
            if cuando > ahora {
                avisos.append(Aviso(id: "semana.\(d.semanaId)", cuando: cuando, titulo: titulo, cuerpo: cuerpo))
                
                apuntar(id)
            } else if cal.isDate(ahora, inSameDayAs: lunes) {
                
                deUnMomento(id, titulo, cuerpo)
            } else {
                apuntar(id)
            }
        }

        if d.codigos {
            for c in d.codigosSinUsar {
                guard let creado = c.creado else { continue }
                let dia = cal.startOfDay(for: creado)
                for (dias, titulo, final) in [
                    (2, "Un Encargo con código sigue sin usar", "nadie lo ha canjeado y no lo has cobrado"),
                    (7, "Un Encargo con código lleva una semana sin usar", "nadie lo ha canjeado y no lo has cobrado"),
                    (14, "Mañana se borra un Encargo con código sin usar", "si lo vendiste, cóbralo a mano hoy"),
                ] {
                    guard let d2 = cal.date(byAdding: .day, value: dias, to: dia),
                          let cuando = cal.date(bySettingHour: 12, minute: 0, second: 0, of: d2),
                          cuando > ahora else { continue }
                    avisos.append(Aviso(id: "codigo.\(c.id).\(dias)", cuando: cuando, titulo: titulo,
                                        cuerpo: "\(c.codigo) · \(Formato.euros(c.euros)): \(final)"))
                }
            }
        }

        if d.fallos {
            for f in d.fallosAhora {
                deUnMomento("fallo:\(f.id)", "Algo no funciona", "\(f.titulo): \(f.detalle)")
            }
        }

        let quedan = orden.filter { siguenAhi.contains($0) }
        UserDefaults.standard.set(Array(quedan.suffix(500)), forKey: claveYa)

        let centro = UNUserNotificationCenter.current()
        let pendientes = await centro.pendingNotificationRequests()
        centro.removePendingNotificationRequests(
            withIdentifiers: pendientes.map(\.identifier).filter { $0.hasPrefix(prefijo) })
        
        let ordenados = avisos.sorted { ($0.cuando ?? .distantPast) < ($1.cuando ?? .distantPast) }
        for a in ordenados.prefix(24) {
            let contenido = UNMutableNotificationContent()
            contenido.title = a.titulo
            contenido.body = a.cuerpo
            contenido.sound = .default

            let disparo: UNNotificationTrigger? = a.cuando.map {
                var c = cal.dateComponents([.year, .month, .day, .hour, .minute], from: $0)
                c.timeZone = zona
                return UNCalendarNotificationTrigger(dateMatching: c, repeats: false)
            }
            try? await centro.add(UNNotificationRequest(identifier: prefijo + a.id, content: contenido,
                                                         trigger: disparo))
        }
    }

    private static func fraseDeLaReserva(_ d: Datos) -> String? {
        guard let si = d.siNoEmite, let cruza = d.cruza else { return nil }
        return cruza == "negativo" ? "Si hoy no emites, la reserva se queda en \(Formato.euros(si))"
                                   : "Si hoy no emites, la reserva baja a \(Formato.euros(si))"
    }

    private static func fraseDeHoy(_ d: Datos) -> String {
        if d.estado == "descansar" { return "El plan del mes te deja descansar hoy" }
        if !d.trabajado, d.falta > 0 { return "Te faltan \(Formato.euros(d.falta)) para el objetivo de hoy" }
        return ""
    }

    private static func duracion(_ minutos: Int) -> String {
        minutos % 60 == 0 ? (minutos == 60 ? "1 hora" : "\(minutos / 60) horas") : "\(minutos) min"
    }

    private static func jornadaDe(_ momento: Date, _ cal: Calendar) -> String {
        Datos.iso(momento.addingTimeInterval(-9 * 3600), cal)
    }

    private static func fecha(_ iso: String, _ cal: Calendar) -> Date? {
        let p = iso.split(separator: "-").compactMap { Int($0) }
        guard p.count == 3 else { return nil }
        return cal.date(from: DateComponents(year: p[0], month: p[1], day: p[2]))
    }

    private static func horaYMinuto(_ texto: String) -> (Int, Int)? {
        let p = texto.split(separator: ":").compactMap { Int($0) }
        guard p.count == 2, (0...23).contains(p[0]), (0...59).contains(p[1]) else { return nil }
        return (p[0], p[1])
    }
}

private struct Datos {
    var jornada = ""
    var enElIPhone = false
    var alistarse = false
    var horaAlistarse = "21:00"
    var diasAlistarse: Set<Int> = Set(0...6)
    var segundo = 0
    var reservaActiva = true
    var descansar = true
    var pedidos = true
    var semana = true
    var fallos = true
    var codigos = true
    var estado = ""
    var manana = ""
    var falta = 0.0
    var trabajado = false
    var descansos: Int?
    var siNoEmite: Double?
    var cruza: String?
    var reservaAvisos: [(id: String, titulo: String, cuerpo: String)] = []
    var semanaId = ""
    var semanaHasta = ""
    var semanaEuros = 0.0
    var semanaNoches = 0
    var semanaAnterior = 0.0
    var semanaCerrada = false
    var pedidosEsperando: [(id: String, estado: String)] = []
    var fallosAhora: [(id: String, titulo: String, detalle: String)] = []
    
    var codigosSinUsar: [(id: String, codigo: String, euros: Double, creado: Date?)] = []

    init(_ j: [String: Any]) {
        jornada = j["jornada"] as? String ?? ""
        let a = j["ajustes"] as? [String: Any] ?? [:]
        enElIPhone = a["en_el_iphone"] as? Bool ?? false
        alistarse = a["alistarse_activo"] as? Bool ?? false
        horaAlistarse = a["alistarse_hora"] as? String ?? "21:00"
        diasAlistarse = Set(a["alistarse_dias"] as? [Int] ?? Array(0...6))
        segundo = a["segundo"] as? Int ?? 0
        reservaActiva = a["hucha_activo"] as? Bool ?? true
        descansar = a["descansar"] as? Bool ?? true
        pedidos = a["pedidos"] as? Bool ?? true
        semana = a["semana"] as? Bool ?? true
        fallos = a["fallos"] as? Bool ?? true
        codigos = a["codigos"] as? Bool ?? true
        let hoy = j["hoy"] as? [String: Any] ?? [:]
        estado = hoy["estado"] as? String ?? ""
        falta = Datos.numero(hoy["falta"])
        trabajado = hoy["trabajado"] as? Bool ?? false
        descansos = hoy["descansos"] as? Int
        manana = j["manana"] as? String ?? ""
        let r = j["reserva"] as? [String: Any] ?? [:]
        siNoEmite = r["si_no_emite"].flatMap { $0 is NSNull ? nil : Datos.numero($0) }
        cruza = r["cruza"] as? String
        reservaAvisos = (r["avisos"] as? [[String: Any]] ?? []).compactMap { x in
            guard let id = x["id"] as? String else { return nil }

            var cuerpo = x["cuerpo"] as? String ?? ""
            if x["euros"] != nil, !(x["euros"] is NSNull) {
                let euros = Datos.numero(x["euros"])
                cuerpo = (x["clase"] as? String) == "sin_saldo"
                    ? "No llegó para completar el día: faltaron \(Formato.euros(euros))"
                    : "Quedan \(Formato.euros(euros))"
            }
            return (id, x["titulo"] as? String ?? "", cuerpo)
        }
        let s = j["semana"] as? [String: Any] ?? [:]
        semanaId = s["id"] as? String ?? ""
        semanaHasta = s["hasta"] as? String ?? ""
        semanaEuros = Datos.numero(s["euros"])
        semanaNoches = s["noches"] as? Int ?? 0
        semanaAnterior = Datos.numero(s["anterior"])
        semanaCerrada = s["cerrada"] as? Bool ?? false
        pedidosEsperando = (j["pedidos"] as? [[String: Any]] ?? []).compactMap { x in
            guard let id = x["id"] as? String else { return nil }
            return (id, x["estado"] as? String ?? "")
        }
        fallosAhora = (j["fallos"] as? [[String: Any]] ?? []).compactMap { x in
            guard let id = x["id"] as? String else { return nil }
            return (id, x["titulo"] as? String ?? "", x["detalle"] as? String ?? "")
        }
        let lector = ISO8601DateFormatter()
        codigosSinUsar = (j["codigos"] as? [[String: Any]] ?? []).compactMap { x in
            guard let codigo = x["codigo"] as? String else { return nil }
            return (x["id"] as? String ?? codigo, codigo, Datos.numero(x["euros"]),
                    (x["creado"] as? String).flatMap(lector.date(from:)))
        }
    }

    static func numero(_ x: Any?) -> Double {
        if let d = x as? Double { return d }
        if let i = x as? Int { return Double(i) }
        return 0
    }

    static func iso(_ d: Date, _ cal: Calendar) -> String {
        let c = cal.dateComponents([.year, .month, .day], from: d)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }
}

final class DelegadoDeAvisos: NSObject, UNUserNotificationCenterDelegate, @unchecked Sendable {
    static let compartido = DelegadoDeAvisos()

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification) async
        -> UNNotificationPresentationOptions {
        notification.request.identifier.hasPrefix("avisos.reserva:") ? [.banner, .list, .sound] : []
    }
}
