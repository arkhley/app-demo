import Foundation
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

enum Aparato {

    static var identificador: String {
        #if targetEnvironment(simulator)
        return ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] ?? "Simulador"
        #else
        var sistema = utsname()
        uname(&sistema)
        return withUnsafePointer(to: &sistema.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) { String(cString: $0) }
        }
        #endif
    }

    private static let nombres: [String: String] = [
        
        "iPhone18,1": "iPhone 17 Pro",
        "iPhone18,2": "iPhone 17 Pro Max",
        "iPhone18,3": "iPhone 17",
        "iPhone18,4": "iPhone Air",
        
        "iPhone17,1": "iPhone 16 Pro",
        "iPhone17,2": "iPhone 16 Pro Max",
        "iPhone17,3": "iPhone 16",
        "iPhone17,4": "iPhone 16 Plus",
        
        "iPhone16,1": "iPhone 15 Pro",
        "iPhone16,2": "iPhone 15 Pro Max",
        "iPhone15,4": "iPhone 15",
        "iPhone15,5": "iPhone 15 Plus",
        
        "iPhone15,2": "iPhone 14 Pro",
        "iPhone15,3": "iPhone 14 Pro Max",
        "iPhone14,7": "iPhone 14",
        "iPhone14,8": "iPhone 14 Plus",
    ]

    static var modelo: String {
        let id = identificador
        return nombres[id] ?? id
    }

    static var familia: String {
        let id = identificador
        if id.hasPrefix("iPhone") { return "iPhone" }
        if id.hasPrefix("iPad") { return "iPad" }
        if id.hasPrefix("Watch") { return "Apple Watch" }
        if id.hasPrefix("AppleTV") { return "Apple TV" }
        if id.hasPrefix("Mac") { return "Mac" }
        return "Aparato"
    }

    static var paraElServidor: String {
        "\(familia)|\(modelo)|\(identificador)"
    }

    static func simbolo(_ nombre: String) -> String {
        let n = nombre.lowercased()
        if n.contains("ipad") { return "ipad" }
        if n.contains("iphone") { return "iphone" }
        if n.contains("watch") { return "applewatch" }
        if n.contains("apple tv") || n.contains("appletv") { return "appletv" }
        if n.contains("mac") { return "laptopcomputer" }
        if n.contains("windows") || n.contains("pc") { return "pc" }
        if n.contains("android") { return "candybarphone" }
        if n.contains("linux") { return "terminal" }
        return "globe"
    }
}

struct FilaDeAparato: View {
    let titulo: String
    let detalle: String
    var esteMismo: Bool = false

    @ScaledMetric(relativeTo: .title2) private var alto: CGFloat = 30

    var body: some View {
        HStack(spacing: Diseno.hueco3) {
            Image(systemName: Aparato.simbolo(titulo + " " + detalle))
                .font(.system(size: alto * 0.9, weight: .regular))
                .foregroundStyle(.primary)
                .frame(width: alto * 1.2, height: alto)

            VStack(alignment: .leading, spacing: 1) {
                Text(titulo)
                    .font(.title3)
                    .foregroundStyle(.primary)

                Text(esteMismo ? "Este \(detalle)" : detalle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, Diseno.hueco2)
        .contentShape(.rect)
    }

    var sangria: CGFloat { alto * 1.2 + Diseno.hueco3 }
}
