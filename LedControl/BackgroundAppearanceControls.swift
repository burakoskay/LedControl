import SwiftUI

private enum AppearanceDefaults {
    static let backgroundSolidity = "LedControl.backgroundSolidity"
}

struct AdjustableGlassBackground: View {
    @AppStorage(AppearanceDefaults.backgroundSolidity) private var solidity = 0.0

    var body: some View {
        ZStack {
            nativeGlass
            Color(nsColor: .windowBackgroundColor)
                .opacity(clampedSolidity)
        }
    }

    @ViewBuilder
    private var nativeGlass: some View {
        if #available(macOS 26.0, *) {
            Color.clear
                .glassEffect(.clear, in: .rect(cornerRadius: 16))
        } else {
            VisualEffectBlur()
        }
    }

    private var clampedSolidity: Double {
        max(0, min(1, solidity))
    }
}

struct BackgroundAppearanceSlider: View {
    @AppStorage(AppearanceDefaults.backgroundSolidity) private var solidity = 0.0

    var body: some View {
        HStack(spacing: 8) {
            Text("Glass")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)

            Slider(value: solidityBinding, in: 0...1)
                .accessibilityLabel("Background appearance")
                .accessibilityValue(clampedSolidity < 0.5 ? "Glass" : "Solid")

            Text("Solid")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 7)
    }

    private var clampedSolidity: Double {
        max(0, min(1, solidity))
    }

    private var solidityBinding: Binding<Double> {
        Binding(
            get: { clampedSolidity },
            set: { solidity = max(0, min(1, $0)) }
        )
    }
}

struct LoginItemControl: View {
    @Binding var launchAtLogin: Bool
    @Binding var errorMessage: String?

    var body: some View {
        if #available(macOS 13.0, *) {
            Button(action: toggleLoginItem) {
                HStack {
                    Image(systemName: "arrow.right.circle")
                        .font(.system(size: 12))
                    Text("Open at Login")
                        .font(.system(size: 13))
                    Spacer()
                    if launchAtLogin {
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color.accentColor)
                    }
                }
                .contentShape(Rectangle())
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
            .buttonStyle(.plain)

            if let errorMessage {
                Text(errorMessage)
                    .font(.system(size: 10))
                    .foregroundStyle(.red)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 4)
            }
        }
    }

    private func toggleLoginItem() {
        do {
            try LoginItemHelper.setEnabled(!launchAtLogin)
            launchAtLogin = LoginItemHelper.isEnabled()
            errorMessage = nil
        } catch {
            errorMessage = "Could not update Open at Login: \(error.localizedDescription)"
        }
    }
}
