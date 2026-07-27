import Cocoa
import SwiftUI
import Combine

// MARK: - LED Mode

enum LEDMode: String, CaseIterable, Identifiable {
    case off = "OFF"
    case solidColor = "SOLID"
    case rainbow = "RAINBOW"
    case breathing = "BREATHING"
    case fire = "FIRE"
    case chase = "CHASE"
    case gradient = "GRADIENT"
    case colorCycle = "COLORCYCLE"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .off: return "Off"
        case .solidColor: return "Solid"
        case .rainbow: return "Rainbow"
        case .breathing: return "Breathe"
        case .fire: return "Fire"
        case .chase: return "Chase"
        case .gradient: return "Gradient"
        case .colorCycle: return "Cycle"
        }
    }

    var icon: String {
        switch self {
        case .off: return "power"
        case .solidColor: return "circle.fill"
        case .rainbow: return "rainbow"
        case .breathing: return "wave.3.forward"
        case .fire: return "flame.fill"
        case .chase: return "bolt.fill"
        case .gradient: return "paintpalette.fill"
        case .colorCycle: return "arrow.triangle.2.circlepath"
        }
    }

    static var effects: [LEDMode] {
        [.rainbow, .breathing, .fire, .chase, .gradient, .colorCycle]
    }
}

// MARK: - Preset Color

struct PresetColor: Codable, Identifiable, Equatable {
    let id: UUID
    let red: Double
    let green: Double
    let blue: Double

    init(red: Double, green: Double, blue: Double) {
        self.id = UUID()
        self.red = red
        self.green = green
        self.blue = blue
    }

    var color: Color {
        Color(red: red, green: green, blue: blue)
    }

    static let defaults: [PresetColor] = [
        PresetColor(red: 1.0, green: 0.23, blue: 0.19),   // Red
        PresetColor(red: 1.0, green: 0.58, blue: 0.0),    // Orange
        PresetColor(red: 1.0, green: 0.84, blue: 0.0),    // Yellow
        PresetColor(red: 0.20, green: 0.78, blue: 0.35),   // Green
        PresetColor(red: 0.0, green: 0.68, blue: 1.0),    // Blue
        PresetColor(red: 0.69, green: 0.32, blue: 0.87),   // Purple
        PresetColor(red: 1.0, green: 0.40, blue: 0.68),   // Pink
        PresetColor(red: 1.0, green: 1.0, blue: 1.0)      // White
    ]
}

// MARK: - LED Manager

class LEDManager: NSObject, ObservableObject, ORSSerialPortDelegate {

    static let shared = LEDManager()

    // MARK: Published State

    @Published var isConnected = false
    @Published var connectedPortName = ""
    @Published var currentMode: LEDMode = .off
    // Store RGB as concrete doubles — never derive from SwiftUI Color
    @Published var colorR: Double = 1.0
    @Published var colorG: Double = 1.0
    @Published var colorB: Double = 1.0
    @Published var brightness: Double = 0.75
    @Published var speed: Double = 0.5
    @Published var isOn = false
    @Published var availablePorts: [ORSSerialPort] = []
    @Published var presets: [PresetColor] = PresetColor.defaults
    @Published private(set) var connectionMessage = "Not Connected"
    @Published private(set) var lastError: String?

    /// Derived SwiftUI Color for display only — never used for serial commands
    var displayColor: Color {
        Color(red: colorR, green: colorG, blue: colorB)
    }

    /// CGColor binding for ColorPicker
    var cgColor: CGColor {
        get {
            CGColor(srgbRed: colorR, green: colorG, blue: colorB, alpha: 1.0)
        }
        set {
            guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
                  let converted = newValue.converted(
                to: colorSpace,
                intent: .defaultIntent,
                options: nil
            ) else { return }
            let components = converted.components ?? [1, 1, 1, 1]
            colorR = max(0, min(1, Double(components[0])))
            colorG = max(0, min(1, Double(components.count > 1 ? components[1] : 0)))
            colorB = max(0, min(1, Double(components.count > 2 ? components[2] : 0)))
        }
    }

    // MARK: Private

    private let portManager = ORSSerialPortManager.shared()
    private var selectedPort: ORSSerialPort?
    private var cancellables = Set<AnyCancellable>()
    private var receiveBuffer = Data()
    private var handshakeRetry: DispatchWorkItem?
    private var handshakeTimeout: DispatchWorkItem?

    // UserDefaults keys
    private let kBrightness = "led_brightness"
    private let kColorR = "led_color_r"
    private let kColorG = "led_color_g"
    private let kColorB = "led_color_b"
    private let kSpeed = "led_speed"
    private let kPresets = "led_presets"
    private let kLastMode = "led_last_mode"
    private let kLastPortPath = "led_last_port"

    // MARK: Init

    override init() {
        super.init()

        loadPersistedState()
        refreshPorts()

        NotificationCenter.default.addObserver(
            self, selector: #selector(portsChanged(_:)),
            name: .ORSSerialPortsWereConnected, object: nil
        )
        NotificationCenter.default.addObserver(
            self, selector: #selector(portsChanged(_:)),
            name: .ORSSerialPortsWereDisconnected, object: nil
        )

        autoConnect()

        // Throttle color changes — sends latest value every 100ms
        // (9600 baud can handle ~960 bytes/sec, each command ~15 bytes,
        // so ~64 commands/sec max. 100ms = 10/sec is very safe.)
        Publishers.CombineLatest3($colorR, $colorG, $colorB)
            .dropFirst()
            .throttle(for: .milliseconds(100), scheduler: RunLoop.main, latest: true)
            .sink { [weak self] _, _, _ in
                guard let self, self.currentMode == .solidColor, self.isOn else { return }
                self.sendCurrentColor()
            }
            .store(in: &cancellables)

        $brightness
            .dropFirst()
            .throttle(for: .milliseconds(100), scheduler: RunLoop.main, latest: true)
            .sink { [weak self] _ in
                guard let self, self.isOn else { return }
                if self.currentMode == .solidColor {
                    self.sendCurrentColor()
                } else {
                    self.sendBrightnessOnly()
                }
            }
            .store(in: &cancellables)

        $speed
            .dropFirst()
            .throttle(for: .milliseconds(100), scheduler: RunLoop.main, latest: true)
            .sink { [weak self] _ in
                guard let self, self.isOn, LEDMode.effects.contains(self.currentMode) else { return }
                self.sendSpeed()
                self.persistState()
            }
            .store(in: &cancellables)
    }

    // MARK: - Persistence

    private func loadPersistedState() {
        let defaults = UserDefaults.standard
        if defaults.object(forKey: kBrightness) != nil {
            brightness = defaults.double(forKey: kBrightness)
        }
        if defaults.object(forKey: kSpeed) != nil {
            speed = defaults.double(forKey: kSpeed)
        }
        colorR = defaults.object(forKey: kColorR) != nil ? defaults.double(forKey: kColorR) : 1.0
        colorG = defaults.object(forKey: kColorG) != nil ? defaults.double(forKey: kColorG) : 1.0
        colorB = defaults.object(forKey: kColorB) != nil ? defaults.double(forKey: kColorB) : 1.0

        if let data = defaults.data(forKey: kPresets) {
            do {
                presets = try JSONDecoder().decode([PresetColor].self, from: data)
            } catch {
                lastError = "Saved presets could not be read and were reset."
                defaults.removeObject(forKey: kPresets)
            }
        }
    }

    private func persistState() {
        let defaults = UserDefaults.standard
        defaults.set(brightness, forKey: kBrightness)
        defaults.set(speed, forKey: kSpeed)
        defaults.set(colorR, forKey: kColorR)
        defaults.set(colorG, forKey: kColorG)
        defaults.set(colorB, forKey: kColorB)
        defaults.set(currentMode.rawValue, forKey: kLastMode)

        do {
            defaults.set(try JSONEncoder().encode(presets), forKey: kPresets)
        } catch {
            lastError = "Presets could not be saved."
        }
        if let path = selectedPort?.path {
            defaults.set(path, forKey: kLastPortPath)
        }
    }

    // MARK: - Port Management

    func refreshPorts() {
        availablePorts = portManager.availablePorts
    }

    func connect(to port: ORSSerialPort) {
        disconnect()
        selectedPort = port
        port.delegate = self
        port.baudRate = 9600
        connectionMessage = "Opening \(port.name)…"
        lastError = nil
        port.open()
    }

    func disconnect() {
        cancelHandshake()
        receiveBuffer.removeAll(keepingCapacity: false)
        selectedPort?.close()
        selectedPort?.delegate = nil
        selectedPort = nil
        isConnected = false
        connectedPortName = ""
        connectionMessage = "Not Connected"
    }

    private func autoConnect() {
        let lastPath = UserDefaults.standard.string(forKey: kLastPortPath)
        if let lastPath,
           let port = availablePorts.first(where: { $0.path == lastPath }) {
            connect(to: port)
            return
        }
    }

    @objc private func portsChanged(_ notification: Notification) {
        refreshPorts()
        if selectedPort == nil || !(selectedPort?.isOpen ?? false) {
            autoConnect()
        }
    }

    // MARK: - LED Control

    func turnOn() {
        isOn = true
        if currentMode == .off {
            currentMode = .solidColor
        }
        sendCurrentState()
        persistState()
    }

    func turnOff() {
        isOn = false
        currentMode = .off
        sendCommand("OFF")
        persistState()
    }

    func toggle() {
        if isOn { turnOff() } else { turnOn() }
    }

    func setEffect(_ mode: LEDMode) {
        isOn = true
        currentMode = mode
        if mode == .solidColor {
            sendCurrentColor()
        } else {
            // For effects that use the stored color (breathing, chase, gradient),
            // send the current color first so Arduino knows what to use
            let colorEffects: [LEDMode] = [.breathing, .chase, .gradient]
            if colorEffects.contains(mode) {
                sendCommand(
                    LEDProtocolCodec.storedColorCommand(red: colorR, green: colorG, blue: colorB)
                )
            }
            sendSpeed()
            sendCommand(mode.rawValue)
        }
        persistState()
    }

    func setColorRGB(red: Double, green: Double, blue: Double) {
        colorR = red
        colorG = green
        colorB = blue
        isOn = true
        currentMode = .solidColor
        sendCurrentColor()
        persistState()
    }

    func setPresetColor(_ preset: PresetColor) {
        setColorRGB(red: preset.red, green: preset.green, blue: preset.blue)
    }

    func saveCurrentAsPreset() {
        let preset = PresetColor(red: colorR, green: colorG, blue: colorB)
        presets.append(preset)
        persistState()
    }

    func removePreset(_ preset: PresetColor) {
        presets.removeAll { $0.id == preset.id }
        persistState()
    }

    // MARK: - Serial Communication

    private func sendCurrentState() {
        if currentMode == .solidColor {
            sendCurrentColor()
        } else if currentMode != .off {
            sendCommand(currentMode.rawValue)
        }
    }

    private func sendCurrentColor() {
        sendCommand(
            LEDProtocolCodec.colorCommand(
                brightness: brightness,
                red: colorR,
                green: colorG,
                blue: colorB
            )
        )
    }

    private func sendSpeed() {
        sendCommand(LEDProtocolCodec.speedCommand(speed))
    }

    private func sendBrightnessOnly() {
        sendCommand(LEDProtocolCodec.brightnessCommand(brightness))
    }

    private func sendCommand(_ command: String) {
        guard isConnected, let port = selectedPort, port.isOpen else {
            lastError = "Choose and connect an LED controller first."
            return
        }
        sendRawCommand(command, through: port)
    }

    private func sendRawCommand(_ command: String, through port: ORSSerialPort) {
        port.send(Data("\(command)\n".utf8))
    }

    private func cancelHandshake() {
        handshakeRetry?.cancel()
        handshakeRetry = nil
        handshakeTimeout?.cancel()
        handshakeTimeout = nil
    }

    private func scheduleHandshakeAttempt(on port: ORSSerialPort, after delay: TimeInterval) {
        let retry = DispatchWorkItem { [weak self, weak port] in
            guard let self,
                  let port,
                  self.selectedPort === port,
                  port.isOpen,
                  !self.isConnected else { return }
            self.sendRawCommand(LEDProtocolCodec.handshakeRequest, through: port)
            self.scheduleHandshakeAttempt(on: port, after: 0.75)
        }
        handshakeRetry = retry
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: retry)
    }

    // MARK: - ORSSerialPortDelegate

    func serialPortWasOpened(_ serialPort: ORSSerialPort) {
        DispatchQueue.main.async { [weak self, weak serialPort] in
            guard let self, let serialPort else { return }
            self.connectionMessage = "Verifying \(serialPort.name)…"
            self.cancelHandshake()
            // Opening an Arduino serial port toggles DTR and resets the board. Retry long enough
            // for the bootloader and firmware setup to finish instead of losing one early HELLO.
            self.scheduleHandshakeAttempt(on: serialPort, after: 0.25)

            let timeout = DispatchWorkItem { [weak self, weak serialPort] in
                guard let self, let serialPort, !self.isConnected else { return }
                self.cancelHandshake()
                self.lastError = "No compatible LED controller responded on \(serialPort.name)."
                self.connectionMessage = "Incompatible Device"
                serialPort.close()
            }
            self.handshakeTimeout = timeout
            DispatchQueue.main.asyncAfter(deadline: .now() + 6, execute: timeout)
        }
    }

    func serialPortWasClosed(_ serialPort: ORSSerialPort) {
        DispatchQueue.main.async {
            self.isConnected = false
            self.connectedPortName = ""
            if self.connectionMessage != "Incompatible Device" {
                self.connectionMessage = "Not Connected"
            }
        }
    }

    func serialPort(_ serialPort: ORSSerialPort, didReceive data: Data) {
        receiveBuffer.append(data)
        while let newlineIndex = receiveBuffer.firstIndex(of: 0x0A) {
            let lineData = receiveBuffer[..<newlineIndex]
            receiveBuffer.removeSubrange(...newlineIndex)
            guard let decodedLine = String(bytes: lineData, encoding: .utf8) else {
                lastError = "The controller returned an invalid response."
                continue
            }
            let line = decodedLine.trimmingCharacters(in: .whitespacesAndNewlines)
            if line == LEDProtocolCodec.handshakeResponse {
                cancelHandshake()
                isConnected = true
                connectedPortName = serialPort.name
                connectionMessage = serialPort.name
                lastError = nil
                persistState()
            }
        }
    }

    func serialPort(_ serialPort: ORSSerialPort, didEncounterError error: Error) {
        DispatchQueue.main.async {
            self.isConnected = false
            self.connectionMessage = "Connection Error"
            self.lastError = "Serial connection failed: \(error.localizedDescription)"
        }
    }

    func serialPortWasRemovedFromSystem(_ serialPort: ORSSerialPort) {
        DispatchQueue.main.async {
            if serialPort == self.selectedPort {
                self.selectedPort = nil
                self.isConnected = false
                self.connectedPortName = ""
                self.connectionMessage = "Device Removed"
                self.lastError = "The LED controller was disconnected."
            }
            self.refreshPorts()
        }
    }
}
