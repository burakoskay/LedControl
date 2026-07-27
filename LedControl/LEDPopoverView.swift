import SwiftUI

// MARK: - Main Popover View

struct LEDPopoverView: View {
    @ObservedObject var manager: LEDManager
    @State private var showPortPicker = false
    @State private var hoveringEffect: LEDMode?
    @State private var hoveringPreset: UUID?
    @State private var editingPresets = false
    @State private var launchAtLogin = LoginItemHelper.isEnabled()
    @State private var loginItemError: String?

    var body: some View {
        VStack(spacing: 0) {
            connectionHeader
            Divider()

            ScrollView {
                VStack(spacing: 16) {
                    powerAndPreview
                        .padding(.top, 12)
                    colorPickerSection
                    brightnessSection
                    Divider().padding(.horizontal)
                    effectsSection
                    if manager.isOn && LEDMode.effects.contains(manager.currentMode) {
                        speedSection
                    }
                    Divider().padding(.horizontal)
                    presetsSection
                }
                .padding(.bottom, 12)
            }

            Divider()
            footerSection
        }
        .frame(width: 300)
        .background(.ultraThinMaterial)
    }

    // MARK: - Connection Header

    private var connectionHeader: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(manager.isConnected ? Color.green : Color.red.opacity(0.7))
                .frame(width: 8, height: 8)
                .shadow(color: manager.isConnected ? .green.opacity(0.5) : .clear, radius: 4)

            VStack(alignment: .leading, spacing: 2) {
                Text(manager.connectionMessage)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                if let errorMessage = manager.lastError {
                    Text(errorMessage)
                        .font(.system(size: 10))
                        .foregroundStyle(.red)
                        .lineLimit(2)
                }
            }

            Spacer()

            if manager.isConnected {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.system(size: 10))
                    .foregroundStyle(.green)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - Power + Color Preview

    private var powerAndPreview: some View {
        HStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(manager.isOn ? manager.displayColor.opacity(0.3) : Color.clear)
                    .frame(width: 80, height: 80)
                    .blur(radius: 12)

                Circle()
                    .fill(
                        manager.isOn
                            ? AnyShapeStyle(manager.displayColor)
                            : AnyShapeStyle(Color.gray.opacity(0.3))
                    )
                    .frame(width: 60, height: 60)
                    .overlay(
                        Circle()
                            .strokeBorder(.white.opacity(0.2), lineWidth: 1)
                    )
                    .shadow(color: manager.isOn ? manager.displayColor.opacity(0.4) : .clear, radius: 8)
            }
            .animation(.easeInOut(duration: 0.3), value: manager.isOn)
            .animation(.easeInOut(duration: 0.3), value: manager.currentMode)

            VStack(alignment: .leading, spacing: 6) {
                Text(manager.isOn ? manager.currentMode.displayName : "Off")
                    .font(.system(size: 18, weight: .semibold))

                Text(manager.isOn ? "Brightness \(Int(manager.brightness * 100))%" : "Tap power to turn on")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                withAnimation(.spring(response: 0.3)) {
                    manager.toggle()
                }
            } label: {
                Image(systemName: "power")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(manager.isOn ? .white : .secondary)
                    .frame(width: 44, height: 44)
                    .background(
                        Circle()
                            .fill(manager.isOn ? Color.accentColor : Color.gray.opacity(0.15))
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Color Picker (uses CGColor binding for deterministic RGB)

    private var colorPickerSection: some View {
        let colorBinding = Binding<CGColor>(
            get: { manager.cgColor },
            set: { newValue in
                manager.cgColor = newValue
                if manager.isOn && manager.currentMode != .solidColor {
                    manager.setEffect(.solidColor)
                } else if !manager.isOn {
                    manager.turnOn()
                    manager.setEffect(.solidColor)
                }
            }
        )

        return HStack {
            Text("Color")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
            Spacer()
            ColorPicker("", selection: colorBinding, supportsOpacity: false)
                .labelsHidden()
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Brightness Slider

    private var brightnessSection: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "sun.min.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)

                Slider(value: $manager.brightness, in: 0.01...1.0)
                    .tint(manager.displayColor)

                Image(systemName: "sun.max.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)

                Text("\(Int(manager.brightness * 100))%")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .frame(width: 36, alignment: .trailing)
            }
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Effects Grid

    private var effectsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Effects")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                ForEach(LEDMode.effects) { mode in
                    effectButton(mode)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private func effectButton(_ mode: LEDMode) -> some View {
        let isActive = manager.isOn && manager.currentMode == mode
        let isHovering = hoveringEffect == mode

        return Button {
            withAnimation(.spring(response: 0.3)) {
                if isActive {
                    manager.setEffect(.solidColor)
                } else {
                    manager.setEffect(mode)
                }
            }
        } label: {
            VStack(spacing: 6) {
                Image(systemName: mode.icon)
                    .font(.system(size: 16, weight: .medium))
                    .symbolRenderingMode(isActive ? .multicolor : .monochrome)

                Text(mode.displayName)
                    .font(.system(size: 10, weight: .medium))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isActive
                        ? Color.accentColor.opacity(0.2)
                        : isHovering
                            ? Color.primary.opacity(0.06)
                            : Color.primary.opacity(0.03))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(isActive ? Color.accentColor.opacity(0.4) : Color.clear, lineWidth: 1)
            )
            .foregroundStyle(isActive ? Color.accentColor : .primary)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            hoveringEffect = hovering ? mode : nil
        }
    }

    // MARK: - Speed Slider

    private var speedSection: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "tortoise.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)

                Slider(value: $manager.speed, in: 0.0...1.0)
                    .tint(Color.accentColor)

                Image(systemName: "hare.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)

                Text("\(Int(manager.speed * 100))%")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .frame(width: 36, alignment: .trailing)
            }
        }
        .padding(.horizontal, 16)
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    // MARK: - Presets

    private var presetsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Presets")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
                Spacer()
                if manager.presets.count > PresetColor.defaults.count {
                    Button {
                        withAnimation { editingPresets.toggle() }
                    } label: {
                        Text(editingPresets ? "Done" : "Edit")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(manager.presets) { preset in
                        presetDot(preset)
                    }

                    Button {
                        withAnimation(.spring(response: 0.3)) {
                            manager.saveCurrentAsPreset()
                        }
                    } label: {
                        ZStack {
                            Circle()
                                .strokeBorder(Color.primary.opacity(0.2), style: StrokeStyle(lineWidth: 1.5, dash: [3, 3]))
                                .frame(width: 28, height: 28)
                            Image(systemName: "plus")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
        }
    }

    private func presetDot(_ preset: PresetColor) -> some View {
        let isHovering = hoveringPreset == preset.id
        let isDefaultPreset = PresetColor.defaults.contains {
            $0.red == preset.red && $0.green == preset.green && $0.blue == preset.blue
        }

        return Button {
            withAnimation(.spring(response: 0.3)) {
                manager.setPresetColor(preset)
            }
        } label: {
            Circle()
                .fill(preset.color)
                .frame(width: 28, height: 28)
                .overlay(
                    Circle()
                        .strokeBorder(.white.opacity(0.3), lineWidth: 1)
                )
                .shadow(color: isHovering ? preset.color.opacity(0.5) : .clear, radius: 6)
                .scaleEffect(isHovering ? 1.12 : 1.0)
                .animation(.easeInOut(duration: 0.15), value: isHovering)
        }
        .buttonStyle(.plain)
        .frame(width: 34, height: 34)
        .overlay(alignment: .topTrailing) {
            if editingPresets && !isDefaultPreset {
                Button {
                    withAnimation { manager.removePreset(preset) }
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.white, .red)
                }
                .buttonStyle(.plain)
            }
        }
        .onHover { hovering in
            hoveringPreset = hovering ? preset.id : nil
        }
    }

    // MARK: - Footer

    private var footerSection: some View {
        VStack(spacing: 0) {
            Button {
                showPortPicker.toggle()
            } label: {
                HStack {
                    Image(systemName: "cable.connector")
                        .font(.system(size: 12))
                    Text("Serial Ports")
                        .font(.system(size: 13))
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
                .contentShape(Rectangle())
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showPortPicker, arrowEdge: .trailing) {
                portPickerPopover
            }

            if #available(macOS 13.0, *) {
                Button {
                    do {
                        try LoginItemHelper.setEnabled(!launchAtLogin)
                        launchAtLogin = LoginItemHelper.isEnabled()
                        loginItemError = nil
                    } catch {
                        loginItemError = "Could not update Open at Login: \(error.localizedDescription)"
                    }
                } label: {
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
                if let loginItemError {
                    Text(loginItemError)
                        .font(.system(size: 10))
                        .foregroundStyle(.red)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 4)
                }
            }

            Divider().padding(.horizontal, 8)

            Button {
                manager.disconnect()
                NSApplication.shared.terminate(nil)
            } label: {
                HStack {
                    Image(systemName: "xmark.circle")
                        .font(.system(size: 12))
                    Text("Quit")
                        .font(.system(size: 13))
                    Spacer()
                    Text("\u{2318}Q")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.tertiary)
                }
                .contentShape(Rectangle())
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
            .buttonStyle(.plain)
            .keyboardShortcut("q", modifiers: .command)
        }
        .padding(.vertical, 4)
    }

    // MARK: - Port Picker Popover

    private var portPickerPopover: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Serial Ports")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.top, 8)

            if manager.availablePorts.isEmpty {
                Text("No ports available")
                    .font(.system(size: 12))
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
            } else {
                ForEach(Array(manager.availablePorts.enumerated()), id: \.offset) { _, port in
                    let portName = port.name
                    let portPath = port.path
                    Button {
                        manager.connect(to: port)
                        showPortPicker = false
                    } label: {
                        HStack {
                            Text(portName)
                                .font(.system(size: 12))
                            Spacer()
                            if portPath == manager.availablePorts.first(where: { $0.name == manager.connectedPortName })?.path {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(Color.accentColor)
                            }
                        }
                        .contentShape(Rectangle())
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                    }
                    .buttonStyle(.plain)
                }
            }

            Divider().padding(.horizontal, 4)

            Button {
                manager.refreshPorts()
            } label: {
                HStack {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 10))
                    Text("Refresh")
                        .font(.system(size: 12))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
            }
            .buttonStyle(.plain)
            .padding(.bottom, 4)
        }
        .frame(width: 220)
    }
}
