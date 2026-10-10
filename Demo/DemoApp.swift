import Combine
import SwiftUI
import UserNotifications

@main
struct DemoApp: App {
    @State private var sesion = Sesion()

    init() {

        UNUserNotificationCenter.current().delegate = DelegadoDeAvisos.compartido
        #if MAQUETA
        
        TexturasDeTema.compartidas.hacerYaParaLasFotos()
        #endif
    }

    var body: some Scene {
        WindowGroup {
            Raiz()
                .environment(sesion)
                .task { await sesion.arrancar() }
        }

        .backgroundTask(.appRefresh(AvisosDelIPhone.tarea)) {
            await AvisosDelIPhone.enSegundoPlano()
        }
    }
}

@MainActor
enum VeloDeLaMultitarea {
    private static var ventana: UIWindow?

    static func poner(_ visible: Bool) {
        guard visible else {
            ventana?.isHidden = true
            return
        }
        if ventana == nil,
           let escena = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first {
            let v = UIWindow(windowScene: escena)
            v.windowLevel = .alert + 1
            v.rootViewController = UIHostingController(rootView: VeloOpaco(cara: .ahora(empanado: false)))
            ventana = v
        }
        
        (ventana?.rootViewController as? UIHostingController<VeloOpaco>)?.rootView =
            VeloOpaco(cara: .ahora(empanado: false))
        ventana?.layer.removeAllAnimations()
        ventana?.alpha = 1
        ventana?.isHidden = false
    }

    static func quitar() {
        DispatchQueue.main.async {
            MainActor.assumeIsolated {
                guard let v = ventana, !v.isHidden else { return }
                UIView.animate(withDuration: 0.2, delay: 0,
                               options: [.curveEaseOut, .allowUserInteraction]) {
                    v.alpha = 0
                } completion: { terminado in
                    guard terminado else { return }
                    v.isHidden = true
                    v.alpha = 1
                }
            }
        }
    }
}

private struct VeloOpaco: View {
    
    let cara: CaraDelCerrojo

    var body: some View {
        cara
            .accessibilityHidden(true)
    }
}

struct Raiz: View {
    @Environment(Sesion.self) private var sesion
    @Environment(\.scenePhase) private var fase

    @State private var cargaHecha = false
    
    @State private var sinActualizar = false

    @State private var llegada: Double = Llegada.fin

    @State private var saliendo = false
    @State private var opacidadDelCerrojo: Double = 1
    @State private var opacidadDelFondo: Double = 1

    @State private var vez = 0

    var body: some View {

        contenido

            .task {
                try? await Task.sleep(for: PantallaCarga.duracion)
                cargaHecha = true
            }

            .overlay {
                EscucharToques { sesion.tocado() }
                    .frame(width: 0, height: 0)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }

            .task {
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(20))
                    
                    sinAnimacion { sesion.revisarCerrojo() }
                }
            }
            .onChange(of: fase) { _, nueva in
                
                var dentro = false
                if case .dentro = sesion.estado { dentro = true }
                if nueva == .active {

                    sinAnimacion { sesion.revisarCerrojo() }
                    VeloDeLaMultitarea.quitar()
                } else {
                    VeloDeLaMultitarea.poner(dentro)
                }
                
                if nueva == .active {
                    Task { await PuenteWidget.ponerAlDia(testigo: sesion.testigo) }
                }
            }
            .onChange(of: estadoDeLaSesion) { antes, ahora in
                cambioDeEstado(de: antes, a: ahora)
            }

            .onReceive(NotificationCenter.default.publisher(for: .testigoRechazado)
                .receive(on: DispatchQueue.main)) { _ in
                Task { await sesion.testigoRechazado() }
            }
            
            .onReceive(NotificationCenter.default.publisher(for: .recargaFallida)
                .receive(on: DispatchQueue.main)) { _ in
                guard case .dentro = sesion.estado, !sinActualizar else { return }
                withAnimation(Diseno.suave) { sinActualizar = true }
                AccessibilityNotification.Announcement("No se ha podido actualizar").post()
            }
            .task(id: sinActualizar) {
                guard sinActualizar else { return }
                try? await Task.sleep(for: .seconds(3.5))
                withAnimation(Diseno.suave) { sinActualizar = false }
            }
            .overlay(alignment: .top) {
                if sinActualizar {
                    Label("No se ha podido actualizar", systemImage: "wifi.exclamationmark")
                        .font(.footnote.weight(.semibold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .cristal(.regular, en: Capsule())
                        .padding(.top, 4)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
            }

    }

    private var estadoDeLaSesion: String {
        switch sesion.estado {
        case .comprobando: return "comprobando"
        case .fuera: return "fuera"
        case .bloqueada: return "bloqueada"
        case .dentro: return "dentro"
        }
    }

    private var esBloqueada: Bool { if case .bloqueada = sesion.estado { true } else { false } }
    private var esDentro: Bool { if case .dentro = sesion.estado { true } else { false } }
    private var esFuera: Bool { if case .fuera = sesion.estado { true } else { false } }
    private var esComprobando: Bool { if case .comprobando = sesion.estado { true } else { false } }

    private var appViva: Bool { esBloqueada || (esDentro && cargaHecha) }

    private var cerrojoALaVista: Bool { esBloqueada || saliendo || (esDentro && llegada == 0) }

    private var contenido: some View {
        ZStack {
            if appViva {
                Principal()
                    .id(vez)
                    .environment(\.llegada, llegada)
                    .environment(\.bajoElCerrojo, esBloqueada)

                    .environment(\.fondoDelCerrojoDetras, cerrojoALaVista ? opacidadDelFondo : nil)

                    .animation(nil) { $0.opacity(esBloqueada ? 0 : 1) }
                    .allowsHitTesting(!esBloqueada)
                    .accessibilityHidden(esBloqueada)
                    .transition(.opacity.animation(Diseno.suave))
                    #if MAQUETA
                    .onAppear { if esDentro { Maqueta.avisarLista() } }
                    #endif
            }
            if cargaHecha, esFuera {
                PantallaEntrar()
                    .transition(.opacity.animation(Diseno.suave))
                    #if MAQUETA
                    .onAppear { Maqueta.avisarLista() }
                    #endif
            }
            if cargaHecha, cerrojoALaVista {
                PantallaBloqueo()
                    .environment(\.cerrojoSaliendo, saliendo)
                    .opacity(opacidadDelCerrojo)
                    .allowsHitTesting(!saliendo)

                    .transition(.identity)
                    #if MAQUETA
                    .onAppear { Maqueta.avisarLista() }
                    #endif
            }
            if !cargaHecha || esComprobando {

                PantallaCarga()
                    .transition(.opacity.animation(Diseno.suave))
            }
        }
    }

    private func cambioDeEstado(de antes: String, a ahora: String) {
        switch ahora {
        case "bloqueada":
            
            sinAnimacion {
                saliendo = false
                opacidadDelCerrojo = 1
                opacidadDelFondo = 1
                llegada = 0
                if antes == "dentro" { vez += 1 }
            }
        case "dentro" where antes == "bloqueada":
            abrirLaPuerta()
        default:
            
            sinAnimacion {
                saliendo = false
                opacidadDelCerrojo = 1
                opacidadDelFondo = 1
                llegada = Llegada.fin
            }
        }
    }

    private func abrirLaPuerta() {
        #if MAQUETA
        
        if let fija = Maqueta.llegadaFija {
            saliendo = true
            opacidadDelCerrojo = Llegada.queda(fija, de: Llegada.salida)
            opacidadDelFondo = Llegada.queda(fija, de: Llegada.fondo)
            llegada = fija
            return
        }
        #endif
        Llegada.terminaEn = Date().addingTimeInterval(Llegada.fin)
        withAnimation(.linear(duration: Llegada.fin)) {
            saliendo = true
            llegada = Llegada.fin
        }
        withAnimation(.linear(duration: Llegada.salida)) { opacidadDelCerrojo = 0 }
        withAnimation(.linear(duration: Llegada.fondo)) { opacidadDelFondo = 0 }
        Task {
            try? await Task.sleep(for: .seconds(max(Llegada.salida, Llegada.fondo) + 0.05))
            sinAnimacion {
                saliendo = false
                opacidadDelCerrojo = 1
                opacidadDelFondo = 1
            }
        }
    }

    private func sinAnimacion(_ cambio: () -> Void) {
        var t = Transaction()
        t.disablesAnimations = true
        withTransaction(t, cambio)
    }
}

struct Principal: View {
    @Environment(Sesion.self) private var sesion
    @Environment(\.scenePhase) private var fase
    
    @Environment(\.bajoElCerrojo) private var bajoElCerrojo
    #if MAQUETA
    @State private var pestana = Maqueta.pestana
    #else
    @State private var pestana = "inicio"
    #endif

    @State private var agenda = AgendaEstado()

    @State private var panel = EstadoPanel()

    var body: some View {
        TabView(selection: $pestana) {
            Tab("Inicio", systemImage: "chart.bar.fill", value: "inicio") {
                NavigationStack { PantallaInicio() }
            }

            Tab("Agenda", systemImage: "checklist", value: "agenda") {
                NavigationStack { PantallaAgenda() }
            }
            .badge(agenda.cuantas)
            #if MAQUETA
            
            if Maqueta.pestana == "pedidos" {
                Tab("Pedidos", systemImage: "doc.text.fill", value: "pedidos") {
                    NavigationStack { PantallaPedidos() }
                }
            }
            #endif
            
            Tab("Sala", systemImage: "video.fill", value: "sala") {
                NavigationStack { PantallaSala() }
            }

            Tab("Cobros", systemImage: "eurosign.circle.fill",
                value: "cobros") {
                NavigationStack { PantallaCobros() }
            }
        }

        .tabBarMinimizeBehavior(.onScrollDown)

        .overlay {
            if Compilacion.beta {
                CapaDelanteDeLaVida()
                    .ignoresSafeArea()
            }
        }
        .overlay {
            PanelBeta()
        }

        .overlay(alignment: .topLeading) {
            if pestana == "inicio", !panel.enPantalla, !bajoElCerrojo {
                GeometryReader { g in
                    let hueco = (panel.bordeDeLaCapsula ?? g.size.width / 2) - 16 - 8
                    PistaDelPanel(veces: panel.pista, ancho: max(hueco, 0))
                        .padding(.leading, 16)
                        .padding(.top, 22 - 13)
                }
                .allowsHitTesting(false)
            }
        }

        .background {
            if !bajoElCerrojo {
                TirarDeLaIsla(estado: panel)
                    .frame(width: 0, height: 0)
                    .accessibilityHidden(true)
            }
        }
        
        .statusBarHidden((panel.enPantalla || bajoElCerrojo))
        
        .accessibilityAction(named: Text("Herramientas")) {
            panel.abierto = true
        }

        .onChange(of: panel.ajuste) { _, a in
            if a != nil { pestana = "inicio" }
        }
        .environment(panel)
        .environment(agenda)

        .task {
            await panel.cargarFondo()
            if FondoDelCerrojo.recordado == nil { FondoDelCerrojo.recordado = panel.fondo }
            
            await Temas.compartido.ponerFoto(panel.fondo)
        }

        .task(id: fase) {
            if fase == .active {
                await AvisosDelIPhone.asegurarLlave(testigo: sesion.testigo)
                await AvisosDelIPhone.renovar(testigo: sesion.testigo, enPrimerPlano: true)
            } else if fase == .background {
                AvisosDelIPhone.programarSiguiente()
            }
        }

        .task(id: "\(fase)-\(bajoElCerrojo)") {
            guard fase == .active, !bajoElCerrojo else { return }
            #if MAQUETA
            
            guard Maqueta.pistaAnimada else { return }
            #endif
            try? await Task.sleep(for: .seconds(1.5))
            guard !Task.isCancelled, pestana == "inicio" else { return }
            panel.quizaPista()
        }

        .task(id: fase) {
            guard fase == .active else { return }
            while !Task.isCancelled {
                await agenda.cargar(testigo: sesion.testigo)
                try? await Task.sleep(for: .seconds(300))
            }
        }

        .modifier(AplicarTema())
        .onAppear { Temas.compartido.aplicarModo(animado: false) }
    }
}
