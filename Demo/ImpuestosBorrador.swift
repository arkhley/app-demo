import SwiftUI

struct BorradorAsesoria: Equatable {
    
    let cuando: String
    let euros: Double
    let fecha: String
    
    let dudoso: Bool

    let anteriorEuros: Double?
    let anteriorFecha: String

    init?(_ j: Any?) {
        guard let j = j as? [String: Any], let cuando = j["cuando"] as? String else { return nil }
        self.cuando = cuando
        euros = (j["euros"] as? NSNumber)?.doubleValue ?? 0
        fecha = j["fecha"] as? String ?? ""
        dudoso = j["dudoso"] as? Bool ?? false
        let anterior = j["anterior"] as? [String: Any]
        anteriorEuros = (anterior?["euros"] as? NSNumber)?.doubleValue
        anteriorFecha = anterior?["fecha"] as? String ?? ""
    }
}

struct SeccionBorradorAsesoria: View {
    let cobro: DatosImpuestos.Cobro
    
    let alCrear: () async -> Void

    @Environment(Sesion.self) private var sesion
    @State private var hecho: BorradorAsesoria?
    @State private var vista: Vista?
    @State private var creando = false
    @State private var preguntando = false

    @State private var pidiendo: Pedir = .nuevo
    @State private var fallo: String?

    enum Pedir { case nuevo, otraVez, rehacer, borrado }

    struct Vista: Equatable {
        let listo: Bool
        let motivo: String
        let falta: [String]
        let cliente: String

        let desfasado: Bool
        
        let fallo: String

        init(_ j: [String: Any]) {
            listo = j["listo"] as? Bool ?? false
            motivo = j["motivo"] as? String ?? ""
            falta = j["falta"] as? [String] ?? []
            desfasado = j["desfasado"] as? Bool ?? false
            fallo = j["fallo"] as? String ?? ""
            let campos = j["campos"] as? [String: Any]
            cliente = (campos?["customer"] as? [String: Any])?["business_name"] as? String ?? ""
        }
    }

    private var desfasado: Bool {
        guard let h = hecho, !h.dudoso else { return false }
        return vista?.desfasado ?? false
    }

    private var tituloPregunta: String {
        switch pidiendo {
        case .rehacer: return "¿Crear el borrador nuevo?"
        case .borrado: return "¿Lo has borrado en la gestoría?"
        default: return "¿Crear el borrador en la gestoría?"
        }
    }

    private var mensajePregunta: String {
        let a = vista?.cliente.isEmpty == false ? " a \(vista!.cliente)" : ""
        let nuevo = "un borrador de \(Formato.euros(cobro.paraFactura))\(a) con fecha del \(Formato.diaCorto(cobro.fecha))"
        if pidiendo == .rehacer, let h = hecho {
            return "Aparece en la gestoría \(nuevo). El de \(Formato.euros(h.euros)) sigue allí: bórralo tú."
        }
        if pidiendo == .borrado {
            
            return "La app crea otro: \(nuevo). Si el de antes sigue en la gestoría, tendrás dos."
        }
        return "Aparece en la gestoría \(nuevo). Sin número: lo emites tú."
    }

    var body: some View {
        Section {
            contenido
            if let fallo {
                Text(fallo).font(.footnote).foregroundStyle(Diseno.rojo)
            }
        } header: {
            Text("Gestoría")
        } footer: {
            pie
        }
        .task {
            hecho = cobro.borrador
            await cargar()
        }
        .confirmationDialog(tituloPregunta, isPresented: $preguntando, titleVisibility: .visible) {
            Button(pidiendo == .otraVez ? "Crearlo otra vez"
                   : pidiendo == .rehacer ? "Crear el nuevo"
                   : pidiendo == .borrado ? "Crear otro" : "Crear borrador") {
                Task { await crear() }
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text(mensajePregunta)
        }
    }

    @ViewBuilder private var contenido: some View {
        if let h = hecho, !h.dudoso {
            HStack {
                Label {
                    Text("Borrador creado").foregroundStyle(.primary)
                } icon: {
                    Image(systemName: desfasado ? "exclamationmark.triangle.fill"
                                                : "checkmark.circle.fill")
                        .foregroundStyle(desfasado ? Diseno.naranja : Diseno.verde)
                }
                Spacer()
                Text(Formato.diaCorto(String(h.cuando.prefix(10))))
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)
            if desfasado {
                HStack {
                    Text("En el borrador")
                    Spacer()
                    Text(Formato.euros(h.euros)).monospacedDigit().foregroundStyle(.secondary)
                }
                Button("Crear el borrador nuevo") { pedir(.rehacer) }
            }

            Button("Lo he borrado en la gestoría") { pedir(.borrado) }
        } else if creando {
            HStack(spacing: Diseno.hueco1) {
                ProgressView()
                Text("Creando el borrador…").foregroundStyle(.secondary)
            }
        } else if hecho?.dudoso == true {
            Label {
                Text("Gestoría no contestó a tiempo").foregroundStyle(.primary)
            } icon: {
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(Diseno.naranja)
            }
            Button("Crearlo otra vez") { pedir(.otraVez) }
        } else if let v = vista {
            if v.listo {
                if !v.fallo.isEmpty {
                    
                    Text("Gestoría dijo: \(v.fallo)").font(.footnote).foregroundStyle(Diseno.rojo)
                }
                Button {
                    pedir(.nuevo)
                } label: {
                    Label("Crear borrador en la gestoría", systemImage: "doc.badge.plus")
                }
            } else if !v.motivo.isEmpty {
                Text(v.motivo).foregroundStyle(.secondary)
            } else if !v.falta.isEmpty {
                Text("Falta " + v.falta.joined(separator: ", ") + ".").foregroundStyle(.secondary)
            }
        } else if fallo == nil {
            ProgressView().frame(maxWidth: .infinity)
        }
    }

    @ViewBuilder private var pie: some View {
        if let h = hecho, !h.dudoso {
            if desfasado {
                
                Text("La factura sale ahora por \(Formato.euros(cobro.paraFactura)) con fecha del \(Formato.diaCorto(cobro.fecha)). Crea el nuevo, o cambia el borrador en la gestoría antes de emitirlo.")
            } else if let e = h.anteriorEuros {
                
                Text("Borra en la gestoría el borrador anterior, el de \(Formato.euros(e))"
                     + (h.anteriorFecha.isEmpty ? "" : " del \(Formato.diaCorto(h.anteriorFecha))")
                     + ". Emite este y apunta aquí su número.")
            } else {
                Text("Míralo en la gestoría y emítelo allí. Luego apunta aquí su número.")
            }
        } else if hecho?.dudoso == true {
            Text("Puede que se creara: míralo en la gestoría antes de crearlo otra vez.")
        }
    }

    private var ruta: String {
        let id = cobro.id.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? cobro.id
        return "api/impuestos/asesoria/borrador?id=\(id)"
    }

    private func cargar() async {
        do {
            let j = try await API.pedir(ruta, testigo: sesion.testigo)
            vista = Vista(j)

            hecho = BorradorAsesoria(j["creado"])
        } catch is CancellationError {
        } catch {
            fallo = error.localizedDescription
        }
    }

    private func pedir(_ que: Pedir) {
        pidiendo = que
        preguntando = true
    }

    private func crear() async {
        creando = true
        fallo = nil
        defer { creando = false }
        var cuerpo: [String: any Sendable] = ["id": cobro.id]
        if pidiendo == .otraVez { cuerpo["repetir"] = true }
        if pidiendo == .rehacer { cuerpo["rehacer"] = true }
        if pidiendo == .borrado { cuerpo["borrado"] = true }
        do {
            let j = try await API.pedir("api/impuestos/asesoria/borrador", metodo: "POST",
                                        cuerpo: cuerpo, testigo: sesion.testigo)
            withAnimation(Diseno.suave) { hecho = BorradorAsesoria(j["creado"]) }
            await cargar()
            await alCrear()
        } catch {
            fallo = error.localizedDescription
            
            await cargar()
        }
    }
}
