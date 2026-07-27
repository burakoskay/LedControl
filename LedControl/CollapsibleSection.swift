import SwiftUI

struct PanelContentHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value += nextValue()
    }
}

extension View {
    func reportPanelContentHeight() -> some View {
        background {
            GeometryReader { geometry in
                Color.clear.preference(
                    key: PanelContentHeightPreferenceKey.self,
                    value: geometry.size.height
                )
            }
        }
    }

    func onPanelContentHeightChange(_ action: @escaping (CGFloat) -> Void) -> some View {
        onPreferenceChange(PanelContentHeightPreferenceKey.self) { measuredHeight in
            action(measuredHeight + 2)
        }
    }
}

struct CollapsibleSection<Accessory: View, Content: View>: View {
    let title: String
    @Binding var isExpanded: Bool
    @ViewBuilder let accessory: Accessory
    @ViewBuilder let content: Content

    init(
        title: String,
        isExpanded: Binding<Bool>,
        @ViewBuilder accessory: () -> Accessory,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        _isExpanded = isExpanded
        self.accessory = accessory()
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Button(action: toggle) {
                    Text(title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                accessory

                Button(action: toggle) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.tertiary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        .frame(width: 16, height: 16)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isExpanded ? "Collapse \(title)" : "Expand \(title)")
            }
            .padding(.horizontal, 16)
            .frame(height: 44)

            if isExpanded {
                content
                    .padding(.bottom, 10)
            }
        }
    }

    private func toggle() {
        isExpanded.toggle()
    }
}

extension CollapsibleSection where Accessory == EmptyView {
    init(
        title: String,
        isExpanded: Binding<Bool>,
        @ViewBuilder content: () -> Content
    ) {
        self.init(
            title: title,
            isExpanded: isExpanded,
            accessory: { EmptyView() },
            content: content
        )
    }
}
