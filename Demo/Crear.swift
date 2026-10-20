import SwiftUI

struct CrearCodigo: View {
    @Environment(Sesion.self) private var sesion
    @Environment(\.dismiss) private var cerrar
    let hecho: () async -> Void

    @State private var esCustom = false
    @State private var codigo = ""
    @State private var tipo = "percent"
    @State private var valor = ""
    @State private var caduca = ""
    @State private var maxUsos = ""
    @State private var soloPrimero = false
    @State private var descripcion = ""
    @State private var precio = ""
    @State private var trabajando = false
    @State private var aviso: String?

    private let tipos = [("percent", "Porcentaje"), ("amount", "Euros"),
                         ("free_time", "Minutos gratis")]

    var body: some View {
        NavigationStack {
            Form {
                Picker("Qué crear", selection: $esCustom) {
                    Text("Descuento").tag(false)
                    Text("Encargo con código").tag(true)
                }
                .pickerStyle(.segmented)

                if esCustom {
                    Section {
                        TextField("Qué incluye", text: $descripcion, axis: .vertical)
                            .lineLimit(2...5)
                        TextField("Precio en euros", text: $precio)
                            .keyboardType(.decimalPad)
                    } footer: {
                        Text("Un código para una petición concreta. Se usa una sola vez.")
                    }
                } else {
                    Section {
                        TextField("Código (letras y números)", text: $codigo)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                        Picker("Tipo", selection: $tipo) {
                            ForEach(tipos, id: \.0) { Text($0.1).tag($0.0) }
                        }
                        TextField(tipo == "percent" ? "Descuento en %"
                                  : tipo == "amount" ? "Descuento en €" : "Minutos",
                                  text: $valor)
                            .keyboardType(.decimalPad)
                    }
                    Section {
                        TextField("Caduca (AAAA-MM-DD, opcional)", text: $caduca)
                            .autocorrectionDisabled()
                        TextField("Máximo de personas (0 = sin límite)", text: $maxUsos)
                            .keyboardType(.numberPad)
                        Toggle("Solo primera compra", isOn: $soloPrimero)
                    }
                }

                if let aviso {
                    Section { Text(aviso).foregroundStyle(Diseno.rojo).font(.footnote) }
                }
            }
            .navigationTitle("Nuevo código")
            .salidaDelTeclado()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { cerrar() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(trabajando ? "Creando…" : "Crear") { Task { await crear() } }
                        .disabled(trabajando)
                }
            }
        }
    }

    private func crear() async {
        trabajando = true
        aviso = nil
        let cuerpo: [String: any Sendable] = esCustom
            ? ["kind": "encargocodigo", "descripcion": descripcion, "precio": precio]
            : ["codigo": codigo, "tipo": tipo, "valor": valor, "caduca": caduca,
               "max_uses": maxUsos, "solo_primero": soloPrimero]
        do {
            let j = try await API.pedir("api/codigos/crear", metodo: "POST",
                                        cuerpo: cuerpo, testigo: sesion.testigo)
            if j["ok"] as? Bool ?? false {
                await hecho()
                cerrar()
            } else {
                aviso = j["mensaje"] as? String ?? "No se ha podido crear."
            }
        } catch {
            aviso = error.localizedDescription
        }
        trabajando = false
    }
}

struct CrearCategoria: View {
    @Environment(Sesion.self) private var sesion
    @Environment(\.dismiss) private var cerrar
    let hecho: () async -> Void

    @State private var nombre = ""
    @State private var precio = ""
    @State private var trabajando = false
    @State private var aviso: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Nombre", text: $nombre)
                    TextField("Precio en euros", text: $precio)
                        .keyboardType(.decimalPad)
                } footer: {
                    
                    Text("El cliente verá este nombre tal y como lo escribas.")
                }

                if let aviso {
                    Section { Text(aviso).foregroundStyle(Diseno.rojo).font(.footnote) }
                }
            }
            .navigationTitle("Nueva categoría")
            .salidaDelTeclado()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { cerrar() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(trabajando ? "Creando…" : "Crear") { Task { await crear() } }
                        .disabled(trabajando || nombre.isEmpty)
                }
            }
        }
    }

    private func crear() async {
        trabajando = true
        aviso = nil
        do {
            let j = try await API.pedir("api/videos/accion", metodo: "POST",
                                        cuerpo: ["accion": "crear", "nombre": nombre,
                                                 "precio": precio],
                                        testigo: sesion.testigo)
            if j["ok"] as? Bool ?? false {
                await hecho()
                cerrar()
            } else {
                aviso = j["mensaje"] as? String ?? "No se ha podido crear."
            }
        } catch {
            aviso = error.localizedDescription
        }
        trabajando = false
    }
}
