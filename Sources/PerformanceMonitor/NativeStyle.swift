import SwiftUI

extension Resource {
    var symbol: String {
        switch self {
        case .cpu: return "cpu"
        case .memory: return "memorychip"
        case .disk: return "internaldrive"
        case .network: return "network"
        case .gpu: return "square.3.layers.3d"
        }
    }
}

struct MonitorSurface: ViewModifier {
    @Environment(\.colorScheme) private var scheme
    func body(content: Content) -> some View {
        content
            .background(Color(nsColor: .controlBackgroundColor).opacity(scheme == .dark ? 0.7 : 0.85), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay { RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(.primary.opacity(scheme == .dark ? 0.07 : 0.05), lineWidth: 0.5) }
            .shadow(color: .black.opacity(scheme == .dark ? 0.05 : 0.025), radius: 8, y: 3)
    }
}

extension View {
    func monitorSurface() -> some View { modifier(MonitorSurface()) }
    @ViewBuilder func statusGlass() -> some View {
        if #available(macOS 26.0, *) { glassEffect(.regular, in: .capsule) }
        else { background(.regularMaterial, in: Capsule()) }
    }
}

struct LiveStatus: View {
    let paused: Bool
    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(paused ? .orange : .green).frame(width: 6, height: 6)
            Text(paused ? "Pausado" : "Ao vivo").font(.system(size: 11, weight: .medium))
        }.padding(.horizontal, 12).padding(.vertical, 7).statusGlass()
            .accessibilityLabel(paused ? "Monitoramento pausado" : "Monitoramento em tempo real")
    }
}
