

extension Tema {

    static let ordenDelCampo: [String: [Int]] = ["todo": [0, 1, 2], "plataforma1": [1, 2, 0], "plataforma2": [2, 0, 1], "tienda": [0, 2, 1], "otra": [1, 0, 2]]
    
    static let ordenDeLaJoya: [String: [Int]] = ["cobros": [0, 1, 2], "sala": [1, 2, 0], "impuestos": [1, 0, 2], "agenda": [2, 1, 0], "todo": [0, 1, 2], "plataforma1": [1, 2, 0], "plataforma2": [2, 0, 1], "tienda": [0, 2, 1]]
    
    static let renombrados: [String: String] = ["amanecer": "atardecer", "champan": "verano", "corcho": "kraft", "granito": "hormigon", "terrazo": "marmol", "titanio": "grafito", "zafiro": "cobalto"]

    static let estrellada = Tema(
        id: "estrellada", nombre: "Noche estrellada", clase: .vida, lienzo: .malla(.estadio), vida: .estrellas,
        soloDeNoche: true, soloDeDia: false,
        fondo: Tono(0x030A1C, 0x030A1C), tarjeta: Tono(0x111B2F, 0x111B2F),
        luz: Tono(0xA1C1E4, 0xA1C1E4),
        acento: Tono(0xF1C45E, 0xF1C45E), sobreAcento: Tono(0x0B0B0F, 0x0B0B0F),
        vivos: [Tono(0x002356, 0x002356), Tono(0x003659, 0x003659), Tono(0x0A154B, 0x0A154B)],
        apagados: [Tono(0x021B44, 0x021B44), Tono(0x032846, 0x032846), Tono(0x07123C, 0x07123C)],
        particulas: [Tono(0xFFFBF4, 0xFFFBF4), Tono(0xD5EBFF, 0xD5EBFF), Tono(0xE5F5FD, 0xE5F5FD), Tono(0xFDFDFD, 0xFDFDFD)])

    static let otono = Tema(
        id: "otono", nombre: "Otoño", clase: .vida, lienzo: .cielo, vida: .hojas,
        fondo: Tono(0xFDEBDA, 0x210E06), tarjeta: Tono(0xFFFFFF, 0x341F16),
        luz: Tono(0xFFF7EB, 0xE5A059),
        acento: Tono(0x8E3510, 0xF2B966), sobreAcento: Tono(0xFFFFFF, 0x0B0B0F),
        vivos: [Tono(0xE9884D, 0x97400D), Tono(0xD86353, 0x89221C), Tono(0xEDB345, 0x986600)],
        apagados: [Tono(0xF1A67A, 0x71300D), Tono(0xE68D7B, 0x681D15), Tono(0xF2C479, 0x714909)],
        cielo: [Tono(0xF3D2A4, 0x411E0D), Tono(0xFEEADB, 0x1E0C06)],
        particulas: [Tono(0xD56326, 0xD16022), Tono(0xBD4334, 0xC44132), Tono(0xE19B1B, 0xDA950B), Tono(0x8E5224, 0x94582A), Tono(0xE0BA31, 0xE0BA31)])

    static let lluvia = Tema(
        id: "lluvia", nombre: "Lluvia", clase: .vida, lienzo: .cielo, vida: .lluvia,
        fondo: Tono(0xE1E9EF, 0x0A151E), tarjeta: Tono(0xFFFFFF, 0x1B2730),
        luz: Tono(0xEFF7FB, 0x9EB1BF),
        acento: Tono(0x0A517F, 0x98CCEB), sobreAcento: Tono(0xFFFFFF, 0x0B0B0F),
        vivos: [Tono(0x89A2B5, 0x3B5062), Tono(0xA4BCC6, 0x49626E), Tono(0x788EAB, 0x2B3E57)],
        apagados: [Tono(0xA3B7C6, 0x2B3D4C), Tono(0xB6C9D2, 0x354954), Tono(0x96A9BF, 0x213145)],
        cielo: [Tono(0xB0C0CD, 0x263746), Tono(0xD5E0E6, 0x0B1722)],
        particulas: [Tono(0x3D4F5F, 0xF2F6F8)])

    static let tormenta = Tema(
        id: "tormenta", nombre: "Tormenta", clase: .vida, lienzo: .cielo, vida: .tormenta,
        soloDeNoche: true, soloDeDia: false,
        fondo: Tono(0x0A0F1A, 0x0A0F1A), tarjeta: Tono(0x1B202C, 0x1B202C),
        luz: Tono(0xB7CFF6, 0xB7CFF6),
        acento: Tono(0xECD065, 0xECD065), sobreAcento: Tono(0x0B0B0F, 0x0B0B0F),
        vivos: [Tono(0x323D52, 0x323D52), Tono(0x3F4F60, 0x3F4F60), Tono(0x262C47, 0x262C47)],
        apagados: [Tono(0x252E40, 0x252E40), Tono(0x2E3A4A, 0x2E3A4A), Tono(0x1D2339, 0x1D2339)],
        cielo: [Tono(0x273042, 0x273042), Tono(0x0E1321, 0x0E1321)],
        particulas: [Tono(0xF3F5F8, 0xF3F5F8), Tono(0xF5F9FF, 0xF5F9FF), Tono(0xDAE4FF, 0xDAE4FF)])

    static let nieve = Tema(
        id: "nieve", nombre: "Nieve", clase: .vida, lienzo: .cielo, vida: .nieve,
        fondo: Tono(0xE7F0F5, 0x07121E), tarjeta: Tono(0xFFFFFF, 0x182431),
        luz: Tono(0xF8FDFF, 0xB2CFE1),
        acento: Tono(0x00467B, 0x9ED7F3), sobreAcento: Tono(0xFFFFFF, 0x0B0B0F),
        vivos: [Tono(0xA1C3DB, 0x334A62), Tono(0xBAD6E2, 0x425C6B), Tono(0x92ADD1, 0x273857)],
        apagados: [Tono(0xB6D0E3, 0x25384C), Tono(0xC7DEE8, 0x2F4452), Tono(0xABC1DC, 0x1D2C45)],
        cielo: [Tono(0x9AB5CC, 0x1C2F44), Tono(0xD5E4ED, 0x06101C)],
        particulas: [Tono(0xFDFDFD, 0xFDFDFD), Tono(0xEFF6FB, 0xD9E7F1)])

    static let cerezo = Tema(
        id: "cerezo", nombre: "Cerezo", clase: .vida, lienzo: .cielo, vida: .petalos,
        fondo: Tono(0xFEEDF1, 0x180A13), tarjeta: Tono(0xFFFFFF, 0x2A1B24),
        luz: Tono(0xFFFAFB, 0xE8A9C0),
        acento: Tono(0x943569, 0xFAB2CD), sobreAcento: Tono(0xFFFFFF, 0x0B0B0F),
        vivos: [Tono(0xF4ACC7, 0x743355), Tono(0xFDC8CB, 0x834957), Tono(0xE394C1, 0x60204F)],
        apagados: [Tono(0xF8C0D3, 0x562640), Tono(0xFED3D6, 0x603541), Tono(0xECAFCF, 0x491A3C)],
        cielo: [Tono(0xFBD6E3, 0x341A2C), Tono(0xFFF1F3, 0x140813)],
        particulas: [Tono(0xF6A0C1, 0xFCBCD4), Tono(0xFFBCCA, 0xFFD9E1), Tono(0xEC84B7, 0xF4A0C8), Tono(0xFEDADE, 0xFFE8EA)])

    static let luciernagas = Tema(
        id: "luciernagas", nombre: "Luciérnagas", clase: .vida, lienzo: .cielo, vida: .luciernagas,
        soloDeNoche: true, soloDeDia: false,
        fondo: Tono(0x020E09, 0x020E09), tarjeta: Tono(0x101F19, 0x101F19),
        luz: Tono(0xCCE576, 0xCCE576),
        acento: Tono(0xCFE56A, 0xCFE56A), sobreAcento: Tono(0x0B0B0F, 0x0B0B0F),
        vivos: [Tono(0x124230, 0x124230), Tono(0x344F39, 0x344F39), Tono(0x00312A, 0x00312A)],
        apagados: [Tono(0x0C3124, 0x0C3124), Tono(0x233A2A, 0x233A2A), Tono(0x022620, 0x022620)],
        cielo: [Tono(0x05231A, 0x05231A), Tono(0x020C06, 0x020C06)],
        particulas: [Tono(0xDEF766, 0xDEF766), Tono(0xFFFAAA, 0xFFFAAA)])

    static let oceano = Tema(
        id: "oceano", nombre: "Océano", clase: .vida, lienzo: .cielo, vida: .burbujas,
        fondo: Tono(0xDCF4F5, 0x000F1A), tarjeta: Tono(0xFFFFFF, 0x0C202C),
        luz: Tono(0xF2FFFE, 0x83D4D8),
        acento: Tono(0x004C62, 0x73DFDF), sobreAcento: Tono(0xFFFFFF, 0x0B0B0F),
        vivos: [Tono(0x71D0D5, 0x005766), Tono(0x9CE1D7, 0x20696D), Tono(0x58BAD6, 0x00435B)],
        apagados: [Tono(0x94DBDF, 0x00404E), Tono(0xB0E7E0, 0x134C52), Tono(0x84CCE0, 0x003246)],
        cielo: [Tono(0xA0E7E6, 0x004552), Tono(0x74BDD4, 0x00111E)],
        particulas: [Tono(0xFDFDFD, 0xE6FAFA), Tono(0xDCF8FA, 0xAFEBEE)])

    static let tesoro = Tema(
        id: "tesoro", nombre: "Tesoro", clase: .vida, lienzo: .cielo, vida: .monedas,
        soloDeNoche: true, soloDeDia: false,
        fondo: Tono(0x001208, 0x001208), tarjeta: Tono(0x0D2418, 0x0D2418),
        luz: Tono(0xEFCE6F, 0xEFCE6F),
        acento: Tono(0xF4CC64, 0xF4CC64), sobreAcento: Tono(0x0B0B0F, 0x0B0B0F),
        vivos: [Tono(0x124830, 0x124830), Tono(0x34563B, 0x34563B), Tono(0x003729, 0x003729)],
        apagados: [Tono(0x0A3723, 0x0A3723), Tono(0x22402A, 0x22402A), Tono(0x002B1F, 0x002B1F)],
        cielo: [Tono(0x0A3723, 0x0A3723), Tono(0x001208, 0x001208)],
        particulas: [Tono(0xFDDB72, 0xFDDB72), Tono(0xE0A61E, 0xE0A61E), Tono(0xA06604, 0xA06604), Tono(0xFFFCF0, 0xFFFCF0)])

    static let hoguera = Tema(
        id: "hoguera", nombre: "Hoguera", clase: .vida, lienzo: .cielo, vida: .brasas,
        soloDeNoche: true, soloDeDia: false,
        fondo: Tono(0x120805, 0x120805), tarjeta: Tono(0x241814, 0x241814),
        luz: Tono(0xFFA659, 0xFFA659),
        acento: Tono(0xFFBB69, 0xFFBB69), sobreAcento: Tono(0x0B0B0F, 0x0B0B0F),
        vivos: [Tono(0x723311, 0x723311), Tono(0x7C4A1C, 0x7C4A1C), Tono(0x651911, 0x651911)],
        apagados: [Tono(0x53250E, 0x53250E), Tono(0x593415, 0x593415), Tono(0x4A150E, 0x4A150E)],
        cielo: [Tono(0x150A07, 0x150A07), Tono(0x421807, 0x421807)],
        particulas: [Tono(0xFFF2C2, 0xFFF2C2), Tono(0xFFB169, 0xFFB169), Tono(0xF0532B, 0xF0532B)])

    static let aurora = Tema(
        id: "aurora", nombre: "Aurora boreal", clase: .vida, lienzo: .cielo, vida: .aurora,
        soloDeNoche: true, soloDeDia: false,
        fondo: Tono(0x010D16, 0x010D16), tarjeta: Tono(0x0E1E28, 0x0E1E28),
        luz: Tono(0x76EEA5, 0x76EEA5),
        acento: Tono(0xDAB0FA, 0xDAB0FA), sobreAcento: Tono(0x0B0B0F, 0x0B0B0F),
        vivos: [Tono(0x006E30, 0x006E30), Tono(0x005D55, 0x005D55), Tono(0x44206F, 0x44206F)],
        apagados: [Tono(0x004F2B, 0x004F2B), Tono(0x014341, 0x014341), Tono(0x2F1C52, 0x2F1C52)],
        cielo: [Tono(0x071523, 0x071523), Tono(0x02060D, 0x02060D)],
        particulas: [Tono(0x3EEE92, 0x3EEE92), Tono(0x00C4BD, 0x00C4BD), Tono(0x9D69D2, 0x9D69D2), Tono(0xFFFBF4, 0xFFFBF4), Tono(0xD5EBFF, 0xD5EBFF), Tono(0xE5F5FD, 0xE5F5FD)])

    static let lava = Tema(
        id: "lava", nombre: "Lava", clase: .vida, lienzo: .cielo, vida: .lava,
        fondo: Tono(0xFEEEE6, 0x140513), tarjeta: Tono(0xFFFFFF, 0x261525),
        luz: Tono(0xFFFBF8, 0xFFA191),
        acento: Tono(0xA02D41, 0xFFB79D), sobreAcento: Tono(0xFFFFFF, 0x0B0B0F),
        vivos: [Tono(0xF8A49D, 0x950E4F), Tono(0xFDC495, 0xA7391E), Tono(0xEA93AE, 0x6D0F69)],
        apagados: [Tono(0xFBBAB3, 0x6B0F3C), Tono(0xFED1AE, 0x762920), Tono(0xF2AEBF, 0x500E4D)],
        cielo: [Tono(0xFDEFE5, 0x220C21), Tono(0xFBE1DB, 0x100413)],
        particulas: [Tono(0xFFB5AE, 0xE83174), Tono(0xFFCD9D, 0xFD7933)])

    static let corazones = Tema(
        id: "corazones", nombre: "San Valentín", clase: .vida, lienzo: .cielo, vida: .corazones,
        fondo: Tono(0xFFEDF0, 0x180409), tarjeta: Tono(0xFFFFFF, 0x2B1319),
        luz: Tono(0xFFFAFB, 0xFF9DAC),
        acento: Tono(0xB61537, 0xFF9EA6), sobreAcento: Tono(0xFFFFFF, 0x0B0B0F),
        vivos: [Tono(0xF58397, 0x8C1832), Tono(0xFAA9C1, 0x913C5B), Tono(0xEA696E, 0x78000E)],
        apagados: [Tono(0xFBA4B1, 0x661225), Tono(0xFDBECF, 0x692940), Tono(0xF49394, 0x59050F)],
        cielo: [Tono(0xFFD9E3, 0x360A15), Tono(0xFFF1F3, 0x150308)],
        particulas: [Tono(0xF0415A, 0xEA3B48), Tono(0xFC7B9D, 0xF97096), Tono(0xFCB2C8, 0xFAA9C1)])

    static let fiesta = Tema(
        id: "fiesta", nombre: "Fiesta", clase: .vida, lienzo: .cielo, vida: .confeti,
        fondo: Tono(0xF5F4FD, 0x0B0917), tarjeta: Tono(0xFFFFFF, 0x1B1A29),
        luz: Tono(0xFBFBFF, 0xBCB3FA),
        acento: Tono(0x6141B9, 0xCEB5FF), sobreAcento: Tono(0xFFFFFF, 0x0B0B0F),
        vivos: [Tono(0xBCB3FA, 0x493883), Tono(0xEFCC83, 0x705300), Tono(0xDC95D5, 0x601A5D)],
        apagados: [Tono(0xCDC7FC, 0x352960), Tono(0xF1D8AA, 0x4E3C18), Tono(0xE5B2E1, 0x451647)],
        cielo: [Tono(0xF1F0FF, 0x1A162E), Tono(0xF4F9FF, 0x070815)],
        particulas: [Tono(0xF4514F, 0xFF635F), Tono(0xEFBD24, 0xFDCA3A), Tono(0x4CB86A, 0x51C672), Tono(0x487CDE, 0x5A8FF3), Tono(0xD469CC, 0xE175D9)])

    static let granizo = Tema(
        id: "granizo", nombre: "Granizo", clase: .vida, lienzo: .cielo, vida: .granizo,
        fondo: Tono(0xE8ECEF, 0x0B1016), tarjeta: Tono(0xFFFFFF, 0x1C2128),
        luz: Tono(0xF6F9FB, 0xC0CCD7),
        acento: Tono(0x25415E, 0xBAD5E9), sobreAcento: Tono(0xFFFFFF, 0x0B0B0F),
        vivos: [Tono(0xA8B2BE, 0x414853), Tono(0xBBC6CD, 0x515960), Tono(0x969FAE, 0x323845)],
        apagados: [Tono(0xBBC3CD, 0x303640), Tono(0xC8D1D7, 0x3A4148), Tono(0xAEB6C1, 0x262B36)],
        cielo: [Tono(0xA2ACB7, 0x252C35), Tono(0xCFD5DA, 0x0B1016)],
        particulas: [Tono(0xFDFDFD, 0xFDFDFD), Tono(0xCCD2D7, 0xB9BEC4)])

    static let oro = Tema(
        id: "oro", nombre: "Oro", clase: .vida, lienzo: .cielo, vida: .purpurina,
        soloDeNoche: true, soloDeDia: false,
        fondo: Tono(0x0C0508, 0x0C0508), tarjeta: Tono(0x1D1418, 0x1D1418),
        luz: Tono(0xF8D376, 0xF8D376),
        acento: Tono(0xF4CC64, 0xF4CC64), sobreAcento: Tono(0x0B0B0F, 0x0B0B0F),
        vivos: [Tono(0x4C2D3C, 0x4C2D3C), Tono(0x5C4221, 0x5C4221), Tono(0x371F35, 0x371F35)],
        apagados: [Tono(0x37202B, 0x37202B), Tono(0x422E1A, 0x422E1A), Tono(0x291627, 0x291627)],
        cielo: [Tono(0x1A0D13, 0x1A0D13), Tono(0x070305, 0x070305)],
        particulas: [Tono(0xFFE38C, 0xFFE38C), Tono(0xEDB333, 0xEDB333), Tono(0xFFFCF0, 0xFFFCF0)])

    static let fuegos = Tema(
        id: "fuegos", nombre: "Fuegos artificiales", clase: .vida, lienzo: .cielo, vida: .fuegos,
        soloDeNoche: true, soloDeDia: false,
        fondo: Tono(0x050613, 0x050613), tarjeta: Tono(0x131625, 0x131625),
        luz: Tono(0xD4BDFF, 0xD4BDFF),
        acento: Tono(0xF5C761, 0xF5C761), sobreAcento: Tono(0x0B0B0F, 0x0B0B0F),
        vivos: [Tono(0x353766, 0x353766), Tono(0x53446E, 0x53446E), Tono(0x1A2B56, 0x1A2B56)],
        apagados: [Tono(0x25274B, 0x25274B), Tono(0x393050, 0x393050), Tono(0x131F40, 0x131F40)],
        cielo: [Tono(0x060A1A, 0x060A1A), Tono(0x211731, 0x211731)],
        particulas: [Tono(0xFFA191, 0xFFA191), Tono(0xFED252, 0xFED252), Tono(0x00DBC1, 0x00DBC1), Tono(0xD57AE9, 0xD57AE9), Tono(0xDDEDFF, 0xDDEDFF)])

    static let nubes = Tema(
        id: "nubes", nombre: "Cielo", clase: .vida, lienzo: .cielo, vida: .nubes,
        fondo: Tono(0xE3F1FB, 0x050C1E), tarjeta: Tono(0xFFFFFF, 0x141D31),
        luz: Tono(0xF8FCFF, 0xB9D4F1),
        acento: Tono(0x003D7C, 0xE9CA89), sobreAcento: Tono(0xFFFFFF, 0x0B0B0F),
        vivos: [Tono(0x73B1E6, 0x304168), Tono(0x9BD4F0, 0x385573), Tono(0x639BE1, 0x282E5B)],
        apagados: [Tono(0x95C4ED, 0x223050), Tono(0xB1DDF3, 0x273D58), Tono(0x89B5EA, 0x1D2348)],
        cielo: [Tono(0x70AEE3, 0x182544), Tono(0xC4E4F4, 0x050C1E)],
        particulas: [Tono(0xFDFDFD, 0x949FB2), Tono(0xE2E9EE, 0x697284)])

    static let soleado = Tema(
        id: "soleado", nombre: "Soleado", clase: .vida, lienzo: .cielo, vida: .sol,
        soloDeNoche: false, soloDeDia: true,
        fondo: Tono(0xFAF1DC, 0xFAF1DC), tarjeta: Tono(0xFFFFFF, 0xFFFFFF),
        luz: Tono(0xFFFCF0, 0xFFFCF0),
        acento: Tono(0x004F7F, 0x004F7F), sobreAcento: Tono(0xFFFFFF, 0xFFFFFF),
        vivos: [Tono(0x7CC1E9, 0x7CC1E9), Tono(0xF9E596, 0xF9E596), Tono(0xF3C898, 0xF3C898)],
        apagados: [Tono(0xA4D0E6, 0xA4D0E6), Tono(0xF9E9AC, 0xF9E9AC), Tono(0xF5D4AD, 0xF5D4AD)],
        cielo: [Tono(0x82C3EE, 0x82C3EE), Tono(0xFBEEC9, 0xFBEEC9)],
        particulas: [Tono(0xFFFCF0, 0xFFFCF0), Tono(0xFFF4DE, 0xFFF4DE)])

    static let niebla = Tema(
        id: "niebla", nombre: "Niebla", clase: .vida, lienzo: .cielo, vida: .niebla,
        fondo: Tono(0xE7EDE9, 0x090E10), tarjeta: Tono(0xFFFFFF, 0x191F21),
        luz: Tono(0xF6F9F7, 0xB7BFC2),
        acento: Tono(0x2F5649, 0xB8D4D5), sobreAcento: Tono(0xFFFFFF, 0x0B0B0F),
        vivos: [Tono(0xB6C1BA, 0x363F41), Tono(0xCED3CC, 0x474F50), Tono(0x9EAFAB, 0x262F34)],
        apagados: [Tono(0xC4CEC8, 0x282F31), Tono(0xD5DBD5, 0x333A3B), Tono(0xB3C1BD, 0x1D2529)],
        cielo: [Tono(0xBDC7C2, 0x232A2D), Tono(0xDEE3DE, 0x0B1012)],
        particulas: [Tono(0xFDFDFD, 0xA7B0B2)])

    static let vilanos = Tema(
        id: "vilanos", nombre: "Diente de león", clase: .vida, lienzo: .cielo, vida: .vilanos,
        fondo: Tono(0xF1F5DE, 0x040E04), tarjeta: Tono(0xFFFFFF, 0x131F12),
        luz: Tono(0xFFFEE2, 0xC4D29F),
        acento: Tono(0x29612D, 0xCBD689), sobreAcento: Tono(0xFFFFFF, 0x0B0B0F),
        vivos: [Tono(0xBCD68E, 0x32512C), Tono(0xEDE091, 0x535E2F), Tono(0x8FC990, 0x124227)],
        apagados: [Tono(0xCCDFA6, 0x233B1F), Tono(0xEEE6A9, 0x394421), Tono(0xADD6A7, 0x0E311B)],
        cielo: [Tono(0xCDE0AE, 0x13240F), Tono(0xF4F0D1, 0x030F05)],
        particulas: [Tono(0xFFFDF7, 0xF2EFE0), Tono(0xD8D1BB, 0xC5BDA8)])

    static let pompas = Tema(
        id: "pompas", nombre: "Pompas", clase: .vida, lienzo: .cielo, vida: .pompas,
        soloDeNoche: false, soloDeDia: true,
        fondo: Tono(0xEEF2FC, 0xEEF2FC), tarjeta: Tono(0xFFFFFF, 0xFFFFFF),
        luz: Tono(0xF9FCFF, 0xF9FCFF),
        acento: Tono(0x5346A7, 0x5346A7), sobreAcento: Tono(0xFFFFFF, 0xFFFFFF),
        vivos: [Tono(0xC1C6F8, 0xC1C6F8), Tono(0xA0E6EA, 0xA0E6EA), Tono(0xDCABD6, 0xDCABD6)],
        apagados: [Tono(0xCED3FA, 0xCED3FA), Tono(0xB9EAEF, 0xB9EAEF), Tono(0xE2C0E1, 0xE2C0E1)],
        cielo: [Tono(0xD1D5F5, 0xD1D5F5), Tono(0xE5F5FD, 0xE5F5FD)],
        particulas: [Tono(0xFAB1F3, 0xFAB1F3), Tono(0x80ECF1, 0x80ECF1), Tono(0xF9E596, 0xF9E596), Tono(0xB1B7FD, 0xB1B7FD)])

    static let galaxia = Tema(
        id: "galaxia", nombre: "Galaxia", clase: .vida, lienzo: .cielo, vida: .galaxia,
        soloDeNoche: true, soloDeDia: false,
        fondo: Tono(0x060410, 0x060410), tarjeta: Tono(0x151222, 0x151222),
        luz: Tono(0xDFB9FC, 0xDFB9FC),
        acento: Tono(0xEDB1FB, 0xEDB1FB), sobreAcento: Tono(0x0B0B0F, 0x0B0B0F),
        vivos: [Tono(0x50266B, 0x50266B), Tono(0x434582, 0x434582), Tono(0x4C0C49, 0x4C0C49)],
        apagados: [Tono(0x381B4D, 0x381B4D), Tono(0x2F2F5C, 0x2F2F5C), Tono(0x350B37, 0x350B37)],
        cielo: [Tono(0x130922, 0x130922), Tono(0x02020C, 0x02020C)],
        particulas: [Tono(0xB545AE, 0xB545AE), Tono(0x6356BF, 0x6356BF), Tono(0x0095B5, 0x0095B5), Tono(0xFFFBF4, 0xFFFBF4), Tono(0xD5EBFF, 0xD5EBFF), Tono(0xE5F5FD, 0xE5F5FD)])

    static let papel = Tema(
        id: "papel", nombre: "Papel", clase: .textura, lienzo: .textura(.papel),
        fondo: Tono(0xF4EEE1, 0x221F1B), tarjeta: Tono(0xFFFDF8, 0x35312D),
        luz: Tono(0xFFFFFF, 0x2D2B29),
        acento: Tono(0x25211D, 0xE8E4DD), sobreAcento: Tono(0xFFFFFF, 0x0B0B0F),
        vivos: [Tono(0xF4EEE1, 0x221F1B), Tono(0xE9DCC8, 0x34302B), Tono(0xFFFBF4, 0x2C2824)],
        apagados: [Tono(0xF4EEE1, 0x221F1B), Tono(0xECE1CF, 0x2E2B26), Tono(0xFCF7EE, 0x292521)],
        material: Tono(0xF4EEE1, 0x221F1B),
        veta: Tono(0xE9DCC8, 0x34302B))

    static let kraft = Tema(
        id: "kraft", nombre: "Kraft", clase: .textura, lienzo: .textura(.kraft),
        fondo: Tono(0xF9D3A8, 0x352516), tarjeta: Tono(0xFFFFFF, 0x493828),
        luz: Tono(0xCAB7A3, 0x3C342C),
        acento: Tono(0x462C19, 0xE5C9A3), sobreAcento: Tono(0xFFFFFF, 0x0B0B0F),
        vivos: [Tono(0xC8A47A, 0x352516), Tono(0x8E6945, 0x513E2C), Tono(0xDAAE7C, 0x422E1B)],
        apagados: [Tono(0xD6B288, 0x352516), Tono(0xAD8761, 0x483625), Tono(0xE3B989, 0x3E2B19)],
        material: Tono(0xC8A47A, 0x352516),
        veta: Tono(0x8E6945, 0x513E2C))

    static let washi = Tema(
        id: "washi", nombre: "Washi", clase: .textura, lienzo: .textura(.washi),
        fondo: Tono(0xF1EEE6, 0x221E1A), tarjeta: Tono(0xFFFFFF, 0x35302C),
        luz: Tono(0xFFFFFF, 0x2D2B29),
        acento: Tono(0x9E2E21, 0xFFA28A), sobreAcento: Tono(0xFFFFFF, 0x0B0B0F),
        vivos: [Tono(0xF1EEE6, 0x221E1A), Tono(0xE7E1D3, 0x322D27), Tono(0xFFFCF2, 0x2D2823)],
        apagados: [Tono(0xF1EEE6, 0x221E1A), Tono(0xEAE5D9, 0x2D2823), Tono(0xFBF8EE, 0x2A2520)],
        material: Tono(0xF1EEE6, 0x221E1A),
        veta: Tono(0xE7E1D3, 0x322D27),
        extra: [Tono(0xEAA9BB, 0x884F61), Tono(0xAAC8A3, 0x516C4B), Tono(0xBDAFD9, 0x63567B)])

    static let lino = Tema(
        id: "lino", nombre: "Lino", clase: .textura, lienzo: .textura(.lino),
        fondo: Tono(0xE5D8C5, 0x2C2822), tarjeta: Tono(0xFFFFFF, 0x3F3B35),
        luz: Tono(0xE7E0D6, 0x373532),
        acento: Tono(0x5A3A1F, 0xDFCFB4), sobreAcento: Tono(0xFFFFFF, 0x0B0B0F),
        vivos: [Tono(0xDCCFBC, 0x2C2822), Tono(0xB4A289, 0x423C35), Tono(0xEBDCC4, 0x37322B)],
        apagados: [Tono(0xDFD2BF, 0x2C2822), Tono(0xC2B29B, 0x3B362F), Tono(0xE9DBC4, 0x342F28)],
        material: Tono(0xDCCFBC, 0x2C2822),
        veta: Tono(0xB4A289, 0x423C35))

    static let vaquero = Tema(
        id: "vaquero", nombre: "Vaquero", clase: .textura, lienzo: .textura(.vaquero),
        fondo: Tono(0xC0DEFD, 0x162F58), tarjeta: Tono(0xFFFFFF, 0x29436E),
        luz: Tono(0xC1D0E0, 0x313E52),
        acento: Tono(0x7F3900, 0xEFB062), sobreAcento: Tono(0xFFFFFF, 0x0B0B0F),
        vivos: [Tono(0xA4C1E0, 0x162F58), Tono(0xEAEFF5, 0x3E5F8A), Tono(0xAACFF5, 0x1A396C)],
        apagados: [Tono(0xACCAE9, 0x162F58), Tono(0xDDEAF8, 0x31507B), Tono(0xB1D3F7, 0x193666)],
        material: Tono(0xA4C1E0, 0x162F58),
        veta: Tono(0xEAEFF5, 0x3E5F8A))

    static let terciopelo = Tema(
        id: "terciopelo", nombre: "Terciopelo", clase: .textura, lienzo: .textura(.terciopelo),
        fondo: Tono(0xF7CEDC, 0x3B091E), tarjeta: Tono(0xFFFFFF, 0x511D30),
        luz: Tono(0xEDD8DF, 0x3C232A),
        acento: Tono(0x85204A, 0xFFB4B3), sobreAcento: Tono(0xFFFFFF, 0x0B0B0F),
        vivos: [Tono(0xEAC1CF, 0x3B091E), Tono(0xF9E0E9, 0x782445), Tono(0xFCCBDD, 0x4B0C27)],
        apagados: [Tono(0xEEC5D3, 0x3B091E), Tono(0xF8DBE5, 0x651C39), Tono(0xFBCCDD, 0x460B24)],
        material: Tono(0xEAC1CF, 0x3B091E),
        veta: Tono(0xF9E0E9, 0x782445))

    static let marmol = Tema(
        id: "marmol", nombre: "Mármol", clase: .textura, lienzo: .textura(.marmol),
        fondo: Tono(0xF3F2EF, 0x121111), tarjeta: Tono(0xFFFFFF, 0x232222),
        luz: Tono(0xFFFFFF, 0x1D1D1D),
        acento: Tono(0x7B5600, 0xEBC573), sobreAcento: Tono(0xFFFFFF, 0x0B0B0F),
        vivos: [Tono(0xF3F2EF, 0x121111), Tono(0x84868A, 0xDFDEDA), Tono(0xFFFFFF, 0x1C1A1A)],
        apagados: [Tono(0xF3F2EF, 0x121111), Tono(0xA4A5A7, 0x9A9997), Tono(0xFBFBFA, 0x191717)],
        material: Tono(0xF3F2EF, 0x121111),
        veta: Tono(0x84868A, 0xDFDEDA))

    static let madera = Tema(
        id: "madera", nombre: "Madera", clase: .textura, lienzo: .textura(.madera),
        fondo: Tono(0xFAD4AA, 0x2F2016), tarjeta: Tono(0xFFFFFF, 0x433328),
        luz: Tono(0xDDCAB6, 0x372E29),
        acento: Tono(0x623512, 0xEDC388), sobreAcento: Tono(0xFFFFFF, 0x0B0B0F),
        vivos: [Tono(0xDBB68D, 0x2F2016), Tono(0x9D6F48, 0x1A0F07), Tono(0xEEC18E, 0x3C291C)],
        apagados: [Tono(0xE4BF96, 0x2F2016), Tono(0xB88C64, 0x20140B), Tono(0xF2C796, 0x38261A)],
        material: Tono(0xDBB68D, 0x2F2016),
        veta: Tono(0x9D6F48, 0x1A0F07))

    static let hormigon = Tema(
        id: "hormigon", nombre: "Hormigón", clase: .textura, lienzo: .textura(.hormigon),
        fondo: Tono(0xDCDAD6, 0x2E2E2C), tarjeta: Tono(0xFFFFFF, 0x41413F),
        luz: Tono(0xDBDBD8, 0x3B3A39),
        acento: Tono(0x903A03, 0xFFAF78), sobreAcento: Tono(0xFFFFFF, 0x0B0B0F),
        vivos: [Tono(0xCCCAC6, 0x2E2E2C), Tono(0xA09E99, 0x22221F), Tono(0xD9D7D2, 0x393835)],
        apagados: [Tono(0xD1CFCB, 0x2E2E2C), Tono(0xB2B0AB, 0x262623), Tono(0xDAD8D3, 0x363532)],
        material: Tono(0xCCCAC6, 0x2E2E2C),
        veta: Tono(0xA09E99, 0x22221F))

    static let pizarra = Tema(
        id: "pizarra", nombre: "Pizarra", clase: .textura, lienzo: .textura(.pizarra),
        soloDeNoche: true, soloDeDia: false,
        fondo: Tono(0x1B2722, 0x1B2722), tarjeta: Tono(0x2D3A34, 0x2D3A34),
        luz: Tono(0x2C322F, 0x2C322F),
        acento: Tono(0xF0DE99, 0xF0DE99), sobreAcento: Tono(0x0B0B0F, 0x0B0B0F),
        vivos: [Tono(0x1B2722, 0x1B2722), Tono(0xDFE7E2, 0xDFE7E2), Tono(0x22322B, 0x22322B)],
        apagados: [Tono(0x1B2722, 0x1B2722), Tono(0x9EA8A3, 0x9EA8A3), Tono(0x202F28, 0x202F28)],
        material: Tono(0x1B2722, 0x1B2722),
        veta: Tono(0xDFE7E2, 0xDFE7E2))

    static let acuarela = Tema(
        id: "acuarela", nombre: "Acuarela", clase: .textura, lienzo: .textura(.acuarela),
        soloDeNoche: false, soloDeDia: true,
        fondo: Tono(0xFBF8F2, 0xFBF8F2), tarjeta: Tono(0xFFFFFF, 0xFFFFFF),
        luz: Tono(0xFFFFFF, 0xFFFFFF),
        acento: Tono(0x005798, 0x005798), sobreAcento: Tono(0xFFFFFF, 0xFFFFFF),
        vivos: [Tono(0xFBF8F2, 0xFBF8F2), Tono(0x9BC4E1, 0x9BC4E1), Tono(0xFFFFFF, 0xFFFFFF)],
        apagados: [Tono(0xFBF8F2, 0xFBF8F2), Tono(0xB8D4E7, 0xB8D4E7), Tono(0xFEFDFB, 0xFEFDFB)],
        material: Tono(0xFBF8F2, 0xFBF8F2),
        veta: Tono(0x9BC4E1, 0x9BC4E1),
        extra: [Tono(0x9BC4E1, 0x9BC4E1), Tono(0xEDB2BA, 0xEDB2BA), Tono(0xEED592, 0xEED592), Tono(0xB6DDBD, 0xB6DDBD)])

    static let libreta = Tema(
        id: "libreta", nombre: "Libreta", clase: .textura, lienzo: .textura(.libreta),
        fondo: Tono(0xF7F5EF, 0x191D22), tarjeta: Tono(0xFFFFFF, 0x2B2F35),
        luz: Tono(0xFFFFFF, 0x27292B),
        acento: Tono(0xA92227, 0xFB9890), sobreAcento: Tono(0xFFFFFF, 0x0B0B0F),
        vivos: [Tono(0xF7F5EF, 0x191D22), Tono(0x9EC3E2, 0x2F4154), Tono(0xFFFFFF, 0x22272C)],
        apagados: [Tono(0xF7F5EF, 0x191D22), Tono(0xB9D2E6, 0x283644), Tono(0xFDFCFA, 0x1F2429)],
        material: Tono(0xF7F5EF, 0x191D22),
        veta: Tono(0x9EC3E2, 0x2F4154))

    static let cianotipo = Tema(
        id: "cianotipo", nombre: "Cianotipo", clase: .textura, lienzo: .textura(.cianotipo),
        soloDeNoche: true, soloDeDia: false,
        fondo: Tono(0x073567, 0x073567), tarjeta: Tono(0x1F4A7E, 0x1F4A7E),
        luz: Tono(0x30445D, 0x30445D),
        acento: Tono(0xF3DE90, 0xF3DE90), sobreAcento: Tono(0x0B0B0F, 0x0B0B0F),
        vivos: [Tono(0x073567, 0x073567), Tono(0xE4ECF5, 0xE4ECF5), Tono(0x023E7D, 0x023E7D)],
        apagados: [Tono(0x073567, 0x073567), Tono(0x9FB2CA, 0x9FB2CA), Tono(0x043B76, 0x043B76)],
        material: Tono(0x073567, 0x073567),
        veta: Tono(0xE4ECF5, 0xE4ECF5))

    static let cuero = Tema(
        id: "cuero", nombre: "Cuero", clase: .textura, lienzo: .textura(.cuero),
        fondo: Tono(0xFCD2AB, 0x2C1E17), tarjeta: Tono(0xFFFFFF, 0x3F3029),
        luz: Tono(0xCBB6A4, 0x332C28),
        acento: Tono(0x4D3020, 0xE6BC8B), sobreAcento: Tono(0xFFFFFF, 0x0B0B0F),
        vivos: [Tono(0xCAA27C, 0x2C1E17), Tono(0x946A4B, 0x4A392F), Tono(0xDDAD7E, 0x38271E)],
        apagados: [Tono(0xD9B08A, 0x2C1E17), Tono(0xB28867, 0x413128), Tono(0xE6B88B, 0x34241C)],
        material: Tono(0xCAA27C, 0x2C1E17),
        veta: Tono(0x946A4B, 0x4A392F))

    static let arena = Tema(
        id: "arena", nombre: "Arena", clase: .textura, lienzo: .textura(.arena),
        fondo: Tono(0xECD9B2, 0x2A2319), tarjeta: Tono(0xFFFFFF, 0x3D362B),
        luz: Tono(0xEDE4D0, 0x33302B),
        acento: Tono(0x83451E, 0xE3C697), sobreAcento: Tono(0xFFFFFF, 0x0B0B0F),
        vivos: [Tono(0xE5D2AC, 0x2A2319), Tono(0xA58A66, 0x473B2B), Tono(0xF6DFB0, 0x352C20)],
        apagados: [Tono(0xE7D4AE, 0x2A2319), Tono(0xBAA17C, 0x3E3425), Tono(0xF3DDB1, 0x32291E)],
        material: Tono(0xE5D2AC, 0x2A2319),
        veta: Tono(0xA58A66, 0x473B2B))

    static let carbono = Tema(
        id: "carbono", nombre: "Carbono", clase: .textura, lienzo: .textura(.carbono),
        soloDeNoche: true, soloDeDia: false,
        fondo: Tono(0x121417, 0x121417), tarjeta: Tono(0x232529, 0x232529),
        luz: Tono(0x1E1F21, 0x1E1F21),
        acento: Tono(0xFD7466, 0xFD7466), sobreAcento: Tono(0x0B0B0F, 0x0B0B0F),
        vivos: [Tono(0x121417, 0x121417), Tono(0x404247, 0x404247), Tono(0x1B1D20, 0x1B1D20)],
        apagados: [Tono(0x121417, 0x121417), Tono(0x313338, 0x313338), Tono(0x181A1D, 0x181A1D)],
        material: Tono(0x121417, 0x121417),
        veta: Tono(0x404247, 0x404247))

    static let escarcha = Tema(
        id: "escarcha", nombre: "Escarcha", clase: .textura, lienzo: .textura(.escarcha),
        soloDeNoche: true, soloDeDia: false,
        fondo: Tono(0x0A1A25, 0x0A1A25), tarjeta: Tono(0x1C2C38, 0x1C2C38),
        luz: Tono(0x1E252B, 0x1E252B),
        acento: Tono(0x94DEF5, 0x94DEF5), sobreAcento: Tono(0x0B0B0F, 0x0B0B0F),
        vivos: [Tono(0x0A1A25, 0x0A1A25), Tono(0x9FC4DA, 0x9FC4DA), Tono(0x102431, 0x102431)],
        apagados: [Tono(0x0A1A25, 0x0A1A25), Tono(0x6E8C9F, 0x6E8C9F), Tono(0x0E212D, 0x0E212D)],
        material: Tono(0x0A1A25, 0x0A1A25),
        veta: Tono(0x9FC4DA, 0x9FC4DA))

    static let medianoche = Tema(
        id: "medianoche", nombre: "Medianoche", clase: .difuminado, lienzo: .malla(.estadio),
        soloDeNoche: true, soloDeDia: false,
        fondo: Tono(0x030A1C, 0x030A1C), tarjeta: Tono(0x111B2F, 0x111B2F),
        luz: Tono(0xA1C1E4, 0xA1C1E4),
        acento: Tono(0xF1C45E, 0xF1C45E), sobreAcento: Tono(0x0B0B0F, 0x0B0B0F),
        vivos: [Tono(0x002356, 0x002356), Tono(0x003659, 0x003659), Tono(0x0A154B, 0x0A154B)],
        apagados: [Tono(0x021B44, 0x021B44), Tono(0x032846, 0x032846), Tono(0x07123C, 0x07123C)])

    static let cobalto = Tema(
        id: "cobalto", nombre: "Cobalto", clase: .difuminado, lienzo: .malla(.diagonal),
        fondo: Tono(0xD5E6FF, 0x0E1E47), tarjeta: Tono(0xFFFFFF, 0x1F315C),
        luz: Tono(0xEDF6FF, 0x59AAF8),
        acento: Tono(0x1F57D3, 0x85BAFF), sobreAcento: Tono(0xFFFFFF, 0x0B0B0F),
        vivos: [Tono(0x528DFF, 0x003EB4), Tono(0x51B9F6, 0x006592), Tono(0x6A74FC, 0x3116A1)],
        apagados: [Tono(0x7EACFF, 0x083592), Tono(0x7FC7F9, 0x00456F), Tono(0x95A7FF, 0x261D85)])

    static let amatista = Tema(
        id: "amatista", nombre: "Amatista", clase: .difuminado, lienzo: .malla(.remolino),
        fondo: Tono(0xEAE0FF, 0x221338), tarjeta: Tono(0xFFFFFF, 0x34264C),
        luz: Tono(0xF7F3FF, 0xB897F0),
        acento: Tono(0x7233BB, 0xC9ACFF), sobreAcento: Tono(0xFFFFFF, 0x0B0B0F),
        vivos: [Tono(0x9D64ED, 0x721EBA), Tono(0x9791FF, 0x5D4DBE), Tono(0xB956DE, 0x770092)],
        apagados: [Tono(0xC09AFF, 0x581D90), Tono(0xAFAAFF, 0x44338A), Tono(0xD791F8, 0x5C1076)])

    static let fucsia = Tema(
        id: "fucsia", nombre: "Fucsia", clase: .difuminado, lienzo: .malla(.esquinas),
        fondo: Tono(0xFDDEEE, 0x38102D), tarjeta: Tono(0xFFFFFF, 0x4D2340),
        luz: Tono(0xFFF1F7, 0xE57BBA),
        acento: Tono(0xB20D8F, 0xFD97D2), sobreAcento: Tono(0xFFFFFF, 0x0B0B0F),
        vivos: [Tono(0xF059B9, 0x920069), Tono(0xFF97AB, 0xA53453), Tono(0xCB4ED4, 0x710079)],
        apagados: [Tono(0xFA88CC, 0x760C56), Tono(0xFFADBF, 0x781F40), Tono(0xEA8BEA, 0x5F0B61)])

    static let tropical = Tema(
        id: "tropical", nombre: "Tropical", clase: .difuminado, lienzo: .malla(.horizonte),
        fondo: Tono(0xCEF4F1, 0x002824), tarjeta: Tono(0xFFFFFF, 0x153B37),
        luz: Tono(0xE6FFF7, 0x59D7B9),
        acento: Tono(0xC32E6E, 0xFD9CBA), sobreAcento: Tono(0xFFFFFF, 0x0B0B0F),
        vivos: [Tono(0x32D8CD, 0x006E61), Tono(0x36BDDD, 0x005E68), Tono(0x72F1B8, 0x097145)],
        apagados: [Tono(0x72E1D8, 0x004B42), Tono(0x6FCEE4, 0x00494F), Tono(0x92F2C9, 0x004B30)])

    static let primavera = Tema(
        id: "primavera", nombre: "Primavera", clase: .difuminado, lienzo: .malla(.ondas),
        fondo: Tono(0xFFE8EB, 0x2A111D), tarjeta: Tono(0xFFFFFF, 0x3E232F),
        luz: Tono(0xFFF6F6, 0xE4A2B0),
        acento: Tono(0x8E2F63, 0xF2ACCA), sobreAcento: Tono(0xFFFFFF, 0x0B0B0F),
        vivos: [Tono(0xFBA9BF, 0x6E2342), Tono(0xFFC5B3, 0x7A3939), Tono(0xEDA4CB, 0x5D1D4C)],
        apagados: [Tono(0xFDBCCC, 0x591E36), Tono(0xFFD0C4, 0x612C31), Tono(0xF3B8D5, 0x4D1A3D)])

    static let verano = Tema(
        id: "verano", nombre: "Verano", clase: .difuminado, lienzo: .malla(.halo),
        fondo: Tono(0xF9F3CD, 0x281203), tarjeta: Tono(0xFFFFFF, 0x3C2413),
        luz: Tono(0xFFFEE2, 0xFDA856),
        acento: Tono(0x006E8C, 0x73D3F1), sobreAcento: Tono(0xFFFFFF, 0x0B0B0F),
        vivos: [Tono(0xFCE765, 0x854F00), Tono(0xFFC761, 0x7F3F00), Tono(0xFFB984, 0x845B00)],
        apagados: [Tono(0xFBEB89, 0x623800), Tono(0xFED585, 0x6A3300), Tono(0xFECB9A, 0x5B3C00)])

    static let atardecer = Tema(
        id: "atardecer", nombre: "Atardecer", clase: .difuminado, lienzo: .malla(.horizonte),
        fondo: Tono(0xFFE6D5, 0x291022), tarjeta: Tono(0xFFFFFF, 0x3D2235),
        luz: Tono(0xFFF4E1, 0xEC9C63),
        acento: Tono(0x6D389E, 0xCEACF7), sobreAcento: Tono(0xFFFFFF, 0x0B0B0F),
        vivos: [Tono(0xFF9A64, 0xA52C18), Tono(0xFFCB77, 0x9C4B00), Tono(0xF97770, 0x960336)],
        apagados: [Tono(0xFFB28A, 0x79211F), Tono(0xFFD396, 0x6D3012), Tono(0xFE9A8E, 0x731131)])

    static let lavanda = Tema(
        id: "lavanda", nombre: "Lavanda", clase: .difuminado, lienzo: .malla(.ondas),
        fondo: Tono(0xEAE3FD, 0x191029), tarjeta: Tono(0xFFFFFF, 0x2B223C),
        luz: Tono(0xF7F3FF, 0xB59EDB),
        acento: Tono(0x6A45A6, 0xC4B2F1), sobreAcento: Tono(0xFFFFFF, 0x0B0B0F),
        vivos: [Tono(0xC5ADEB, 0x3E1665), Tono(0xC3C6F8, 0x3D3571), Tono(0xC79AD9, 0x400A4E)],
        apagados: [Tono(0xD0BDF1, 0x321552), Tono(0xCFCFFA, 0x32295A), Tono(0xD2B0E4, 0x340E43)])

    static let opalo = Tema(
        id: "opalo", nombre: "Ópalo", clase: .difuminado, lienzo: .malla(.halo),
        fondo: Tono(0xEEEDFB, 0x10101E), tarjeta: Tono(0xFFFFFF, 0x212131),
        luz: Tono(0xEAFDFE, 0x64D1D7),
        acento: Tono(0x5849B2, 0x6ED9D2), sobreAcento: Tono(0xFFFFFF, 0x0B0B0F),
        vivos: [Tono(0xFFA7D9, 0x7B226D), Tono(0x6CE6F3, 0x006965), Tono(0xEFDB8D, 0x1C3A8B)],
        apagados: [Tono(0xFCBDE3, 0x591F54), Tono(0x9BE9F5, 0x104A4D), Tono(0xEFE1B0, 0x1A2D68)])

    static let salvia = Tema(
        id: "salvia", nombre: "Salvia", clase: .difuminado, lienzo: .malla(.diagonal),
        fondo: Tono(0xDAECDA, 0x081B0E), tarjeta: Tono(0xFFFFFF, 0x1A2D1F),
        luz: Tono(0xF1F8EA, 0x9AB894),
        acento: Tono(0x2B6547, 0xA0D2B1), sobreAcento: Tono(0xFFFFFF, 0x0B0B0F),
        vivos: [Tono(0xA2CAA2, 0x00411D), Tono(0xC8D4A8, 0x334B06), Tono(0x8AC2AE, 0x00372A)],
        apagados: [Tono(0xB3D4B3, 0x053518), Tono(0xCDDBB7, 0x253C0D), Tono(0xA2CFBB, 0x042E21)])

    static let neon = Tema(
        id: "neon", nombre: "Neón", clase: .difuminado, lienzo: .malla(.esquinas),
        soloDeNoche: true, soloDeDia: false,
        fondo: Tono(0x0A0316, 0x0A0316), tarjeta: Tono(0x1A1128, 0x1A1128),
        luz: Tono(0x36DCEC, 0x36DCEC),
        acento: Tono(0x58E5ED, 0x58E5ED), sobreAcento: Tono(0x0B0B0F, 0x0B0B0F),
        vivos: [Tono(0x006C80, 0x006C80), Tono(0x99007A, 0x99007A), Tono(0x50038F, 0x50038F)],
        apagados: [Tono(0x12475C, 0x12475C), Tono(0x6A095A, 0x6A095A), Tono(0x390667, 0x390667)])

    static let invierno = Tema(
        id: "invierno", nombre: "Invierno", clase: .difuminado, lienzo: .malla(.remolino),
        fondo: Tono(0xE0F4FE, 0x002139), tarjeta: Tono(0xFFFFFF, 0x13344D),
        luz: Tono(0xF7FDFF, 0x92CEE7),
        acento: Tono(0x185A89, 0x93D5F5), sobreAcento: Tono(0xFFFFFF, 0x0B0B0F),
        vivos: [Tono(0xA3DAF7, 0x1A5E84), Tono(0xBCEBF5, 0x336A7D), Tono(0x91C3F6, 0x204B7F)],
        apagados: [Tono(0xB6E2F9, 0x074566), Tono(0xC7EEF8, 0x14475B), Tono(0xA9D2F9, 0x153E69)])

    static let tomate = Tema(
        id: "tomate", nombre: "Tomate", clase: .plano, lienzo: .plano,
        fondo: Tono(0xFFE4DE, 0x2F0B07), tarjeta: Tono(0xFFFFFF, 0x441E18),
        luz: Tono(0xFFF2ED, 0xEFA187),
        acento: Tono(0x9B1F1B, 0xFFAD90), sobreAcento: Tono(0xFFFFFF, 0x0B0B0F),
        vivos: [Tono(0xFA6B52, 0xA81A00), Tono(0xFA8C58, 0xA84100), Tono(0xF05653, 0x990016)],
        apagados: [Tono(0xFA6B52, 0xA81A00), Tono(0xFA8C58, 0xA84100), Tono(0xF05653, 0x990016)])

    static let mostaza = Tema(
        id: "mostaza", nombre: "Mostaza", clase: .plano, lienzo: .plano,
        soloDeNoche: false, soloDeDia: true,
        fondo: Tono(0xFCF2CD, 0xFCF2CD), tarjeta: Tono(0xFFFFFF, 0xFFFFFF),
        luz: Tono(0xFFFDEC, 0xFFFDEC),
        acento: Tono(0x1D487C, 0x1D487C), sobreAcento: Tono(0xFFFFFF, 0xFFFFFF),
        vivos: [Tono(0xEAC33F, 0xEAC33F), Tono(0xEAB02F, 0xEAB02F), Tono(0xE5D76C, 0xE5D76C)],
        apagados: [Tono(0xEAC33F, 0xEAC33F), Tono(0xEAB02F, 0xEAB02F), Tono(0xE5D76C, 0xE5D76C)])

    static let menta = Tema(
        id: "menta", nombre: "Menta", clase: .plano, lienzo: .plano,
        fondo: Tono(0xE0F9EE, 0x001C14), tarjeta: Tono(0xFFFFFF, 0x112E25),
        luz: Tono(0xF4FFF9, 0x8CCFB1),
        acento: Tono(0x005B4D, 0x91DEBC), sobreAcento: Tono(0xFFFFFF, 0x0B0B0F),
        vivos: [Tono(0x8CE6C4, 0x00694A), Tono(0x6ADCC4, 0x005B4B), Tono(0xB1EFCA, 0x2F6E49)],
        apagados: [Tono(0x8CE6C4, 0x00694A), Tono(0x6ADCC4, 0x005B4B), Tono(0xB1EFCA, 0x2F6E49)])

    static let chicle = Tema(
        id: "chicle", nombre: "Chicle", clase: .plano, lienzo: .plano,
        fondo: Tono(0xFFE7EE, 0x260B19), tarjeta: Tono(0xFFFFFF, 0x3A1D2B),
        luz: Tono(0xFFF6F8, 0xF2A3C1),
        acento: Tono(0xA02262, 0xFFB0CE), sobreAcento: Tono(0xFFFFFF, 0x0B0B0F),
        vivos: [Tono(0xFF9ABD, 0x922961), Tono(0xFFB8BF, 0x9D4459), Tono(0xF587C2, 0x7F1F63)],
        apagados: [Tono(0xFF9ABD, 0x922961), Tono(0xFFB8BF, 0x9D4459), Tono(0xF587C2, 0x7F1F63)])

    static let lima = Tema(
        id: "lima", nombre: "Lima", clase: .plano, lienzo: .plano,
        fondo: Tono(0xECF8D3, 0x0C1805), tarjeta: Tono(0xFFFFFF, 0x1D2A15),
        luz: Tono(0xF9FFEA, 0xB9D880),
        acento: Tono(0x235B28, 0xBBE26E), sobreAcento: Tono(0xFFFFFF, 0x0B0B0F),
        vivos: [Tono(0xBEEA63, 0x5B6900), Tono(0x9DE25C, 0x4F6C00), Tono(0xD9EE7E, 0x676700)],
        apagados: [Tono(0xBEEA63, 0x5B6900), Tono(0x9DE25C, 0x4F6C00), Tono(0xD9EE7E, 0x676700)])

    static let lila = Tema(
        id: "lila", nombre: "Lila", clase: .plano, lienzo: .plano,
        fondo: Tono(0xF3EAFF, 0x190D25), tarjeta: Tono(0xFFFFFF, 0x2B1F38),
        luz: Tono(0xFAF7FF, 0xC6A7EB),
        acento: Tono(0x6D389E, 0xD3B4F9), sobreAcento: Tono(0xFFFFFF, 0x0B0B0F),
        vivos: [Tono(0xBCAEFC, 0x532A78), Tono(0xC0C5FF, 0x524286), Tono(0xBC9BED, 0x521962)],
        apagados: [Tono(0xBCAEFC, 0x532A78), Tono(0xC0C5FF, 0x524286), Tono(0xBC9BED, 0x521962)])

    static let arcilla = Tema(
        id: "arcilla", nombre: "Arcilla", clase: .plano, lienzo: .plano,
        fondo: Tono(0xF3E1D5, 0x21120A), tarjeta: Tono(0xFFFFFF, 0x34241B),
        luz: Tono(0xFCEFE5, 0xCEA081),
        acento: Tono(0x633416, 0xEBB890), sobreAcento: Tono(0xFFFFFF, 0x0B0B0F),
        vivos: [Tono(0xBD7953, 0x593215), Tono(0xC48F60, 0x5F411E), Tono(0xB77054, 0x4F2611)],
        apagados: [Tono(0xBD7953, 0x593215), Tono(0xC48F60, 0x5F411E), Tono(0xB77054, 0x4F2611)])

    static let hueso = Tema(
        id: "hueso", nombre: "Hueso", clase: .plano, lienzo: .plano,
        fondo: Tono(0xF5F0E5, 0x191511), tarjeta: Tono(0xFFFFFF, 0x2B2722),
        luz: Tono(0xFEFCF4, 0xA69D91),
        acento: Tono(0x342C23, 0xEBE4D6), sobreAcento: Tono(0xFFFFFF, 0x0B0B0F),
        vivos: [Tono(0xE4D5BE, 0x2C251D), Tono(0xDBC7AF, 0x382E26), Tono(0xEAE1CB, 0x211C15)],
        apagados: [Tono(0xE4D5BE, 0x2C251D), Tono(0xDBC7AF, 0x382E26), Tono(0xEAE1CB, 0x211C15)])

    static let klein = Tema(
        id: "klein", nombre: "Klein", clase: .plano, lienzo: .plano,
        soloDeNoche: true, soloDeDia: false,
        fondo: Tono(0x04114C, 0x04114C), tarjeta: Tono(0x122662, 0x122662),
        luz: Tono(0x98BFFE, 0x98BFFE),
        acento: Tono(0xF0D777, 0xF0D777), sobreAcento: Tono(0x0B0B0F, 0x0B0B0F),
        vivos: [Tono(0x1430B6, 0x1430B6), Tono(0x0050AF, 0x0050AF), Tono(0x2418A8, 0x2418A8)],
        apagados: [Tono(0x1430B6, 0x1430B6), Tono(0x0050AF, 0x0050AF), Tono(0x2418A8, 0x2418A8)])

    static let cereza = Tema(
        id: "cereza", nombre: "Cereza", clase: .plano, lienzo: .plano,
        soloDeNoche: true, soloDeDia: false,
        fondo: Tono(0x29050B, 0x29050B), tarjeta: Tono(0x3E171C, 0x3E171C),
        luz: Tono(0xF7A3A9, 0xF7A3A9),
        acento: Tono(0xFFBFB4, 0xFFBFB4), sobreAcento: Tono(0x0B0B0F, 0x0B0B0F),
        vivos: [Tono(0x5F0024, 0x5F0024), Tono(0x681438, 0x681438), Tono(0x4E0013, 0x4E0013)],
        apagados: [Tono(0x5F0024, 0x5F0024), Tono(0x681438, 0x681438), Tono(0x4E0013, 0x4E0013)])

    static let petroleo = Tema(
        id: "petroleo", nombre: "Petróleo", clase: .plano, lienzo: .plano,
        soloDeNoche: true, soloDeDia: false,
        fondo: Tono(0x00181C, 0x00181C), tarjeta: Tono(0x102A2E, 0x102A2E),
        luz: Tono(0x86CBD3, 0x86CBD3),
        acento: Tono(0xFBC77C, 0xFBC77C), sobreAcento: Tono(0x0B0B0F, 0x0B0B0F),
        vivos: [Tono(0x004456, 0x004456), Tono(0x005461, 0x005461), Tono(0x00384E, 0x00384E)],
        apagados: [Tono(0x004456, 0x004456), Tono(0x005461, 0x005461), Tono(0x00384E, 0x00384E)])

    static let grafito = Tema(
        id: "grafito", nombre: "Grafito", clase: .plano, lienzo: .plano,
        fondo: Tono(0xD8DDE3, 0x1F2225), tarjeta: Tono(0xFFFFFF, 0x313438),
        luz: Tono(0xE9F0F5, 0x95A0AA),
        acento: Tono(0x3D4958, 0xC7D2DE), sobreAcento: Tono(0xFFFFFF, 0x0B0B0F),
        vivos: [Tono(0x95A0AB, 0x575B60), Tono(0xABB2B8, 0x5F6467), Tono(0x8993A2, 0x4C5057)],
        apagados: [Tono(0x95A0AB, 0x575B60), Tono(0xABB2B8, 0x5F6467), Tono(0x8993A2, 0x4C5057)])

    static let blanco = Tema(
        id: "blanco", nombre: "Blanco", clase: .plano, lienzo: .plano,
        soloDeNoche: false, soloDeDia: true,
        fondo: Tono(0xFDFDFD, 0xFDFDFD), tarjeta: Tono(0xF2F2F2, 0xF2F2F2),
        luz: Tono(0xFFFFFF, 0xFFFFFF),
        acento: Tono(0x1B1B1B, 0x1B1B1B), sobreAcento: Tono(0xFFFFFF, 0xFFFFFF),
        vivos: [Tono(0xFDFDFD, 0xFDFDFD), Tono(0xF7F7F7, 0xF7F7F7), Tono(0xFFFFFF, 0xFFFFFF)],
        apagados: [Tono(0xFDFDFD, 0xFDFDFD), Tono(0xF7F7F7, 0xF7F7F7), Tono(0xFFFFFF, 0xFFFFFF)])

    static let negro = Tema(
        id: "negro", nombre: "Negro puro", clase: .plano, lienzo: .plano,
        soloDeNoche: true, soloDeDia: false,
        fondo: Tono(0x000000, 0x000000), tarjeta: Tono(0x0E0E10, 0x0E0E10),
        luz: Tono(0x636363, 0x636363),
        acento: Tono(0xE8E8E8, 0xE8E8E8), sobreAcento: Tono(0x0B0B0F, 0x0B0B0F),
        vivos: [Tono(0x000000, 0x000000), Tono(0x040404, 0x040404), Tono(0x000000, 0x000000)],
        apagados: [Tono(0x000000, 0x000000), Tono(0x040404, 0x040404), Tono(0x000000, 0x000000)])

    static let todos: [Tema] = [
        .original, .foto, .estrellada, .otono, .lluvia, .tormenta,
        .nieve, .cerezo, .luciernagas, .oceano, .tesoro, .hoguera,
        .aurora, .lava, .corazones, .fiesta, .granizo, .oro,
        .fuegos, .nubes, .soleado, .niebla, .vilanos, .pompas,
        .galaxia, .papel, .kraft, .washi, .lino, .vaquero,
        .terciopelo, .marmol, .madera, .hormigon, .pizarra, .acuarela,
        .libreta, .cianotipo, .cuero, .arena, .carbono, .escarcha,
        .medianoche, .cobalto, .amatista, .fucsia, .tropical, .primavera,
        .verano, .atardecer, .lavanda, .opalo, .salvia, .neon,
        .invierno, .tomate, .mostaza, .menta, .chicle, .lima,
        .lila, .arcilla, .hueso, .klein, .cereza, .petroleo,
        .grafito, .blanco, .negro,
    ]
}
