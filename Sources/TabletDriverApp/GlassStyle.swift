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
        if prominent {
            self.buttonStyle(.borderedProminent)
        } else {
            self.buttonStyle(.bordered)
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
                content
            }
            .padding(.horizontal, 28)
            .padding(.top, 8)
            .padding(.bottom, 28)
        }
        .scrollContentBackground(.hidden)
        .navigationTitle(title)
    }
}
