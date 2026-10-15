import SwiftUI

struct HojaEditarGastoFijo: View {
    let datos: EstadoGastosFijos
    var existente: GastosFijos.Gasto?
    
    var alBorrar: (() -> Void)?

    @Environment(Sesion.self) private var sesion
    @Environment(\.dismiss) private var cerrar
    @State private var nombre = ""
    @State private var tipo: TipoDeGasto = .casa
    @State private var euros = ""
    @State private var dia = 1
    @State private var desde = MesesGasto.actual
    @State private var fin = "siempre"
    @State private var hasta = MesesGasto.sumar(MesesGasto.actual, 11)
    @State private var cuotas = 12
    @State private var trabajando = false
    @State private var fallo: String?
    @State private var preguntarBorrar = false
    @State private var hecho = 0
    @FocusState private var escribiendo: Bool

    private var importe: Double { CuentaIVA.numero(euros) ?? 0 }
    private var puedeGuardar: Bool {
        !trabajando && !nombre.trimmingCharacters(in: .whitespaces).isEmpty
            && (existente != nil || importe > 0)
    }
    
    private var mesesParaEmpezar: [String] {
        let base = MesesGasto.actual
        var lista = (-12...24).map { MesesGasto.sumar(base, $0) }
        if !lista.contains(desde) { lista.append(desde); lista.sort() }
        return lista
    }
    
    private var mesesParaAcabar: [String] {
        (0...120).map { MesesGasto.sumar(desde, $0) }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Nombre", text: $nombre)
                        .focused($escribiendo)
                        .submitLabel(.done)
                    if existente == nil {
                        HStack {
                            Text("Al mes")
                            Spacer()
                            TextField("0,00", text: $euros)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .monospacedDigit()
                            Text("€").foregroundStyle(.secondary)
                        }
                    }
                    Picker("Se paga el día", selection: $dia) {
                        ForEach(1...31, id: \.self) { Text("\($0)").tag($0) }
                    }
                } footer: {
                    
                    if existente == nil {
                        Text("Se aparta de tus cobros antes que la Reserva.")
                    }
                }

                Section("Ficha") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 6),
                              spacing: 10) {
                        ForEach(TipoDeGasto.allCases) { t in
                            Button { tipo = t } label: {
                                FichaIcono(simbolo: t.simbolo, color: t.color, lado: 36)
                                    .padding(3)
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 36 * 0.263 + 4, style: .continuous)
                                            .strokeBorder(Color.primary, lineWidth: tipo == t ? 2.5 : 0)
                                    }
                                    .frame(minWidth: 44, minHeight: 44)
                                    .contentShape(.rect)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(t.nombre)
                            .accessibilityAddTraits(tipo == t ? .isSelected : [])
                        }
                    }
                    .padding(.vertical, 4)
                    .animation(.snappy(duration: 0.2), value: tipo)
                }

                Section {
                    Picker("Empieza", selection: $desde) {
                        ForEach(mesesParaEmpezar, id: \.self) { m in
                            Text(MesesGasto.nombre(m, hoy: MesesGasto.actual).capitalizandoPrimera).tag(m)
                        }
                    }
                    Picker("Hasta", selection: $fin.animation(Diseno.suave)) {
                        Text("Siempre").tag("siempre")
                        Text("Un mes").tag("mes")
                        Text("Cuotas").tag("cuotas")
                    }
                    .pickerStyle(.segmented)
                    if fin == "mes" {
                        Picker("Último mes", selection: $hasta) {
                            ForEach(mesesParaAcabar, id: \.self) { m in
                                Text(MesesGasto.nombre(m, hoy: MesesGasto.actual).capitalizandoPrimera).tag(m)
                            }
                        }
                    } else if fin == "cuotas" {
                        Stepper(value: $cuotas, in: 1...600) {
                            Text(cuotas == 1 ? "1 cuota" : "\(cuotas) cuotas").monospacedDigit()
                        }
                    }
                } footer: {
                    switch fin {
                    case "cuotas":
                        Text("La última, en \(MesesGasto.nombre(MesesGasto.sumar(desde, cuotas - 1), hoy: MesesGasto.actual)).")
                    case "mes":
                        let n = MesesGasto.entre(desde, hasta) + 1
                        Text(n == 1 ? "Un solo pago." : "\(n) pagos.")
                    default:
                        EmptyView()
                    }
                }

                if let fallo {
                    Text(fallo).foregroundStyle(Diseno.rojo).font(.footnote)
                }

                if existente != nil {
                    Section {
                        Button("Borrar este gasto", role: .destructive) { preguntarBorrar = true }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .salidaDelTeclado()
            .navigationTitle(existente == nil ? "Nuevo gasto" : "Cambiar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .close) { cerrar() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button { Task { await confirmar() } } label: {
                        MarcaConfirmar(trabajando: trabajando)
                    }
                    .disabled(!puedeGuardar)
                }
            }
            .confirmationDialog("¿Borrar «\(nombre)»?", isPresented: $preguntarBorrar,
                                titleVisibility: .visible) {
                Button("Borrar", role: .destructive) { Task { await borrar() } }
            } message: {
                Text("Deja de apartarse de tus cobros, también de los de este mes.")
            }
            .sensoryFeedback(.success, trigger: hecho)
        }
        .presentationDetents([.large])
        .onAppear {
            rellenar()
            escribiendo = existente == nil
        }
        .onChange(of: desde) { _, nuevo in
            if hasta < nuevo { hasta = nuevo }
        }
    }

    private func rellenar() {
        guard let g = existente else {
            #if MAQUETA
            nombre = "Gimnasio"
            euros = "39,90"
            tipo = .gimnasio
            dia = 5
            fin = "cuotas"
            #endif
            return
        }
        nombre = g.nombre
        tipo = TipoDeGasto.de(simbolo: g.simbolo)
        dia = g.dia
        desde = g.desde
        if g.paraSiempre {
            fin = "siempre"
        } else {
            fin = "mes"
            hasta = g.hasta
            cuotas = max(1, MesesGasto.entre(g.desde, g.hasta) + 1)
        }
    }

    private func confirmar() async {
        trabajando = true
        defer { trabajando = false }
        var cuerpo: [String: any Sendable] = [
            "nombre": nombre.trimmingCharacters(in: .whitespaces), "simbolo": tipo.simbolo,
            "dia": dia, "desde": desde, "fin": fin]
        if fin == "mes" { cuerpo["hasta"] = hasta }
        if fin == "cuotas" { cuerpo["cuotas"] = cuotas }
        if let g = existente { cuerpo["id"] = g.id } else { cuerpo["euros"] = euros }
        let r = await datos.mandar("api/gastos", cuerpo, testigo: sesion.testigo)
        if r.ok {
            hecho += 1
            cerrar()
        } else {
            fallo = r.mensaje
        }
    }

    private func borrar() async {
        guard let g = existente else { return }
        let r = await datos.mandar("api/gastos/borrar", ["id": g.id], testigo: sesion.testigo)
        if r.ok {
            cerrar()
            alBorrar?()
        } else {
            fallo = r.mensaje
        }
    }
}

struct HojaGastoFijo: View {
    let id: String
    let datos: EstadoGastosFijos

    @Environment(Sesion.self) private var sesion
    @Environment(\.dismiss) private var cerrar
    @State private var editando = false
    @State private var cambiandoImporte = false
    @State private var quitando: GastosFijos.Importe?
    @ScaledMetric(relativeTo: .largeTitle) private var tamCifra: CGFloat = 44

    private var todo: GastosFijos? { datos.estado.listos }
    private var gasto: GastosFijos.Gasto? { todo?.gastos.first { $0.id == id } }

    var body: some View {
        NavigationStack {
            ScrollView {
                if let g = gasto {
                    contenido(g, hoy: todo?.hoy ?? "")
                        .padding(.horizontal, Diseno.margen)
                        .padding(.bottom, Diseno.hueco4)
                } else {
                    Vacio(icono: "creditcard", titulo: "Ese gasto ya no está")
                }
            }
            
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .close) { cerrar() }
                }
                if gasto != nil {
                    ToolbarItem(placement: .primaryAction) {
                        Button("Editar") { editando = true }
                    }
                }
            }
            .sheet(isPresented: $editando) {
                if let g = gasto {
                    HojaEditarGastoFijo(datos: datos, existente: g, alBorrar: { cerrar() })
                }
            }
            .sheet(isPresented: $cambiandoImporte) {
                if let g = gasto {
                    HojaCambiarImporte(gasto: g, datos: datos)
                }
            }
            .confirmationDialog("¿Quitar este cambio?",
                                isPresented: .init(get: { quitando != nil },
                                                   set: { if !$0 { quitando = nil } }),
                                titleVisibility: .visible, presenting: quitando) { i in
                Button("Quitar", role: .destructive) {
                    Task {
                        _ = await datos.mandar("api/gastos/importe",
                                               ["id": id, "desde": i.desde, "quitar": true],
                                               testigo: sesion.testigo)
                    }
                }
            } message: { i in
                Text("Desde \(MesesGasto.nombre(i.desde, hoy: todo?.hoy ?? "")) vuelve al importe de antes.")
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func contenido(_ g: GastosFijos.Gasto, hoy: String) -> some View {
        VStack(alignment: .leading, spacing: Diseno.hueco3) {
            HStack(spacing: Diseno.hueco2) {
                FichaIcono(simbolo: g.simbolo, color: TipoDeGasto.de(simbolo: g.simbolo).color,
                           lado: 44)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(g.nombre).font(.title2.weight(.bold))
                    Text(subtitulo(g, hoy: hoy))
                        .font(.subheadline)
                        .foregroundStyle(Diseno.apoyoEnCristal)
                }
            }
            .padding(.top, Diseno.hueco2)

            VStack(alignment: .leading, spacing: 2) {
                Text(Formato.euros(g.importeVisible))
                    .font(.system(size: min(tamCifra, 60), weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .contentTransition(.numericText(value: g.importeVisible))
                Text(g.estado == "empieza" ? "al mes, desde \(MesesGasto.nombre(g.desde, hoy: hoy))" : "al mes")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Diseno.apoyoEnCristal)
            }

            if let c = g.cuotas {
                cuotas(c, g: g, hoy: hoy)
            }

            importes(g, hoy: hoy)

            if g.estado != "terminado" {
                Button { cambiandoImporte = true } label: {
                    Label("Cambiar el importe", systemImage: "eurosign.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glass)
                .controlSize(.large)
            }
        }
    }

    private func subtitulo(_ g: GastosFijos.Gasto, hoy: String) -> String {
        var trozos = ["Día \(g.dia)"]
        if g.paraSiempre {
            trozos.append("sin fecha de fin")
        } else {
            trozos.append("hasta \(MesesGasto.nombre(g.hasta, hoy: hoy))")
        }
        return trozos.joined(separator: " · ")
    }

    private func cuotas(_ c: GastosFijos.Cuotas, g: GastosFijos.Gasto, hoy: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("Cuotas").font(.headline)
                Spacer()
                Text("\(c.pagadas) de \(c.total) pagadas")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Diseno.apoyoEnCristal)
                    .monospacedDigit()
            }
            BarraDeCuotas(cuotas: c, alto: 8)
            if c.quedan > 0 {
                Text("Quedan \(c.quedan == 1 ? "1" : "\(c.quedan)") · \(Formato.euros(c.falta)) · la última, en \(MesesGasto.nombre(g.hasta, hoy: hoy))")
                    .font(.footnote)
                    .foregroundStyle(Diseno.apoyoEnCristal)
                    .monospacedDigit()
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Label("Pagado entero", systemImage: "checkmark.circle.fill")
                    .font(.footnote.weight(.medium))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, Diseno.verdeRelleno)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func importes(_ g: GastosFijos.Gasto, hoy: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Importes").font(.headline)
                .padding(.bottom, Diseno.hueco1)
            ForEach(Array(g.importes.enumerated()), id: \.element) { i, imp in
                if i > 0 { Divider() }
                HStack {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Desde \(MesesGasto.nombre(imp.desde, hoy: hoy))")
                            .font(.subheadline)
                        if imp.desde > (todo?.mes ?? "") {
                            Text("próximo").font(.caption2.weight(.semibold))
                                .foregroundStyle(Diseno.apoyoEnCristal)
                        }
                    }
                    Spacer()
                    Text(Formato.euros(imp.euros))
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .monospacedDigit()
                    if i > 0 {
                        Button { quitando = imp } label: {
                            Image(systemName: "minus.circle.fill")
                                .symbolRenderingMode(.palette)
                                .foregroundStyle(.white, Diseno.rojoRelleno)
                                .frame(minWidth: 44, minHeight: 44)
                                .contentShape(.rect)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Quitar el cambio de \(MesesGasto.nombre(imp.desde, hoy: hoy))")
                    }
                }
                .frame(minHeight: 44)
            }
        }
    }
}

struct HojaCambiarImporte: View {
    let gasto: GastosFijos.Gasto
    let datos: EstadoGastosFijos

    @Environment(Sesion.self) private var sesion
    @Environment(\.dismiss) private var cerrar
    @State private var euros = ""
    @State private var desde = ""
    @State private var trabajando = false
    @State private var fallo: String?
    @State private var hecho = 0
    @FocusState private var escribiendo: Bool

    private var meses: [String] {
        let primero = max(MesesGasto.sumar(MesesGasto.actual, 0), gasto.desde)
        let ultimo = gasto.hasta.isEmpty ? MesesGasto.sumar(primero, 36) : gasto.hasta
        return (0...max(0, MesesGasto.entre(primero, ultimo))).map { MesesGasto.sumar(primero, $0) }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Text("Nuevo importe")
                        Spacer()
                        TextField(CuentaIVA.paraPegar(gasto.importeVisible), text: $euros)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .monospacedDigit()
                            .focused($escribiendo)
                        Text("€").foregroundStyle(.secondary)
                    }
                    Picker("Desde", selection: $desde) {
                        ForEach(meses, id: \.self) { m in
                            Text(MesesGasto.nombre(m, hoy: MesesGasto.actual).capitalizandoPrimera).tag(m)
                        }
                    }
                } footer: {
                    
                    Text("Los meses de antes siguen con su importe.")
                }
                if let fallo {
                    Text(fallo).foregroundStyle(Diseno.rojo).font(.footnote)
                }
            }
            .scrollContentBackground(.hidden)
            .salidaDelTeclado()
            .navigationTitle("Cambiar el importe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .close) { cerrar() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button { Task { await confirmar() } } label: {
                        MarcaConfirmar(trabajando: trabajando)
                    }
                    .disabled(trabajando || (CuentaIVA.numero(euros) ?? 0) <= 0 || desde.isEmpty)
                }
            }
            .sensoryFeedback(.success, trigger: hecho)
        }
        .presentationDetents([.medium])
        .onAppear {
            desde = meses.dropFirst().first ?? meses.first ?? ""
            escribiendo = true
        }
    }

    private func confirmar() async {
        trabajando = true
        defer { trabajando = false }
        let r = await datos.mandar("api/gastos/importe",
                                   ["id": gasto.id, "euros": euros, "desde": desde],
                                   testigo: sesion.testigo)
        if r.ok {
            hecho += 1
            cerrar()
        } else {
            fallo = r.mensaje
        }
    }
}
