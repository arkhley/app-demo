import Foundation
import UIKit
import Vision

enum LectorCapturas {
    struct Linea: Sendable {
        let texto: String
        let x: Double
        let y: Double
        let w: Double
        let h: Double

        var comoDiccionario: [String: any Sendable] {
            ["texto": texto, "x": x, "y": y, "w": w, "h": h]
        }
    }

    static func leer(_ datos: Data) async -> [Linea] {
        await Task.detached(priority: .userInitiated) { () -> [Linea] in
            guard let imagen = UIImage(data: datos), let cg = imagen.cgImage else { return [] }
            let peticion = VNRecognizeTextRequest()
            peticion.recognitionLevel = .accurate
            peticion.recognitionLanguages = ["es-ES", "en-US"]
            
            peticion.usesLanguageCorrection = false
            do {
                try VNImageRequestHandler(cgImage: cg, options: [:]).perform([peticion])
            } catch {
                return []
            }
            return (peticion.results ?? []).compactMap { o in
                guard let texto = o.topCandidates(1).first?.string else { return nil }
                let caja = o.boundingBox        
                return Linea(texto: texto, x: caja.minX, y: 1 - caja.maxY,
                             w: caja.width, h: caja.height)
            }
        }.value
    }
}
