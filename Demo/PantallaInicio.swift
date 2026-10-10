import SwiftUI

struct PantallaInicio: View {
    @Environment(Sesion.self) private var sesion

    #if MAQUETA
    @State private var plataforma = Maqueta.plataforma ?? "todo"
    @State private var periodo = Maqueta.periodo ?? "mes"
    #else
    @State private var plataforma = "todo"
    @State private var periodo = "mes"
    #endif
    @State private var cuentaAbierta = false
    
    @State private var ajuste: AjusteLateral?
    
    @Environment(EstadoPanel.self) private var panelBeta
    
    @Environment(\.fondoDelCerrojoDetras) private var fondoDelCerrojoDetras

    @State private var plataformas: [(clave: String, nombre: String, aMano: Bool)] = []

    @State private var cobrados: [String: Double] = [:]
    
    @State private var series: [String: SerieCobrado] = [:]

    @State private var rastreando = false

    @State private var cambioPorApuntar = false

    @State private var cuotaPorSubir = false
    
    @State private var gastoPorSubir = false

    @State private var plataforma2PorApuntar: String?

    @State private var todasEnMemoria: [String: [String: Any]] = [:]
    @State private var ordenCarrusel: [String] = []

    @State private var visible: String? = "1-todo"
    @State private var euros: Double = 0
    @State private var tokens = 0
    @State private var horas: Double = 0
    @State private var enSala = 0
    
    @State private var enDinero = false
    @State private var enDirecto = false
    @State private var nombrePlataforma = ""
    @State private var medias: Medias?

    @State private var ahorroDelDia: Double?
    @State private var racha = 0

    @State private var semanas: [Semana] = []

    @State private var semanasDe: [String: (cuando: Date, lista: [Semana])] = [:]
    private static let semanasFrescas: TimeInterval = 120
    @State private var semanaVisibleID: String?
    
    @State private var semanasSonDe = ""

    @State private var semanaTocada = false

    struct Semana: Identifiable, Equatable {
        let atras: Int
        let titulo: String
        let dias: [DiaSemana]
        var id: String { "s\(atras)" }
    }
    
    @State private var verServidor = false
    @State private var partes: [Parte] = []
    @State private var tg: Tienda?
    @State private var estado: Carga<Bool> = .cargando

    @State private var relojSala: Task<Void, Never>?
    
    @State private var prevision: PrevisionHoy?
    
    @State private var anchoDePantalla: CGFloat = 0

    @State private var reservaMes: ReservaMes?
    
    @State private var proximosCobros: [CobroQueLlega] = []
    
    @State private var diaElegido: Int?
    
    @State private var previsionAbierta = false
    
    @Namespace private var espacioPrevision
    private static let idPrevision = "prevision"

    @State private var relojPrevision: Task<Void, Never>?

    @State private var recargaPeriodo: Task<Void, Never>?

    @State private var periodoCargado = "mes"
    @Environment(\.scenePhase) private var fase
    
    @Environment(\.colorScheme) private var modo

    struct Medias: Equatable {
        let alMes: Double?
        let alDia: Double
        let porHora: Double?

        var horaParcial: Bool = false
        
        var horas: Double = 0
        let tendenciaMes: Tendencia?
        let tendenciaDia: Tendencia?
        let tendenciaHora: Tendencia?
    }

    struct DiaSemana: Identifiable, Equatable {
        let dia: Int
        let nombre: String
        let euros: Double
        let veces: Int
        
        let relativo: Double
        let mejor: Bool
        var id: Int { dia }
    }

    struct Parte: Identifiable, Equatable {
        let clave: String
        let nombre: String
        let euros: Double
        let detalle: String
        var id: String { clave }
    }

    struct Tienda: Equatable {
        let recientes: [Pedido]
        let hanAbierto: Int
        let peticiones: Int
        let compradores: Int
        let bots: [Bot]
        let todoBien: Bool
        let latido: Int?
        let cobrosAuto: CobrosAuto

        struct CobrosAuto: Equatable {
            let activo: Bool
            let cuantos: Int
            let ambiguos: Int
            let ultimaRevision: String
        }

        struct Pedido: Identifiable, Equatable {
            let id: String
            let cliente: String
            let estado: String
            let estadoTxt: String
            let importe: String
            let creado: String
        }

        struct Bot: Identifiable, Equatable {
            let nombre: String
            let bonito: String
            let activo: Bool
            var id: String { nombre }
        }
    }

    @State private var deMemoria = false

    init() {
        #if !MAQUETA
        
        let m = MemoriaDeInicio.compartida
        guard let c = m.cifras["mes"] else { return }
        _todasEnMemoria = State(initialValue: c.todas)
        _ordenCarrusel = State(initialValue: c.orden)
        _cobrados = State(initialValue: c.cobrados)
        _series = State(initialValue: c.series)
        _cambioPorApuntar = State(initialValue: c.cambioPorApuntar)
        _cuotaPorSubir = State(initialValue: c.cuotaPorSubir)
        _gastoPorSubir = State(initialValue: c.gastoPorSubir)
        _plataforma2PorApuntar = State(initialValue: c.plataforma2PorApuntar)
        _plataformas = State(initialValue: m.plataformas)
        _prevision = State(initialValue: m.prevision)
        _ahorroDelDia = State(initialValue: m.ahorroDelDia)
        _reservaMes = State(initialValue: m.reservaMes)
        _proximosCobros = State(initialValue: m.proximosCobros)
        _semanasDe = State(initialValue: m.semanasDe)
        _estado = State(initialValue: .listo(true))
        _deMemoria = State(initialValue: true)
        #endif
    }

    private var esTokens: Bool { esTokensDe(plataforma) }

    private func esTokensDe(_ clave: String) -> Bool {
        clave != "tienda" && clave != "todo"
    }

    var body: some View {
        ZStack {
            ScrollView {
                marcador
            }

            .refreshable { await cargar() }
            .scrollDisabled(rastreando)
            .modifier(BordeDeArribaSuave(activo: true))
            #if MAQUETA
            .defaultScrollAnchor(Maqueta.bajar ? .bottom : .top)
            #endif

        }
        .background { fondoDeInicio }
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { anchoDePantalla = $0 }
        
        .navigationTitle(tituloBarra)
        .navigationBarTitleDisplayMode(tituloBarra.isEmpty ? .inline : .large)
        .toolbar {

            if let p = prevision, p.noche != nil {
                ToolbarItem(placement: .principal) {
                    CapsulaPrevision(p: p, anchoMaximo: CapsulaPrevision.anchoCentrado(en: anchoDePantalla)) {
                        previsionAbierta = true
                    }
                        .llegaComoElIPhone()
                        
                        .onGeometryChange(for: CGFloat.self) { $0.frame(in: .global).minX } action: { x in
                            panelBeta.bordeDeLaCapsula = x
                        }
                }

                .sharedBackgroundVisibility(.hidden)
                
                .matchedTransitionSource(id: Self.idPrevision, in: espacioPrevision)
            }
            ToolbarItem(placement: .topBarTrailing) {

                Button { cuentaAbierta = true } label: {
                    Avatar(lado: 40)
                }

                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
                .controlSize(.mini)
                .chocable(.circulo, reacciona: true)
                .llegaComoElIPhone()
                .accessibilityLabel("Cuenta")
            }

            .sharedBackgroundVisibility(.hidden)
        }

        .sheet(isPresented: $cuentaAbierta) {
            NavigationStack { PantallaCuenta(enHoja: true) }
                .hojaQueChoca()

                .presentationDetents([.large])
        }

        .sheet(isPresented: $previsionAbierta) {
            if let p = prevision {
                HojaPrevision(p: p)
                    .hojaQueChoca()
                    .navigationTransition(.zoom(sourceID: Self.idPrevision, in: espacioPrevision))
            }
        }

        .navigationDestination(item: Binding(
            get: { panelBeta.ajuste },
            set: { panelBeta.ajuste = $0 })) { a in
            switch a {
            case .codigos: PantallaCodigos()
            case .videos: PantallaVideos()
            case .compras: PantallaCompras()
            case .plataformas: PantallaPlataformas()
            }
        }
        .task {
            if let otro = SelectorPeriodo.periodo(para: plataforma, desde: periodo) {
                periodo = otro
            }

            if deMemoria {
                var t = Transaction()
                t.disablesAnimations = true
                withTransaction(t) {
                    aplicarPlataforma()
                    if let ya = semanasDe[plataforma] { ponerSemanas(ya.lista, de: plataforma) }
                }
            }
            await cargar()
            #if MAQUETA

            if Maqueta.abrirPrevision {
                try? await Task.sleep(for: .seconds(1))
                previsionAbierta = true
            }
            if Maqueta.abrirPanel {
                if let p = Maqueta.progresoPanel {
                    panelBeta.seguir(p)
                } else {
                    panelBeta.abierto = true
                }
            }
            if Maqueta.abrirCuenta { cuentaAbierta = true }
            #endif
        }
        #if MAQUETA
        
        .navigationDestination(isPresented: .constant(Maqueta.pantalla != nil)) {
            Maqueta.vistaDeInicio()
        }
        #endif
        .onChange(of: fase) { _, nueva in
            
            if nueva == .active {
                arrancarReloj()

                Task { await renovarPrevision() }
                arrancarRelojPrevision()
            } else {
                pararReloj()
                pararRelojPrevision()
            }
        }
        .onDisappear {
            pararReloj()
            pararRelojPrevision()
            recargaPeriodo?.cancel()
        }
    }

    private var tituloBarra: String { "" }

    private func cambiarA(_ clave: String) {
        plataforma = clave

        if let otro = SelectorPeriodo.periodo(para: clave, desde: periodo) {
            periodo = otro
            pedirRecarga()
        }
        aplicarPlataforma()
        arrancarReloj()
        Task { await cargarSemanas() }       
    }

    private func claveDe(_ id: String?) -> String? {
        guard let id, let corte = id.firstIndex(of: "-") else { return nil }
        return String(id[id.index(after: corte)...])
    }

    private func nombreDe(_ clave: String) -> String {
        plataformas.first { $0.clave == clave }?.nombre ?? clave.capitalized
    }

    private func resumenDe(_ clave: String) -> [String: Any]? {
        todasEnMemoria[clave]?["c"] as? [String: Any]
    }

    private func accesosDe(_ clave: String, delMarcador: Bool = false) -> some View {

            AccesosHeroe {
                if delMarcador { avisosDe(clave) }
                if esTokensDe(clave) {
                    AccesoHeroe(icono: "list.bullet.rectangle", titulo: "Detalle") {
                        PantallaDetalleP1(periodo: periodo, plataforma: clave)
                    }

                    if clave != "plataforma1" {
                        AccesoHeroe(icono: "square.and.pencil", titulo: "Apuntar") {
                            PantallaManual(clave: clave)
                        }
                    }
                    if delMarcador {
                        AccesoHeroe(icono: "chart.line.uptrend.xyaxis", titulo: "Historial") {
                            PantallaHistorial(plataforma: clave)
                        }
                        if clave == "plataforma1" {

                            AccesoHeroe(icono: "video.fill", titulo: "Encargos") {
                                PantallaEncargosBalanza()
                            }
                        }
                    }
                } else if clave == "tienda" {
                    AccesoHeroe(icono: "list.bullet.rectangle", titulo: "Pedidos") {
                        PantallaPedidos()
                    }
                } else if clave == "todo" {

                    AccesoHeroe(icono: "chart.bar", titulo: "Historial") {
                        PantallaHistorial(plataforma: "todo")
                    }
                }
                if !delMarcador { avisosDe(clave) }
            }
    }

    @ViewBuilder
    private func avisosDe(_ clave: String) -> some View {

        if cambioPorApuntar && (clave == "plataforma1" || clave == "todo") {
            AccesoHeroe(icono: "exclamationmark.arrow.triangle.2.circlepath",
                        titulo: "Cambio de Monedero", aviso: true) {
                PantallaAjustesP1(abrirEditando: true) { await cargar() }
            }
        }

        if (cuotaPorSubir || gastoPorSubir) && clave == "todo" {
            AccesoHeroe(icono: "person.badge.clock", titulo: "Subir a la gestoría",
                        aviso: true) {
                PantallaImpuestos()
                    .onDisappear { Task { await cargar() } }
            }
        }

        if let fecha = plataforma2PorApuntar,
           clave == "plataforma2" || clave == "todo" {
            AccesoHeroe(icono: "building.columns", titulo: "Lo que llegó",
                        aviso: true) {
                PantallaTransferencias(abrir: fecha, plataformaAbrir: "plataforma2") {
                    await cargar()
                }
            }
        }
    }

    private var semanaVisible: Semana? {
        guard semanaTocada else { return semanas.last }
        return semanas.first { $0.id == semanaVisibleID } ?? semanas.last
    }

    private func cargarSemanas(renovar: Bool = false) async {
        guard esTokens else { semanas = []; semanasSonDe = plataforma; return }
        let clave = plataforma
        if let ya = semanasDe[clave] {
            ponerSemanas(ya.lista, de: clave)
            if !renovar && Date().timeIntervalSince(ya.cuando) < Self.semanasFrescas { return }
        }
        guard let j = try? await API.pedir("api/semanas/\(clave)",
                                           testigo: sesion.testigo) else { return }
        let lista = ((j["semanas"] as? [[String: Any]]) ?? []).map { s -> Semana in
            Semana(atras: s["atras"] as? Int ?? 0,
                   titulo: s["titulo"] as? String ?? "",
                   dias: ((s["semana"] as? [[String: Any]]) ?? []).map {
                       DiaSemana(dia: $0["dia"] as? Int ?? 0,
                                 nombre: $0["nombre"] as? String ?? "",
                                 euros: $0["euros"] as? Double ?? 0,
                                 veces: $0["veces"] as? Int ?? 0,
                                 relativo: $0["relativo"] as? Double ?? 0,
                                 mejor: $0["mejor"] as? Bool ?? false)
                   })
        }
        semanasDe[clave] = (cuando: Date(), lista: lista)
        MemoriaDeInicio.compartida.semanasDe = semanasDe
        
        if clave == plataforma { ponerSemanas(lista, de: clave) }
    }

    private func ponerSemanas(_ lista: [Semana], de clave: String) {
        
        if lista == semanas && clave == semanasSonDe { return }
        let otraPlataforma = clave != semanasSonDe
        semanas = lista
        semanasSonDe = clave

        if otraPlataforma || !lista.contains(where: { $0.id == semanaVisibleID }) {
            semanaTocada = false
            
            semanaVisibleID = lista.last?.id
        }
    }

    private var MAX_SEMANAS_ATRAS: Int { 104 }

    private var tinte: Color { Diseno.colorDePlataforma(plataforma) }

    private func pedirRecarga() {
        recargaPeriodo?.cancel()
        recargaPeriodo = Task {
            try? await Task.sleep(for: .milliseconds(260))
            guard !Task.isCancelled else { return }
            await cargar(renovarSemanas: false)
        }
    }

    private func cargar(renovarSemanas: Bool = true) async {

        let pedido = periodo
        do {
            async let lista = API.pedir("api/plataformas", testigo: sesion.testigo)

            async let hucha = API.pedir("api/hucha", testigo: sesion.testigo)

            async let previsionNueva = pedirPrevisionSi(renovarSemanas)
            
            async let cobrosNuevos = pedirProximosCobrosSi(renovarSemanas)

            let todo = try await API.pedir(
                "api/inicio?plataforma=todas&periodo=\(pedido)", testigo: sesion.testigo)

            guard pedido == periodo else { return }
            let nuevaPrevision = await previsionNueva

            if case .listo = estado {
                await Llegada.esperarQueAcabe()
                guard pedido == periodo else { return }
            }
            let todas = (todo["todas"] as? [String: [String: Any]]) ?? [:]
            ordenCarrusel = (todo["orden"] as? [String]) ?? []

            if claveDe(visible) != plataforma { visible = "1-\(plataforma)" }

            let cambio = Transaction(animation: pedido != periodoCargado ? Diseno.suave : Diseno.cifra)
            withTransaction(cambio) {
                cobrados = todas.mapValues { cobradoDe($0) }
                series = todas.compactMapValues { SerieCobrado($0["serie"]) }
                cambioPorApuntar = !((todo["cambio_por_apuntar"] as? [String: Any]) ?? [:]).isEmpty
                cuotaPorSubir = !((todo["cuotas_por_subir"] as? [Any]) ?? []).isEmpty
                gastoPorSubir = !((todo["gastos_por_subir"] as? [Any]) ?? []).isEmpty
                plataforma2PorApuntar = ((todo["plataforma2_por_apuntar"] as? [[String: Any]]) ?? [])
                    .first?["fecha"] as? String
                todasEnMemoria = todas
                periodoCargado = pedido
                if let p = nuevaPrevision { prevision = p }
                aplicarPlataforma()
            }

            if let l = try? await lista {
                plataformas = ((l["lista"] as? [[String: Any]]) ?? []).map {
                    (clave: $0["clave"] as? String ?? "",
                     nombre: $0["nombre"] as? String ?? "",
                     aMano: $0["a_mano"] as? Bool ?? false)
                }
            }
            if renovarSemanas {
                for k in semanasDe.keys { semanasDe[k]?.cuando = .distantPast }
            }
            await cargarSemanas(renovar: renovarSemanas)

            if let h = try? await hucha {
                ahorroDelDia = ((h["ahorro_porcentaje"] as? NSNumber)?.doubleValue ?? 0) > 0
                    ? (h["ahorro_hoy"] as? NSNumber)?.doubleValue : nil
                withAnimation(Diseno.suave) { reservaMes = ReservaMes(h) }
            }
            if let c = await cobrosNuevos {
                withAnimation(Diseno.suave) { proximosCobros = c }
            }
            estado = .listo(true)
            recordar()
            arrancarReloj()
            arrancarRelojPrevision()
        } catch is CancellationError {

            return
        } catch {
            if (error as NSError).code == NSURLErrorCancelled { return }
            estado.fallar(error)

            if case .listo = estado, pedido == periodo, periodo != periodoCargado {
                periodo = periodoCargado
            }
        }
    }

    private func recordar() {
        let m = MemoriaDeInicio.compartida
        m.cifras[periodoCargado] = .init(
            todas: todasEnMemoria, orden: ordenCarrusel, cobrados: cobrados, series: series,
            cambioPorApuntar: cambioPorApuntar, cuotaPorSubir: cuotaPorSubir,
            gastoPorSubir: gastoPorSubir, plataforma2PorApuntar: plataforma2PorApuntar)
        m.plataformas = plataformas
        m.prevision = prevision
        m.ahorroDelDia = ahorroDelDia
        m.reservaMes = reservaMes
        m.proximosCobros = proximosCobros
        m.semanasDe = semanasDe
    }

    private func aplicarPlataforma() {
        let j = todasEnMemoria[plataforma] ?? [:]

            medias = nil

            tokens = 0
            horas = 0
            enDinero = false
            enSala = 0
            enDirecto = false
            racha = 0
            partes = []
            tg = nil

            if let c = j["c"] as? [String: Any] {
                leerPlataformaDeTokens(c)
            } else if let junto = j["junto"] as? [String: Any] {
                euros = junto["euros"] as? Double ?? 0
                partes = ((junto["partes"] as? [[String: Any]]) ?? []).map {
                    Parte(clave: $0["clave"] as? String ?? "",
                          nombre: $0["nombre"] as? String ?? "",
                          euros: $0["euros"] as? Double ?? 0,
                          detalle: $0["detalle"] as? String ?? "")
                }

                if let m = junto["medias"] as? [String: Any] {
                    medias = Medias(alMes: m["al_mes"] as? Double,
                                    alDia: m["al_dia"] as? Double ?? 0,
                                    porHora: nil,
                                    horaParcial: false, horas: 0,
                                    tendenciaMes: nil, tendenciaDia: nil, tendenciaHora: nil)
                }
            } else if let t = j["tienda"] as? [String: Any] {
                leerTienda(t, servicios: j["servicios"] as? [String: Any])
                
                verServidor = !(tg?.todoBien ?? true)
            }
    }

    private func cobradoDe(_ j: [String: Any]) -> Double {
        for clave in ["c", "junto", "tienda"] {
            if let sub = j[clave] as? [String: Any], let e = sub["euros"] as? Double {
                return e
            }
        }
        return 0
    }

    private func leerPlataformaDeTokens(_ c: [String: Any]) {
        euros = c["euros"] as? Double ?? 0
        tokens = c["tokens"] as? Int ?? 0
        horas = c["horas"] as? Double ?? 0
        nombrePlataforma = c["nombre"] as? String ?? ""
        enDinero = c["en_dinero"] as? Bool ?? false
        let directo = c["directo"] as? [String: Any]
        enDirecto = directo?["si"] as? Bool ?? false
        enSala = (c["publico"] as? [String: Any])?["cuantos"] as? Int ?? 0
        racha = ((c["racha"] as? [String: Any])?["actual"] as? Int) ?? 0

        _ = ((c["semana"] as? [[String: Any]]) ?? []).map {
            DiaSemana(dia: $0["dia"] as? Int ?? 0,
                      nombre: $0["nombre"] as? String ?? "",
                      euros: $0["euros"] as? Double ?? 0,
                      veces: $0["veces"] as? Int ?? 0,
                      relativo: $0["relativo"] as? Double ?? 0,
                      mejor: $0["mejor"] as? Bool ?? false)
        }
        if let m = c["medias"] as? [String: Any] {
            let t = m["tendencias"] as? [String: Any]
            medias = Medias(
                alMes: (m["hay_mes"] as? Bool ?? false) ? m["al_mes"] as? Double : nil,
                alDia: m["al_dia"] as? Double ?? 0,

                porHora: (m["hay_hora"] as? Bool ?? false) ? m["por_hora"] as? Double : nil,
                horaParcial: m["hora_parcial"] as? Bool ?? false,
                horas: m["horas"] as? Double ?? 0,
                tendenciaMes: Tendencia(t?["mes"] as? [String: Any]),
                tendenciaDia: Tendencia(t?["dia"] as? [String: Any]),
                tendenciaHora: Tendencia(t?["hora"] as? [String: Any]))
        }
    }

    private func leerTienda(_ t: [String: Any], servicios: [String: Any]?) {
        euros = t["euros"] as? Double ?? 0
        let c = (t["clientes"] as? [String: Any]) ?? [:]
        let s = (t["servicios"] as? [String: Any]) ?? servicios ?? [:]
        tg = Tienda(
            recientes: ((t["recientes"] as? [[String: Any]]) ?? []).map {
                Tienda.Pedido(id: $0["id"] as? String ?? "",
                                cliente: $0["cliente"] as? String ?? "",
                                estado: $0["estado"] as? String ?? "",
                                estadoTxt: $0["estado_txt"] as? String ?? "",
                                importe: $0["importe"] as? String ?? "",
                                creado: $0["creado"] as? String ?? "")
            },
            hanAbierto: c["han_abierto"] as? Int ?? 0,
            peticiones: c["peticiones"] as? Int ?? 0,
            compradores: c["compradores"] as? Int ?? 0,
            bots: ((s["servicios"] as? [[String: Any]]) ?? []).map {
                Tienda.Bot(nombre: $0["nombre"] as? String ?? "",
                             bonito: $0["bonito"] as? String ?? "",
                             activo: $0["activo"] as? Bool ?? false)
            },
            todoBien: s["todo_bien"] as? Bool ?? false,
            latido: s["latido"] as? Int,
            cobrosAuto: leerCobrosAuto(t["cobros_auto"] as? [String: Any]))
    }

    private func leerCobrosAuto(_ c: [String: Any]?) -> Tienda.CobrosAuto {
        Tienda.CobrosAuto(
            activo: c?["activo"] as? Bool ?? true,
            cuantos: c?["cuantos"] as? Int ?? 0,
            ambiguos: (c?["ambiguos"] as? [Any])?.count ?? 0,
            ultimaRevision: c?["ultima_revision"] as? String ?? "")
    }

    private func arrancarReloj() {
        pararReloj()
        guard plataforma == "plataforma1" || (plataforma == "todo") else { return }
        relojSala = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                if Task.isCancelled { return }
                guard let j = try? await API.pedir("api/sala", testigo: sesion.testigo) else {
                    continue      
                }

                let nuevos = j["cuantos"] as? Int ?? 0
                let emitiendo = j["en_directo"] as? Bool ?? false

                if nuevos != enSala { enSala = nuevos }
                if emitiendo != enDirecto {
                    enDirecto = emitiendo
                    
                    Task { await renovarPrevision() }
                }
            }
        }
    }

    private func pararReloj() {
        relojSala?.cancel()
        relojSala = nil
    }

    private func pedirPrevision() async -> PrevisionHoy? {
        guard let j = try? await API.pedir("api/prevision", testigo: sesion.testigo) else { return nil }
        
        PuenteWidget.guardar(prevision: j)
        return PrevisionHoy(j)
    }

    private func pedirPrevisionSi(_ pedir: Bool) async -> PrevisionHoy? {
        pedir ? await pedirPrevision() : nil
    }

    private func renovarPrevision() async {
        guard let p = await pedirPrevision(), p != prevision else { return }
        await Llegada.esperarQueAcabe()
        withAnimation(Diseno.suave) { prevision = p }
        MemoriaDeInicio.compartida.prevision = p
    }

    private func arrancarRelojPrevision() {
        relojPrevision?.cancel()
        relojPrevision = Task {
            while !Task.isCancelled {
                let enDirecto = prevision?.hoy.emitiendo ?? false
                try? await Task.sleep(for: .seconds(enDirecto ? 20 : 60))
                if Task.isCancelled { return }
                await renovarPrevision()
            }
        }
    }

    private func pararRelojPrevision() {
        relojPrevision?.cancel()
        relojPrevision = nil
    }
}

struct ReservaMes: Equatable {
    let jornada: String
    let objetivoDia: Double
    let objetivoMes: Double
    
    let saldo: Double
    let diasMes: Int

    init?(_ h: [String: Any]) {
        guard let m = h["mes"] as? [String: Any] else { return nil }
        func n(_ v: Any?) -> Double { (v as? NSNumber)?.doubleValue ?? 0 }
        jornada = h["jornada"] as? String ?? ""
        objetivoDia = n(m["objetivo_diario"])
        objetivoMes = n(m["objetivo_mes"])
        saldo = n(m["saldo"])

        diasMes = ((m["dias_hechos"] as? NSNumber)?.intValue ?? 0)
            + ((m["dias_que_quedan"] as? NSNumber)?.intValue ?? 0)
    }
}

extension PantallaInicio {

    @ViewBuilder
    var marcador: some View {
        if case .error(let qué) = estado {
            Tarjeta { Vacio(icono: "wifi.exclamationmark", titulo: "No se ha podido cargar", detalle: qué) }
                .padding(.horizontal, Diseno.margen)
                .padding(.top, Diseno.hueco3)
        } else {
            let cargando: Bool = { if case .cargando = estado { return true } else { return false } }()
            VStack(alignment: .leading, spacing: 0) {
                cabeceraMarcador
                    .redacted(reason: cargando ? .placeholder : [])
                seccionesMarcador

                    .animation(Diseno.suave, value: plataforma)
            }
            .padding(.bottom, Diseno.hueco5)
            .sensoryFeedback(.selection, trigger: plataforma)
            .sensoryFeedback(.selection, trigger: diaElegido) { _, nuevo in nuevo != nil }
        }
    }

    @ViewBuilder
    var fondoDeInicio: some View {
        ZStack {
            CampoDeColor(plataforma: plataforma, enDirecto: enDirectoAhora)
                .id(plataforma)
                .transition(.opacity)
        }
        .animation(.smooth(duration: 0.7), value: plataforma)
        
        .overlay {
            if let queda = fondoDelCerrojoDetras {
                CaraDelCerrojo.ahora().opacity(queda)
            }
        }
    }

    private var cabeceraMarcador: some View {
        VStack(alignment: .leading, spacing: 0) {
            
            EquiposDeCristal(equipos: equiposDelMarcador, elegido: plataforma) { elegirEquipo($0) }
                .llegaComoElIPhone()
                .padding(.top, Diseno.hueco1)

            VStack(alignment: .leading, spacing: Diseno.hueco2) {
                filaDelPeriodo
                    .llegaComoElIPhone()
                CifraMarcador(euros: cifraDelMarcador)
                    .llegaComoElIPhone()
                    .padding(.top, -4)
                if let linea = lineaDeApoyo {
                    Text(linea)
                        .font(.subheadline)
                        .foregroundStyle(Marcador.apoyo)
                        .monospacedDigit()
                        .contentTransition(.interpolate)
                        .chocableComoTexto(tamano: 15, reacciona: false)
                        .llegaComoElIPhone()
                }
                if let cinta = cintaDelPeriodo {
                    CintaDeDias(valores: cinta.valores, hoy: cinta.hoy,
                                color: Diseno.colorDePlataforma(plataforma),
                                enDirecto: enDirectoAhora && cinta.hoy != nil,
                                hoyCubierto: plataforma == "todo" && (prevision?.objetivoCubierto ?? false),
                                resaltada: cinta.resaltada,
                                version: "\(plataforma)-\(periodoCargado)")
                        .llegaComoElIPhone()
                        .padding(.top, Diseno.hueco1)
                    filaDelRitmo(dia: cinta.dia, de: cinta.valores.count)
                        .llegaComoElIPhone()
                }
                
                if periodoCargado == "dia", plataforma == "todo", !enDirectoAhora,
                   let r = reservaMes, r.objetivoDia > 0 {
                    BarraDeHoy(euros: cobrados["todo"] ?? 0, objetivo: r.objetivoDia,
                               color: Diseno.colorDePlataforma("todo"), enDirecto: enDirectoAhora)
                        .llegaComoElIPhone()
                        .padding(.top, Diseno.hueco1)
                }
            }
            .padding(.horizontal, Diseno.margen)
            .padding(.top, Diseno.hueco3)
            .contentShape(.rect)
            .simultaneousGesture(deslizarEquipo)

            if let s = series[plataforma] {
                LineaCobrado(serie: s, color: tintaDeLinea, margen: Diseno.margen,
                             eje: ejeDeLaLinea,
                             elegido: $diaElegido, rastreando: $rastreando)
                    .frame(height: 164)
                    .llegaComoElIPhone()
                    .padding(.top, Diseno.hueco2)
                    .id("\(plataforma)-\(periodoCargado)")
                    .transition(.opacity)
            }

            SelectorPeriodo(periodo: $periodo, semanal: plataforma == "plataforma2") { _ in
                diaElegido = nil
                pedirRecarga()
            }
            .padding(.horizontal, Diseno.margen)
            .llegaComoElIPhone()
            .padding(.top, Diseno.hueco3)

            ScrollView(.horizontal, showsIndicators: false) {
                accesosDe(plataforma, delMarcador: true)
                    .padding(.horizontal, Diseno.margen)
            }
            .scrollClipDisabled()
            .modifier(BordeQueSigue())
            .llegaComoElIPhone()
            .padding(.top, Diseno.hueco1)
        }
    }

    private var equiposDelMarcador: [(clave: String, nombre: String)] {
        let resto = ordenCarrusel.filter { $0 != "todo" }
        return (["todo"] + resto).map { ($0, $0 == "todo" ? "Todo" : nombreDe($0)) }
    }

    private func elegirEquipo(_ clave: String) {
        guard clave != plataforma else { return }
        diaElegido = nil
        withAnimation(.smooth(duration: 0.6)) { cambiarA(clave) }
    }

    private var deslizarEquipo: some Gesture {
        DragGesture(minimumDistance: 24)
            .onEnded { v in
                let dx = v.translation.width
                guard abs(dx) > 70, abs(dx) > abs(v.translation.height) * 1.5, !rastreando else { return }
                let lista = equiposDelMarcador.map(\.clave)
                guard let i = lista.firstIndex(of: plataforma), !lista.isEmpty else { return }
                let siguiente = (i + (dx < 0 ? 1 : lista.count - 1)) % lista.count
                elegirEquipo(lista[siguiente])
            }
    }

    private var enDirectoAhora: Bool { enDirecto || (prevision?.hoy.emitiendo ?? false) }

    private var cifraDelMarcador: Double {
        if let i = diaElegido, let s = series[plataforma], s.puntos.indices.contains(i) {
            return s.puntos[i].euros
        }
        return cobrados[plataforma] ?? 0
    }

    private var tintaDeLinea: Color {
        modo == .dark ? .white : Diseno.colorDePlataforma(plataforma)
    }

    private var filaDelPeriodo: some View {
        let nombre = Text(nombreDelPeriodo)
            .font(.title3.weight(.semibold))
            .contentTransition(.interpolate)
        return ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: Diseno.hueco1) {
                nombre.lineLimit(1)
                Spacer(minLength: Diseno.hueco1)
                pastillasDelMarcador
            }
            VStack(alignment: .leading, spacing: Diseno.hueco1) {
                nombre
                HStack(spacing: Diseno.hueco1) { pastillasDelMarcador }
            }
            VStack(alignment: .leading, spacing: Diseno.hueco1) {
                nombre
                VStack(alignment: .leading, spacing: Diseno.hueco1) { pastillasDelMarcador }
            }
        }
        .frame(minHeight: 32)
    }

    @ViewBuilder
    private var pastillasDelMarcador: some View {
        let racha = ((resumenDe(plataforma)?["racha"] as? [String: Any])?["actual"] as? Int) ?? 0

        if let t = medias?.tendenciaMes, periodoCargado == "mes", esTokens {
            PastillaDeCristal(texto: "\(t.porcentaje) % \(t.sube ? "más" : "menos") al día que \(t.contra)",
                              icono: t.sube ? "arrow.up.right" : "arrow.down.right",
                              tinte: t.sube ? .green : .red)
        }
        if racha > 1 {
            PastillaDeCristal(texto: "\(racha) días seguidos", icono: "flame.fill", tinte: .orange)
        }
        if let a = ahorroDelDia, a > 0, plataforma == "todo" {
            PastillaDeCristal(texto: "Aparta \(Formato.eurosRedondos(a))", icono: "banknote.fill",
                              tinte: .blue)
        }
    }

    private var nombreDelPeriodo: String {
        if let i = diaElegido, let s = series[plataforma], s.puntos.indices.contains(i) {
            return s.nombre(i)
        }
        let (ano, mes, dia) = fechaDeTrabajo
        let meses = ["enero", "febrero", "marzo", "abril", "mayo", "junio", "julio", "agosto",
                     "septiembre", "octubre", "noviembre", "diciembre"]
        let nombreMes = (1...12).contains(mes) ? meses[mes - 1] : ""
        switch periodoCargado {
        case "dia": return "Hoy"
        case "quincena": return dia <= 15 ? "1.ª quincena de \(nombreMes)" : "2.ª quincena de \(nombreMes)"
        case "mes": return nombreMes.capitalized
        case "ano": return "\(ano)"
        default: return "Desde el principio"
        }
    }

    private var fechaDeTrabajo: (Int, Int, Int) {
        let iso = reservaMes?.jornada ?? prevision?.jornada ?? ""
        let p = iso.split(separator: "-").compactMap { Int($0) }
        if p.count == 3 { return (p[0], p[1], p[2]) }
        let c = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        return (c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    private var lineaDeApoyo: String? {
        let total = cobrados["todo"] ?? 0
        let parte = total > 0 ? Int(((cobrados[plataforma] ?? 0) / total * 100).rounded()) : 0
        switch plataforma {
        case "todo":
            guard let r = reservaMes, r.objetivoDia > 0 else { return nil }
            switch periodoCargado {
            case "mes": return "de \(Formato.eurosRedondos(r.objetivoMes)) que pide la Reserva este mes"
            case "quincena":
                let dias = fechaDeTrabajo.2 <= 15 ? 15 : max(r.diasMes - 15, 1)
                return "de \(Formato.eurosRedondos(r.objetivoDia * Double(dias))) que pide la Reserva en la quincena"
            case "ano", "total":
                return medias?.alMes.map { "unos \(Formato.eurosRedondos($0)) al mes de media" }
            default: return nil
            }
        case "tienda":
            return total > 0 ? "\(parte) % de todo lo de este periodo" : nil
        default:
            var partes: [String] = []
            if !enDinero {
                partes.append("\(Formato.tokens(tokens, unidad: "tokens"))")
                if horas > 0 { partes.append(Formato.duracion(horas)) }
            }
            if total > 0 { partes.append("\(parte) % del total") }
            return partes.isEmpty ? nil : partes.joined(separator: " · ")
        }
    }

    private var cintaDelPeriodo: (valores: [Double?], hoy: Int?, resaltada: Int?, dia: Int,
                                  casillaDe: [Int?])? {
        guard periodoCargado == "mes" || periodoCargado == "quincena",
              let s = series[plataforma], s.paso == "dia" else { return nil }
        let (_, _, hoyDia) = fechaDeTrabajo
        let diasMes = reservaMes?.diasMes ?? 31
        let (desde, hasta): (Int, Int) = periodoCargado == "mes" ? (1, diasMes)
            : (hoyDia <= 15 ? (1, 15) : (16, diasMes))
        var valores = [Double?](repeating: nil, count: max(hasta - desde + 1, 1))
        for d in desde...max(desde, min(hoyDia, hasta)) { valores[d - desde] = 0 }
        var indiceDe: [Int: Int] = [:]
        for (i, punto) in s.puntos.enumerated() {
            guard let d = Int(punto.fecha.suffix(2)), d >= desde, d <= hasta else { continue }
            valores[d - desde] = (valores[d - desde] ?? 0) + punto.euros
            indiceDe[i] = d - desde
        }
        let hoy = (desde...hasta).contains(hoyDia) ? hoyDia - desde : nil
        let resaltada = diaElegido.flatMap { indiceDe[$0] }
        return (valores, hoy, resaltada, min(max(hoyDia - desde + 1, 1), valores.count),
                s.puntos.indices.map { indiceDe[$0] })
    }

    private var ejeDeLaLinea: EjeDeDias? {
        guard let c = cintaDelPeriodo else { return nil }
        let casillas = c.casillaDe.compactMap { $0 }
        guard casillas.count == c.casillaDe.count, casillas == casillas.sorted(),
              Set(casillas).count == casillas.count else { return nil }
        return EjeDeDias(casillas: c.valores.count, espacio: CintaDeDias.espacio(c.valores.count),
                         casillaDe: casillas)
    }

    private func filaDelRitmo(dia: Int, de total: Int) -> some View {
        let cuenta = Text("Día \(dia) de \(total)").foregroundStyle(Marcador.apoyo)
        return ViewThatFits(in: .horizontal) {
            HStack(spacing: Diseno.hueco1) {
                cuenta
                Spacer(minLength: Diseno.hueco1)
                pastillaDelRitmo
            }
            VStack(alignment: .leading, spacing: Diseno.hueco1) {
                cuenta
                pastillaDelRitmo
            }
        }
        .font(.footnote.weight(.semibold))
        .monospacedDigit()
    }

    @ViewBuilder
    private var pastillaDelRitmo: some View {
        if plataforma == "todo", periodoCargado == "mes", let r = reservaMes, r.objetivoDia > 0 {
            let delante = r.saldo >= 0
            PastillaDeCristal(
                texto: delante ? "\(Formato.eurosRedondos(r.saldo)) por delante del ritmo"
                               : "\(Formato.eurosRedondos(-r.saldo)) por detrás del ritmo",
                icono: delante ? "gauge.with.dots.needle.67percent" : "gauge.with.dots.needle.33percent",
                tinte: delante ? .green : .orange)
        }
    }

    private var seccionesMarcador: some View {
        VStack(alignment: .leading, spacing: Diseno.hueco2) {
            if let p = prevision, p.noche != nil, plataforma != "tienda" {
                ModuloEstaNoche(p: p, sala: enSala > 0 ? enSala : p.hoy.sala) { previsionAbierta = true }
                    .padding(.horizontal, Diseno.margen)
                    .llegaComoElIPhone()
                    .padding(.top, Diseno.hueco4)
            }
            
            Group {
                switch plataforma {
                case "todo":
                    if !partes.isEmpty {
                        TituloDeSeccion(texto: "Clasificación")
                            .padding(.horizontal, Diseno.margen)
                        TablaClasificacion(filas: filasDeClasificacion) { elegirEquipo($0) }
                            .padding(.horizontal, Diseno.margen)

                        Text("Las plataformas de tokens van sin comisiones. Tienda es lo que facturas.")
                            .font(.footnote)
                            .foregroundStyle(Marcador.apoyo)
                            .padding(.horizontal, Diseno.margen)
                    }
                    if !proximosCobros.isEmpty {
                        let total = proximosCobros.reduce(0) { $0 + $1.euros }
                        NavigationLink { PantallaCobros() } label: {
                            HStack(spacing: 4) {
                                TituloDeSeccion(texto: "Lo que te llega", dato: "≈ \(Formato.eurosRedondos(total))")
                                Image(systemName: "chevron.right")
                                    .font(.footnote.weight(.bold))
                                    .foregroundStyle(Marcador.apoyo)
                                    .padding(.top, Diseno.hueco3)
                            }
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, Diseno.margen)
                        FilasDeCobros(cobros: proximosCobros)
                            .padding(.horizontal, Diseno.margen)
                    }
                    if let m = medias { seccionDeMedias(m) }
                case "tienda":
                    if let t = tg {
                        tiendaEnCampo(t)
                            .padding(.horizontal, Diseno.margen)
                    }
                default:
                    if let m = medias { seccionDeMedias(m) }
                    if semanas.contains(where: { s in s.dias.contains { $0.veces > 0 } }) {
                        semanaEnCampo
                    }
                }
            }
            .llegaComoElIPhone()
        }
    }

    private var semanaEnCampo: some View {
        VStack(alignment: .leading, spacing: Diseno.hueco2) {
            TituloDeSeccion(texto: "Resumen", dato: semanaVisible?.titulo)
                .animation(Diseno.suave, value: semanaVisible?.titulo)
                .padding(.horizontal, Diseno.margen)
            ScrollView(.horizontal) {
                HStack(spacing: 0) {
                    ForEach(semanas) { sem in
                        ColumnasSemana(dias: sem.dias, tinte: tinte)
                            .padding(.horizontal, Diseno.margen)
                            .containerRelativeFrame(.horizontal)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.paging)
            .scrollPosition(id: $semanaVisibleID)
            .scrollIndicators(.hidden)
            .defaultScrollAnchor(.trailing)
            .onScrollPhaseChange { _, fase in
                if fase != .idle { semanaTocada = true }
            }
            .frame(height: ColumnasSemana.alto - 2 * Diseno.hueco3)
            .id(semanas.count)
        }
    }

    static func creadoCorto(_ texto: String) -> String {
        let partes = texto.split(separator: " ")
        guard let dia = partes.first, dia.count == 10 else { return texto }
        let hora = partes.count > 1 ? " · " + partes[1].prefix(5) : ""
        return Fechas.corta(String(dia)) + hora
    }

    @ViewBuilder
    private func tiendaEnCampo(_ t: Tienda) -> some View {
        TituloDeSeccion(texto: "Pedidos recientes")
        if t.recientes.isEmpty {
            Text("Ningún pedido todavía")
                .font(.subheadline)
                .foregroundStyle(Marcador.apoyo)
                .padding(.vertical, Diseno.hueco2)
        } else {
            VStack(spacing: 0) {
                ForEach(Array(t.recientes.enumerated()), id: \.element.id) { i, p in
                    NavigationLink { PantallaPedido(id: p.id) } label: {
                        HStack(spacing: Diseno.hueco2) {

                            PuntoDeArea(color: PantallaPedidos.color(p.estado))
                                .frame(minWidth: 10)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(p.cliente).font(.headline)
                                Text("\(p.estadoTxt) · \(Self.creadoCorto(p.creado))")
                                    .font(.footnote).foregroundStyle(Marcador.apoyo)
                            }
                            Spacer()
                            Text(Formato.importe(p.importe))
                                .font(.system(.headline, design: .rounded)).monospacedDigit()
                            Image(systemName: "chevron.right")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.vertical, Diseno.hueco2)
                        .contentShape(.rect)
                    }
                    .buttonStyle(Hundirse())
                    if i < t.recientes.count - 1 { Divider() }
                }
            }
        }

        TituloDeSeccion(texto: "Clientes")
        FilaDeNumeros(numeros: [("Han abierto el bot", t.hanAbierto),
                                ("Peticiones", t.peticiones),
                                ("Han comprado", t.compradores)])
        NavigationLink { PantallaClientes() } label: {
            Label("Ver quién es", systemImage: "person.2.fill")
                .font(.subheadline.weight(.medium))
        }
        .buttonStyle(.glass)
        .padding(.top, Diseno.hueco1)

        SeccionPlegable(titulo: "Servidor",
                        estado: t.todoBien ? "Todo en marcha" : "Algo está parado",
                        bien: t.todoBien, abierto: $verServidor) {
            VStack(spacing: 0) {
                ForEach(Array(t.bots.enumerated()), id: \.element.id) { i, b in
                    if i > 0 { Divider().padding(.leading, 22) }
                    HStack(spacing: Diseno.hueco2) {
                        PilotoRadar(color: b.activo ? Diseno.verdeRelleno : Diseno.rojoRelleno,
                                    activo: b.activo)
                            .frame(width: 10)
                        Text(b.bonito)
                        Spacer()
                        Text(b.activo ? "en marcha" : "parado")
                            .font(.footnote).foregroundStyle(Marcador.apoyo)
                    }
                    .padding(.vertical, Diseno.hueco2)
                    .accessibilityElement(children: .combine)
                }
                if let latido = t.latido {
                    Divider().padding(.leading, 22)
                    HStack(spacing: Diseno.hueco2) {

                        Circle().fill(latido < 180 ? Diseno.verde : Diseno.rojo)
                            .frame(width: 8, height: 8)
                            .frame(width: 10)
                        Text("Último latido")
                        Spacer()
                        Text("hace \(latido) s").font(.footnote).foregroundStyle(Marcador.apoyo)
                    }
                    .padding(.vertical, Diseno.hueco2)
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }

    private var filasDeClasificacion: [TablaClasificacion.Fila] {
        partes.sorted { $0.euros > $1.euros }.map { p in
            let t = ((resumenDe(p.clave)?["medias"] as? [String: Any])?["tendencias"] as? [String: Any])?["mes"]
            return .init(clave: p.clave, nombre: p.nombre, euros: p.euros, detalle: p.detalle,
                         cambio: periodoCargado == "mes" ? Tendencia(t as? [String: Any]) : nil)
        }
    }

    @ViewBuilder
    private func seccionDeMedias(_ m: Medias) -> some View {
        TituloDeSeccion(texto: "De media")
            .padding(.horizontal, Diseno.margen)
        FilaDeMedias(medias: [
            .init(titulo: "Al mes", valor: m.alMes, tendencia: m.tendenciaMes, nota: nil),
            .init(titulo: "Al día", valor: m.alDia, tendencia: m.tendenciaDia, nota: nil),
        ] + (esTokens ? [.init(titulo: "Por hora", valor: m.porHora, tendencia: m.tendenciaHora,
                               nota: m.horaParcial && m.horas > 0
                                   ? "en \(Formato.duracion(m.horas)) medidas" : nil)] : []))
        .padding(.horizontal, Diseno.margen)
    }

    private func pedirProximosCobrosSi(_ pedir: Bool) async -> [CobroQueLlega]? {
        guard pedir, let j = try? await API.pedir("api/cobros", testigo: sesion.testigo) else { return nil }

        var juntos: [String: CobroQueLlega] = [:]
        for c in (j["proximos"] as? [[String: Any]]) ?? [] {
            guard let fecha = c["fecha"] as? String, !fecha.isEmpty else { continue }
            let plataforma = c["plataforma"] as? String ?? ""
            let clave = "\(plataforma)@\(fecha)"
            let euros = (c["euros"] as? NSNumber)?.doubleValue ?? 0
            let estimado = c["estimado"] as? Bool ?? false
            if let ya = juntos[clave] {
                juntos[clave] = CobroQueLlega(id: ya.id, plataforma: plataforma, nombre: ya.nombre,
                                              fecha: fecha, euros: ya.euros + euros,
                                              estimado: ya.estimado || estimado)
            } else {
                juntos[clave] = CobroQueLlega(id: clave, plataforma: plataforma,
                                              nombre: c["nombre"] as? String ?? "", fecha: fecha,
                                              euros: euros, estimado: estimado)
            }
        }
        
        let juntando = ((j["juntando"] as? [[String: Any]]) ?? []).map { c in
            CobroQueLlega(id: c["id"] as? String ?? UUID().uuidString,
                          plataforma: c["plataforma"] as? String ?? "",
                          nombre: c["nombre"] as? String ?? "", fecha: "",
                          euros: (c["euros"] as? NSNumber)?.doubleValue ?? 0,
                          estimado: c["estimado"] as? Bool ?? true,
                          faltaUSD: (c["falta_usd"] as? NSNumber)?.doubleValue ?? 0)
        }
        return juntos.values.sorted { $0.fecha < $1.fecha } + juntando
    }
}

@MainActor
final class MemoriaDeInicio {
    static let compartida = MemoriaDeInicio()

    struct Cifras {
        let todas: [String: [String: Any]]
        let orden: [String]
        let cobrados: [String: Double]
        let series: [String: SerieCobrado]
        let cambioPorApuntar: Bool
        let cuotaPorSubir: Bool
        let gastoPorSubir: Bool
        let plataforma2PorApuntar: String?
    }

    var cifras: [String: Cifras] = [:]
    var plataformas: [(clave: String, nombre: String, aMano: Bool)] = []
    var prevision: PrevisionHoy?
    var ahorroDelDia: Double?
    var reservaMes: ReservaMes?
    var proximosCobros: [CobroQueLlega] = []
    var semanasDe: [String: (cuando: Date, lista: [PantallaInicio.Semana])] = [:]

    func olvidar() {
        cifras = [:]
        plataformas = []
        prevision = nil
        ahorroDelDia = nil
        reservaMes = nil
        proximosCobros = []
        semanasDe = [:]
    }
}
