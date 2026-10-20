import Foundation

enum TexturaDeTema: String, Sendable, CaseIterable, Hashable {
    case papel, kraft, washi, lino, vaquero, terciopelo, marmol, madera, hormigon, pizarra
    case acuarela, libreta, cianotipo, cuero, arena, carbono, escarcha

    var numero: UInt64 {
        switch self {
        case .papel: 0
        case .kraft: 1
        case .washi: 2
        case .lino: 3
        case .vaquero: 4
        case .terciopelo: 5
        case .marmol: 6
        case .madera: 7
        case .hormigon: 8
        case .pizarra: 9
        case .acuarela: 12
        case .libreta: 13
        case .cianotipo: 14
        case .cuero: 15
        case .arena: 16
        case .carbono: 18
        case .escarcha: 19
        }
    }
}

struct PeticionDeTextura: Sendable, Hashable {
    let textura: TexturaDeTema
    let ancho: Int
    let alto: Int
    let pxPorPunto: Float
    
    let base: UInt32
    
    let veta: UInt32
    
    let extra: [UInt32]
    let oscuro: Bool
}

enum GeneradorDeTexturas {
    
    static let version = 1

    nonisolated static func pixeles(_ p: PeticionDeTextura) -> [UInt8] {
        let c = Contexto(p)
        switch p.textura {
        case .papel: papel(c)
        case .kraft: kraft(c)
        case .washi: washi(c)
        case .lino: lino(c)
        case .vaquero: vaquero(c)
        case .terciopelo: terciopelo(c)
        case .marmol: marmol(c)
        case .madera: madera(c)
        case .hormigon: hormigon(c)
        case .pizarra: pizarra(c)
        case .acuarela: acuarela(c)
        case .libreta: libreta(c)
        case .cianotipo: cianotipo(c)
        case .cuero: cuero(c)
        case .arena: arena(c)
        case .carbono: carbono(c)
        case .escarcha: escarcha(c)
        }
        return c.rgba()
    }
}

private struct RGB {
    var r: Float, g: Float, b: Float

    init(_ r: Float, _ g: Float, _ b: Float) { self.r = r; self.g = g; self.b = b }

    init(hex: UInt32) {
        r = Float((hex >> 16) & 0xFF) / 255
        g = Float((hex >> 8) & 0xFF) / 255
        b = Float(hex & 0xFF) / 255
    }

    static func * (a: RGB, k: Float) -> RGB { RGB(a.r * k, a.g * k, a.b * k) }
    static func + (a: RGB, b: RGB) -> RGB { RGB(a.r + b.r, a.g + b.g, a.b + b.b) }

    func mezcla(_ o: RGB, _ t: Float) -> RGB {
        RGB(r + (o.r - r) * t, g + (o.g - g) * t, b + (o.b - b) * t)
    }

    var luz: Float { 0.2126 * r + 0.7152 * g + 0.0722 * b }
}

private struct Azar {
    var s: UInt64

    mutating func siguiente() -> UInt64 {
        s &+= 0x9E37_79B9_7F4A_7C15
        var z = s
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    mutating func uno() -> Float { Float(siguiente() >> 40) / Float(1 << 24) }

    mutating func entre(_ a: Float, _ b: Float) -> Float { a + (b - a) * uno() }
}

@inline(__always)
private func hash(_ x: Int32, _ y: Int32, _ s: UInt32) -> UInt32 {
    var h = UInt32(bitPattern: x) &* 0x8DA6_B343 ^ UInt32(bitPattern: y) &* 0xD816_3841 ^ s &* 0xCB1A_B31F
    h ^= h >> 13
    h = h &* 0x5BD1_E995
    h ^= h >> 15
    return h
}

@inline(__always)
private func azar01(_ x: Int32, _ y: Int32, _ s: UInt32) -> Float {
    Float(hash(x, y, s) >> 8) / Float(1 << 24)
}

@inline(__always)
private func suave(_ a: Float, _ b: Float, _ x: Float) -> Float {
    let t = min(max((x - a) / (b - a), 0), 1)
    return t * t * (3 - 2 * t)
}

@inline(__always)
private func fraccion(_ x: Float) -> Float { x - x.rounded(.down) }

private final class Ruido {
    private let p: UnsafeMutablePointer<Int32>

    init(semilla: UInt64) {
        p = .allocate(capacity: 512)
        var a = Azar(s: semilla)
        var tabla = Array(Int32(0)..<256)
        for i in stride(from: 255, to: 0, by: -1) {
            let j = Int(a.siguiente() % UInt64(i + 1))
            tabla.swapAt(i, j)
        }
        for i in 0..<512 { p[i] = tabla[i & 255] }
    }

    deinit { p.deallocate() }

    @inline(__always)
    private func grad(_ h: Int32, _ x: Float, _ y: Float) -> Float {
        switch h & 7 {
        case 0: return x + y
        case 1: return -x + y
        case 2: return x - y
        case 3: return -x - y
        case 4: return x
        case 5: return -x
        case 6: return y
        default: return -y
        }
    }

    @inline(__always)
    func perlin(_ x: Float, _ y: Float) -> Float {
        let fx = x.rounded(.down), fy = y.rounded(.down)
        let xi = Int32(truncatingIfNeeded: Int(fx)) & 255
        let yi = Int32(truncatingIfNeeded: Int(fy)) & 255
        let xf = x - fx, yf = y - fy
        let u = xf * xf * xf * (xf * (xf * 6 - 15) + 10)
        let v = yf * yf * yf * (yf * (yf * 6 - 15) + 10)
        let a = p[Int(xi)] + yi, b = p[Int(xi) + 1] + yi
        let aa = p[Int(a)], ab = p[Int(a) + 1], ba = p[Int(b)], bb = p[Int(b) + 1]
        let x1 = grad(aa, xf, yf) + (grad(ba, xf - 1, yf) - grad(aa, xf, yf)) * u
        let x2 = grad(ab, xf, yf - 1) + (grad(bb, xf - 1, yf - 1) - grad(ab, xf, yf - 1)) * u
        return (x1 + (x2 - x1) * v) * 0.7
    }

    @inline(__always)
    func fbm(_ x: Float, _ y: Float, _ octavas: Int, ganancia: Float = 0.5) -> Float {
        var suma: Float = 0, amp: Float = 1, f: Float = 1, total: Float = 0
        for o in 0..<octavas {
            
            let d = Float(o) * 17.31
            suma += amp * perlin(x * f + d, y * f - d * 0.7)
            total += amp
            amp *= ganancia
            f *= 2.03
        }
        return suma / total
    }

    @inline(__always)
    func crestas(_ x: Float, _ y: Float, _ octavas: Int) -> Float {
        var suma: Float = 0, amp: Float = 1, f: Float = 1, total: Float = 0
        for o in 0..<octavas {
            let d = Float(o) * 9.7
            let r = 1 - abs(perlin(x * f + d, y * f + d * 0.3))
            suma += amp * r * r
            total += amp
            amp *= 0.55
            f *= 2.1
        }
        return suma / total
    }
}

@inline(__always)
private func celdas(_ x: Float, _ y: Float, _ s: UInt32, jitter: Float = 0.85) -> (f1: Float, f2: Float, id: UInt32) {
    let cx = Int32(truncatingIfNeeded: Int(x.rounded(.down)))
    let cy = Int32(truncatingIfNeeded: Int(y.rounded(.down)))
    var f1: Float = 9, f2: Float = 9, id: UInt32 = 0
    for dy in Int32(-1)...1 {
        for dx in Int32(-1)...1 {
            let ix = cx &+ dx, iy = cy &+ dy
            let h = hash(ix, iy, s)
            let px = Float(ix) + 0.5 + (Float(h & 0xFFFF) / 65535 - 0.5) * jitter
            let py = Float(iy) + 0.5 + (Float(h >> 16) / 65535 - 0.5) * jitter
            let ddx = px - x, ddy = py - y
            let d = (ddx * ddx + ddy * ddy).squareRoot()
            if d < f1 { f2 = f1; f1 = d; id = h } else if d < f2 { f2 = d }
        }
    }
    return (f1, f2, id)
}

private struct Enviable<T>: @unchecked Sendable {
    let valor: T
    init(_ valor: T) { self.valor = valor }
}

private final class Contexto {
    let w: Int, h: Int, n: Int
    
    let s: Float
    let base: RGB, veta: RGB
    let extra: [RGB]
    let oscuro: Bool
    let ruido: Ruido
    var azar: Azar
    let semilla: UInt32
    let r: UnsafeMutablePointer<Float>
    let g: UnsafeMutablePointer<Float>
    let b: UnsafeMutablePointer<Float>

    init(_ p: PeticionDeTextura) {
        w = max(p.ancho, 1); h = max(p.alto, 1); n = w * h
        s = max(p.pxPorPunto, 0.05)
        base = RGB(hex: p.base); veta = RGB(hex: p.veta)
        extra = p.extra.map(RGB.init(hex:))
        oscuro = p.oscuro
        
        let clave = p.textura.numero &* 0x1000_0000_01B3 &+ (p.oscuro ? 7 : 3)
        ruido = Ruido(semilla: clave)
        azar = Azar(s: clave &* 31 &+ 11)
        semilla = UInt32(truncatingIfNeeded: clave &* 2_654_435_761)
        r = .allocate(capacity: n); g = .allocate(capacity: n); b = .allocate(capacity: n)
        pintar { _, _ in base }
    }

    deinit { r.deallocate(); g.deallocate(); b.deallocate() }

    var areaEnPuntos: Float { Float(n) / (s * s) }

    func porFilas(_ cuerpo: (Int) -> Void) {
        let bandas = max(1, min(h / 24, ProcessInfo.processInfo.activeProcessorCount * 3))
        let alto = h
        withoutActuallyEscaping(cuerpo) { cuerpo in
            
            let trabajo = Enviable(cuerpo)
            DispatchQueue.concurrentPerform(iterations: bandas) { banda in
                let y0 = banda * alto / bandas, y1 = (banda + 1) * alto / bandas
                for y in y0..<y1 { trabajo.valor(y) }
            }
        }
    }

    func pintar(_ f: (Float, Float) -> RGB) {
        let k = 1 / s
        let w = w, r = r, g = g, b = b
        porFilas { y in
            let py = (Float(y) + 0.5) * k
            let fila = y * w
            for x in 0..<w {
                let c = f((Float(x) + 0.5) * k, py)
                r[fila + x] = c.r; g[fila + x] = c.g; b[fila + x] = c.b
            }
        }
    }

    func retocar(_ f: (Float, Float, Int, RGB) -> RGB) {
        let k = 1 / s
        let w = w, r = r, g = g, b = b
        porFilas { y in
            let py = (Float(y) + 0.5) * k
            let fila = y * w
            for x in 0..<w {
                let i = fila + x
                let c = f((Float(x) + 0.5) * k, py, i, RGB(r[i], g[i], b[i]))
                r[i] = c.r; g[i] = c.g; b[i] = c.b
            }
        }
    }

    func llenar(_ destino: UnsafeMutablePointer<Float>, _ f: (Int, Int) -> Float) {
        let w = w
        porFilas { y in
            for x in 0..<w { destino[y * w + x] = f(x, y) }
        }
    }

    func campo(paso: Int = 4, _ f: (Float, Float) -> Float) -> UnsafeMutablePointer<Float> {
        let gw = w / paso + 2, gh = h / paso + 2
        let rejilla = UnsafeMutablePointer<Float>.allocate(capacity: gw * gh)
        defer { rejilla.deallocate() }
        let k = Float(paso) / s
        let bandas = max(1, min(gh, ProcessInfo.processInfo.activeProcessorCount * 3))
        withoutActuallyEscaping(f) { f in
            let trabajo = Enviable((f, rejilla))
            DispatchQueue.concurrentPerform(iterations: bandas) { banda in
                let (f, rejilla) = trabajo.valor
                for gy in (banda * gh / bandas)..<((banda + 1) * gh / bandas) {
                    for gx in 0..<gw { rejilla[gy * gw + gx] = f(Float(gx) * k, Float(gy) * k) }
                }
            }
        }
        let salida = UnsafeMutablePointer<Float>.allocate(capacity: n)
        let inv = 1 / Float(paso)
        let w = w
        porFilas { y in
            let fy = Float(y) * inv
            let y0 = min(Int(fy), gh - 2), ty = fy - Float(y0)
            for x in 0..<w {
                let fx = Float(x) * inv
                let x0 = min(Int(fx), gw - 2), tx = fx - Float(x0)
                let a = rejilla[y0 * gw + x0], b = rejilla[y0 * gw + x0 + 1]
                let c = rejilla[(y0 + 1) * gw + x0], d = rejilla[(y0 + 1) * gw + x0 + 1]
                let arriba = a + (b - a) * tx, abajo = c + (d - c) * tx
                salida[y * w + x] = arriba + (abajo - arriba) * ty
            }
        }
        return salida
    }

    func buffer() -> UnsafeMutablePointer<Float> {
        let p = UnsafeMutablePointer<Float>.allocate(capacity: n)
        p.initialize(repeating: 0, count: n)
        return p
    }

    func relieve(_ altura: UnsafeMutablePointer<Float>, fuerza: Float) -> UnsafeMutablePointer<Float> {
        let out = buffer()
        let w = w, h = h
        porFilas { y in
            guard y > 0, y < h - 1 else { return }
            for x in 1..<(w - 1) {
                let i = y * w + x
                let gx = altura[i + 1] - altura[i - 1]
                let gy = altura[i + w] - altura[i - w]
                out[i] = -(gx * 0.7071 + gy * 0.7071) * fuerza
            }
        }
        return out
    }

    func fibra(en destino: UnsafeMutablePointer<Float>, x: Float, y: Float, angulo: Float, largo: Float,
               curva: Float, grosor: Float, intensidad: Float) {
        var px = x * s, py = y * s, a = angulo
        let pasos = max(Int(largo * s * 2), 2)
        let dCurva = curva / Float(pasos)
        let radio = max(grosor * 0.5, 0.35)
        for k in 0..<pasos {
            
            let t = Float(k) / Float(pasos - 1)
            let punta = min(t, 1 - t) * 4
            let fuerza = intensidad * min(punta, 1)
            depositar(destino, px, py, radio, fuerza)
            px += cos(a) * 0.5
            py += sin(a) * 0.5
            a += dCurva
        }
    }

    @inline(__always)
    private func depositar(_ d: UnsafeMutablePointer<Float>, _ x: Float, _ y: Float, _ radio: Float, _ v: Float) {
        let x0 = Int((x - radio).rounded(.down)), x1 = Int((x + radio).rounded(.up))
        let y0 = Int((y - radio).rounded(.down)), y1 = Int((y + radio).rounded(.up))
        guard x1 >= 0, y1 >= 0, x0 < w, y0 < h else { return }
        let r2 = (radio + 0.5) * (radio + 0.5)
        for yy in max(y0, 0)...min(y1, h - 1) {
            let dy = Float(yy) + 0.5 - y
            for xx in max(x0, 0)...min(x1, w - 1) {
                let dx = Float(xx) + 0.5 - x
                let d2 = dx * dx + dy * dy
                if d2 < r2 {
                    let peso = 1 - d2 / r2
                    d[yy * w + xx] += v * peso * 0.5
                }
            }
        }
    }

    func rgba() -> [UInt8] {
        var out = [UInt8](repeating: 255, count: n * 4)
        out.withUnsafeMutableBufferPointer { o in
            for i in 0..<n {
                o[i * 4] = UInt8(min(max(r[i], 0), 1) * 255 + 0.5)
                o[i * 4 + 1] = UInt8(min(max(g[i], 0), 1) * 255 + 0.5)
                o[i * 4 + 2] = UInt8(min(max(b[i], 0), 1) * 255 + 0.5)
            }
        }
        return out
    }
}

extension GeneradorDeTexturas {

    fileprivate nonisolated static func papel(_ c: Contexto, fibras densidad: Float = 1, nubes: Float = 1) {
        let r = c.ruido
        let formacion = c.campo { x, y in r.fbm(x / 34, y / 34, 4) }
        let altura = c.buffer()
        let s = c.s, semilla = c.semilla
        c.llenar(altura) { x, y in
            let px = Float(x) / s, py = Float(y) / s
            return 0.55 * r.fbm(px / 2.6, py / 2.6, 3) + 0.25 * (azar01(Int32(x), Int32(y), semilla) - 0.5)
        }
        let luz = c.relieve(altura, fuerza: c.oscuro ? 0.11 : 0.055)
        let fibras = c.buffer()
        let cuantas = Int(c.areaEnPuntos / 11 * densidad)
        for _ in 0..<cuantas {
            let clara = c.azar.uno() < (c.oscuro ? 0.75 : 0.45)
            let fuerza = c.azar.entre(0.022, 0.07) * (clara ? 1 : -0.85) * (c.oscuro ? 2.2 : 1)
            c.fibra(en: fibras, x: c.azar.entre(0, Float(c.w) / c.s), y: c.azar.entre(0, Float(c.h) / c.s),
                    angulo: c.azar.entre(0, 2 * .pi), largo: c.azar.entre(2.5, 11), curva: c.azar.entre(-1.4, 1.4),
                    grosor: c.azar.entre(0.45, 0.9), intensidad: fuerza)
        }
        let base = c.base, veta = c.veta
        c.retocar { _, _, i, _ in
            let f = formacion[i]
            var col = base.mezcla(veta, max(0, f) * 0.35 * nubes)
            let k = 1 + f * 0.045 * nubes + luz[i] + fibras[i]
            col = col * k
            return col
        }
        formacion.deallocate(); altura.deallocate(); luz.deallocate(); fibras.deallocate()
    }

    fileprivate nonisolated static func kraft(_ c: Contexto) {
        papel(c, fibras: 1.6, nubes: 1.8)
        let fibras = c.buffer()
        let cuantas = Int(c.areaEnPuntos / 30)
        for _ in 0..<cuantas {
            c.fibra(en: fibras, x: c.azar.entre(0, Float(c.w) / c.s), y: c.azar.entre(0, Float(c.h) / c.s),
                    angulo: c.azar.entre(0, 2 * .pi), largo: c.azar.entre(5, 18), curva: c.azar.entre(-1, 1),
                    grosor: c.azar.entre(0.5, 1.1), intensidad: c.azar.entre(0.05, 0.13))
        }
        let veta = c.veta
        let semilla = c.semilla &+ 99
        c.retocar { x, y, i, col in
            var out = col.mezcla(veta, min(fibras[i], 1))
            
            if azar01(Int32(x * 1.3), Int32(y * 1.3), semilla) > 0.9965 { out = out * 1.12 }
            return out
        }
        fibras.deallocate()
    }

    fileprivate nonisolated static func washi(_ c: Contexto) {
        let r = c.ruido
        let nubes = c.campo { x, y in r.fbm(x / 48, y / 48, 4) }
        let fibras = c.buffer()
        let cuantas = Int(c.areaEnPuntos / 90)
        for _ in 0..<cuantas {
            c.fibra(en: fibras, x: c.azar.entre(-10, Float(c.w) / c.s), y: c.azar.entre(-10, Float(c.h) / c.s),
                    angulo: c.azar.entre(0, 2 * .pi), largo: c.azar.entre(10, 42), curva: c.azar.entre(-3, 3),
                    grosor: c.azar.entre(0.4, 0.8), intensidad: c.azar.entre(0.03, 0.08) * (c.oscuro ? 1.2 : 1))
        }
        
        let capas = c.extra.prefix(3).map { _ in c.buffer() }
        if !capas.isEmpty {
            for k in 0..<Int(c.areaEnPuntos / 2200) {
                c.fibra(en: capas[k % capas.count], x: c.azar.entre(0, Float(c.w) / c.s),
                        y: c.azar.entre(0, Float(c.h) / c.s), angulo: c.azar.entre(0, 2 * .pi),
                        largo: c.azar.entre(14, 40), curva: c.azar.entre(-2.5, 2.5), grosor: 0.9, intensidad: 1)
            }
        }
        let base = c.base, extra = c.extra, veta = c.veta
        c.retocar { _, _, i, _ in
            let n = nubes[i]
            var col = base.mezcla(veta, max(0, -n) * 0.5) * (1 + n * 0.05) * (1 + fibras[i])
            for (k, capa) in capas.enumerated() where capa[i] > 0.01 {
                col = col.mezcla(extra[k], min(capa[i], 1) * 0.5)
            }
            return col
        }
        nubes.deallocate(); fibras.deallocate(); capas.forEach { $0.deallocate() }
    }

    fileprivate nonisolated static func lino(_ c: Contexto) {
        let r = c.ruido
        let paso: Float = 2.1
        let base = c.base, veta = c.veta
        let nubes = c.campo { x, y in r.fbm(x / 60, y / 60, 3) }
        let contraste: Float = c.oscuro ? 0.55 : 0.2
        c.retocar { x, y, i, _ in
            let fila = (y / paso).rounded(.down), col = (x / paso).rounded(.down)
            let fy = fraccion(y / paso), fx = fraccion(x / paso)
            
            let grosorH = 0.7 + 0.6 * max(0, r.perlin(x / 9, fila * 3.7))
            let grosorV = 0.7 + 0.6 * max(0, r.perlin(col * 3.1, y / 9))
            let hiloH = pow(max(0, sin(fy * .pi)), 1.3) * grosorH
            let hiloV = pow(max(0, sin(fx * .pi)), 1.3) * grosorV
            let arribaH = (Int(fila) + Int(col)) & 1 == 0
            let v = min(arribaH ? max(hiloH, hiloV * 0.5) : max(hiloV, hiloH * 0.5), 1.2)
            let pelusa = (azar01(Int32(x * 3), Int32(y * 3), 5) - 0.5) * 0.05
            let k = 1 - contraste * 0.6 + contraste * v + pelusa + nubes[i] * 0.04
            return base.mezcla(veta, (1 - min(v, 1)) * 0.45) * k
        }
        nubes.deallocate()
    }

    fileprivate nonisolated static func vaquero(_ c: Contexto) {
        let r = c.ruido
        let base = c.base, veta = c.veta
        let lavado = c.campo { x, y in r.fbm(x / 46, y / 70, 4) }
        let semilla = c.semilla
        c.retocar { x, y, i, _ in
            let d = (x + y * 0.55) / 1.55
            let costilla = pow(0.5 + 0.5 * sin(d * 2 * .pi), 1.5)
            
            let urdimbre = 0.5 + 0.5 * r.perlin(x * 1.8, y / 16)
            let asoma = azar01(Int32(x * 2.2), Int32(y * 2.2), semilla) > 0.93 ? Float(0.16) : 0
            let azul = 0.5 + 0.42 * costilla + 0.14 * (urdimbre - 0.5) - asoma
            let claro = max(0, lavado[i]) * 0.5
            return veta.mezcla(base, min(max(azul - claro, 0), 1))
        }
        lavado.deallocate()
    }

    fileprivate nonisolated static func terciopelo(_ c: Contexto) {
        let r = c.ruido
        let base = c.base, veta = c.veta
        let brillo = c.campo { x, y in
            let qx = r.fbm(x / 110, y / 110, 3), qy = r.fbm(x / 110 + 5.2, y / 110 + 1.3, 3)
            return r.fbm(x / 70 + 3 * qx, y / 70 + 3 * qy, 4)
        }
        c.retocar { x, y, i, _ in
            let s = brillo[i]
            let pelo = (azar01(Int32(x * 2), Int32(y * 2), 3) - 0.5) * 0.03
            let k = 0.84 + 0.42 * (s * 0.5 + 0.5) + pelo
            return base.mezcla(veta, max(0, s) * 0.45) * k
        }
        brillo.deallocate()
    }

    fileprivate nonisolated static func marmol(_ c: Contexto) {
        let r = c.ruido
        let base = c.base, veta = c.veta
        let fase = c.campo(paso: 2) { x, y in
            (x * 0.62 + y * 0.78) / 150 + 1.05 * r.fbm(x / 170, y / 170, 5)
        }
        let grosor = c.campo(paso: 4) { x, y in 0.5 + 0.5 * r.fbm(x / 90 + 7, y / 90 - 3, 3) }
        let red = c.campo(paso: 2) { x, y in
            (x * -0.7 + y * 0.71) / 64 + 2.4 * r.fbm(x / 80 + 11, y / 80 + 2, 4)
        }
        let nubes = c.campo { x, y in r.fbm(x / 75, y / 75, 4) }
        c.retocar { x, y, i, _ in
            let v1 = abs(sin(fase[i] * .pi))
            let g = grosor[i]
            let fina = 10 + 50 * (1 - g)
            let vena = pow(1 - v1, fina) * (0.55 + 0.4 * g) + pow(1 - v1, 4) * (c.oscuro ? 0.05 : 0.12) * g
            let v2 = abs(sin(red[i] * .pi))
            let vetilla = pow(1 - v2, 60) * 0.42 * max(0, nubes[i] + 0.45)
            let cristal = (azar01(Int32(x * 2), Int32(y * 2), 13) - 0.5) * 0.018
            let piedra = base.mezcla(veta, max(0, -nubes[i]) * 0.16) * (1 + cristal)
            return piedra.mezcla(veta, min(vena + vetilla, 0.92))
        }
        fase.deallocate(); grosor.deallocate(); red.deallocate(); nubes.deallocate()
    }

    fileprivate nonisolated static func madera(_ c: Contexto) {
        let r = c.ruido
        let base = c.base, veta = c.veta
        let anillos = c.campo(paso: 2) { x, y in
            (y + 46 * r.fbm(x / 640, y / 260, 3) + 13 * r.fbm(x / 170, y / 90, 3)) / (6.5 + 2.5 * r.fbm(y / 60, 3.3, 2))
        }
        let tono = c.campo { x, y in r.fbm(x / 300, y / 70, 3) }
        let semilla = c.semilla
        c.retocar { x, y, i, _ in
            let a = fraccion(anillos[i])
            
            let banda = pow(a, 3) * 0.45 + suave(0.9, 0.975, a) * (1 - suave(0.975, 1, a)) * 0.55
            let raya = max(0, r.perlin(x / 220, y * 2.4)) * 0.22
            let poro = azar01(Int32(x / 2.6), Int32(y * 1.4), semilla) > 0.93 ? Float(0.22) : 0
            let m = min(banda + raya + poro, 1)
            return base.mezcla(veta, m * 0.8) * (1 + tono[i] * 0.08)
        }
        anillos.deallocate(); tono.deallocate()
    }

    fileprivate nonisolated static func hormigon(_ c: Contexto) {
        let r = c.ruido
        let base = c.base, veta = c.veta
        let manchas = c.campo { x, y in r.fbm(x / 32, y / 32, 5) }
        let semilla = c.semilla
        c.retocar { x, y, i, _ in
            var k = 1 + manchas[i] * 0.12 + r.fbm(x / 3.5, y / 3.5, 2) * 0.04
            k += (azar01(Int32(x * c.s), Int32(y * c.s), semilla) - 0.5) * 0.05
            
            let p = celdas(x / 5.5, y / 5.5, semilla)
            if p.id & 0xFF < 34 {
                let radio: Float = 0.08 + Float((p.id >> 8) & 0xFF) / 255 * 0.1
                k -= (1 - suave(radio * 0.5, radio, p.f1)) * 0.2
            }
            let grande = celdas(x / 24, y / 24, semilla &+ 7)
            if grande.id & 0xFF < 22 { k -= (1 - suave(0.03, 0.06, grande.f1)) * 0.28 }
            return base.mezcla(veta, max(0, -manchas[i]) * 0.5) * k
        }
        manchas.deallocate()
    }

    fileprivate nonisolated static func pizarra(_ c: Contexto) {
        let r = c.ruido
        let base = c.base, veta = c.veta
        let neblina = c.campo { x, y in r.fbm(x / 120, y / 90, 5) }
        let barridos = c.campo { x, y in r.fbm(x / 200 + r.fbm(x / 300, y / 300, 2) * 2, y / 26, 3) }
        let semilla = c.semilla
        c.retocar { x, y, i, _ in
            var tiza = max(0, neblina[i] + 0.12) * 0.13 + max(0, barridos[i] - 0.1) * 0.06
            let polvo = azar01(Int32(x * 1.7), Int32(y * 1.7), semilla)
            if polvo > 0.997 { tiza += 0.16 }
            let grano = (azar01(Int32(x * c.s), Int32(y * c.s), semilla &+ 3) - 0.5) * 0.03
            return base.mezcla(veta, min(tiza, 0.4)) * (1 + grano)
        }
        neblina.deallocate(); barridos.deallocate()
    }

    fileprivate nonisolated static func acuarela(_ c: Contexto) {
        let r = c.ruido
        let alto = Float(c.h) / c.s, ancho = Float(c.w) / c.s
        let bultos = c.buffer()
        let s = c.s
        c.llenar(bultos) { x, y in r.fbm(Float(x) / s / 4.5, Float(y) / s / 4.5, 3) }
        let luz = c.relieve(bultos, fuerza: 0.09)
        
        struct Mancha { let x: Float, y: Float, radio: Float, color: RGB, fuerza: Float, d: Float }
        var manchas: [Mancha] = []
        let colores = c.extra.isEmpty ? [c.veta] : c.extra
        let sitios: [(Float, Float)] = [(0.1, 0.05), (0.85, 0.12), (0.45, 0.0), (0.05, 0.55), (0.95, 0.6),
                                        (0.3, 0.98), (0.8, 0.95)]
        for (k, (sx, sy)) in sitios.enumerated() {
            manchas.append(Mancha(x: sx * ancho + c.azar.entre(-30, 30), y: sy * alto + c.azar.entre(-30, 30),
                                  radio: c.azar.entre(120, 210), color: colores[k % colores.count],
                                  fuerza: c.azar.entre(0.22, 0.36), d: Float(k) * 3.3))
        }
        let base = c.base
        c.retocar { x, y, i, _ in
            var col = base * (1 + luz[i])
            for m in manchas {
                let dx = x - m.x, dy = y - m.y
                let dist = (dx * dx + dy * dy).squareRoot() / m.radio + 0.32 * r.fbm(x / 80 + m.d, y / 80 - m.d, 3)
                guard dist < 1 else { continue }
                
                let borde = suave(0.72, 0.98, dist) * (1 - suave(0.98, 1, dist))
                let a = (m.fuerza * (0.5 + 0.5 * (1 - dist)) + borde * 0.3) * (0.78 + 0.5 * max(0, -bultos[i]))
                col = RGB(col.r * (1 - a + a * m.color.r), col.g * (1 - a + a * m.color.g), col.b * (1 - a + a * m.color.b))
            }
            return col
        }
        bultos.deallocate(); luz.deallocate()
    }

    fileprivate nonisolated static func libreta(_ c: Contexto) {
        papel(c, fibras: 0.45, nubes: 0.6)
        let veta = c.veta
        let lado: Float = 18
        let grosor: Float = 0.42 * c.s
        c.retocar { x, y, _, col in
            let dx = abs(fraccion(x / lado + 0.5) - 0.5) * lado * c.s
            let dy = abs(fraccion(y / lado + 0.5) - 0.5) * lado * c.s
            let linea = max(1 - suave(grosor, grosor + 0.9, dx), 1 - suave(grosor, grosor + 0.9, dy))
            return col.mezcla(veta, linea * 0.55)
        }
    }

    fileprivate nonisolated static func cianotipo(_ c: Contexto) {
        let r = c.ruido
        let base = c.base, veta = c.veta
        let manchas = c.campo { x, y in r.fbm(x / 28, y / 28, 4) }
        let semilla = c.semilla
        c.retocar { x, y, i, _ in
            var col = base * (1 + manchas[i] * 0.09 + (azar01(Int32(x * c.s), Int32(y * c.s), semilla) - 0.5) * 0.05)
            func linea(_ lado: Float, _ grosor: Float) -> Float {
                let dx = abs(fraccion(x / lado + 0.5) - 0.5) * lado * c.s
                let dy = abs(fraccion(y / lado + 0.5) - 0.5) * lado * c.s
                return max(1 - suave(grosor, grosor + 1, dx), 1 - suave(grosor, grosor + 1, dy))
            }
            col = col.mezcla(veta, linea(12, 0.25 * c.s) * 0.13)
            col = col.mezcla(veta, linea(60, 0.5 * c.s) * 0.22)
            return col
        }
        manchas.deallocate()
    }

    fileprivate nonisolated static func cuero(_ c: Contexto) {
        let r = c.ruido
        let base = c.base, veta = c.veta
        let altura = c.buffer()
        let semilla = c.semilla, s = c.s
        c.llenar(altura) { x, y in
            let px = Float(x) / s, py = Float(y) / s
            let cel = celdas(px / 2.6 + r.perlin(px / 9, py / 9) * 0.25, py / 2.6, semilla, jitter: 0.9)
            return suave(0, 0.42, cel.f2 - cel.f1) * 0.8 + r.perlin(px / 1.1, py / 1.1) * 0.08
        }
        let luz = c.relieve(altura, fuerza: c.oscuro ? 0.3 : 0.12)
        let tono = c.campo { x, y in r.fbm(x / 70, y / 70, 4) }
        c.retocar { x, y, i, _ in
            var k = 1 + luz[i] + tono[i] * 0.08 - (1 - altura[i]) * 0.12
            if azar01(Int32(x * 2.2), Int32(y * 2.2), semilla &+ 1) > 0.993 { k -= 0.18 }
            return base.mezcla(veta, max(0, tono[i]) * 0.4) * k
        }
        altura.deallocate(); luz.deallocate(); tono.deallocate()
    }

    fileprivate nonisolated static func arena(_ c: Contexto) {
        let r = c.ruido
        let base = c.base, veta = c.veta
        let altura = c.campo(paso: 2) { x, y in
            let fase = (y + 16 * r.fbm(x / 90, y / 60, 3) + x * 0.1) / (8 + 3 * r.fbm(x / 120, y / 120, 2))
            return (sin(fase * 2 * .pi) * 0.5 + 0.5) * (0.4 + 0.6 * max(0, r.fbm(x / 140 + 4, y / 140, 3) + 0.3))
        }
        let luz = c.relieve(altura, fuerza: 0.16 * c.s)
        let semilla = c.semilla
        c.retocar { x, y, i, _ in
            let a = azar01(Int32(x * c.s), Int32(y * c.s), semilla)
            var k = 1 + luz[i] + (a - 0.5) * 0.12
            var col = base
            if a > 0.982 { k += 0.2 } else if a < 0.035 { col = base.mezcla(veta, 0.65) }
            k += r.fbm(x / 40, y / 40, 3) * 0.05
            return col * k
        }
        altura.deallocate(); luz.deallocate()
    }

    fileprivate nonisolated static func carbono(_ c: Contexto) {
        let base = c.base, veta = c.veta
        let lado: Float = 3.4
        c.retocar { x, y, _, _ in
            let u = x / lado, v = y / lado
            let i = Int(u.rounded(.down)), j = Int(v.rounded(.down))
            let horizontal = ((i - j) % 4 + 4) % 4 < 2
            
            let traves = horizontal ? fraccion(v) : fraccion(u)
            let largo = horizontal ? fraccion(u * 0.5 + Float(j & 1) * 0.5) : fraccion(v * 0.5 + Float(i & 1) * 0.5)
            let redonda = sin(traves * .pi)
            let hilos = 0.5 + 0.5 * sin(traves * lado * c.s * 1.6)
            let brillo = (horizontal ? 0.85 : 0.4) * redonda * (0.75 + 0.25 * hilos) * (0.8 + 0.2 * sin(largo * .pi))
            return base.mezcla(veta, min(brillo, 1))
        }
    }

    fileprivate nonisolated static func escarcha(_ c: Contexto) {
        let r = c.ruido
        let base = c.base, veta = c.veta
        let ramas = c.campo(paso: 2) { x, y in max(r.crestas(x / 46, y / 46, 4), r.crestas(x / 19 + 3, y / 19, 3) * 0.8) }
        let semilla = c.semilla
        c.retocar { x, y, i, _ in
            let cel = celdas(x / 14, y / 14, semilla)
            let arista = 1 - suave(0, 0.035, cel.f2 - cel.f1)
            let hielo = pow(ramas[i], 8) * 0.55 + arista * 0.22
            let escarcha = azar01(Int32(x * c.s), Int32(y * c.s), semilla &+ 9) > 0.992 ? 0.25 : 0
            return base.mezcla(veta, min(hielo + Float(escarcha), 0.9))
        }
        ramas.deallocate()
    }
}
