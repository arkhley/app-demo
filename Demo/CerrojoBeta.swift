import SwiftUI
import UIKit

struct CerrojoComoElIPhone: View {
    @Environment(Sesion.self) private var sesion
    @Environment(\.scenePhase) private var fase
    @AppStorage(Ajustes.desbloquearConCara) private var desbloquearConCara = true
    
    @Environment(\.cerrojoSaliendo) private var saliendo

    @State private var biometria = Cerrojo.disponible()
    
    @State private var fondo: UIImage? = FondoDelCerrojo.recordado
    
    @State private var teclado = false
    @State private var pidiendo = false

    @State private var estuvoEnSegundoPlano = false
    @State private var marcado = ""
    @State private var intentos = CerrojoComoElIPhone.leerIntentos()
    @State private var olvido = false

    @State private var vez = 0

    static let esperaDeLaCara: Duration = .seconds(2)

    private var caraActiva: Bool { desbloquearConCara && biometria != .ninguna }

    var body: some View {
        ZStack {
            FondoDelCerrojo(imagen: fondo, empanado: teclado)
                
                .animation(nil) { $0.opacity(saliendo ? 0 : 1) }
            if teclado {
                TecladoComoElIPhone(marcado: $marcado, intentos: intentos, conCara: caraActiva,
                                    comprobar: comprobar, cancelar: cancelar,
                                    olvidado: { olvido = true })
                    .id(vez)
            }
        }
        
        .statusBarHidden(true)
        
        .onChange(of: teclado, initial: true) { _, ahora in FondoDelCerrojo.empanadoAhora = ahora }
        
        .contentShape(.rect)
        .onTapGesture {
            guard !teclado, !pidiendo else { return }
            Task { await empezar() }
        }
        .confirmationDialog("¿Has olvidado el código?", isPresented: $olvido, titleVisibility: .visible) {
            Button("Cerrar sesión y quitar el código", role: .destructive) {
                CodigoNumerico.quitar()
                sesion.salir()
            }
        } message: {
            Text("Para volver a entrar hará falta la contraseña de Ingresos, con la VPN encendida.")
        }
        .task {
            intentos = Self.leerIntentos()
            await empezar()
        }
        
        .task {
            let leido = await cargarFondo()
            fondo = leido
            FondoDelCerrojo.recordado = leido
        }
        .onChange(of: fase) { _, nueva in
            if nueva == .background { estuvoEnSegundoPlano = true; return }
            guard nueva == .active, estuvoEnSegundoPlano else { return }
            estuvoEnSegundoPlano = false
            
            teclado = false
            marcado = ""
            Task { await empezar() }
        }
        
        .task(id: intentos.hasta) {
            guard let hasta = intentos.hasta, hasta > Date() else { return }
            try? await Task.sleep(for: .seconds(hasta.timeIntervalSinceNow))
            guard !Task.isCancelled, teclado else { return }
            teclado = false
            mostrarTeclado()
        }
    }

    private func empezar() async {
        biometria = Cerrojo.disponible()
        #if MAQUETA
        if Maqueta.caraQueNoLee || Maqueta.caraQueNoAcaba || Maqueta.caraQueLee { biometria = .faceID }
        #endif
        guard caraActiva else { mostrarTeclado(); return }
        await intentarCara()
    }

    private func intentarCara() async {
        guard !pidiendo else { return }
        pidiendo = true
        #if MAQUETA
        
        let salida: Cerrojo.Resultado
        if Maqueta.caraQueNoLee || Maqueta.caraQueNoAcaba {
            try? await Task.sleep(for: Maqueta.caraQueNoAcaba ? .seconds(3600) : Self.esperaDeLaCara)
            salida = .cancelado
        } else if Maqueta.caraQueLee {
            
            try? await Task.sleep(for: .seconds(1.2))
            salida = .si
        } else {
            salida = await Cerrojo.pedir(cancelar: "Introducir código", limite: Self.esperaDeLaCara)
        }
        #else
        let salida = await Cerrojo.pedir(cancelar: "Introducir código", limite: Self.esperaDeLaCara)
        #endif
        pidiendo = false
        switch salida {
        case .si:
            CodigoNumerico.Intentos.acierto()
            sesion.desbloquear()
        case .cancelado:
            
            mostrarTeclado()
        case .fallo:
            
            biometria = Cerrojo.disponible()
            mostrarTeclado()
        }
    }

    private func mostrarTeclado() {
        marcado = ""
        intentos = Self.leerIntentos()
        vez += 1
        teclado = true
    }

    private static func leerIntentos() -> CodigoNumerico.Intentos {
        #if MAQUETA
        if let n = Maqueta.fallosDePrueba {
            return CodigoNumerico.Intentos(
                fallos: n, hasta: CodigoNumerico.Intentos.espera(tras: n).map { Date().addingTimeInterval($0) })
        }
        #endif
        return CodigoNumerico.Intentos.leer()
    }

    private func cancelar() {
        teclado = false
        marcado = ""
        Task { await empezar() }
    }

    private func comprobar(_ intento: String) -> Bool {
        #if MAQUETA
        if Maqueta.codigoDePrueba {
            if intento == "1234" { sesion.desbloquear(); return true }
            intentos.fallos += 1
            return false
        }
        #endif
        if CodigoNumerico.comprueba(intento) {
            CodigoNumerico.Intentos.acierto()
            sesion.desbloquear()
            return true
        }
        intentos = CodigoNumerico.Intentos.fallo()
        return false
    }

    private func cargarFondo() async -> UIImage? {
        #if MAQUETA
        if let demo = Maqueta.fondoDePrueba { return demo }
        #endif
        return await FondoDelPanel.cargar()
    }
}

struct FondoDelCerrojo: View {
    let imagen: UIImage?
    let empanado: Bool

    @MainActor static var recordado: UIImage?
    
    @MainActor static var empanadoAhora = false

    var body: some View {
        ZStack {
            Group {
                if let imagen {
                    Color.clear
                        .overlay {
                            Image(uiImage: imagen)
                                .resizable()
                                .scaledToFill()
                        }
                        .clipped()
                } else {
                    LinearGradient(colors: [Color(red: 0.16, green: 0.17, blue: 0.30),
                                            Color(red: 0.05, green: 0.05, blue: 0.10)],
                                   startPoint: .top, endPoint: .bottom)
                }
            }

            .blur(radius: empanado ? 8 : 0, opaque: true)
            .overlay(Color.black.opacity(empanado ? 0.2 : 0))
            .animation(.easeOut(duration: 0.3), value: empanado)
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

private struct TecladoComoElIPhone: View {
    @Binding var marcado: String
    let intentos: CodigoNumerico.Intentos
    let conCara: Bool
    let comprobar: (String) -> Bool
    let cancelar: () -> Void
    let olvidado: () -> Void

    @Environment(\.accessibilityReduceMotion) private var sinMovimiento
    
    @State private var abierto = false
    @State private var meneo = false
    @State private var fallos = 0

    var body: some View {
        GeometryReader { geo in
            let m = Medidas(tamano: geo.size)
            ZStack {
                if intentos.bloqueado() {
                    noDisponible(m)
                } else {
                    cabecera(m)
                    teclas(m)
                }
                pie(m)
            }
        }
        .ignoresSafeArea()
        .foregroundStyle(.white)
        .sensoryFeedback(.error, trigger: fallos)
        .onAppear { abierto = true }
    }

    private func cabecera(_ m: Medidas) -> some View {
        Group {
            Text("Introduce el código")
                .font(.system(size: 20, weight: .medium))
                .position(x: m.centro, y: m.titulo)
            puntos
                .position(x: m.centro, y: m.puntos)
        }
        .animation(.easeOut(duration: 0.18)) { $0.opacity(abierto ? 1 : 0) }
    }

    private var puntos: some View {
        HStack(spacing: Medidas.entrePuntos - Medidas.punto) {
            ForEach(0..<CodigoNumerico.digitos, id: \.self) { i in
                Circle()
                    .strokeBorder(.white, lineWidth: 1.4)
                    .background(Circle().fill(i < marcado.count ? .white : .clear))
                    .frame(width: Medidas.punto, height: Medidas.punto)
            }
        }
        
        .offset(x: meneo ? -10 : 0)
        .animation(meneo ? .linear(duration: 0.06).repeatCount(5, autoreverses: true) : .default,
                   value: meneo)
        .accessibilityElement()
        .accessibilityLabel("\(marcado.count) de \(CodigoNumerico.digitos) dígitos")
    }

    private func teclas(_ m: Medidas) -> some View {
        ZStack {
            
            ForEach(Tecla.todas.sorted { $0.cifra == "0" && $1.cifra != "0" }) { t in
                let sitio = m.sitio(t)
                boton(t)
                    .animation(.easeOut(duration: sinMovimiento ? 0.2 : 0.12)) {
                        $0.opacity(abierto ? 1 : 0)
                    }

                    .animation(sinMovimiento ? nil : .spring(response: t.respuesta,
                                                             dampingFraction: t.amortiguacion)) {
                        $0.scaleEffect(abierto || sinMovimiento ? 1 : 0.1,
                                       anchor: m.anclaEnElCinco(desde: sitio))
                    }
                    .position(sitio)
            }
        }
    }

    private func boton(_ t: Tecla) -> some View {
        Button {
            pulsar(t.cifra)
        } label: {
            ZStack {
                Text(t.cifra)
                    .font(.system(size: 38, weight: .regular))
                    .offset(y: t.letras.isEmpty && t.cifra == "0" ? 0 : -6)
                if !t.letras.isEmpty {
                    Text(t.letras)
                        .font(.system(size: 9.5, weight: .semibold))
                        .tracking(2)
                        .offset(y: 16)
                }
            }
            .frame(width: Medidas.tecla - 2 * Medidas.rellenoDelCristal,
                   height: Medidas.tecla - 2 * Medidas.rellenoDelCristal)
        }
        .estiloDeTeclaDeCristal()
        .buttonBorderShape(.circle)
        .accessibilityLabel(t.letras.isEmpty ? t.cifra : "\(t.cifra), \(t.letras)")
    }

    private func pulsar(_ cifra: String) {
        guard marcado.count < CodigoNumerico.digitos else { return }
        marcado.append(cifra)
        guard marcado.count == CodigoNumerico.digitos else { return }
        let intento = marcado
        if comprobar(intento) { return }
        fallos += 1
        meneo = true
        Task {
            try? await Task.sleep(for: .milliseconds(450))
            meneo = false
            marcado = ""
        }
    }

    private func pie(_ m: Medidas) -> some View {
        ZStack {
            if intentos.fallos >= 5 {
                Button("¿Lo has olvidado?", action: olvidado)
                    .position(x: m.pieIzquierda, y: m.pie)
            }
            if !marcado.isEmpty && !intentos.bloqueado() {
                Button("Borrar") { marcado.removeLast() }
                    .position(x: m.pieDerecha, y: m.pie)
            } else if conCara {
                Button("Cancelar", action: cancelar)
                    .position(x: m.pieDerecha, y: m.pie)
            }
        }
        .font(.system(size: 16, weight: .medium))
        
        .tint(.white)
        
        .animation(.easeOut(duration: 0.12).delay(0.15)) { $0.opacity(abierto ? 1 : 0) }
    }

    private func noDisponible(_ m: Medidas) -> some View {
        TimelineView(.periodic(from: .now, by: 1)) { contexto in
            VStack(spacing: 6) {
                Text("No disponible")
                    .font(.system(size: 20, weight: .medium))
                Text(textoDeEspera(hasta: intentos.hasta, ahora: contexto.date))
                    .font(.system(size: 15))
                    .opacity(0.8)
            }
            .multilineTextAlignment(.center)
            .position(x: m.centro, y: m.titulo + 14)
        }
        .animation(.easeOut(duration: 0.18)) { $0.opacity(abierto ? 1 : 0) }
    }

    private func textoDeEspera(hasta: Date?, ahora: Date) -> String {
        let quedan = max(0, (hasta ?? ahora).timeIntervalSince(ahora))
        let minutos = Int((quedan / 60).rounded(.up))
        return minutos <= 1 ? "Vuelve a intentarlo en 1 minuto"
                            : "Vuelve a intentarlo en \(minutos) minutos"
    }
}

private struct Tecla: Identifiable {
    let cifra: String
    let letras: String
    let columna: Int     
    let fila: Int        
    
    let respuesta: Double
    var amortiguacion: Double { cifra == "0" ? 0.52 : 0.54 }
    var id: String { cifra }

    static let todas: [Tecla] = [
        Tecla(cifra: "1", letras: "", columna: 0, fila: 0, respuesta: 0.37),
        Tecla(cifra: "2", letras: "ABC", columna: 1, fila: 0, respuesta: 0.30),
        Tecla(cifra: "3", letras: "DEF", columna: 2, fila: 0, respuesta: 0.37),
        Tecla(cifra: "4", letras: "GHI", columna: 0, fila: 1, respuesta: 0.33),
        Tecla(cifra: "5", letras: "JKL", columna: 1, fila: 1, respuesta: 0.28),
        Tecla(cifra: "6", letras: "MNO", columna: 2, fila: 1, respuesta: 0.33),
        Tecla(cifra: "7", letras: "PQRS", columna: 0, fila: 2, respuesta: 0.455),
        Tecla(cifra: "8", letras: "TUV", columna: 1, fila: 2, respuesta: 0.37),
        Tecla(cifra: "9", letras: "WXYZ", columna: 2, fila: 2, respuesta: 0.455),
        Tecla(cifra: "0", letras: "", columna: 1, fila: 3, respuesta: 0.70),
    ]
}

private struct Medidas {
    let tamano: CGSize

    static let tecla: CGFloat = 80
    static let entreColumnas: CGFloat = 102
    static let entreFilas: CGFloat = 99
    static let hastaElCero: CGFloat = 101
    static let punto: CGFloat = 11
    static let entrePuntos: CGFloat = 33.5
    
    static let rellenoDelCristal: CGFloat = 7

    var centro: CGFloat { tamano.width / 2 }
    var filaDelCinco: CGFloat { tamano.height * 0.4854 }
    var titulo: CGFloat { filaDelCinco - 256.5 }
    var puntos: CGFloat { filaDelCinco - 227 }
    var pie: CGFloat { tamano.height - 78 }
    var pieIzquierda: CGFloat { centro - 109 }
    var pieDerecha: CGFloat { centro + 109 }
    var sitioDelCinco: CGPoint { CGPoint(x: centro, y: filaDelCinco) }

    func anclaEnElCinco(desde sitio: CGPoint) -> UnitPoint {
        UnitPoint(x: 0.5 + (sitioDelCinco.x - sitio.x) / Self.tecla,
                  y: 0.5 + (sitioDelCinco.y - sitio.y) / Self.tecla)
    }

    func sitio(_ t: Tecla) -> CGPoint {
        let x = centro + CGFloat(t.columna - 1) * Self.entreColumnas
        let y = t.fila == 3 ? filaDelCinco + Self.entreFilas + Self.hastaElCero
                            : filaDelCinco + CGFloat(t.fila - 1) * Self.entreFilas
        return CGPoint(x: x, y: y)
    }
}

private extension View {

    @ViewBuilder
    func estiloDeTeclaDeCristal() -> some View {
        #if MAQUETA
        if Maqueta.cristalRegular {
            buttonStyle(.glass)
        } else if #available(iOS 26.1, *) {
            buttonStyle(.glass(.clear))
        } else {
            buttonStyle(.glass)
        }
        #else
        if #available(iOS 26.1, *) {
            buttonStyle(.glass(.clear))
        } else {
            buttonStyle(.glass)
        }
        #endif
    }
}
