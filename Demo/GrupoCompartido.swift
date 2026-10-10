import Foundation

public enum GrupoCompartido {
    
    public static var identificador: String? {
        (Bundle.main.object(forInfoDictionaryKey: "ALTAppGroups") as? [String])?.first
    }

    private static var almacen: UserDefaults? {
        identificador.flatMap { UserDefaults(suiteName: $0) }
    }

    private enum Clave {
        static let llave = "widget.llave"
        static let oculto = "widget.oculto"
        static let ultima = "widget.ultima"
    }

    public static var llave: String? {
        get { almacen?.string(forKey: Clave.llave) }
        set {
            if let newValue { almacen?.set(newValue, forKey: Clave.llave) }
            else { almacen?.removeObject(forKey: Clave.llave) }
        }
    }

    public static var oculto: Bool {
        get { almacen?.bool(forKey: Clave.oculto) ?? false }
        set { almacen?.set(newValue, forKey: Clave.oculto) }
    }

    public static var ultima: Instantanea? {
        get {
            guard let datos = almacen?.data(forKey: Clave.ultima) else { return nil }
            return try? JSONDecoder().decode(Instantanea.self, from: datos)
        }
        set {
            if let newValue, let datos = try? JSONEncoder().encode(newValue) {
                almacen?.set(datos, forKey: Clave.ultima)
            } else {
                almacen?.removeObject(forKey: Clave.ultima)
            }
        }
    }

    public static func olvidar() {
        llave = nil
        ultima = nil
    }
}
