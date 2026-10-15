import SwiftUI

struct PantallaAgenda: View {
    @Environment(Sesion.self) private var sesion
    @Environment(AgendaEstado.self) private var agenda
    @Environment(\.tema) private var tema
    @Environment(\.scenePhase) private var fase
    @Environment(\.accessibilityReduceMotion) private var menosMovimiento

    @State private var elegida: String?
    @State private var trabajando: String?
    @State private var aviso: (texto: String, bien: Bool)?

    @State private var paraDeshacer: (texto: String, marcas: [[String: Any]],
                                      propio: (() async -> Bool)?, tarea: String?)?
    
    @State private var viaje = ViajeDelExcel()
    @Environment(\.openURL) private var abrirURL
    
    @State private var presentando: Tarea?
    @State private var relojDeshacer: Task<Void, Never>?
    @State private var nueva = false
    @State private var cambiando: Tarea?
    
    @State private var borrandoPropia: Tarea?
    
    @State private var llegoOtroDia: Tarea?
    @State private var destino: Destino?
    
    @State private var hechas = 0
    @AppStorage(AvisosDeLaAgenda.clave) private var avisosActivos = false

    @Namespace private var espacioLosa
    private var espacio: Namespace.ID? { menosMovimiento ? nil : espacioLosa }

    enum Destino: Hashable, Identifiable {
        case plataforma2(jornada: String, fin: String)
        case transferencia(fecha: String)
        case monedero

        case impuestos(trimestre: String, abrir: String = "")
        case factura(id: String, trimestre: String)
        case pedido(String)
        var id: Self { self }
    }

    private var pendientes: [Tarea] { agenda.pendientes }

    private var enLaLosa: Tarea? {
        if let e = elegida, let t = pendientes.first(where: { $0.id == e }) { return t }
        return pendientes.first
    }

    private var cola: [Tarea] { pendientes.filter { $0.id != enLaLosa?.id } }

    private var queViene: [Tarea] {
        enLaLosa == nil ? Array(agenda.viene.dropFirst()) : agenda.viene
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                contenido
            }
            .padding(.bottom, Diseno.hueco5 + (paraDeshacer == nil ? 0 : 60))
        }
        .scrollEdgeEffectStyle(.soft, for: .top)
        .background { campo }
        .navigationTitle("Agenda")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { nueva = true } label: {
                    Label("Nueva", systemImage: "plus")
                }
                .accessibilityLabel("Apuntar una tuya")
            }
        }
        .safeAreaInset(edge: .bottom) {
            if let d = paraDeshacer {
                BandaDeshacer(texto: d.texto, deshacer: d.marcas.isEmpty && d.propio == nil ? nil : {
                    Task { await deshacer() }
                })
                .padding(.bottom, Diseno.hueco1)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(menosMovimiento ? nil : .spring(duration: 0.5, bounce: 0.22),
                   value: pendientes.map(\.id))
        .animation(Diseno.suave, value: paraDeshacer?.texto)
        .refreshable { await agenda.cargar(testigo: sesion.testigo) }
        .task(id: fase) {
            guard fase == .active else { return }
            await agenda.cargar(testigo: sesion.testigo)
        }
        .sheet(isPresented: $nueva) {
            HojaTareaPropia { texto, fecha in
                await agenda.propia(["texto": texto, "fecha": fecha], testigo: sesion.testigo)
            }
            .hojaQueChoca()
        }
        .sheet(item: $cambiando) { t in
            HojaTareaPropia(existente: t) { texto, fecha in
                await agenda.propia(["id": propiaId(t), "texto": texto, "fecha": fecha],
                                    testigo: sesion.testigo)
            } borrar: {
                _ = await agenda.propia(["id": propiaId(t), "borrar": true], testigo: sesion.testigo)
            }
            .hojaQueChoca()
        }
        .sheet(item: $llegoOtroDia) { t in
            HojaDiaDeLlegada(tarea: t) { dia in
                await tachar(t, fecha: dia)
            }
            .presentationDetents([.medium])
            .hojaQueChoca()
        }
        .confirmationDialog("¿Borrar esta tarea?",
                            isPresented: Binding(get: { borrandoPropia != nil },
                                                 set: { if !$0 { borrandoPropia = nil } }),
                            titleVisibility: .visible, presenting: borrandoPropia) { t in
            Button("Borrar", role: .destructive) {
                Task { _ = await agenda.propia(["id": propiaId(t), "borrar": true],
                                               testigo: sesion.testigo) }
            }
        } message: { _ in
            Text("Se borra de la Agenda y no vuelve.")
        }
        .navigationDestination(item: $destino) { d in
            vista(de: d)
                .onDisappear { Task { await agenda.cargar(testigo: sesion.testigo) } }
        }
        .subidaDelExcel(viaje) { fin in await acabarExcel(fin) }

        .confirmationDialog("¿Coincide con tu gestoría?",
                            isPresented: .init(get: { presentando != nil },
                                               set: { if !$0 { presentando = nil } }),
                            titleVisibility: .visible, presenting: presentando) { t in
            Button("Sí, coincide") { Task { await presentado(t) } }
            Button("No, apuntar lo que dice") {
                destino = .impuestos(trimestre: t.trimestre, abrir: "gestoria")
            }
            Button("Cancelar", role: .cancel) {}
        } message: { t in
            Text("\(DatosImpuestos.nombre(t.trimestre, conAño: true)): "
                 + "130 \(Formato.euros(t.m130 ?? 0)) · 303 \(Formato.euros(t.m303 ?? 0))")
        }
        .sensoryFeedback(.selection, trigger: elegida)
        .sensoryFeedback(.success, trigger: hechas)
        #if MAQUETA
        .defaultScrollAnchor(Maqueta.anclaSala)
        .onAppear {
            if Maqueta.abrirNueva { nueva = true }
            if Maqueta.abrirImpuestos { destino = .impuestos(trimestre: Maqueta.trimestre) }
        }
        #endif
    }

    @ViewBuilder
    private var contenido: some View {
        switch agenda.estado {
        case .cargando:
            Vacio(icono: "checklist", titulo: "Cargando…")
                .redacted(reason: .placeholder)
                .padding(.top, Diseno.hueco5)
        case .error(let qué):
            Vacio(icono: "wifi.exclamationmark", titulo: "No se ha podido cargar", detalle: qué)
                .padding(.top, Diseno.hueco5)
        default:
            lineaDeApoyo
                .padding(.horizontal, Diseno.margen)
            losa
                .padding(.horizontal, Diseno.margen)
                .padding(.top, Diseno.hueco2)
            if let aviso {
                Banda(aviso)
                    .padding(.horizontal, Diseno.margen)
                    .padding(.top, Diseno.hueco2)
            }
            if !cola.isEmpty { seccionCola }
            if !queViene.isEmpty { seccionQueViene }
            seccionAvisos
        }
    }

    @ViewBuilder
    private var lineaDeApoyo: some View {
        if agenda.cuantas > 0 {
            HStack(spacing: 6) {
                Text(agenda.cuantas == 1 ? "1 te toca" : "\(agenda.cuantas) te tocan")
                    .monospacedDigit()
                    .contentTransition(.numericText(value: Double(agenda.cuantas)))
                if agenda.atrasadas > 0 {
                    Text("·")

                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundStyle(.white, Diseno.rojoRelleno)
                    Text(agenda.atrasadas == 1 ? "1 atrasada" : "\(agenda.atrasadas) atrasadas")
                }
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Marcador.apoyo)
            .accessibilityElement(children: .combine)
        }
    }

    @ViewBuilder
    private var losa: some View {
        ZStack(alignment: .top) {
            if let t = enLaLosa {
                LosaDeTarea(t: t, hoy: agenda.hoy,
                            trabajando: trabajando == t.id
                                || (viaje.subiendo && t.accion?.tipo == "excel"),
                            marcar: { Task { await tachar(t) } },
                            descartar: { Task { await tachar(t, descartar: true) } },
                            abrir: { abrir(t) },
                            deslizar: { await deslizar(t) },
                            espacio: espacio,
                            hacer: { hacer(t) },
                            otroDia: { llegoOtroDia = t })
                    .id(t.id)

                    .transition(menosMovimiento ? .opacity : .asymmetric(
                        insertion: .opacity,
                        removal: .scale(scale: 1.04, anchor: .top).combined(with: .opacity)))
                    .contextMenu { menuDePropia(t) }
            } else {
                LosaAlDia(siguiente: agenda.viene.first, hoy: agenda.hoy)
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
            }
        }
    }

    private var seccionCola: some View {
        VStack(alignment: .leading, spacing: 0) {
            
            TituloDeSeccion(texto: "Después")
            ForEach(Array(cola.enumerated()), id: \.element.id) { i, t in
                if i > 0 { Divider().padding(.leading, 42) }
                FilaDeTarea(t: t, hoy: agenda.hoy, trabajando: trabajando == t.id,
                            elegir: { elegir(t) },
                            marcar: { Task { await tachar(t) } },
                            espacio: espacio)
                    .contextMenu { menuDePropia(t) }
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.horizontal, Diseno.margen)
    }

    private var seccionQueViene: some View {
        VStack(alignment: .leading, spacing: 0) {
            TituloDeSeccion(texto: "Lo que viene")
            ForEach(Array(queViene.enumerated()), id: \.element.id) { i, t in
                if i > 0 { Divider().padding(.leading, 52) }
                if t.accion?.tipo == "abrir" || t.otra?.tipo == "abrir" {
                    
                    Button { abrir(t) } label: {
                        FilaQueViene(t: t, hoy: agenda.hoy, conFlecha: true)
                    }
                    .buttonStyle(Hundirse())
                } else {
                    FilaQueViene(t: t, hoy: agenda.hoy)
                        .contentShape(.rect)
                        .contextMenu { menuDePropia(t) }
                }
            }
        }
        .padding(.horizontal, Diseno.margen)
    }

    private var seccionAvisos: some View {
        VStack(alignment: .leading, spacing: Diseno.hueco1) {
            Toggle(isOn: Binding(get: { avisosActivos }, set: { quiere in
                Task { await cambiarAvisos(quiere) }
            })) {
                Label("Avisarme en el iPhone", systemImage: "bell.badge.fill")
                    .font(.headline)
            }
            .tint(tema.relleno)
            .frame(minHeight: 44)
            Text("El día que toca algo con fecha, a las \(AvisosDeLaAgenda.hora):00.")
                .font(.footnote)
                .foregroundStyle(Marcador.apoyo)
        }
        .padding(.horizontal, Diseno.margen)
        .padding(.top, Diseno.hueco4)
    }

    @ViewBuilder
    private func menuDePropia(_ t: Tarea) -> some View {
        if t.tipo == "propia" {
            Button { cambiando = t } label: { Label("Cambiar", systemImage: "pencil") }
            
            Button(role: .destructive) { borrandoPropia = t } label: {
                Label("Borrar", systemImage: "trash")
            }
        }
    }

    private var campo: some View {
        let c = AgendaColor.luz(cuantas: agenda.estado.cargada ? agenda.cuantas : 1,
                                atrasadas: agenda.atrasadas)
        return ZStack {
            CampoJoya(joya: .agenda, luz: c.luz)
                .id(c.clave)
                .transition(.opacity)
        }
        
        .animation(.smooth(duration: 0.7), value: c.clave)
    }

    private func elegir(_ t: Tarea) {
        withAnimation(menosMovimiento ? nil : .spring(duration: 0.5, bounce: 0.22)) {
            elegida = t.id
        }
    }

    private func propiaId(_ t: Tarea) -> String {
        t.id.hasPrefix("propia:") ? String(t.id.dropFirst("propia:".count)) : t.id
    }

    private func tachar(_ t: Tarea, descartar: Bool = false, fecha: String? = nil) async {
        trabajando = t.id
        aviso = nil
        let r = await agenda.tachar(t, descartar: descartar, fecha: fecha, testigo: sesion.testigo)
        trabajando = nil
        if r.ok {
            if elegida == t.id { elegida = nil }
            hechas += 1
            mostrarDeshacer(r.mensaje, r.deshacer, tarea: t.id)
        } else {
            aviso = (r.mensaje, false)
        }
    }

    private func mostrarDeshacer(_ texto: String, _ marcas: [[String: Any]],
                                 tarea: String? = nil, propio: (() async -> Bool)? = nil) {
        relojDeshacer?.cancel()
        paraDeshacer = (texto, marcas, propio, tarea)
        relojDeshacer = Task { @MainActor in
            try? await Task.sleep(for: .seconds(6))
            guard !Task.isCancelled else { return }
            paraDeshacer = nil
        }
    }

    private func deshacer() async {
        guard let d = paraDeshacer else { return }
        relojDeshacer?.cancel()
        paraDeshacer = nil
        let ok: Bool
        if let propio = d.propio {
            ok = await propio()
            await agenda.cargar(testigo: sesion.testigo)
        } else {
            ok = await agenda.deshacer(d.marcas, tarea: d.tarea, testigo: sesion.testigo)
        }
        if !ok { aviso = ("No se ha podido deshacer.", false) }
    }

    private func hacer(_ t: Tarea) {
        switch t.accion?.tipo {
        case "excel":
            guard let url = t.accion?.enlace else { abrir(t); return }
            aviso = nil
            viaje.descargar(url, trimestre: t.trimestre, con: abrirURL)
        case "presentado":
            presentando = t
        default:
            abrir(t)
        }
    }

    private func acabarExcel(_ fin: FinDelExcel) async {
        switch fin {
        case .revisado(let r):
            aviso = (r.resumen, r.errores == 0)

            if r.errores + r.avisos == 0 { hechas += 1 }
            await agenda.cargar(testigo: sesion.testigo)
        case .fallo(let texto):
            aviso = (texto, false)
        case .sinArchivo:
            aviso = (FinDelExcel.sinSesion, false)
        }
        if let a = aviso { AccessibilityNotification.Announcement(a.texto).post() }
    }

    private func presentado(_ t: Tarea) async {
        trabajando = t.id
        defer { trabajando = nil }
        do {
            _ = try await API.pedir("api/impuestos/gestoria", metodo: "POST",
                                    cuerpo: ["trimestre": t.trimestre, "coincide": true],
                                    testigo: sesion.testigo)
            hechas += 1
            if elegida == t.id { elegida = nil }
            let trimestre = t.trimestre
            let testigo = sesion.testigo
            mostrarDeshacer("Apuntado como presentado", [], propio: {
                (try? await API.pedir("api/impuestos/gestoria", metodo: "POST",
                                      cuerpo: ["trimestre": trimestre, "borrar": true],
                                      testigo: testigo)) != nil
            })
            await agenda.cargar(testigo: sesion.testigo)
        } catch {
            aviso = (error.localizedDescription, false)
        }
    }

    private func deslizar(_ t: Tarea) async -> Bool {
        guard let p = t.pedido, let accion = t.accion?.pedido, !accion.isEmpty else { return false }
        trabajando = t.id
        defer { trabajando = nil }
        do {
            let r = try await API.pedir("api/pedidos/\(p.id)/accion", metodo: "POST",
                                        cuerpo: ["accion": accion], testigo: sesion.testigo)
            let ok = r["ok"] as? Bool ?? false
            if ok {
                hechas += 1
                mostrarDeshacer(r["mensaje"] as? String ?? "Hecho.", [])
            } else {
                aviso = (r["mensaje"] as? String ?? "No se ha podido.", false)
            }
            await agenda.cargar(testigo: sesion.testigo)
            return ok
        } catch {
            aviso = (error.localizedDescription, false)
            return false
        }
    }

    private func abrir(_ t: Tarea) {
        let d = t.accion?.tipo == "abrir" ? t.accion?.destino : t.otra?.destino
        switch d {
        case "plataforma2_apuntar": destino = .plataforma2(jornada: t.fecha, fin: t.nocheFin)
        case "transferencias": destino = .transferencia(fecha: t.accion?.fecha ?? t.fecha)
        case "monedero": destino = .monedero
        case "impuestos": destino = .impuestos(trimestre: t.trimestre)
        case "impuestos_detalle": destino = .impuestos(trimestre: t.trimestre, abrir: "detalle")
        case "factura":
            if let a = t.accion { destino = .factura(id: a.id, trimestre: a.trimestre) }
        case "pedido": if let p = t.pedido { destino = .pedido(p.id) }
        default: break
        }
    }

    @ViewBuilder
    private func vista(de d: Destino) -> some View {
        switch d {
        case .plataforma2(_, let fin):

            PantallaManual(clave: "plataforma2", recibidoEn: Self.momento(fin))
        case .transferencia(let fecha):
            PantallaTransferencias(abrir: fecha, plataformaAbrir: "plataforma2") {
                await agenda.cargar(testigo: sesion.testigo)
            }
        case .monedero:
            PantallaAjustesP1(abrirEditando: true) { await agenda.cargar(testigo: sesion.testigo) }
        case .impuestos(let trimestre, let abrir):
            
            PantallaImpuestos(trimestreInicial: trimestre, abrirDetalle: abrir == "detalle",
                              abrirGestoria: abrir == "gestoria")
        case .factura(let id, let trimestre):
            
            PantallaImpuestos(trimestreInicial: trimestre, abrirIngreso: id)
        case .pedido(let id):
            PantallaPedido(id: id)
        }
    }

    private func cambiarAvisos(_ quiere: Bool) async {
        if quiere {
            let ok = await AvisosDeLaAgenda.pedirPermiso()
            avisosActivos = ok
            if ok {
                AvisosDeLaAgenda.programar(ahora: pendientes, viene: agenda.viene, hoy: agenda.hoy)
            } else {
                aviso = ("Los avisos están apagados en Ajustes del iPhone › Ingresos.", false)
            }
        } else {
            avisosActivos = false
            AvisosDeLaAgenda.quitarTodos()
        }
    }

    static func momento(_ iso: String) -> Date? {
        guard !iso.isEmpty else { return nil }
        let limpio = iso.replacingOccurrences(of: #"\.\d+"#, with: "", options: .regularExpression)
        return ISO8601DateFormatter().date(from: limpio)
    }
}

extension Carga {
    
    var cargada: Bool {
        if case .listo = self { return true }
        if case .vacio = self { return true }
        return false
    }
}
