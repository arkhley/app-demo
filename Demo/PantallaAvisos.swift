import SwiftUI

struct PantallaAvisos: View {
    @Environment(Sesion.self) private var sesion
    @Environment(\.openURL) private var abrirURL
    @Environment(\.tema) private var tema

    @State private var alistarseActivo = false
    @State private var hora = Date()
    @State private var dias: Set<Int> = [0, 1, 2, 3, 4, 5, 6]
    @State private var huchaActivo = true
    @State private var estado: Carga<Bool> = .cargando
    @State private var aviso: (texto: String, bien: Bool)?
    
    @State private var cargado = false

    @State private var alistarseLeido = ""
    @State private var huchaLeido: Bool?
    
    @State private var enElIPhone = false
    @State private var segundo = 0
    @State private var descansar = true
    @State private var pedidos = true
    @State private var semana = true
    @State private var fallos = true
    @State private var codigos = true
    @State private var permisoDenegado = false
    @State private var iphoneLeido = ""

    private static let segundos: [(Int, String)] = [
        (0, "No"), (-120, "2 h antes"), (-60, "1 h antes"), (-30, "30 min antes"),
        (-15, "15 min antes"), (15, "15 min después"), (30, "30 min después"),
    ]

    private static let nombresDia = ["L", "M", "X", "J", "V", "S", "D"]

    var body: some View {
        ScrollView {
            VStack(spacing: Diseno.hueco3) {
                if let aviso { Banda(aviso) }

                switch estado {
                case .cargando:
                    Tarjeta { Vacio(icono: "bell", titulo: "Cargando…") }
                        .redacted(reason: .placeholder)
                case .error(let qué):
                    Tarjeta { Vacio(icono: "wifi.exclamationmark",
                                    titulo: "No se ha podido cargar", detalle: qué) }
                default:
                    Tarjeta {
                        VStack(alignment: .leading, spacing: Diseno.hueco2) {
                            Toggle("En el iPhone", isOn: $enElIPhone)
                            if permisoDenegado {
                                Text("Las notificaciones de Ingresos están apagadas en Ajustes del iPhone.")
                                    .font(.caption).foregroundStyle(.secondary)
                                Button("Abrir Ajustes") {
                                    if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
                                        abrirURL(url)
                                    }
                                }
                                .font(.callout.weight(.semibold))
                            }
                        }
                    }

                    Tarjeta {
                        VStack(alignment: .leading, spacing: Diseno.hueco3) {
                            Toggle("Hora de alistarme", isOn: $alistarseActivo)
                            if alistarseActivo {
                                DatePicker("A las", selection: $hora,
                                           displayedComponents: .hourAndMinute)
                                diasDeLaSemana
                                if enElIPhone {

                                    HStack {
                                        Text("Otro aviso")
                                        Spacer(minLength: Diseno.hueco2)
                                        Picker("Otro aviso", selection: $segundo) {
                                            ForEach(Self.segundos, id: \.0) { s in Text(s.1).tag(s.0) }
                                        }
                                        .labelsHidden()
                                    }
                                }
                            }
                        }
                    }

                    Tarjeta {
                        VStack(alignment: .leading, spacing: Diseno.hueco2) {
                            Toggle("Avisos de la reserva", isOn: $huchaActivo)
                            Text(enElIPhone
                                 ? "Si una noche sin emitir la deja en negativo o por debajo de 50 €, a la hora de alistarte; y cuando se queda sin saldo."
                                 : "Cuando se queda sin saldo o baja de 50 €.")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }

                    if enElIPhone {
                        Tarjeta {
                            VStack(alignment: .leading, spacing: Diseno.hueco3) {
                                Toggle("Hoy puedes descansar", isOn: $descansar)
                                Toggle("Pedido nuevo esperando", isOn: $pedidos)
                                Toggle("Resumen de la semana", isOn: $semana)
                                Toggle("Algo no funciona", isOn: $fallos)
                                VStack(alignment: .leading, spacing: 4) {
                                    Toggle("Encargo con código sin usar", isOn: $codigos)
                                    Text("A los 2 días, a la semana y a las 2 semanas; al día siguiente se borra solo.")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }

                    Text(enElIPhone
                         ? "Lo que tiene hora llega a su hora. Un pedido, un fallo o el cierre de la reserva llegan cuando iOS deja mirar a la app, y puede tardar: Tienda sigue avisando de pedidos y fallos al momento."
                         : "Los avisos llegan por Tienda, al bot de avisos.")
                        .font(.caption).foregroundStyle(.secondary).padding(.horizontal, 4)
                }
            }
            .padding(.horizontal, Diseno.margen)
            .padding(.vertical, Diseno.hueco2)
        }
        .fondoDePantalla()
        .navigationTitle("Notificaciones")

        .navigationBarTitleDisplayMode(.inline)
        .animation(Diseno.suave, value: alistarseActivo)

        .onChange(of: huchaActivo) { _, nuevo in
            guard cargado, nuevo != huchaLeido else { return }
            huchaLeido = nuevo
            Task {
                await mandar(["accion": "hucha", "activo": nuevo])
                await reprogramarElIPhone()
            }
        }
        .onChange(of: alistarseActivo) { _, _ in guardarSiCargado() }
        .onChange(of: hora) { _, _ in guardarSiCargado() }
        .onChange(of: dias) { _, _ in guardarSiCargado() }
        .onChange(of: enElIPhone) { _, nuevo in
            guard cargado, firmaIPhone != iphoneLeido else { return }
            if nuevo {
                
                Task {
                    if await AvisosDeLaAgenda.pedirPermiso() {
                        permisoDenegado = false
                        guardarIPhone()
                    } else {
                        permisoDenegado = true
                        enElIPhone = false
                    }
                }
            } else {
                guardarIPhone()
            }
        }

        .onChange(of: firmaResto) { _, _ in
            guard cargado, enElIPhone, firmaIPhone != iphoneLeido else { return }
            guardarIPhone()
        }
        .task { await cargar() }
    }

    private var diasDeLaSemana: some View {
        HStack(spacing: 6) {
            ForEach(0..<7, id: \.self) { i in
                Button {
                    if dias.contains(i) { dias.remove(i) } else { dias.insert(i) }
                } label: {
                    Text(Self.nombresDia[i])
                        .font(.footnote.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                        .background(dias.contains(i) ? tema.relleno
                                                     : Color.secondary.opacity(0.15),
                                    in: .rect(cornerRadius: 9))
                        .foregroundStyle(dias.contains(i) ? tema.sobreRelleno : .primary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(nombreLargo(i))
                .accessibilityAddTraits(dias.contains(i) ? [.isSelected] : [])
            }
        }
    }

    private func nombreLargo(_ i: Int) -> String {
        ["Lunes", "Martes", "Miércoles", "Jueves", "Viernes", "Sábado", "Domingo"][i]
    }

    private func cargar() async {
        do {
            let j = try await API.pedir("api/avisos", testigo: sesion.testigo)
            alistarseActivo = j["alistarse_activo"] as? Bool ?? false
            huchaActivo = j["hucha_activo"] as? Bool ?? true
            dias = Set(((j["alistarse_dias"] as? [Int]) ?? [0, 1, 2, 3, 4, 5, 6]))
            hora = Self.desdeTexto(j["alistarse_hora"] as? String ?? "21:00")
            alistarseLeido = firmaAlistarse
            huchaLeido = huchaActivo
            enElIPhone = j["en_el_iphone"] as? Bool ?? false
            segundo = j["segundo"] as? Int ?? 0
            descansar = j["descansar"] as? Bool ?? true
            pedidos = j["pedidos"] as? Bool ?? true
            semana = j["semana"] as? Bool ?? true
            fallos = j["fallos"] as? Bool ?? true
            codigos = j["codigos"] as? Bool ?? true
            iphoneLeido = firmaIPhone
            estado = .listo(true)
            cargado = true
        } catch {
            estado.fallar(error)
        }
    }

    private var firmaAlistarse: String {
        "\(alistarseActivo)|\(Self.aTexto(hora))|\(dias.sorted())"
    }

    private var firmaIPhone: String { "\(enElIPhone)|\(firmaResto)" }

    private var firmaResto: String {
        "\(segundo)|\(descansar)|\(pedidos)|\(semana)|\(fallos)|\(codigos)"
    }

    private func reprogramarElIPhone() async {
        guard enElIPhone else { return }
        await AvisosDelIPhone.renovar(testigo: sesion.testigo, enPrimerPlano: true)
    }

    private func guardarIPhone() {
        iphoneLeido = firmaIPhone
        Task {
            await mandar(["accion": "iphone", "en_el_iphone": enElIPhone, "segundo": segundo,
                          "descansar": descansar, "pedidos": pedidos, "semana": semana,
                          "fallos": fallos, "codigos": codigos])
            
            await AvisosDelIPhone.asegurarLlave(testigo: sesion.testigo)
            await AvisosDelIPhone.renovar(testigo: sesion.testigo, enPrimerPlano: true)
            if !enElIPhone { AvisosDelIPhone.quitarTodos() }
        }
    }

    private func guardarSiCargado() {
        guard cargado, firmaAlistarse != alistarseLeido else { return }
        alistarseLeido = firmaAlistarse
        Task { await guardar() }
    }

    private func guardar() async {
        await mandar(["activo": alistarseActivo,
                      "hora": Self.aTexto(hora),

                      "dias": dias.isEmpty ? [0, 1, 2, 3, 4, 5, 6] : dias.sorted()])
        await reprogramarElIPhone()
    }

    private func mandar(_ cuerpo: [String: any Sendable]) async {
        do {
            let j = try await API.pedir("api/avisos", metodo: "POST",
                                        cuerpo: cuerpo, testigo: sesion.testigo)
            aviso = (j["mensaje"] as? String ?? "Guardado.", j["ok"] as? Bool ?? true)
        } catch {
            aviso = (error.localizedDescription, false)
        }
    }

    private static func desdeTexto(_ t: String) -> Date {
        let partes = t.split(separator: ":").compactMap { Int($0) }
        var c = DateComponents()
        c.hour = partes.first ?? 21
        c.minute = partes.count > 1 ? partes[1] : 0
        return Calendar.current.date(from: c) ?? Date()
    }

    private static func aTexto(_ d: Date) -> String {
        let c = Calendar.current.dateComponents([.hour, .minute], from: d)
        return String(format: "%02d:%02d", c.hour ?? 21, c.minute ?? 0)
    }
}
