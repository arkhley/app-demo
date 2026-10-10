import Foundation
import WidgetKit
#if canImport(PiezasWidget)
import PiezasWidget
#endif

enum PuenteWidget {

    @MainActor private static var pidiendoLlave = false

    @MainActor
    static func ponerAlDia(testigo: String?) async {
        #if !MAQUETA
        guard let testigo, GrupoCompartido.identificador != nil else { return }
        GrupoCompartido.oculto = Privacidad.compartida.oculta
        guard GrupoCompartido.llave == nil, !pidiendoLlave else { return }
        pidiendoLlave = true
        defer { pidiendoLlave = false }
        if let j = try? await API.pedir("api/widget/testigo", metodo: "POST",
                                        cuerpo: ["aparato": "Widget|Widget de Ingresos β||"],
                                        testigo: testigo),
           let llave = j["testigo"] as? String {
            GrupoCompartido.llave = llave
            WidgetCenter.shared.reloadAllTimelines()
        }
        #endif
    }

    static func guardar(prevision j: [String: Any]) {
        #if !MAQUETA
        guard GrupoCompartido.identificador != nil,
              var nueva = Instantanea(json: j) else { return }
        let antes = GrupoCompartido.ultima
        nueva.generado = Date()
        GrupoCompartido.ultima = nueva
        if antes?.veredicto != nueva.veredicto
            || Int(antes?.hoy.euros ?? -1) != Int(nueva.hoy.euros)
            || antes?.descansos != nueva.descansos {
            WidgetCenter.shared.reloadAllTimelines()
        }
        #endif
    }

    static func ocultar(_ oculta: Bool) {
        #if !MAQUETA
        guard GrupoCompartido.identificador != nil else { return }
        GrupoCompartido.oculto = oculta
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }

    static func olvidar() {
        #if !MAQUETA
        guard GrupoCompartido.identificador != nil else { return }
        if let llave = GrupoCompartido.llave {
            Task { _ = try? await API.pedir("api/widget/salir", metodo: "POST", testigo: llave) }
        }
        GrupoCompartido.olvidar()
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }
}
