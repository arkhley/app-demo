import SwiftUI

enum AjusteLateral: String, Identifiable, Hashable, CaseIterable {
    case codigos, videos, compras, plataformas

    var id: String { rawValue }

    var simbolo: String {
        switch self {
        case .codigos: return "ticket.fill"
        case .videos: return "camera.fill"
        case .compras: return "creditcard.fill"
        case .plataformas: return "apps.iphone"
        }
    }

    var color: Color {
        switch self {
        case .codigos, .plataformas: return .blue
        case .videos, .compras: return .gray
        }
    }

    var titulo: String {
        switch self {
        case .codigos: return "Códigos"
        case .videos: return "Vídeos"
        case .compras: return "Contenido y compras"
        case .plataformas: return "Gestión de plataformas"
        }
    }
}

