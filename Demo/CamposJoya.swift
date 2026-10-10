import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

enum Joya {
    case agenda, sala, cobros, impuestos

    case plataforma1, plataforma2, tienda, todo

    static func de(_ plataforma: String) -> Joya {
        switch plataforma {
        case "plataforma1": .plataforma1
        case "plataforma2": .plataforma2
        case "tienda": .tienda
        case "todo", "todas": .todo
        default: .impuestos
        }
    }

    var tonos: [Color] {
        switch self {

        case .agenda: [tono(0xD3DCF2, 0x1A2442), tono(0xC0CDEE, 0x25345C), tono(0xE2E8F7, 0x111A31)]
        case .sala: [tono(0xEFD9DE, 0x3A1322), tono(0xE4C3CC, 0x531B31), tono(0xF6E8EB, 0x260E18)]
        case .cobros: [tono(0xD5E9DE, 0x0E3428), tono(0xC1DECF, 0x165141), tono(0xE6F2EB, 0x0A251D)]
        case .impuestos: [tono(0xDADFE7, 0x22262D), tono(0xBDC6D3, 0x2F353F), tono(0xE7EAF0, 0x181B20)]

        case .plataforma1: [tono(0xF6E0D3, 0x3B1B14), tono(0xF0CDBC, 0x55271C), tono(0xFAECE3, 0x26120E)]
        
        case .plataforma2: [tono(0xEBDDF1, 0x2D1736), tono(0xDDC8EA, 0x43214F), tono(0xF3EAF7, 0x1D0F24)]
        
        case .tienda: [tono(0xD5E8F3, 0x0F2A3B), tono(0xC0DCEE, 0x163D55), tono(0xE4F1F8, 0x0A1C28)]
        
        case .todo: [tono(0xD3EBE7, 0x0E302D), tono(0xBEE1DB, 0x154540), tono(0xE3F3F0, 0x0A211F)]
        }
    }

    var luz: Color {
        switch self {
        case .agenda: tono(0xF6E6C4, 0xD9C08C)

        case .sala: tono(0xF4DCE6, 0xC27A95)
        case .cobros: tono(0xF2FAF5, 0xA8D8C0)

        case .impuestos: tono(0xBCCADB, 0x9DB2C9)

        case .plataforma1: tono(0xF7D9BF, 0xD9946A)
        case .plataforma2: tono(0xEEDCF7, 0xB48AD6)
        case .tienda: tono(0xE2F2FB, 0x6A9FC6)
        case .todo: tono(0xE1F5F1, 0x6CA99E)
        }
    }

    static let luzAtrasada = tono(0xF5C9C4, 0xD9706A)
    
    static let luzAlDia = tono(0xEAF3FF, 0x8FB4E8)
    
    static let luzDirecto = tono(0xF7C5C5, 0xE05555)
}

private func tono(_ claro: UInt32, _ oscuro: UInt32) -> Color {
    Color(UIColor { entorno in
        let rgb = entorno.userInterfaceStyle == .dark ? oscuro : claro
        return UIColor(red: CGFloat((rgb >> 16) & 0xFF) / 255,
                       green: CGFloat((rgb >> 8) & 0xFF) / 255,
                       blue: CGFloat(rgb & 0xFF) / 255, alpha: 1)
    })
}

struct CampoJoya: View {
    let joya: Joya
    
    var luz: Color?
    
    var late = false

    @Environment(\.colorScheme) private var modo
    @Environment(\.accessibilityReduceMotion) private var menosMovimiento
    @Environment(\.accessibilityReduceTransparency) private var menosTransparencia

    @Environment(\.tema) private var tema

    var body: some View {
        ZStack {
            if tema.esDeFoto {
                FondoDeFoto()
                if luz != nil { soloLaLuz }
            } else if tema.esOriginal {
                campo.id(tema.id)
            } else {
                
                FondoDeTema(sitio: .joya(joya, luz: luz, late: late))
                    .id(tema.id)
            }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }

    private var campo: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: menosMovimiento)) { t in
            let s = menosMovimiento ? 0 : t.date.timeIntervalSinceReferenceDate
            GeometryReader { g in
                ZStack {
                    MeshGradient(width: 3, height: 4, points: puntos(Float(s)), colors: colores)
                    luzQuePasea(s: s, en: g.size)
                }
            }
        }
        .opacity(menosTransparencia ? 0.6 : 1)
    }

    private var soloLaLuz: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: menosMovimiento)) { t in
            let s = menosMovimiento ? 0 : t.date.timeIntervalSinceReferenceDate
            GeometryReader { g in
                luzQuePasea(s: s, en: g.size)
            }
        }
    }

    private func puntos(_ s: Float) -> [SIMD2<Float>] {
        let y1: Float = 0.24 + 0.03 * sin(s * 0.4)
        let cx: Float = 0.5 + 0.08 * sin(s * 0.27)
        let cy: Float = 0.27 + 0.04 * cos(s * 0.33)
        let y3: Float = 0.22 + 0.03 * cos(s * 0.37)
        let mx: Float = 0.5 + 0.05 * cos(s * 0.23)
        return [[0, 0], [0.5, 0], [1, 0],
                [0, y1], [cx, cy], [1, y3],
                [0, 0.52], [mx, 0.56], [1, 0.5],
                [0, 1], [0.5, 1], [1, 1]]
    }

    private var colores: [Color] {
        let a = tema.tonosDeLaJoya(joya) ?? joya.tonos
        let base = tema.colorDeFondo
        let medio = a.map { $0.mix(with: base, by: 0.5) }
        return [a[0], a[1], a[2],
                a[2], a[0], a[1],
                medio[1], medio[2], medio[0],
                base, base, base]
    }

    private func luzQuePasea(s: Double, en tam: CGSize) -> some View {
        let color = luz ?? tema.luz?.color ?? joya.luz
        let latido = late && !menosMovimiento ? 0.75 + 0.25 * sin(s * 2.4) : 1
        let x = 0.5 + 0.28 * sin(s * 0.11)
        let y = 0.1 + 0.05 * cos(s * 0.16)

        let fuerza = (modo == .dark ? 0.34 : 0.3) * latido
        return RadialGradient(colors: [color.opacity(fuerza), color.opacity(0)],
                              center: UnitPoint(x: x, y: y),
                              startRadius: 0, endRadius: max(tam.width, 1) * 0.75)
            .blendMode(modo == .dark ? .plusLighter : .normal)
            
            .mask {
                LinearGradient(stops: [.init(color: .black, location: 0),
                                       .init(color: .black, location: 0.3),
                                       .init(color: .clear, location: 0.58)],
                               startPoint: .top, endPoint: .bottom)
            }
    }
}

extension View {

    @ViewBuilder
    func fondoDeCampo(_ joya: Joya) -> some View {
        self.scrollEdgeEffectStyle(.soft, for: .top)
            .background { CampoJoya(joya: joya) }
            .environment(\.enCampo, true)
    }
}

struct EstiloApoyo: ShapeStyle {
    func resolve(in entorno: EnvironmentValues) -> AnyShapeStyle {
        entorno.enCampo ? AnyShapeStyle(Marcador.apoyo) : AnyShapeStyle(.secondary)
    }
}

extension ShapeStyle where Self == EstiloApoyo {
    
    static var apoyo: EstiloApoyo { EstiloApoyo() }
}
