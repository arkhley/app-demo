import CryptoKit
import Foundation
import SwiftUI

enum CodigoNumerico {
    private static let servicio = "com.example.panel"
    private static let cuenta = "codigo-numerico"

    static let digitos = 4

    static let maxFallos = 5

    static func hayCodigo() -> Bool { _leer() != nil }

    static func poner(_ codigo: String) -> Bool {
        guard codigo.count == digitos, codigo.allSatisfy(\.isNumber) else { return false }
        let sal = UUID().uuidString
        _guardar("\(sal)|\(_huella(codigo, sal: sal))")
        
        Intentos.acierto()
        return true
    }

    static func quitar() {
        _borrar()
        Intentos.acierto()
    }

    static func comprueba(_ codigo: String) -> Bool {
        guard let guardado = _leer() else { return false }
        let partes = guardado.split(separator: "|", maxSplits: 1).map(String.init)
        guard partes.count == 2 else { return false }

        return _huella(codigo, sal: partes[0]) == partes[1]
    }

    private static func _huella(_ codigo: String, sal: String) -> String {
        let datos = Data("\(sal)|\(codigo)".utf8)
        return SHA256.hash(data: datos).map { String(format: "%02x", $0) }.joined()
    }

    private static func _guardar(_ valor: String, en cuenta: String = cuenta) {
        _borrar(cuenta)
        let consulta: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: servicio,
            kSecAttrAccount as String: cuenta,
            kSecValueData as String: Data(valor.utf8),
            
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
        ]
        SecItemAdd(consulta as CFDictionary, nil)
    }

    private static func _leer(_ cuenta: String = cuenta) -> String? {
        let consulta: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: servicio,
            kSecAttrAccount as String: cuenta,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var salida: AnyObject?
        guard SecItemCopyMatching(consulta as CFDictionary, &salida) == errSecSuccess,
              let datos = salida as? Data else { return nil }
        return String(data: datos, encoding: .utf8)
    }

    private static func _borrar(_ cuenta: String = cuenta) {
        SecItemDelete([
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: servicio,
            kSecAttrAccount as String: cuenta,
        ] as CFDictionary)
    }

    struct Intentos: Equatable {
        var fallos = 0
        var hasta: Date?

        private static let cuenta = "codigo-numerico-fallos"

        static func espera(tras n: Int) -> TimeInterval? {
            switch n {
            case ..<5: return nil
            case 5: return 60
            case 6: return 5 * 60
            case 7: return 15 * 60
            default: return 60 * 60
            }
        }

        func bloqueado(_ ahora: Date = Date()) -> Bool { (hasta ?? .distantPast) > ahora }

        static func leer() -> Intentos {
            guard let texto = CodigoNumerico._leer(cuenta) else { return Intentos() }
            let partes = texto.split(separator: "|").map(String.init)
            let fallos = partes.first.flatMap(Int.init) ?? 0
            let hasta = partes.count > 1 ? Double(partes[1]).map(Date.init(timeIntervalSince1970:)) : nil
            return Intentos(fallos: fallos, hasta: hasta)
        }

        @discardableResult
        static func fallo() -> Intentos {
            var i = leer()
            i.fallos += 1
            i.hasta = espera(tras: i.fallos).map { Date().addingTimeInterval($0) }
            CodigoNumerico._guardar("\(i.fallos)|\(i.hasta?.timeIntervalSince1970 ?? 0)", en: cuenta)
            return i
        }

        static func acierto() { CodigoNumerico._borrar(cuenta) }
    }
}

struct TecladoNumerico: View {
    @Binding var marcado: String
    let digitos: Int
    
    let completo: (String) async -> Bool

    @State private var fallando = false
    @ScaledMetric(relativeTo: .title) private var lado: CGFloat = 72

    var body: some View {
        VStack(spacing: Diseno.hueco4) {
            puntos
            teclas
        }
        .sensoryFeedback(.error, trigger: fallando)
    }

    private var puntos: some View {
        HStack(spacing: 18) {
            ForEach(0..<digitos, id: \.self) { i in
                Circle()
                    .fill(i < marcado.count ? Color.primary : Color.secondary.opacity(0.25))
                    .frame(width: 13, height: 13)
            }
        }
        
        .offset(x: fallando ? -8 : 0)
        .animation(fallando ? .default.repeatCount(3, autoreverses: true).speed(6)
                            : .default, value: fallando)
        .accessibilityLabel("\(marcado.count) de \(digitos) dígitos")
    }

    private var teclas: some View {
        VStack(spacing: Diseno.hueco3) {
            ForEach([["1", "2", "3"], ["4", "5", "6"], ["7", "8", "9"], ["", "0", "⌫"]],
                    id: \.self) { fila in
                HStack(spacing: Diseno.hueco3) {
                    ForEach(fila, id: \.self) { t in tecla(t) }
                }
            }
        }
    }

    @ViewBuilder
    private func tecla(_ t: String) -> some View {
        if t.isEmpty {
            Color.clear.frame(width: lado, height: lado)
        } else {

            Button {
                pulsar(t)
            } label: {
                Group {
                    if t == "⌫" {
                        Image(systemName: "delete.left").font(.title3)
                    } else {
                        Text(t).font(.system(size: lado * 0.42, weight: .regular,
                                             design: .rounded))
                    }
                }
                .frame(width: lado, height: lado)
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
            .accessibilityLabel(t == "⌫" ? "Borrar" : t)
        }
    }

    private func pulsar(_ t: String) {
        if t == "⌫" {
            if !marcado.isEmpty { marcado.removeLast() }
            return
        }
        guard marcado.count < digitos else { return }
        marcado.append(t)
        guard marcado.count == digitos else { return }

        let intento = marcado
        Task {
            let vale = await completo(intento)
            if !vale {
                fallando = true
                try? await Task.sleep(for: .milliseconds(450))
                fallando = false
                marcado = ""
            }
        }
    }
}
