#if MAQUETA
import SwiftUI
import WidgetKit
#if canImport(PiezasWidget)
import PiezasWidget
#endif

struct PantallaVistaWidget: View {
    private var instantanea: Instantanea? {
        Maqueta.respuesta("api/prevision").flatMap { Instantanea(json: $0) }
    }

    private var oculto: Bool { Privacidad.compartida.oculta }

    var body: some View {
        ScrollView {
            VStack(spacing: Diseno.hueco4) {
                bloqueada
                inicio
            }
            .padding(.horizontal, Diseno.margen)
            .padding(.vertical, Diseno.hueco3)
        }
        .fondoDePantalla()
        .navigationTitle("Widget")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var bloqueada: some View {
        VStack(spacing: 6) {
            VistaWidget(instantanea, oculto: oculto, forma: .linea)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
            Text("9:41")
                .font(.system(size: 92, weight: .semibold, design: .rounded))
            HStack(spacing: 10) {
                VistaWidget(instantanea, oculto: oculto, forma: .circular)
                    .frame(width: 72, height: 72)
                VistaWidget(instantanea, oculto: oculto, forma: .rectangular)
                    .frame(width: 172, height: 76)
            }
        }
        .foregroundStyle(.white)
        .saturation(0)
        .environment(\.colorScheme, .dark)
        .padding(.vertical, Diseno.hueco4)
        .frame(maxWidth: .infinity)
        .background {
            LinearGradient(colors: [Color(red: 0.16, green: 0.20, blue: 0.42),
                                    Color(red: 0.34, green: 0.18, blue: 0.40),
                                    Color(red: 0.05, green: 0.05, blue: 0.09)],
                           startPoint: .top, endPoint: .bottom)
        }
        .clipShape(.rect(cornerRadius: 34, style: .continuous))
    }

    private var inicio: some View {
        HStack {
            VistaWidget(instantanea, oculto: oculto, forma: .pequeno)
                .padding(16)
                .frame(width: 170, height: 170)
                .background {
                    ZStack {
                        Color(uiColor: .systemBackground)
                        LinearGradient(colors: [(instantanea?.tono ?? .gris).color.opacity(0.24),
                                                .clear],
                                       startPoint: .topLeading, endPoint: .bottomTrailing)
                    }
                }
                .clipShape(.rect(cornerRadius: 22, style: .continuous))
                .shadow(color: .black.opacity(0.18), radius: 10, y: 4)
            Spacer(minLength: 0)
        }
        .padding(Diseno.hueco3)
        .frame(maxWidth: .infinity)
        .background {
            LinearGradient(colors: [Color(red: 0.55, green: 0.78, blue: 0.95),
                                    Color(red: 0.80, green: 0.70, blue: 0.93)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        }
        .clipShape(.rect(cornerRadius: 34, style: .continuous))
    }
}
#endif
