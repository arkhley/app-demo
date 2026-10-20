import SwiftUI
import UniformTypeIdentifiers

struct ResultadoExcel: Equatable {
    let errores: Int
    let avisos: Int
    
    let anadidos: Int
    
    let apuntadas: Int
    
    let trimestre: String

    init(_ j: [String: Any]) {
        trimestre = j["trimestre"] as? String ?? ""
        errores = (j["errores"] as? NSNumber)?.intValue ?? 0
        avisos = (j["avisos"] as? NSNumber)?.intValue ?? 0
        let hecho = (j["hecho"] as? [String]) ?? []
        anadidos = hecho.filter { $0.hasPrefix("Añadido") }.count
        apuntadas = hecho.filter { $0.hasPrefix("Apuntad") }.count
    }

    var hechoSolo: String? {
        var partes: [String] = []
        if anadidos > 0 {
            partes.append("\(anadidos) \(anadidos == 1 ? "gasto añadido" : "gastos añadidos") a la app")
        }
        if apuntadas > 0 {
            partes.append("\(apuntadas) \(apuntadas == 1 ? "factura apuntada" : "facturas apuntadas")")
        }
        return partes.isEmpty ? nil : partes.joined(separator: " · ")
    }

    var resumen: String {
        var partes: [String] = []
        if errores == 0 && avisos == 0 {
            partes.append("Todo cuadra con la gestoría")
        } else {
            if errores > 0 { partes.append("\(errores) \(errores == 1 ? "cosa no cuadra" : "cosas no cuadran")") }
            if avisos > 0 { partes.append("\(avisos) por subir o sin factura") }
        }
        if let h = hechoSolo { partes.append(h) }
        return partes.joined(separator: " · ") + "."
    }
}

enum FinDelExcel {
    case revisado(ResultadoExcel)
    case fallo(String)
    
    case sinArchivo

    static let sinSesion = "Si Safari dijo «No autorizado», entra en la gestoría en Safari y vuelve a darle."
}

@Observable @MainActor
final class ViajeDelExcel {
    
    fileprivate(set) var subiendo = false
    
    fileprivate var esperando = false

    fileprivate var salio = false
    fileprivate var eligiendo = false
    
    fileprivate var trasDescargar = false
    fileprivate var trimestre = ""

    func descargar(_ enlace: URL, trimestre: String, con abrir: OpenURLAction) {
        self.trimestre = trimestre
        esperando = true
        salio = false
        abrir(enlace) { [weak self] abierto in
            
            guard !abierto else { return }
            Task { @MainActor in self?.esperando = false }
        }
    }

    func elegir(trimestre: String) {
        self.trimestre = trimestre
        trasDescargar = false
        eligiendo = true
    }
}

extension View {
    
    func subidaDelExcel(_ viaje: ViajeDelExcel,
                        alAcabar: @escaping (FinDelExcel) async -> Void) -> some View {
        modifier(SubidaDelExcel(viaje: viaje, alAcabar: alAcabar))
    }
}

private struct SubidaDelExcel: ViewModifier {
    @Bindable var viaje: ViajeDelExcel
    let alAcabar: (FinDelExcel) async -> Void

    @Environment(Sesion.self) private var sesion
    @Environment(\.scenePhase) private var fase

    func body(content: Content) -> some View {
        content
            .fileImporter(isPresented: $viaje.eligiendo, allowedContentTypes: tipos,
                          allowsMultipleSelection: false) { resultado in
                Task { await subir(resultado) }
            } onCancellation: {
                if viaje.trasDescargar {
                    viaje.trasDescargar = false
                    Task { await alAcabar(.sinArchivo) }
                }
            }
            .onChange(of: fase) { _, nueva in
                if nueva == .background, viaje.esperando { viaje.salio = true }
                if nueva == .active, viaje.esperando, viaje.salio {
                    viaje.esperando = false
                    viaje.salio = false
                    viaje.trasDescargar = true
                    viaje.eligiendo = true
                }
            }
    }

    private var tipos: [UTType] {
        [UTType("org.openxmlformats.spreadsheetml.sheet") ?? .data]
    }

    private func subir(_ resultado: Result<[URL], Error>) async {
        viaje.trasDescargar = false
        guard case .success(let urls) = resultado, let url = urls.first else { return }
        let acceso = url.startAccessingSecurityScopedResource()
        defer { if acceso { url.stopAccessingSecurityScopedResource() } }
        guard let datos = try? Data(contentsOf: url) else {
            await alAcabar(.fallo("No se ha podido leer ese archivo."))
            return
        }
        viaje.subiendo = true
        defer { viaje.subiendo = false }
        do {
            let j = try await API.subirExcel(datos, nombre: url.lastPathComponent,
                                             trimestre: viaje.trimestre, tipo: "iva",
                                             testigo: sesion.testigo)
            await alAcabar(.revisado(ResultadoExcel(j)))
        } catch {
            await alAcabar(.fallo(error.localizedDescription))
        }
    }
}
