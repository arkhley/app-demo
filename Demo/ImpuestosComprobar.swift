import SwiftUI

struct ResultadoComprobacion: Identifiable {
    struct Punto: Identifiable {
        let id = UUID()
        let tipo: String            
        let titulo: String
        let detalle: String
        
        let poner: Double?
        
        let cuota: String?

        let cuotaRealMes: String?
        let cuotaRealEuros: Double?
    }

    struct Linea: Identifiable {
        let id = UUID()
        let texto: String
        let euros: Double
    }

    struct Modelo: Identifiable {
        var id: String { modelo }
        let modelo: String
        let suyo: Double
        let app: Double
        let explicado: [Linea]
        let sinExplicar: Double
    }

    let id = UUID()
    let veredicto: String           
    let trimestre: String
    let errores: Int
    let avisos: Int

    let completa: Bool
    let puntos: [Punto]
    let modelos: [Modelo]
    let facturas: Int
    let gastos: Int
    let capturas: Int
    let mensaje: String

    init(_ j: [String: Any]) {
        func n(_ v: Any?) -> Double { (v as? NSNumber)?.doubleValue ?? 0 }
        veredicto = j["veredicto"] as? String ?? "ilegible"
        trimestre = j["trimestre"] as? String ?? ""
        errores = (j["errores"] as? NSNumber)?.intValue ?? 0
        avisos = (j["avisos"] as? NSNumber)?.intValue ?? 0
        completa = j["completa"] as? Bool ?? false
        mensaje = j["mensaje"] as? String ?? ""
        puntos = ((j["puntos"] as? [[String: Any]]) ?? []).map { p in
            Punto(tipo: p["tipo"] as? String ?? "aviso",
                  titulo: p["titulo"] as? String ?? "",
                  detalle: p["detalle"] as? String ?? "",
                  poner: (p["poner"] as? NSNumber)?.doubleValue,
                  cuota: p["cuota"] as? String,
                  cuotaRealMes: (p["cuota_real"] as? [String: Any])?["mes"] as? String,
                  cuotaRealEuros: ((p["cuota_real"] as? [String: Any])?["euros"] as? NSNumber)?
                      .doubleValue)
        }
        modelos = ((j["modelos"] as? [[String: Any]]) ?? []).map { m in
            Modelo(modelo: m["modelo"] as? String ?? "",
                   suyo: n(m["suyo"]), app: n(m["app"]),
                   explicado: ((m["explicado"] as? [[String: Any]]) ?? []).map {
                       Linea(texto: $0["texto"] as? String ?? "", euros: n($0["euros"]))
                   },
                   sinExplicar: n(m["sin_explicar"]))
        }
        let l = j["leidas"] as? [String: Any] ?? [:]
        facturas = (l["facturas"] as? NSNumber)?.intValue ?? 0
        gastos = (l["gastos"] as? NSNumber)?.intValue ?? 0
        capturas = (l["capturas"] as? NSNumber)?.intValue ?? 0
    }
}

struct HojaComprobacion: View {
    let resultado: ResultadoComprobacion
    let marcarCuota: (String) async -> Void
    
    let usarCuota: (String, Double) async -> Bool

    @Environment(\.dismiss) private var cerrar
    @State private var visto = false
    @State private var cuotasMarcadas: Set<String> = []
    @State private var cuotasPuestas: Set<String> = []
    @ScaledMetric(relativeTo: .largeTitle) private var tamSello: CGFloat = 52

    private var errores: [ResultadoComprobacion.Punto] { resultado.puntos.filter { $0.tipo == "error" } }
    private var avisos: [ResultadoComprobacion.Punto] { resultado.puntos.filter { $0.tipo == "aviso" } }
    private var bien: [ResultadoComprobacion.Punto] { resultado.puntos.filter { $0.tipo == "bien" } }
    private var aprobado: Bool { resultado.veredicto == "bien" && resultado.avisos == 0 }

    var body: some View {
        NavigationStack {
            List {
                veredicto
                if resultado.veredicto == "ilegible" {
                    Section {
                        Text(resultado.mensaje.isEmpty ? "No he podido leer nada de la gestoría." : resultado.mensaje)
                    } footer: {
                        Text("Sirven las listas de Ingresos y de Gastos, el Desglose de Impuestos y el Resumen de un gasto, enteras y sin recortar.")
                    }
                }
                if !errores.isEmpty {
                    Section("Cambia en la gestoría") {
                        ForEach(errores) { p in fila(p) }
                    }
                }
                if !avisos.isEmpty {
                    Section("Revisa") {
                        ForEach(avisos) { p in fila(p) }
                    }
                }
                ForEach(resultado.modelos) { m in modelo(m) }
                if !bien.isEmpty {
                    Section {

                        if errores.isEmpty && avisos.isEmpty {
                            ForEach(bien) { p in filaBien(p) }
                        } else {
                            DisclosureGroup {
                                ForEach(bien) { p in filaBien(p) }
                            } label: {
                                Label("\(bien.count) \(bien.count == 1 ? "cosa cuadra" : "cosas cuadran")",
                                      systemImage: "checkmark.circle")
                                    .foregroundStyle(Diseno.verde)
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Comprobación")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(role: .close) { cerrar() }
                }
            }
            .onAppear { visto = true }
        }
    }

    private var veredicto: some View {
        Section {
            VStack(spacing: Diseno.hueco2) {
                Image(systemName: aprobado ? "checkmark.seal.fill"
                                           : resultado.veredicto == "ilegible"
                                               ? "questionmark.circle.fill"
                                               : "exclamationmark.triangle.fill")
                    .font(.system(size: tamSello, weight: .semibold))
                    .foregroundStyle(aprobado ? Diseno.verdeRelleno : Diseno.naranjaRelleno)
                    .symbolEffect(.bounce, value: visto)
                    .accessibilityHidden(true)
                Text(titular)
                    .font(.title2.weight(.bold))
                    .multilineTextAlignment(.center)
                if resultado.capturas > 0 {
                    Text(leido)
                        .font(.caption).foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Diseno.hueco2)
            .accessibilityElement(children: .combine)
        }
        .listRowBackground(Color.clear)
        .sensoryFeedback(aprobado ? .success : .warning, trigger: visto)
    }

    private var titular: String {
        switch resultado.veredicto {
        case "ilegible": return "No se ha podido leer"
        default:
            if resultado.errores > 0 {
                return resultado.errores == 1 ? "Cambia 1 cosa antes de presentar"
                                              : "Cambia \(resultado.errores) cosas antes de presentar"
            }
            if resultado.avisos > 0 {
                return resultado.avisos == 1 ? "Revisa 1 cosa" : "Revisa \(resultado.avisos) cosas"
            }
            
            return resultado.completa ? "Listo para presentar" : "Cuadra"
        }
    }

    private var leido: String {
        var partes: [String] = []
        if resultado.facturas > 0 {
            partes.append(resultado.facturas == 1 ? "1 factura" : "\(resultado.facturas) facturas")
        }
        if resultado.gastos > 0 {
            partes.append(resultado.gastos == 1 ? "1 gasto" : "\(resultado.gastos) gastos")
        }
        let de = "\(DatosImpuestos.nombre(resultado.trimestre, conAño: true))"
        return (partes.isEmpty ? "" : partes.joined(separator: " y ") + " · ") + de
    }

    private func filaBien(_ p: ResultadoComprobacion.Punto) -> some View {
        Label {
            VStack(alignment: .leading, spacing: 1) {
                Text(p.titulo).font(.subheadline)
                Text(p.detalle).font(.caption).foregroundStyle(.secondary)
            }
        } icon: {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Diseno.verde)
        }
    }

    @ViewBuilder
    private func fila(_ p: ResultadoComprobacion.Punto) -> some View {
        VStack(alignment: .leading, spacing: Diseno.hueco1) {
            Label {
                Text(p.titulo).font(.subheadline.weight(.semibold))
            } icon: {
                Image(systemName: p.tipo == "error" ? "xmark.circle.fill" : "exclamationmark.circle.fill")
                    .foregroundStyle(p.tipo == "error" ? Diseno.rojo : Diseno.naranja)
            }
            Text(p.detalle).font(.caption).foregroundStyle(.secondary)
            if let v = p.poner {
                HStack {
                    Text(Formato.euros(v))
                        .font(.system(.title3, design: .rounded).weight(.semibold))
                        .foregroundStyle(Diseno.azul)
                        .monospacedDigit()
                    Spacer()
                    BotonCopiar(valor: v)
                }
            }
            if let mes = p.cuota {
                let hecha = cuotasMarcadas.contains(mes)
                Button {
                    Task {
                        await marcarCuota(mes)
                        withAnimation(Diseno.suave) { _ = cuotasMarcadas.insert(mes) }
                    }
                } label: {
                    Label(hecha ? "Marcada como subida" : "Ya la he subido",
                          systemImage: hecha ? "checkmark" : "arrow.up.doc")
                        .contentTransition(.symbolEffect(.replace))
                }
                .buttonStyle(.glass)
                .disabled(hecha)
                .sensoryFeedback(.success, trigger: hecha)
            }
            if let mes = p.cuotaRealMes, let euros = p.cuotaRealEuros {
                let puesta = cuotasPuestas.contains(mes)
                Button {
                    Task {
                        if await usarCuota(mes, euros) {
                            withAnimation(Diseno.suave) { _ = cuotasPuestas.insert(mes) }
                        }
                    }
                } label: {
                    Label(puesta ? "Puesta en la app" : "Poner \(Formato.euros(euros)) en la app",
                          systemImage: puesta ? "checkmark" : "square.and.arrow.down")
                        .contentTransition(.symbolEffect(.replace))
                }
                .buttonStyle(.glass)
                .disabled(puesta)
                .sensoryFeedback(.success, trigger: puesta)
            }
        }
        .padding(.vertical, 2)
    }

    private func modelo(_ m: ResultadoComprobacion.Modelo) -> some View {
        Section {
            HStack {
                Text("Gestoría").foregroundStyle(.secondary)
                Spacer()
                Text(Formato.euros(m.suyo)).monospacedDigit()
            }
            HStack {
                Text("La app").fontWeight(.semibold)
                Spacer()
                Text(Formato.euros(m.app)).monospacedDigit().fontWeight(.semibold)
            }
            ForEach(m.explicado) { l in
                HStack(alignment: .firstTextBaseline) {
                    Text(l.texto).font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Text((l.euros >= 0 ? "+" : "") + Formato.euros(l.euros))
                        .font(.caption).monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            Text(m.modelo == "303" ? "IVA (303)" : "Modelo \(m.modelo)")
        } footer: {
            if abs(m.app - m.suyo) < 0.005 {
                Text("Coinciden.")
            } else if abs(m.sinExplicar) < 0.005 && !m.explicado.isEmpty {
                
                Text("Con los cambios de arriba, Gestoría dirá \(Formato.euros(m.app)).")
            } else if abs(m.sinExplicar) >= 0.005 {
                Text("Quedan \(Formato.euros(m.sinExplicar)) sin explicar.")
            }
        }
    }
}
