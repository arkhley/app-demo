import PhotosUI
import SwiftUI

struct DatosImpuestos: Equatable {
    struct Cobro: Identifiable, Equatable {
        let id: String
        let plataforma: String
        let etiqueta: String
        let fecha: String
        let euros: Double
        let ingreso: Double
        let iva: Double
        let usd: Double
        let cambio: Double
        let llegado: Bool
        let estimado: Bool
        let hacienda: Double?
        let cuota: Double?
        
        let cuotaPagada: Bool
        let apartar: Double?
        let apartado: Bool
        let tipo: String
        
        let facturaEuros: Double?
        let facturaNumero: String

        let facturaAceptada: Bool
        
        let cliente: String
        let clienteNombre: String
        let ivaModo: String
        let ivaPct: Double
        
        let paraFactura: Double
        let facturaTotal: Double
        
        let cambioDia: String
        
        let manual: Bool
        let concepto: String
        
        var faltaMas: Double = 0
        
        var borrador: BorradorAsesoria? = nil

        var llevaIVA: Bool {
            ["tienda", "pasarela"].contains(plataforma) && ivaModo != "sin"
        }
        
        var facturaDeOtroDia: Bool {
            guard let f = facturaEuros, ["plataforma1", "plataforma2"].contains(plataforma) else {
                return false
            }
            return abs(f - paraFactura) >= 0.005
        }
        
        var facturaPorCambiar: Bool { facturaDeOtroDia && !facturaAceptada }
    }

    struct Contacto: Identifiable, Equatable, Hashable {
        let id: String
        let tipo: String            
        let nombre: String
        let ivaModo: String         
        let ivaPct: Double
        let documento: String       
        let fijo: Bool

        var esCliente: Bool { tipo == "cliente" }

        init(_ j: [String: Any]) {
            id = j["id"] as? String ?? ""
            tipo = j["tipo"] as? String ?? "proveedor"
            nombre = j["nombre"] as? String ?? ""
            ivaModo = j["iva_modo"] as? String ?? "sin"
            ivaPct = (j["iva_pct"] as? NSNumber)?.doubleValue ?? 0
            documento = j["documento"] as? String ?? "factura"
            fijo = j["fijo"] as? Bool ?? false
        }

        var resumen: String {
            let pct = "\(Int(ivaPct)) %"
            if esCliente {
                switch ivaModo {
                case "incluido": return "IVA \(pct) incluido"
                case "encima": return "IVA \(pct) encima"
                default: return "Sin IVA"
                }
            }
            if ivaPct == 0 { return documento == "ticket" ? "Ticket" : "Exento de IVA" }
            return documento == "ticket" ? "IVA \(pct) · ticket" : "IVA \(pct) · factura"
        }
    }

    struct Gasto: Identifiable, Equatable {
        let id: String
        let fecha: String
        let concepto: String
        let total: Double
        let base: Double
        let iva: Double
        let auto: Bool
        let mensual: Bool
        let proveedor: String
        let documento: String
    }

    struct Cuota: Identifiable, Equatable {
        var id: String { mes }
        let mes: String
        let cuota: Double
        
        let cubierto: Double
        let apartado: Double
        
        let porLlegar: Double
        
        let falta: Double
        
        let cobro: String
        let estado: String          
    }

    struct Tramo: Equatable {
        let anio: Int
        let tabla: String           
        let tramo: Int
        let base: Double
        let euros: Double
        
        let rendimiento: Double
        
        let anioTabla: Int
        let origen: String          
        
        let diferencia: Double

        init?(_ v: Any?) {
            guard let j = v as? [String: Any],
                  let e = (j["euros"] as? NSNumber)?.doubleValue else { return nil }
            func n(_ x: Any?) -> Double { (x as? NSNumber)?.doubleValue ?? 0 }
            anio = (j["anio"] as? NSNumber)?.intValue ?? 0
            tabla = j["tabla"] as? String ?? ""
            tramo = (j["tramo"] as? NSNumber)?.intValue ?? 0
            base = n(j["base"])
            euros = e
            rendimiento = n(j["rendimiento"])
            anioTabla = (j["anio_tabla"] as? NSNumber)?.intValue ?? 0
            origen = j["origen"] as? String ?? "calculada"
            diferencia = n(j["diferencia"])
        }

        var nombre: String { "tramo \(tramo) de la \(tabla)" }
        var tablaVieja: Bool { anioTabla > 0 && anioTabla < anio }
    }

    struct InfoCuota: Equatable {
        let mes: String
        let euros: Double
        let origen: String          
        
        let desde: String
        let tarifaPlanaHasta: String
        let calculada: Tramo?
        let ritmo: Tramo?
        let siguiente: Tramo?

        init(_ v: Any?) {
            let j = v as? [String: Any] ?? [:]
            mes = j["mes"] as? String ?? ""
            euros = (j["euros"] as? NSNumber)?.doubleValue ?? 0
            origen = j["origen"] as? String ?? "a_mano"
            desde = j["desde"] as? String ?? ""
            tarifaPlanaHasta = j["tarifa_plana_hasta"] as? String ?? ""
            calculada = Tramo(j["calculada"])
            ritmo = Tramo(j["ritmo"])
            siguiente = Tramo(j["siguiente"])
        }
    }

    let trimestre: String
    let enCurso: String
    let estado: String          
    let trimestres: [String]
    
    let presentados: Set<String>
    let plazo: String
    let total: Double
    let ingresos: Double
    let gastos: Double
    let m130: [String: Double]
    let m303: [String: Double]
    let ue: Double
    let cobros: [Cobro]
    let listaGastos: [Gasto]
    
    let hayApartar: Bool
    
    let necesario: Double
    let yaLlegado: Double
    let apartado: Double
    let faltaHacienda: Double
    let porLlegar: Double
    let sobra: Double
    let cuotas: [Cuota]
    
    let pendienteTotal: Double
    let pendiente: [String: Double]
    let pendienteCuota: Double
    
    let gestoriaCoincide: Bool?
    let gestoria130: Double?
    let gestoria303: Double?
    let gestoriaApp130: Double?
    let gestoriaApp303: Double?
    let ajustes: [String: Any]
    
    let presentadoTotal: Double?
    let contactos: [Contacto]
    
    let cuotasPorSubir: [(mes: String, euros: Double)]

    let gastosPorSubir: [(clave: String, mes: String, concepto: String, euros: Double)]
    
    let cuotaAutonomo: InfoCuota
    
    let deduccionDelAnio: Double
    
    let comprobadoCuando: String
    let comprobadoVeredicto: String
    let comprobadoErrores: Int
    let comprobadoAvisos: Int
    
    let comprobadoFuente: String

    let asesoria130: Double?
    let asesoria303: Double?
    let asesoriaCuando: String
    
    let asesoriaApp130: Double?
    let asesoriaApp303: Double?

    let asesoria303Que: String

    let app303Trimestre: Double?
    let app303Acumulado: Double?
    
    let excelIRPF: URL?
    let excelIVA: URL?
    
    let ultimaCuando: String
    let ultimaVeredicto: String

    static func == (a: DatosImpuestos, b: DatosImpuestos) -> Bool {
        a.trimestre == b.trimestre && a.total == b.total && a.cobros == b.cobros
            && a.listaGastos == b.listaGastos && a.apartado == b.apartado
            && a.cuotas == b.cuotas && a.pendienteTotal == b.pendienteTotal
            && a.gestoriaCoincide == b.gestoriaCoincide && a.gestoria130 == b.gestoria130
            && a.gestoria303 == b.gestoria303 && a.presentadoTotal == b.presentadoTotal
            && a.contactos == b.contactos
            && a.cuotasPorSubir.map(\.mes) == b.cuotasPorSubir.map(\.mes)
            && a.gastosPorSubir.map(\.clave) == b.gastosPorSubir.map(\.clave)
            && a.cuotaAutonomo == b.cuotaAutonomo
            && a.comprobadoCuando == b.comprobadoCuando
            && a.asesoriaCuando == b.asesoriaCuando && a.ultimaCuando == b.ultimaCuando
    }

    init(_ j: [String: Any]) {
        func n(_ v: Any?) -> Double { (v as? NSNumber)?.doubleValue ?? 0 }
        func o(_ v: Any?) -> Double? { (v as? NSNumber)?.doubleValue }
        func numeros(_ v: Any?) -> [String: Double] {
            ((v as? [String: Any]) ?? [:]).compactMapValues { ($0 as? NSNumber)?.doubleValue }
        }
        trimestre = j["trimestre"] as? String ?? ""
        enCurso = j["en_curso"] as? String ?? ""
        estado = j["estado"] as? String ?? ""
        trimestres = ((j["trimestres"] as? [[String: Any]]) ?? []).compactMap { $0["id"] as? String }
        presentados = Set(((j["trimestres"] as? [[String: Any]]) ?? []).compactMap {
            ($0["gestoria"] as? Bool ?? false) ? $0["id"] as? String : nil
        })
        let c = j["calculo"] as? [String: Any] ?? [:]
        plazo = c["plazo"] as? String ?? ""
        total = n(c["total"])
        ingresos = n(c["ingresos"])
        gastos = n(c["gastos"])
        m130 = numeros(c["m130"])
        m303 = numeros(c["m303"])
        ue = n((c["m349"] as? [String: Any])?["ue"])

        let a = j["apartar"] as? [String: Any]
        hayApartar = a != nil
        necesario = n(a?["necesario"])
        yaLlegado = n(a?["ya_llegado"])
        apartado = n(a?["apartado"])
        faltaHacienda = n(a?["falta_hacienda"])
        porLlegar = n(a?["por_llegar"])
        sobra = n(a?["sobra"])
        cuotas = ((a?["cuotas"] as? [[String: Any]]) ?? []).map {
            Cuota(mes: $0["mes"] as? String ?? "", cuota: n($0["cuota"]),
                  cubierto: n($0["cubierto"]), apartado: n($0["apartado"]),
                  porLlegar: n($0["por_llegar"]), falta: n($0["falta"]),
                  cobro: $0["cobro"] as? String ?? "",
                  estado: $0["estado"] as? String ?? "futura")
        }

        let filas = (a?["filas"] as? [[String: Any]]) ?? (j["cobros"] as? [[String: Any]]) ?? []
        cobros = filas.map { f in
            Cobro(id: f["id"] as? String ?? "",
                  plataforma: f["plataforma"] as? String ?? "",
                  etiqueta: f["etiqueta"] as? String ?? "",
                  fecha: f["fecha"] as? String ?? "",
                  euros: n(f["euros"]), ingreso: n(f["ingreso"]), iva: n(f["iva"]),
                  usd: n(f["usd"]), cambio: n(f["cambio"]),
                  llegado: f["llegado"] as? Bool ?? false,
                  estimado: f["estimado"] as? Bool ?? false,
                  hacienda: o(f["hacienda"]), cuota: o(f["cuota"]),
                  cuotaPagada: f["cuota_pagada"] as? Bool ?? false,
                  apartar: o(f["apartar"]),
                  apartado: f["apartado"] as? Bool ?? false,
                  tipo: f["tipo"] as? String ?? "",
                  facturaEuros: o((f["factura"] as? [String: Any])?["euros"]),
                  facturaNumero: (f["factura"] as? [String: Any])?["numero"] as? String ?? "",
                  facturaAceptada: (f["factura"] as? [String: Any])?["aceptada"] as? Bool ?? false,
                  cliente: f["cliente"] as? String ?? "",
                  clienteNombre: f["cliente_nombre"] as? String ?? "",
                  ivaModo: f["iva_modo"] as? String ?? "sin",
                  ivaPct: n(f["iva_pct"]),
                  paraFactura: n(f["para_factura"]),
                  facturaTotal: n(f["factura_total"]),
                  cambioDia: f["cambio_dia"] as? String ?? "",
                  manual: f["manual"] as? Bool ?? false,
                  concepto: f["concepto"] as? String ?? "",
                  faltaMas: n(f["falta_mas"]),
                  borrador: BorradorAsesoria(f["borrador_asesoria"]))
        }
        listaGastos = ((j["gastos"] as? [[String: Any]]) ?? []).map { g in
            Gasto(id: g["id"] as? String ?? "", fecha: g["fecha"] as? String ?? "",
                  concepto: g["concepto"] as? String ?? "", total: n(g["total"]),
                  base: n(g["base"]), iva: n(g["iva"]), auto: g["auto"] as? Bool ?? false,
                  mensual: g["mensual"] as? Bool ?? false,
                  proveedor: g["proveedor"] as? String ?? "",
                  documento: g["documento"] as? String ?? "factura")
        }
        let p = j["pendiente"] as? [String: Any] ?? [:]
        pendienteTotal = n(p["total"])
        pendiente = numeros(p["por_trimestre"])
        pendienteCuota = n(p["cuota"])

        let g = j["gestoria"] as? [String: Any] ?? [:]
        gestoriaCoincide = g["coincide"] as? Bool
        gestoria130 = o(g["m130"])
        gestoria303 = o(g["m303"])
        let app = g["app"] as? [String: Any] ?? [:]
        gestoriaApp130 = o(app["m130"])
        gestoriaApp303 = o(app["m303"])
        ajustes = j["ajustes"] as? [String: Any] ?? [:]
        presentadoTotal = o((j["presentado"] as? [String: Any])?["total"])
        contactos = ((j["contactos"] as? [[String: Any]]) ?? []).map(Contacto.init)
        cuotasPorSubir = ((j["cuotas_por_subir"] as? [[String: Any]]) ?? []).map {
            (mes: $0["mes"] as? String ?? "", euros: n($0["euros"]))
        }
        gastosPorSubir = ((j["gastos_por_subir"] as? [[String: Any]]) ?? []).map {
            (clave: $0["clave"] as? String ?? "", mes: $0["mes"] as? String ?? "",
             concepto: $0["concepto"] as? String ?? "", euros: n($0["euros"]))
        }
        cuotaAutonomo = InfoCuota(j["cuota_autonomo"])
        deduccionDelAnio = n(j["deduccion_del_anio"])
        let comp = j["comprobacion"] as? [String: Any] ?? [:]
        comprobadoCuando = comp["cuando"] as? String ?? ""
        comprobadoVeredicto = comp["veredicto"] as? String ?? ""
        comprobadoErrores = (comp["errores"] as? NSNumber)?.intValue ?? 0
        comprobadoAvisos = (comp["avisos"] as? NSNumber)?.intValue ?? 0
        comprobadoFuente = comp["fuente"] as? String ?? ""
        let ot = j["asesoria"] as? [String: Any] ?? [:]
        asesoria130 = o(ot["m130"])
        asesoria303 = o(ot["m303"])
        asesoriaCuando = ot["cuando"] as? String ?? ""
        asesoriaApp130 = o(ot["app130"])
        asesoriaApp303 = o(ot["app303"])
        asesoria303Que = ot["m303_que"] as? String ?? ""
        app303Trimestre = o(j["app303_trimestre"])
        app303Acumulado = o(j["app303_acumulado"])
        let excel = j["asesoria_excel"] as? [String: Any]
        excelIRPF = (excel?["irpf"] as? String).flatMap(URL.init(string:))
        excelIVA = (excel?["iva"] as? String).flatMap(URL.init(string:))
        
        let ultima = j["ultima_comprobacion"] as? [String: Any] ?? [:]
        let valida = ["bien", "cambiar"].contains(ultima["veredicto"] as? String ?? "")
        ultimaCuando = valida ? ultima["cuando"] as? String ?? "" : ""
        ultimaVeredicto = valida ? ultima["veredicto"] as? String ?? "" : ""
    }

    var hayDatos: Bool { !trimestre.isEmpty }

    var abierto: Bool { ["en_curso", "por_presentar"].contains(estado) && gestoriaCoincide == nil }

    static func nombre(_ t: String, conAño: Bool = false) -> String {
        guard t.count == 7, let n = Int(String(t[t.index(t.startIndex, offsetBy: 5)])) else {
            return t
        }
        let ordinal = ["1.er", "2.º", "3.er", "4.º"][max(0, min(3, n - 1))]
        return conAño ? "\(ordinal) trimestre de \(t.prefix(4))" : "\(ordinal) trimestre"
    }

    static func corto(_ t: String) -> String { String(t.suffix(2)) }

    static func mes(_ iso: String) -> String {
        CobrosHucha.nombreDelMes(iso)
    }
}

struct PantallaImpuestos: View {
    @Environment(Sesion.self) private var sesion

    var trimestreInicial: String = ""
    var abrirIngreso: String? = nil

    var abrirDetalle = false
    var abrirGestoria = false
    @State private var ingresoYaAbierto = false
    @State private var entradaHecha = false
    @Environment(\.openURL) private var abrirURL
    
    @State private var viaje = ViajeDelExcel()
    @State private var notaExcel: (texto: String, bien: Bool)?
    @State private var eligiendoFotos = false
    @State private var contactosAbiertos = false

    @State private var datos: DatosImpuestos?
    @State private var error: String?
    @State private var aviso: String?
    @State private var marcando: String?
    @State private var plataforma = "todo"
    @State private var preguntando = false
    @State private var hojaGestoria = false
    @State private var hojaAjustes = false
    @State private var ingresoAbierto: DatosImpuestos.Cobro?
    @State private var nuevoIngreso = false
    @State private var nuevoGasto = false
    
    @State private var fotos: [PhotosPickerItem] = []
    @State private var comprobando = false
    @State private var resultado: ResultadoComprobacion?
    @State private var marcandoCuota: String?

    var body: some View {
        contenido
        .navigationTitle("Impuestos")
        .navigationBarTitleDisplayMode(.inline)
        
        .modifier(TrimestreEnElTitulo(activo: true, datos: datos) { t in
            Task { await cargar(t) }
        })
        .refreshable { await cargar(datos?.trimestre ?? "") }
        .task {

            await cargar(entradaHecha ? (datos?.trimestre ?? "") : trimestreInicial)
            if let id = abrirIngreso, !ingresoYaAbierto,
               let c = datos?.cobros.first(where: { $0.id == id || $0.id.hasPrefix(id + "@") }) {
                ingresoYaAbierto = true
                ingresoAbierto = c
            }
            if !entradaHecha {
                entradaHecha = true
                if abrirDetalle { await verUltimaComprobacion() }
                if abrirGestoria, datos != nil { hojaGestoria = true }
            }
        }
        .toolbar {
            
            ToolbarItem(placement: .topBarTrailing) {
                menuMas
            }
        }
        
        .photosPicker(isPresented: $eligiendoFotos, selection: $fotos, maxSelectionCount: 20,
                      matching: .images)
        .navigationDestination(isPresented: $contactosAbiertos) {
            PantallaContactos(alCambiar: { await cargar(datos?.trimestre ?? "") })
        }
        .subidaDelExcel(viaje) { fin in await acabarExcel(fin) }
        .sheet(item: $ingresoAbierto) { c in
            HojaIngreso(cobro: c, contactos: datos?.contactos ?? []) {
                await cargar(datos?.trimestre ?? "")
            }
        }
        .sheet(isPresented: $nuevoIngreso) {
            HojaIngreso(cobro: nil, contactos: datos?.contactos ?? []) {
                await cargar(datos?.trimestre ?? "")
            }
        }
        .sheet(isPresented: $nuevoGasto) {
            HojaGasto(gasto: nil) { await cargar(datos?.trimestre ?? "") }
        }
        .sheet(item: $resultado) { r in
            HojaComprobacion(resultado: r, marcarCuota: { mes in await marcarCuota(mes) },
                             usarCuota: { mes, euros in await usarCuota(mes, euros) })
        }
        .onChange(of: fotos) { _, nuevas in
            guard !nuevas.isEmpty else { return }
            Task { await comprobar(nuevas) }
        }
        .sheet(isPresented: $hojaGestoria) {
            if let d = datos {
                HojaGestoria(datos: d) { await cargar(d.trimestre) }
            }
        }
        .sheet(isPresented: $hojaAjustes) {
            if let d = datos {
                HojaAjustesImpuestos(ajustes: d.ajustes, info: d.cuotaAutonomo) {
                    await cargar(d.trimestre)
                }
            }
        }
        .confirmationDialog("¿Coincide con tu gestoría?", isPresented: $preguntando,
                            titleVisibility: .visible, presenting: datos) { d in
            Button("Sí, coincide") { Task { await coincide(d) } }
            Button("No, apuntar lo que dice") { hojaGestoria = true }
            Button("Cancelar", role: .cancel) {}
        } message: { d in
            Text("\(DatosImpuestos.nombre(d.trimestre, conAño: true)): 130 \(Formato.euros(d.m130["resultado"] ?? 0)) · 303 \(Formato.euros(d.m303["resultado"] ?? 0))")
        }
    }

    @ViewBuilder
    private var contenido: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if let d = datos, d.hayDatos {
                    ImpuestosSello(d: d, aviso: aviso, trabajando: trabajandoConAsesoria,
                                   notaExcel: notaExcel,
                                   descargarExcel: {
                                       guard let url = d.excelIVA else { return }
                                       notaExcel = nil
                                       viaje.descargar(url, trimestre: d.trimestre, con: abrirURL)
                                   },
                                   preguntarGestoria: { preguntando = true },
                                   verDetalle: { Task { await verUltimaComprobacion() } },
                                   marcar: { c in Task { await marcar(c) } },
                                   recargar: { await cargar(d.trimestre) },
                                   datos: $datos)
                } else if let error {
                    ContentUnavailableView("No se ha podido cargar",
                                           systemImage: "wifi.exclamationmark",
                                           description: Text(error))
                        .padding(.top, 60)
                } else {
                    ProgressView().frame(maxWidth: .infinity).padding(.top, 80)
                }
            }
            .padding(.horizontal, Diseno.margen)
            .padding(.bottom, Diseno.hueco3)
            .animation(Diseno.suave, value: datos)
        }
        .scrollEdgeEffectStyle(.soft, for: .top)
        .background { CampoJoya(joya: .impuestos) }
        #if MAQUETA
        .defaultScrollAnchor(Maqueta.anclaSala)
        .navigationDestination(isPresented: .constant(
            ["porque", "gastos", "ingresos", "contactos", "modelo"]
                .contains(Maqueta.subImpuestos ?? "") && datos != nil)) {
            if let d = datos {
                switch Maqueta.subImpuestos {
                case "gastos": PantallaGastos(trimestre: d.trimestre, alCambiar: {})
                case "ingresos": PantallaIngresosImpuestos(datos: $datos, marcar: { _ in },
                                                           recargar: {})
                case "contactos": PantallaContactos(alCambiar: {})
                case "modelo": PantallaModelo(datos: d, modelo: "130")
                default: PantallaPorQueImpuestos(d: d)
                }
            }
        }
        .onChange(of: datos == nil, initial: true) { _, sinDatos in
            
            guard !sinDatos, let d = datos else { return }
            if Maqueta.subImpuestos == "ajustes" { hojaAjustes = true }
            if Maqueta.subImpuestos == "ingreso" {
                ingresoAbierto = d.cobros.first(where: { $0.llegado }) ?? d.cobros.first
            }
        }
        #endif
    }

    private var menuMas: some View {
        Menu {
            Section {
                Button("Añadir gasto", systemImage: "cart.badge.plus") { nuevoGasto = true }
                Button("Añadir ingreso", systemImage: "arrow.down.to.line") { nuevoIngreso = true }
            }
            if let d = datos {
                Section {
                    if !d.comprobadoCuando.isEmpty || !d.ultimaCuando.isEmpty {
                        Button("Ver la última comprobación", systemImage: "checklist") {
                            Task { await verUltimaComprobacion() }
                        }
                    }
                    if let url = d.excelIVA, !d.abierto {
                        
                        Button("Revisar con el Excel", systemImage: "tablecells") {
                            notaExcel = nil
                            viaje.descargar(url, trimestre: d.trimestre, con: abrirURL)
                        }
                    }
                    if d.excelIVA != nil {
                        
                        Button("Subir un Excel ya bajado", systemImage: "square.and.arrow.up") {
                            notaExcel = nil
                            viaje.elegir(trimestre: d.trimestre)
                        }
                    }
                    if d.abierto {
                        Button("Comprobar con capturas", systemImage: "doc.viewfinder") {
                            eligiendoFotos = true
                        }
                    }
                }
                if d.gestoriaCoincide != nil {
                    Section {
                        Button("Cambiar lo presentado", systemImage: "pencil") { hojaGestoria = true }
                        Button("Quitar lo presentado", systemImage: "trash", role: .destructive) {
                            Task { await quitarComprobacion(d) }
                        }
                    }
                }
            }
            Section {
                Button("Clientes y proveedores", systemImage: "person.2") { contactosAbiertos = true }
                Button("Ajustes", systemImage: "slider.horizontal.3") { hojaAjustes = true }
            }
        } label: {
            Label("Más", systemImage: "ellipsis")
        }
        .disabled(datos == nil)
    }

    private var trabajandoConAsesoria: String? {
        if comprobando { return "Leyendo las capturas" }
        if viaje.subiendo { return "Revisando el Excel" }
        return nil
    }

    private func acabarExcel(_ fin: FinDelExcel) async {
        switch fin {
        case .revisado(let r):

            let otro = !r.trimestre.isEmpty && r.trimestre != (datos?.trimestre ?? "")
            await cargar(otro ? r.trimestre : (datos?.trimestre ?? ""))

            let presentado = datos?.gestoriaCoincide != nil
            notaExcel = presentado || otro ? (r.resumen, r.errores == 0)
                : r.hechoSolo.map { ($0, true) }
            if otro, let n = notaExcel {
                notaExcel = ("Era el Excel del \(DatosImpuestos.corto(r.trimestre)). " + n.texto, n.bien)
            }
            if r.errores + r.avisos > 0 { await verUltimaComprobacion() }
        case .fallo(let texto):
            notaExcel = (texto, false)
        case .sinArchivo:
            notaExcel = (FinDelExcel.sinSesion, false)
        }
        
        if let n = notaExcel { AccessibilityNotification.Announcement(n.texto).post() }
    }

    private func tramo(_ parte: Double, _ ancho: CGFloat, _ color: Color) -> some View {
        Rectangle()
            .fill(color)
            .frame(width: max(0, (ancho - 4) * parte))
            .opacity(parte > 0.001 ? 1 : 0)
    }

    @ViewBuilder
    private func accion(_ d: DatosImpuestos) -> some View {
        if d.pendienteTotal > 0.004 {
            HStack(spacing: Diseno.hueco2) {
                Image(systemName: "tray.and.arrow.down.fill")
                    .font(.title3)
                    .foregroundStyle(Diseno.azulRelleno)
                    .symbolEffect(.bounce, value: d.pendienteTotal)
                VStack(alignment: .leading, spacing: 0) {
                    Text("Aparta ahora").font(.caption).foregroundStyle(.secondary)
                    Text(Formato.euros(d.pendienteTotal))
                        .font(.system(.title3, design: .rounded).weight(.semibold))
                        .foregroundStyle(Diseno.azul)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                }
                Spacer()

                let partes = d.pendiente.keys.sorted().map {
                    "\(DatosImpuestos.corto($0)) \(Formato.euros(d.pendiente[$0] ?? 0))"
                } + (d.pendienteCuota > 0.004 ? ["cuota \(Formato.euros(d.pendienteCuota))"] : [])
                if partes.count > 1 || d.pendiente[d.trimestre] == nil {
                    Text(partes.joined(separator: " · "))
                        .font(.caption).foregroundStyle(.secondary).monospacedDigit()
                        .multilineTextAlignment(.trailing)
                }
            }
            .accessibilityElement(children: .combine)
        } else if d.sobra > 0.004 {
            Label("Puedes sacar \(Formato.euros(d.sobra))",
                  systemImage: "arrow.uturn.up.circle.fill")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Diseno.naranja)
        } else if d.apartado > 0.004 && d.porLlegar < 0.005 {
            Label("Listo para pagar", systemImage: "checkmark.seal.fill")
                .font(.headline)
                .foregroundStyle(Diseno.verde)
                .symbolEffect(.bounce, value: d.apartado)
        } else if d.yaLlegado > 0.004 {
            Label("Todo apartado", systemImage: "checkmark.circle.fill")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Diseno.verde)
        }
    }

    private func cuota(_ d: DatosImpuestos) -> some View {
        Tarjeta {
            VStack(alignment: .leading, spacing: Diseno.hueco3) {
                HStack {
                    Label("Cuota de autónomo", systemImage: "person.badge.shield.checkmark.fill")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Text("\(Formato.euros(d.cuotas.first?.cuota ?? 0)) al mes")
                        .font(.caption).foregroundStyle(.secondary).monospacedDigit()
                }
                HStack(alignment: .top, spacing: 0) {
                    ForEach(d.cuotas) { c in
                        AnilloCuota(cuota: c)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
        }
    }

    private static let filtros = [(clave: "todo", nombre: "Todo"),
                                  (clave: "plataforma1", nombre: "Plataforma 1"),
                                  (clave: "plataforma2", nombre: "Plataforma 2"),
                                  (clave: "tienda", nombre: "Pasarela")]

    private func visibles(_ d: DatosImpuestos) -> [DatosImpuestos.Cobro] {
        switch plataforma {
        case "todo": return d.cobros
        case "tienda":
            return d.cobros.filter { !["plataforma1", "plataforma2"].contains($0.plataforma) }
        default: return d.cobros.filter { $0.plataforma == plataforma }
        }
    }

    @ViewBuilder
    private func cobros(_ d: DatosImpuestos) -> some View {
        VStack(alignment: .leading, spacing: Diseno.hueco2) {
            HStack(alignment: .firstTextBaseline) {
                Text("Ingresos").font(.title3.weight(.semibold))
                Spacer()
                Text("\(Formato.euros(d.ingresos)) de ingresos")
                    .font(.caption).foregroundStyle(.secondary).monospacedDigit()
            }
            .padding(.leading, 4)
            SelectorDeslizante(opciones: Self.filtros, elegida: $plataforma)
                .accessibilityLabel("Plataforma")
            let lista = visibles(d)
            if lista.isEmpty {
                Tarjeta {
                    Vacio(icono: "calendar.badge.clock",
                          titulo: "Nada en el \(DatosImpuestos.nombre(d.trimestre))")
                }
            } else {
                Tarjeta(relleno: 0) {
                    VStack(spacing: 0) {
                        ForEach(Array(lista.enumerated()), id: \.element.id) { i, c in
                            FilaCobroImpuestos(cobro: c, primero: i == 0,
                                               ultimo: i == lista.count - 1,
                                               conApartar: d.hayApartar,
                                               marcando: marcando == c.id,
                                               alAbrir: { ingresoAbierto = c },
                                               alCompletar: { Task { await marcar(c, apartado: true) } }) {
                                Task { await marcar(c) }
                            }
                        }
                    }
                    .padding(.vertical, Diseno.hueco1)
                }
            }
        }
    }

    @ViewBuilder
    private func comprobacion(_ d: DatosImpuestos) -> some View {
        VStack(spacing: Diseno.hueco1) {
            if let coincide = d.gestoriaCoincide {
                Menu {
                    Button("Cambiar", systemImage: "pencil") { preguntando = true }
                    Button("Quitar", systemImage: "trash", role: .destructive) {
                        Task { await quitarComprobacion(d) }
                    }
                } label: {
                    Label(coincide ? "Coincide con tu gestoría" : "Apuntado lo de tu gestoría",
                          systemImage: coincide ? "checkmark.circle" : "doc.text.magnifyingglass")
                        .font(.footnote)
                        .foregroundStyle(coincide ? Diseno.verde : .secondary)
                }
            } else {
                Button("¿Coincide con tu gestoría?") { preguntando = true }
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .buttonStyle(.borderless)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 44)
        .padding(.top, Diseno.hueco2)
    }

    private func cargar(_ t: String) async {
        do {
            let ruta = t.isEmpty ? "api/impuestos" : "api/impuestos?trimestre=\(t)"
            let j = try await API.pedir(ruta, testigo: sesion.testigo)
            let nuevos = DatosImpuestos(j)
            
            if let antes = datos?.trimestre, antes != nuevos.trimestre { notaExcel = nil }
            datos = nuevos
            error = nil
            aviso = nil         
        } catch is CancellationError {
        } catch {
            if (error as NSError).code == NSURLErrorCancelled { return }
            if datos == nil { self.error = error.localizedDescription }
            else { aviso = error.localizedDescription }
        }
    }

    private func usarCuota(_ mes: String, _ euros: Double) async -> Bool {
        do {
            _ = try await API.pedir("api/impuestos/ajustes", metodo: "POST",
                                    cuerpo: ["cuota_autonomo": euros, "cuota_desde": mes],
                                    testigo: sesion.testigo)
            await cargar(datos?.trimestre ?? "")
            return true
        } catch {
            aviso = error.localizedDescription
            return false
        }
    }

    private func marcarCuota(_ mes: String) async {
        marcandoCuota = mes
        defer { marcandoCuota = nil }
        do {
            _ = try await API.pedir("api/impuestos/cuota", metodo: "POST",
                                    cuerpo: ["mes": mes, "subida": true], testigo: sesion.testigo)
            await cargar(datos?.trimestre ?? "")
        } catch {
            aviso = error.localizedDescription
        }
    }

    private func comprobar(_ items: [PhotosPickerItem]) async {
        comprobando = true
        defer {
            comprobando = false
            fotos = []
        }
        var capturas: [[String: any Sendable]] = []
        for it in items {
            guard let datosImagen = try? await it.loadTransferable(type: Data.self) else { continue }
            let lineas = await LectorCapturas.leer(datosImagen)
            capturas.append(["filas": lineas.map(\.comoDiccionario)])
        }
        guard !capturas.isEmpty else {
            aviso = "No se han podido abrir las capturas."
            return
        }
        do {
            let j = try await API.pedir("api/impuestos/comprobar", metodo: "POST",
                                        cuerpo: ["trimestre": datos?.trimestre ?? "",
                                                 "capturas": capturas],
                                        testigo: sesion.testigo)
            resultado = ResultadoComprobacion(j)
            await cargar(datos?.trimestre ?? "")
        } catch {
            aviso = error.localizedDescription
        }
    }

    private func verUltimaComprobacion() async {
        guard let t = datos?.trimestre else { return }
        do {
            let j = try await API.pedir("api/impuestos/comprobacion?trimestre=\(t)",
                                        testigo: sesion.testigo)
            if let r = j["resultado"] as? [String: Any] {
                resultado = ResultadoComprobacion(r)
            } else {
                aviso = "No hay ninguna comprobación guardada de este trimestre."
            }
        } catch is CancellationError {
        } catch {
            aviso = error.localizedDescription
        }
    }

    private func marcar(_ c: DatosImpuestos.Cobro, apartado: Bool? = nil) async {
        marcando = c.id
        defer { marcando = nil }
        do {
            _ = try await API.pedir("api/impuestos/apartar", metodo: "POST",
                                    cuerpo: ["id": c.id, "apartado": apartado ?? !c.apartado],
                                    testigo: sesion.testigo)
            aviso = nil
            await cargar(datos?.trimestre ?? "")
        } catch {
            aviso = error.localizedDescription
        }
    }

    private func coincide(_ d: DatosImpuestos) async {
        do {
            _ = try await API.pedir("api/impuestos/gestoria", metodo: "POST",
                                    cuerpo: ["trimestre": d.trimestre, "coincide": true],
                                    testigo: sesion.testigo)
            await cargar(d.trimestre)
        } catch {
            aviso = error.localizedDescription
        }
    }

    private func quitarComprobacion(_ d: DatosImpuestos) async {
        do {
            _ = try await API.pedir("api/impuestos/gestoria", metodo: "POST",
                                    cuerpo: ["trimestre": d.trimestre, "borrar": true],
                                    testigo: sesion.testigo)
            await cargar(d.trimestre)
        } catch {
            aviso = error.localizedDescription
        }
    }
}

struct AnilloCuota: View {
    let cuota: DatosImpuestos.Cuota

    var enTinta = false
    @Environment(\.accessibilityReduceMotion) private var sinMovimiento
    @Environment(\.colorScheme) private var modo
    @Environment(\.tema) private var tema

    private var total: Double { max(cuota.cuota, 0.01) }
    private var pagada: Bool { cuota.estado == "pagada" }
    private var futura: Bool { cuota.estado == "futura" }
    private var porApartar: Double { max(0, cuota.cubierto - cuota.apartado) }
    private var apartada: Bool { !pagada && cuota.apartado >= cuota.cuota - 0.005 }
    private var sinCubrir: Bool { cuota.estado == "en_curso" && cuota.falta > 0.005 }

    private var finVerde: Double { pagada ? 1 : min(1, cuota.apartado / total) }
    private var finAzul: Double { pagada ? 1 : min(1, cuota.cubierto / total) }
    private var finGris: Double { pagada ? 1 : min(1, (cuota.cubierto + cuota.porLlegar) / total) }

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                if enTinta && modo == .light {

                    Circle().stroke(.black.opacity(0.6), lineWidth: 7.5)
                    Circle().stroke(tema.colorDeFondo, lineWidth: 6)
                }

                Circle().stroke(Color.secondary.opacity(enTinta && modo == .dark ? 0.32 : 0.14), lineWidth: 6)
                arco(finGris, Color.secondary.opacity(0.35))
                arco(finAzul, Diseno.azulRelleno)
                arco(finVerde, Diseno.verdeRelleno)
                Image(systemName: icono)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(colorIcono)
                    .contentTransition(.symbolEffect(.replace))
            }
            .frame(width: 44, height: 44)
            .opacity(futura ? (enTinta ? 0.7 : 0.5) : 1)

            Text(DatosImpuestos.mes(cuota.mes).prefix(3).capitalized)
                .font(.caption.weight(enTinta && cuota.estado == "en_curso" ? .bold : .medium))
                .foregroundStyle(enTinta && futura ? Marcador.apoyo : Color.primary)
            Text(estado)
                .font(.caption2)
                .foregroundStyle(enTinta ? (futura ? Marcador.apoyo : Color.primary) : colorEstado)
                .monospacedDigit()
                .multilineTextAlignment(.center)
                .contentTransition(.numericText())
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Cuota de \(DatosImpuestos.mes(cuota.mes)): \(estadoLargo)")
    }

    private func arco(_ fin: Double, _ color: Color) -> some View {
        Circle()
            .trim(from: 0, to: fin)
            .stroke(color, style: StrokeStyle(lineWidth: 6, lineCap: .round))
            .rotationEffect(.degrees(-90))
            .opacity(fin > 0.001 ? 1 : 0)
            .animation(sinMovimiento ? nil : .smooth(duration: 0.6), value: fin)
    }

    private var dia: String { cuota.cobro.count == 10 ? String(Int(cuota.cobro.suffix(2)) ?? 0) : "" }

    private var icono: String {
        if pagada || apartada { return "checkmark" }
        return sinCubrir ? "exclamationmark" : "eurosign"
    }

    private var colorIcono: Color {
        if pagada || apartada { return Diseno.verde }
        return sinCubrir ? Diseno.naranja : .secondary
    }

    private var estado: String {
        if pagada { return "pagada" }
        if enTinta {

            if sinCubrir { return "faltan \(Formato.euros(cuota.falta))" }
            return "se cobra el \(dia)"
        }
        if futura { return "se cobra el \(dia)" }
        if apartada { return "apartada" }
        if sinCubrir { return "faltan \(Formato.euros(cuota.falta))" }
        if porApartar > 0.004 {
            return enTinta ? "\(Formato.euros(porApartar)) por apartar" : "aparta \(Formato.euros(porApartar))"
        }
        return "\(Formato.euros(cuota.porLlegar)) por llegar"
    }

    private var colorEstado: Color {
        if pagada || apartada { return Diseno.verde }
        if sinCubrir { return Diseno.naranja }
        return porApartar > 0.004 && !futura ? Diseno.azul : .secondary
    }

    private var estadoLargo: String {
        if pagada { return "pagada el \(Formato.diaCorto(cuota.cobro))" }
        if futura { return "se cobra el \(Formato.diaCorto(cuota.cobro))" }
        if apartada { return "apartada entera" }
        var partes: [String] = []
        if cuota.apartado > 0.004 { partes.append("\(Formato.euros(cuota.apartado)) apartados") }
        if porApartar > 0.004 { partes.append("\(Formato.euros(porApartar)) por apartar") }
        if cuota.porLlegar > 0.004 { partes.append("\(Formato.euros(cuota.porLlegar)) por llegar") }
        if sinCubrir { partes.append("\(Formato.euros(cuota.falta)) sin ningún cobro que los cubra") }
        return partes.joined(separator: ", ")
    }
}

private struct FilaCobroImpuestos: View {
    let cobro: DatosImpuestos.Cobro
    let primero: Bool
    let ultimo: Bool
    let conApartar: Bool
    let marcando: Bool
    let alAbrir: () -> Void
    var alCompletar: () -> Void = {}
    let alMarcar: () -> Void

    private var color: Color { Diseno.colorDePlataforma(cobro.plataforma) }

    private var nombre: String {
        
        ["plataforma1", "plataforma2"].contains(cobro.plataforma)
            ? Diseno.nombreDePlataforma(cobro.plataforma)
            : (cobro.clienteNombre.isEmpty ? "Pasarela" : cobro.clienteNombre)
    }

    private var fiscal: String {
        if cobro.iva > 0 {
            return "\(Formato.euros(cobro.ingreso)) + \(Formato.euros(cobro.iva)) de IVA"
                + (cobro.ivaModo == "encima" ? " encima" : "")
        }
        if cobro.plataforma == "plataforma1", cobro.usd > 0, cobro.cambio > 0 {
            let bce = String(format: "%.4f", cobro.cambio).replacingOccurrences(of: ".", with: ",")
            return "\(CuentaIVA.dolares(cobro.usd)) ÷ \(bce) BCE = \(Formato.euros(cobro.ingreso))"
        }
        return "\(Formato.euros(cobro.ingreso)) de ingreso"
    }

    var body: some View {
        HStack(alignment: .top, spacing: Diseno.hueco2) {
            VStack(spacing: 0) {
                Rectangle().fill(primero ? Color.clear : Color.secondary.opacity(0.25))
                    .frame(width: 2, height: 16)
                Circle()
                    .fill(cobro.llegado ? color : Color.clear)
                    .overlay(Circle().strokeBorder(color, lineWidth: cobro.llegado ? 0 : 2))
                    .frame(width: 12, height: 12)
                Rectangle().fill(ultimo ? Color.clear : Color.secondary.opacity(0.25))
                    .frame(width: 2)
                    .frame(maxHeight: .infinity)
            }
            .frame(width: 12)

            VStack(alignment: .leading, spacing: 4) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(nombre).font(.subheadline.weight(.semibold))
                        Spacer()
                        Text((cobro.estimado && !cobro.llegado ? "≈ " : "")
                             + Formato.euros(cobro.euros))
                            .font(.subheadline.weight(.semibold))
                            .monospacedDigit()
                            .foregroundStyle(cobro.llegado ? .primary : .secondary)
                        Image(systemName: "chevron.right")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.tertiary)
                    }
                    HStack(spacing: 5) {
                        Image(systemName: cobro.llegado ? "checkmark" : "clock")
                            .font(.caption2.weight(.semibold))
                        Text("\(Formato.diaCorto(cobro.fecha)) · \(cobro.etiqueta)")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    Text(fiscal)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    if cobro.llegado { factura }
                }
                .contentShape(.rect)
                .onTapGesture(perform: alAbrir)
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(.isButton)
                .accessibilityHint("Abre el ingreso")
                .accessibilityAction(.default) { alAbrir() }
                pie
            }
            .padding(.vertical, Diseno.hueco2)
        }
        .padding(.horizontal, Diseno.hueco3)
    }

    @ViewBuilder
    private var factura: some View {
        if !cobro.facturaNumero.isEmpty {
            HStack(spacing: 6) {
                Label(cobro.facturaNumero, systemImage: "doc.text.fill")
                    .foregroundStyle(Diseno.verde)
                if cobro.facturaPorCambiar {
                    
                    Text("· cambio de otro día").foregroundStyle(Diseno.naranja)
                }
            }
            .font(.caption.weight(.medium))
        } else {
            Label("Para tu factura: \(Formato.euros(cobro.paraFactura))",
                  systemImage: "doc.badge.plus")
                .font(.caption.weight(.medium))
                .foregroundStyle(Diseno.azul)
                .monospacedDigit()
        }
    }

    @ViewBuilder
    private var pie: some View {
        if conApartar, cobro.llegado, let x = cobro.apartar {
            VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center, spacing: Diseno.hueco2) {
                if x > 0.004 {
                    VStack(alignment: .leading, spacing: 1) {
                        Label {
                            Text(Formato.euros(x)).font(.headline).monospacedDigit()
                        } icon: {
                            Image(systemName: cobro.apartado ? "checkmark.circle.fill"
                                                             : "tray.and.arrow.down.fill")
                        }
                        .foregroundStyle(cobro.apartado ? Diseno.verde : Diseno.azul)
                        
                        Text(desglose)
                            .font(.caption2).foregroundStyle(.secondary).monospacedDigit()
                    }
                    .accessibilityElement(children: .combine)
                    Spacer()
                    Button(action: alMarcar) {
                        Group {
                            if marcando {
                                ProgressView().controlSize(.small)
                            } else {
                                Image(systemName: cobro.apartado ? "checkmark.circle.fill"
                                                                 : "circle")
                                    .font(.system(size: 28))
                                    .foregroundStyle(cobro.apartado ? Diseno.verdeRelleno
                                                                    : Color.secondary)
                                    .contentTransition(.symbolEffect(.replace))
                            }
                        }
                        .frame(width: 44, height: 44)
                        .contentShape(.rect)
                    }
                    .buttonStyle(.borderless)
                    .disabled(marcando)
                    
                    .sensoryFeedback(.success, trigger: cobro.apartado) { _, ahora in ahora }
                    .accessibilityLabel(cobro.apartado ? "Apartado. Toca para desmarcar"
                                                       : "Marcar como apartado")
                } else {
                    Label("nada que apartar", systemImage: "minus.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            }
            if cobro.apartado && cobro.faltaMas > 0.004 {
                FaltaMas(euros: cobro.faltaMas, motivo: "Hacienda pide más de este trimestre",
                         trabajando: marcando, accion: alCompletar)
            }
            }
        }
    }

    private var desglose: String {
        var partes: [String] = []
        if let h = cobro.hacienda, h > 0.004 { partes.append("Hacienda \(Formato.euros(h))") }
        
        if let c = cobro.cuota, c > 0.004, !cobro.cuotaPagada {
            partes.append("cuota \(Formato.euros(c))")
        }
        return partes.joined(separator: " · ")
    }
}

struct PantallaModelo: View {
    let datos: DatosImpuestos
    let modelo: String

    var body: some View {
        List {
            switch modelo {
            case "130": m130
            case "303": m303
            default: m349
            }
        }
        .listStyle(.insetGrouped)
        .listaConTema()
        .navigationTitle("Modelo \(modelo)")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func linea(_ t: String, _ v: Double?, fuerte: Bool = false,
                       signo: String = "") -> some View {
        HStack {
            Text(t).foregroundStyle(fuerte ? .primary : .secondary)
            Spacer()
            
            Text((((v ?? 0) == 0 ? "" : signo.trimmingCharacters(in: .whitespaces))) + Formato.euros(v ?? 0))
                .monospacedDigit()
                .fontWeight(fuerte ? .semibold : .regular)
        }
    }

    @ViewBuilder
    private var m130: some View {
        let m = datos.m130
        Section {
            linea("Ingresos", m["ingresos"])
            linea("Gastos", m["gastos"], signo: "− ")
            if (m["dificil_justificacion"] ?? 0) > 0 {
                linea("  de ellos, difícil justificación", m["dificil_justificacion"])
            }
            linea("Rendimiento neto", m["rendimiento"], fuerte: true)
        } header: {
            Text("Desde el 1 de enero")
        }

        Section {
            linea("Cuota 20 %", m["cuota"])
            linea("Retenciones y pagos previos", m["pagado_antes"], signo: "− ")
            linea("Deducciones", m["deduccion"], signo: "− ")
            if (m["negativos_antes"] ?? 0) > 0 {
                linea("Negativos anteriores", m["negativos_antes"], signo: "− ")
            }
            linea("Resultado", m["resultado"], fuerte: true)
        }
        if let g = datos.gestoria130 { gestoria(g, app: datos.gestoriaApp130) }
    }

    @ViewBuilder
    private var m303: some View {
        let m = datos.m303
        Section {
            linea("Base (Pasarela)", m["base"])
            linea("IVA repercutido", m["devengado"])
            linea("IVA soportado", m["deducible"], signo: "− ")
            linea("Compensaciones", m["compensado"], signo: "− ")
            linea("Resultado", m["resultado"], fuerte: true)
            if (m["a_compensar"] ?? 0) > 0 { linea("Queda a compensar", m["a_compensar"]) }
            if (m["a_devolver"] ?? 0) > 0 { linea("A devolver", m["a_devolver"]) }
        }
        if let g = datos.gestoria303 { gestoria(g, app: datos.gestoriaApp303) }
    }

    private var m349: some View {
        Section {
            linea("Plataforma 2 (UE)", datos.ue, fuerte: true)
        } footer: {
            Text("Informativo: no se paga.")
        }
    }

    private func gestoria(_ g: Double, app: Double?) -> some View {
        Section("Tu gestoría") {
            linea("Dijo", g, fuerte: true)
            if let app, abs(app - g) >= 0.01 {
                linea("La app decía", app)
            }
        }
    }
}

private struct HojaGestoria: View {
    let datos: DatosImpuestos
    let alGuardar: () async -> Void

    @Environment(Sesion.self) private var sesion
    @Environment(\.dismiss) private var cerrar
    @State private var m130 = ""
    @State private var m303 = ""
    @State private var nota = ""
    @State private var rendimiento = ""
    @State private var trabajando = false
    @State private var aviso: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    fila("Modelo 130", texto: $m130, app: datos.m130["resultado"] ?? 0)
                    fila("Modelo 303", texto: $m303, app: datos.m303["resultado"] ?? 0)
                } header: {
                    Text(DatosImpuestos.nombre(datos.trimestre, conAño: true))
                } footer: {
                    Text("Lo que pone tu gestoría. Deja vacío el que sí coincida.")
                }
                Section {
                    
                    fila("Rendimiento neto", texto: $rendimiento,
                         app: datos.m130["rendimiento"] ?? 0)
                } footer: {
                    
                    Text("Opcional. Si lo pones, los trimestres siguientes parten de esta cifra.")
                }
                Section("Nota") {
                    TextField("Opcional", text: $nota, axis: .vertical)
                        .lineLimit(1...4)
                }
                if let aviso {
                    Text(aviso).foregroundStyle(Diseno.rojo).font(.footnote)
                }
            }
            .navigationTitle("Tu gestoría")
            .navigationBarTitleDisplayMode(.inline)
            .salidaDelTeclado()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { cerrar() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button { Task { await guardar() } } label: {
                        MarcaConfirmar(trabajando: trabajando)
                    }
                    .disabled(trabajando || (m130.isEmpty && m303.isEmpty))
                }
            }
            .onAppear {
                if let g = datos.gestoria130 { m130 = Formato.ajuste(g) }
                if let g = datos.gestoria303 { m303 = Formato.ajuste(g) }
            }
        }
    }

    private func fila(_ titulo: String, texto: Binding<String>, app: Double) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(titulo)
                Spacer()
                TextField("0,00", text: texto)
                    .keyboardType(.numbersAndPunctuation)
                    .multilineTextAlignment(.trailing)
                    .monospacedDigit()
                Text("€").foregroundStyle(.secondary)
            }
            Text("La app: \(Formato.euros(app))")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private func guardar() async {
        trabajando = true
        defer { trabajando = false }
        do {
            _ = try await API.pedir("api/impuestos/gestoria", metodo: "POST",
                                    cuerpo: ["trimestre": datos.trimestre, "coincide": false,
                                             "m130": m130, "m303": m303, "nota": nota,
                                             "rendimiento": rendimiento],
                                    testigo: sesion.testigo)
            await alGuardar()
            cerrar()
        } catch {
            aviso = error.localizedDescription
        }
    }
}

private struct HojaAjustesImpuestos: View {
    let ajustes: [String: Any]

    let info: DatosImpuestos.InfoCuota
    let alGuardar: () async -> Void

    @Environment(Sesion.self) private var sesion
    @Environment(\.dismiss) private var cerrar
    @State private var cuota = ""
    @State private var cuotaAntes = ""
    @State private var cuotaDesde = ""
    @State private var usarCalculada = false
    @State private var desde = ""
    @State private var dificil = ""
    @State private var deduccion = 0
    @State private var compensar = ""
    @State private var comisiones = false
    @State private var trabajando = false
    @State private var aviso: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    campo("Cuota al mes", $cuota, "€")
                    if cuotaCambiada {
                        Picker("Desde", selection: $cuotaDesde) {
                            ForEach(mesesDeCuota, id: \.self) { m in
                                Text(CobrosHucha.nombreDelMes(m, conAño: true)).tag(m)
                            }
                        }
                    }
                    if info.origen == "a_mano", let c = info.calculada, !usarCalculada {
                        Button("Usar la calculada · \(Formato.euros(c.euros))") {
                            usarCalculada = true
                            cuota = Formato.ajuste(c.euros)
                            cuotaAntes = cuota
                        }
                    }
                    HStack {
                        Text("De alta desde")
                        Spacer()
                        TextField("AAAA-MM", text: $desde)
                            .keyboardType(.numbersAndPunctuation)
                            .multilineTextAlignment(.trailing)
                            .monospacedDigit()
                    }
                } header: {
                    Text("Autónomo")
                } footer: {

                    if !pieCuota.isEmpty { Text(pieCuota) }
                }
                Section {
                    campo("Difícil justificación", $dificil, "%")
                    Toggle("Comisiones de Plataforma 1 y Monedero", isOn: $comisiones)
                } header: {
                    Text("Gastos automáticos")
                }
                Section {
                    Picker("Deducción del 130 en \(anioAlta)", selection: $deduccion) {
                        ForEach([100, 75, 50, 25, 0], id: \.self) { v in
                            Text(v == 0 ? "Ninguna" : "\(v) € al trimestre").tag(v)
                        }
                    }
                    campo("IVA a compensar de antes", $compensar, "€")
                } footer: {
                    Text("La de \(anioAlta) sale del «Deducciones» del 130 de tu gestoría. Desde \(anioAlta + 1) la calcula la app con lo ganado el año anterior.")
                }
                if let aviso {
                    Text(aviso).foregroundStyle(Diseno.rojo).font(.footnote)
                }
            }
            .navigationTitle("Ajustes de impuestos")
            .navigationBarTitleDisplayMode(.inline)
            .salidaDelTeclado()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { cerrar() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button { Task { await guardar() } } label: {
                        MarcaConfirmar(trabajando: trabajando)
                    }
                    .disabled(trabajando)
                }
            }
            .onAppear {
                cuota = Formato.ajuste(info.euros)
                cuotaAntes = cuota
                cuotaDesde = info.mes
                desde = ajustes["autonomo_desde"] as? String ?? ""
                dificil = Formato.ajuste(ajustes["dificil_justificacion_pct"])
                deduccion = Int((ajustes["deduccion_trimestral"] as? NSNumber)?.doubleValue ?? 0)
                compensar = Formato.ajuste(ajustes["iva_a_compensar_inicial"])
                comisiones = ajustes["comisiones_como_gasto"] as? Bool ?? false
            }
        }
    }

    private var anioAlta: Int {
        Int((ajustes["autonomo_desde"] as? String ?? "").prefix(4)) ?? 2026
    }

    private var cuotaCambiada: Bool {
        !usarCalculada && cuota.trimmingCharacters(in: .whitespaces) != cuotaAntes
    }

    private var mesesDeCuota: [String] {
        guard info.mes.count == 7, let a = Int(info.mes.prefix(4)),
              let m = Int(info.mes.suffix(2)) else { return [info.mes] }
        let alta = ajustes["autonomo_desde"] as? String ?? ""
        var lista: [String] = []
        for k in 1...(m + 1) {
            let mes = k == 13 ? "\(a + 1)-01" : String(format: "%04d-%02d", a, k)
            if mes >= alta { lista.append(mes) }
        }
        return lista.isEmpty ? [info.mes] : lista
    }

    private var pieCuota: String {
        let mes = { (m: String) in CobrosHucha.nombreDelMes(m, conAño: true) }
        var partes: [String] = []
        if cuotaCambiada {
            partes.append("Vale desde \(mes(cuotaDesde)) hasta diciembre.")
        } else if usarCalculada, let c = info.calculada {
            partes.append("Todo \(String(c.anio)) con la calculada.")
        } else {
            switch info.origen {
            case "tarifa_plana":
                partes.append("Tarifa plana hasta \(mes(info.tarifaPlanaHasta)).")
            case "calculada":
                if let c = info.calculada {
                    partes.append("Calculada con lo que ganaste en \(String(c.anio - 1)) (\(Formato.euros(c.rendimiento)) al mes de rendimiento): \(c.nombre).")
                }
            default:
                if !info.desde.isEmpty {
                    var t = "La tuya desde \(mes(info.desde))."
                    if let c = info.calculada { t += " La calculada es \(Formato.euros(c.euros))." }
                    partes.append(t)
                }
            }
        }
        if let r = info.ritmo {
            partes.append(r.euros > info.euros
                ? "Con lo que llevas de \(String(r.anio)) te toca el \(r.nombre) (\(Formato.euros(r.euros))): si sigue así, al regularizar te pedirán unos \(Formato.euros(r.diferencia))."
                : "Con lo que llevas de \(String(r.anio)) te toca el \(r.nombre) (\(Formato.euros(r.euros))).")
        }
        if let s = info.siguiente {
            partes.append("En \(String(s.anio)), unos \(Formato.euros(s.euros)) al mes (\(s.nombre)), con lo que llevas de \(String(s.anio - 1)).")
        }
        if let t = [info.calculada, info.siguiente].compactMap({ $0 }).first(where: { $0.tablaVieja }) {
            partes.append("Con la tabla de \(String(t.anioTabla)): la de \(String(t.anio)) aún no ha salido.")
        }
        return partes.joined(separator: " ")
    }

    private func campo(_ titulo: String, _ texto: Binding<String>, _ unidad: String) -> some View {
        HStack {
            Text(titulo)
            Spacer()
            TextField("0", text: texto)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .monospacedDigit()
                .frame(maxWidth: 110)
            Text(unidad).foregroundStyle(.secondary)
        }
    }

    private func guardar() async {
        trabajando = true
        defer { trabajando = false }
        do {
            var cuerpo: [String: any Sendable] = ["autonomo_desde": desde,
                                                  "dificil_justificacion_pct": dificil,
                                                  "deduccion_trimestral": deduccion,
                                                  "iva_a_compensar_inicial": compensar,
                                                  "comisiones_como_gasto": comisiones]

            if usarCalculada {
                cuerpo["usar_calculada"] = true
            } else if cuotaCambiada {
                cuerpo["cuota_autonomo"] = cuota
                cuerpo["cuota_desde"] = cuotaDesde
            }
            _ = try await API.pedir("api/impuestos/ajustes", metodo: "POST", cuerpo: cuerpo,
                                    testigo: sesion.testigo)
            await alGuardar()
            cerrar()
        } catch {
            aviso = error.localizedDescription
        }
    }
}
