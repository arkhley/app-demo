import SwiftUI

enum Herramienta: String, Identifiable, CaseIterable {
    case directo, ocultar, bloquear
    case tokens, adelanto, enlaces, comprobar
    
    case tema
    case asesoria, monedero, plataforma1, plataforma2
    case codigos, videos, plataformas

    var id: String { rawValue }

    enum Grupo: String, CaseIterable {
        case ahora = "Ahora"
        case calcular = "Calcular y compartir"
        case abrir = "Abrir"
        case gestionar = "Gestionar"
    }

    var grupo: Grupo {
        switch self {
        case .directo, .ocultar, .bloquear, .tema: return .ahora
        case .tokens, .adelanto, .enlaces, .comprobar: return .calcular
        case .asesoria, .monedero, .plataforma1, .plataforma2: return .abrir
        case .codigos, .videos, .plataformas: return .gestionar
        }
    }

    var titulo: String {
        switch self {
        case .directo: return "Avisar en directo"
        case .ocultar: return "Ocultar cifras"
        case .bloquear: return "Bloquear"
        case .tokens: return "Tokens y euros"
        case .adelanto: return "Adelanto"
        case .enlaces: return "Enlaces"
        case .comprobar: return "Comprobar"
        case .tema: return "Tema"
        case .asesoria: return "Gestoría"
        case .monedero: return "Monedero"
        case .plataforma1: return "Plataforma 1"
        case .plataforma2: return "Plataforma 2"
        case .codigos: return "Códigos"
        case .videos: return "Vídeos"
        case .plataformas: return "Plataformas"
        }
    }

    func simbolo(activa: Bool) -> String {
        switch self {
        case .directo: return "dot.radiowaves.left.and.right"
        
        case .ocultar: return activa ? "eye.slash.fill" : "eye.fill"
        case .bloquear: return "lock.fill"
        case .tokens: return "arrow.left.arrow.right"
        case .adelanto: return "bolt.fill"
        case .enlaces: return "link"
        case .comprobar: return "checkmark.shield.fill"
        case .tema: return "paintpalette.fill"
        case .asesoria: return "building.columns.fill"
        case .monedero: return "creditcard.fill"
        case .plataforma1, .plataforma2: return "video.fill"
        case .codigos: return "ticket.fill"
        case .videos: return "film.stack.fill"
        case .plataformas: return "square.grid.2x2.fill"
        }
    }

    func color(activa: Bool) -> Color {
        switch self {
        case .directo: return .red
        
        case .ocultar: return activa ? Diseno.azulRelleno : .gray
        case .bloquear: return .gray
        case .tokens: return .green
        case .adelanto: return .indigo
        case .enlaces: return .blue
        case .comprobar: return .teal
        case .tema: return .cyan
        case .asesoria: return .brown
        case .monedero: return .mint
        
        case .plataforma1: return Diseno.colorDePlataforma("plataforma1")
        case .plataforma2: return Diseno.colorDePlataforma("plataforma2")
        case .codigos: return .pink
        case .videos: return .cyan
        case .plataformas: return .gray
        }
    }

    var web: URL? {
        switch self {
        case .asesoria: return URL(string: "https://example.com")
        case .monedero: return URL(string: "https://example.com")
        
        case .plataforma1: return URL(string: "https://example.com")
        case .plataforma2: return URL(string: "https://example.com")
        default: return nil
        }
    }

    var ajuste: AjusteLateral? {
        switch self {
        case .codigos: return .codigos
        case .videos: return .videos
        case .plataformas: return .plataformas
        default: return nil
        }
    }
}

enum HojaHerramienta: String, Identifiable {
    case tokens, adelanto, enlaces, comprobar, tema
    var id: String { rawValue }
}

