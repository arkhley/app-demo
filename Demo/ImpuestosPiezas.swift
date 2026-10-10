import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

enum CuentaIVA {
    static func r2(_ x: Double) -> Double {
        ((x + (x >= 0 ? 1e-9 : -1e-9)) * 100).rounded() / 100
    }

    static func aplicar(_ cobrado: Double, pct: Double, modo: String)
        -> (base: Double, iva: Double, total: Double) {
        let c = r2(cobrado)
        if modo == "sin" || pct <= 0 { return (c, 0, c) }
        if modo == "encima" {
            let iva = r2(c * pct / 100)
            return (c, iva, r2(c + iva))
        }
        let base = r2(c / (1 + pct / 100))
        return (base, r2(c - base), c)
    }

    static func numero(_ texto: String) -> Double? {
        var t = texto.replacingOccurrences(of: "€", with: "")
            .replacingOccurrences(of: " ", with: "")
        if t.contains(",") {
            t = t.replacingOccurrences(of: ".", with: "").replacingOccurrences(of: ",", with: ".")
        }
        guard let v = Double(t), v.isFinite else { return nil }
        return v
    }

    static func paraPegar(_ v: Double) -> String {
        String(format: "%.2f", r2(v)).replacingOccurrences(of: ".", with: ",")
    }

    static func dolares(_ v: Double) -> String { Formato.dolares(v) }
}

struct BarraFactura: View {
    let base: Double
    let iva: Double
    
    var nombreBase = "Base"
    var nombreIVA = "IVA"

    @Environment(\.accessibilityReduceMotion) private var sinMovimiento

    private var total: Double { base + iva }

    var body: some View {
        VStack(alignment: .leading, spacing: Diseno.hueco2) {
            GeometryReader { g in
                let hueco: CGFloat = iva > 0.004 ? 3 : 0
                let ancho = max(0, g.size.width - hueco)
                let parteBase = total > 0 ? base / total : 1
                HStack(spacing: hueco) {
                    Capsule().fill(Color.purple.gradient)
                        .frame(width: ancho * parteBase)
                    if iva > 0.004 {
                        Capsule().fill(Color.orange.gradient)
                    }
                }
            }
            .frame(height: 14)
            .accessibilityHidden(true)

            HStack(alignment: .firstTextBaseline, spacing: Diseno.hueco3) {
                leyenda(.purple, nombreBase, base)
                if iva > 0.004 { leyenda(.orange, nombreIVA, iva) }
                Spacer(minLength: 0)
                VStack(alignment: .trailing, spacing: 1) {
                    Text("Total").font(.caption2).foregroundStyle(.secondary)
                    Text(Formato.euros(total))
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .monospacedDigit()
                        .contentTransition(.numericText(value: total))
                }
            }
        }
        .animation(sinMovimiento ? nil : .smooth(duration: 0.4), value: iva)
        .animation(sinMovimiento ? nil : .smooth(duration: 0.4), value: base)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(nombreBase) \(Formato.euros(base))"
                            + (iva > 0.004 ? ", \(nombreIVA) \(Formato.euros(iva))" : "")
                            + ", total \(Formato.euros(total))")
    }

    private func leyenda(_ color: Color, _ texto: String, _ valor: Double) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: 4) {
                Circle().fill(color).frame(width: 7, height: 7)
                Text(texto).font(.caption2).foregroundStyle(.secondary)
            }
            Text(Formato.euros(valor))
                .font(.caption.weight(.semibold))
                .monospacedDigit()
                .contentTransition(.numericText(value: valor))
        }
    }
}

struct BotonCopiar: View {
    let valor: Double
    @State private var copiado = false

    var body: some View {
        Button {
            #if canImport(UIKit)
            UIPasteboard.general.string = CuentaIVA.paraPegar(valor)
            #endif
            copiado = true
            Task {
                try? await Task.sleep(for: .seconds(1.8))
                copiado = false
            }
        } label: {
            Label(copiado ? "Copiado" : "Copiar",
                  systemImage: copiado ? "checkmark" : "doc.on.doc")
                .contentTransition(.symbolEffect(.replace))
                .fontWeight(.semibold)
        }
        .buttonStyle(.glass)
        .controlSize(.large)        
        .sensoryFeedback(.success, trigger: copiado) { _, nuevo in nuevo }
        .accessibilityLabel(copiado ? "Copiado" : "Copiar \(CuentaIVA.paraPegar(valor)) euros")
    }
}
