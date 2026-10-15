import SwiftUI

struct PantallaPedidos: View {
    var body: some View {

        PedidosMarcador()
    }

    struct Pedido: Identifiable, Equatable {
        let id: String
        let cliente: String
        let tipo: String
        let estado: String
        let estadoTxt: String
        let importe: String
        let creado: String

        var aMano: Bool = false
        var plataforma: String = ""
        var descripcion: String = ""

        var yaCobradoAMano: Bool = false
    }

    static let ordenEstados = ["review", "awaiting_payment_confirm", "approved",
                               "price_proposed", "confirmed", "payment_selected", "paid",
                               "not_received", "rejected", "cancelled", "idle_expired"]

    static func icono(_ e: String) -> String {
        switch e {
        case "paid": return "checkmark"

        case "cancelled": return "nosign"
        case "rejected", "not_received": return "exclamationmark"
        case "review", "awaiting_payment_confirm": return "clock"
        default: return "doc.text"
        }
    }

    static func color(_ e: String) -> Color {
        switch e {
        
        case "paid": return .green
        case "cancelled", "rejected", "not_received": return .red
        case "review", "awaiting_payment_confirm": return .orange
        default: return .gray
        }
    }
}
