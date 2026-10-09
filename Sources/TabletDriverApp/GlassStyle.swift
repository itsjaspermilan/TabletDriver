import SwiftUI

extension View {
    @ViewBuilder
    func glassCard(cornerRadius: CGFloat = 22, tint: Color? = nil) -> some View {
        if #available(macOS 26, *) {
            self.glassEffect(
                tint.map { Glass.regular.tint($0.opacity(0.25)) } ?? .regular,
                in: .rect(cornerRadius: cornerRadius)
            )
        } else {
            self
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(.white.opacity(0.12), lineWidth: 0.5)
                )
        }
    }

    @ViewBuilder
    func glassButton(prominent: Bool = false) -> some View {
        if #available(macOS 26, *) {
            if prominent {
                self.buttonStyle(.glassProminent)
            } else {
                self.buttonStyle(.glass)
            }
        } else {
            if prominent {
                self.buttonStyle(.borderedProminent)
            } else {
                self.buttonStyle(.bordered)
            }
        }
    }
}

struct GlassContainer<Content: View>: View {
    var spacing: CGFloat = 16
    @ViewBuilder let content: Content

    var body: some View {
        if #available(macOS 26, *) {
            GlassEffectContainer(spacing: spacing) { content }
        } else {
            content
        }
    }
}

/// Soft colored light behind the content so glass surfaces have something
/// to refract.
struct AmbientBackground: View {
    var body: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor)
            Circle()
                .fill(Color.indigo.opacity(0.35))
                .frame(width: 380, height: 380)
                .blur(radius: 90)
                .offset(x: -180, y: -170)
            Circle()
                .fill(Color.cyan.opacity(0.25))
                .frame(width: 320, height: 320)
                .blur(radius: 90)
                .offset(x: 230, y: 40)
            Circle()
                .fill(Color.pink.opacity(0.18))
                .frame(width: 300, height: 300)
                .blur(radius: 100)
                .offset(x: -40, y: 260)
        }
        .ignoresSafeArea()
    }
}

struct CardSection<Content: View>: View {
    let title: String
    var systemImage: String?
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label {
                Text(title).font(.headline)
            } icon: {
                if let systemImage {
                    Image(systemName: systemImage).foregroundStyle(.tint)
                }
            }
            content
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }
}

struct PageScaffold<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(title)
                    .font(.largeTitle.weight(.bold))
                    .padding(.bottom, 4)
                content
            }
            .padding(.horizontal, 28)
            .padding(.top, 8)
            .padding(.bottom, 28)
        }
        .scrollContentBackground(.hidden)
    }
}
